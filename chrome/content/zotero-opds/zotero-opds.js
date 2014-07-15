Components.utils.import("resource://gre/modules/Services.jsm");

Zotero.OPDS = {
  document: Components.classes["@mozilla.org/xul/xul-document;1"].getService(Components.interfaces.nsIDOMDocument),
  serializer: Components.classes["@mozilla.org/xmlextras/xmlserializer;1"].createInstance(Components.interfaces.nsIDOMSerializer),
  parser: Components.classes["@mozilla.org/xmlextras/domparser;1"].createInstance(Components.interfaces.nsIDOMParser),
  xslt: Components.classes["@mozilla.org/document-transformer;1?type=xslt"].createInstance(Components.interfaces.nsIXSLTProcessor),

  prefs: {
    zotero: Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch("extensions.zotero."),
    opds:   Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch("extensions.zotero.opds."),
    dflt:   Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getDefaultBranch("extensions.zotero.opds.")
  },

  clients: {
    '127.0.0.1': true
  },

  log: function(msg, e) {
    if (typeof msg != 'string') { msg = JSON.stringify(msg); }

    msg = '[opds] ' + msg;
    if (e) {
      msg += "\nan error occurred: ";
      if (e.name) {
        msg += e.name + ": " + e.message + " \n(" + e.fileName + ", " + e.lineNumber + ")";
      } else {
        msg += e;
      }
      if (e.stack) { msg += "\n" + e.stack; }
    }
    Zotero.debug(msg);
    console.log(msg);
  },

  pref: function(key, dflt, branch) {
    branch = Zotero.OPDS.prefs[branch || 'bbt'];
    try {
      switch (typeof dflt) {
        case 'boolean':
          return branch.getBoolPref(key);
        case 'number':
          return branch.getIntPref(key);
        case 'string':
          return branch.getCharPref(key);
      }
    } catch (err) {
      return dflt;
    }
  },

  init: function () {
    /*
    Zotero.OPDS.xslt.async = false;
    var stylesheet = Zotero.File.getContentsFromURL('resource://zotero-opds/indent.xslt');
    Zotero.OPDS.log('stylesheet: ' + stylesheet);
    stylesheet = Zotero.OPDS.parser.parseFromString(stylesheet, 'text/xml');
    try {
      Zotero.OPDS.xslt.importStylesheet(stylesheet.documentElement);
    } catch (e) {
      Zotero.OPDS.log('could not load stylesheet: ' + e);
    }
    */

    Zotero.OPDS.Server = Zotero.OPDS.Server || {};
    Zotero.OPDS.Server.SocketListener = Zotero.OPDS.Server.SocketListener || {};

    Zotero.OPDS.Server.SocketListener.onSocketAccepted = Zotero.Server.SocketListener.onSocketAccepted;
    Zotero.Server.SocketListener.onSocketAccepted = function(socket, transport) {
      if (typeof Zotero.OPDS.clients[transport.host] == 'undefined') {
        Zotero.OPDS.clients[transport.host] = confirm('Client ' + transport.host + ' wants to access the Zotero embedded webserver');
      }
      if (Zotero.OPDS.clients[transport.host]) {
        Zotero.OPDS.Server.SocketListener.onSocketAccepted.apply(this, [socket, transport]);
      } else {
        socket.close();
      }
    }

    Zotero.OPDS.Server.init = Zotero.Server.init;
    Zotero.Server.init = function(port, bindAllAddr, maxConcurrentConnections) {
      Zotero.OPDS.log('Zotero server now enabled for non-localhost!');
      return Zotero.OPDS.Server.init.apply(this, [port, true, maxConcurrentConnections]);
    }

    Zotero.Server.close();
    Zotero.Server.init();

    for (var endpoint of Object.keys(Zotero.OPDS.endpoints)) {
      var url = (endpoint == 'index' ? '/opds' : '/opds/' + endpoint);
      Zotero.OPDS.log('Registering endpoint ' + url);
      var ep = Zotero.Server.Endpoints[url] = function() {};
      ep.prototype = Zotero.OPDS.endpoints[endpoint];
    }
  },

  Feed: function(name, updated, url, kind) {
    this.id = url;
    this.name = name;
    this.updated = updated;
    this.kind = kind;
    this.url = url;

    var self = this;
    ['id', 'name', 'updated', 'kind', 'url'].forEach(function(key) {
      if (!self[key]) { throw('Feed needs ' + key); }
    });

    this.rjust = function(v) {
      v = '0' + v;
      return v.slice(v.length - 2, v.length);
    }

    this.date = function(timestamp) {
      if (typeof timestamp == 'string') { timestamp = Zotero.Date.sqlToDate(timestamp); }
      return (timestamp || new Date()).toISOString();
    };

    this.namespace = {
      dc: 'http://purl.org/dc/terms/',
      opds: 'http://opds-spec.org/2010/catalog',
      atom: 'http://www.w3.org/2005/Atom'
    };

    this.comment = function(text) {
      this.stack[0].appendChild(this.doc.createComment(text));
    };

    this.newnode = function(name, text, namespace) {
      var node = this.doc.createElementNS(namespace || this.namespace.atom, name);
      if (text) {
        node.appendChild(Zotero.OPDS.document.createTextNode(text));
      }
      this.stack[0].appendChild(node);
      return node;
    };

    this.push = function(node) {
      this.stack.unshift(node);
      return node;
    }

    this.pop = function() {
      if (this.stack.length == 1) {
        return stack[0];
      }
      return this.stack.shift();
    }
    this.clearstack = function() {
      this.stack = [this.doc.documentElement];
    }

    this.doc = Zotero.OPDS.document.implementation.createDocument(this.namespace.atom, 'feed', null);
    this.clearstack();
    this.doc.documentElement.setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns:dc', this.namespace.dc);
    this.doc.documentElement.setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns:opds', this.namespace.opds);

    this.newnode('title', this.name || 'Zotero library');
    this.newnode('subtitle', 'Your bibliography, served by Zotero-OPDS ' + Zotero.OPDS.release);
    this.push(this.newnode('author'));
      this.newnode('name', 'zotero');
      this.newnode('uri', 'https://github.com/AllThatIsTheCase/zotero-opds');
    this.pop();
    this.newnode('updated', this.date(this.updated));

    this.newnode('id', 'urn:zotero-opds:' + this.id);
    var link = this.newnode('link');
      link.setAttribute('href', this.url);
      link.setAttribute('type', 'application/atom+xml;profile=opds-catalog;kind=' + this.kind);
      link.setAttribute('rel', 'self');

    this.item = function(group, item) {
      var attachments = [];
      if (item.isAttachment()) {
        attachments = [item];
      } else {
        attachments = item.getAttachments() || [];
      }
      attachments = attachments.filter(function(a) { return a.attachmentMIMEType && a.attachmentMIMEType != 'text/html'; });
      if (attachments.length == 0) { return; }

      var title = item.getDisplayTitle(true);
      this.comment('item: ' + title + ', ' + Zotero.ItemTypes.getName(item.itemTypeID));

      this.push(this.newnode('entry'));
        this.newnode('title', title);
        this.newnode('id', 'zotero-opds:' + item.key);
        this.push(this.newnode('author'));
          this.newnode('name', item.firstCreator);
        this.pop();
        this.newnode('updated', this.date(item.getField('dateModified')));

        var abstr = item.getField('abstract');
        if (abstr && abstr.length != 0) {
          this.newnode('content', abstr);
        }

        var self = this;
        attachments.forEach(function(a) {
          self.comment('attachment: ' + (a.localPath || a.defaultPath));
          var link = self.newnode('link');
            link.setAttribute('rel', 'http://opds-spec.org/acquisition');
            link.setAttribute('href', '/opds/item?id=' + group + ':' + a.key);
            link.setAttribute('type', a.attachmentMIMEType);
        });
      this.pop();
    }

    this.entry = function(title, url, updated) {
      this.comment('entry: ' + title);
      this.push(this.newnode('entry'));
        this.newnode('title', title);
        this.newnode('id', 'zotero-opds:' + url);
        var link = this.newnode('link');
          link.setAttribute('href', url);
          link.setAttribute('type', 'application/atom+xml');
        this.newnode('updated', this.date(updated));
      this.pop();
    }

    this.serialize = function() {
      return Zotero.OPDS.serializer.serializeToString(this.doc);
    }
  },

  sql: {
    index: 'select max(dateModified) from items',
    group: 'select max(dateModified) from items where libraryID = ?',
    collection: 'with recursive collectiontree (collection) as (values (?) union all select c.collectionID from collections c join collectiontree ct on c.parentCollectionID = ct.collection) select max(dateModified) from collectiontree ct join collectionItems ci on ct.collection = ci.collectionID join items i on ci.itemID = i.itemID'
  },

  buildurl: function(base, q) {
    var url = base + '?id=' + q.id;
    if (q.kind == 'acquisition') {
      url = url + '&kind=acquisition';
    }
    return url;
  },

  endpoints: {
    index: {
      supportedMethods: ['GET'],
      init: function(url, data, sendResponseCallback) {
        var updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.index);
        var doc = new Zotero.OPDS.Feed('Zotero Library', updated, '/opds', 'navigation');

        Zotero.getCollections().forEach(function(collection) {
          var updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) || collection.dateModified;
          doc.entry(collection.name, '/opds/collection?id=0:' + collection.key, updated);
        });

        // don't forget to add saved searches

        Zotero.Groups.getAll().forEach(function(group) {
          var updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.group, group.id);
          doc.entry(group.name, '/opds/group?id=' + group.id, updated);
        });

        sendResponseCallback(200, 'application/atom+xml', doc.serialize());
      }
    },

    item: {
      supportedMethods: ['GET'],
      init: function(url, data, sendResponseCallback) {
        var q = url.query.id.split(':');
        q = {group: q.shift(), item: q.shift()};
        if (!q.group || !q.item) { return sendResponseCallback(500, 'text/plain', 'Unexpected OPDS item ' + url.query.id); }

        var library = (q.group == '0' ? null : Zotero.Groups.getLibraryIDFromGroupID(q.group));

        var item = Zotero.Items.getByLibraryAndKey(library, q.item);
        sendResponseCallback(200, item.attachmentMIMEType, Zotero.File.getBinaryContents(item.getFile()));
      }
    },

    group: {
      supportedMethods: ['GET'],
      init: function(url, data, sendResponseCallback) {
        var libraryID = Zotero.Groups.getLibraryIDFromGroupID(url.query.id);
        var group = Zotero.Groups.getByLibraryID(libraryID);
        var collections = group.getCollections();
        var updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.group, libraryID)

        var doc = new Zotero.OPDS.Feed('Zotero Library Group ' + group.name, updated, Zotero.OPDS.buildurl('/opds/group', url.query), url.query.kind || 'navigation');

        if (url.query.kind == 'acquisition') {
          var items = (new Zotero.ItemGroup('group', group)).getItems();
          (items || []).forEach(function(item) {
            doc.item(url.query.id, item);
          });
        } else {
          (collections || []).forEach(function(collection) {
            var updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) || collection.dateModified;
            doc.entry(collection.name, '/opds/collection?id=' + url.query.id + ':' + collection.key, updated);
          });
          doc.entry('Items', Zotero.OPDS.buildurl('/opds/group', {id: url.query.id, kind: 'acquisition'}), updated);
        }

        sendResponseCallback(200, 'application/atom+xml', doc.serialize());
      }
    },

    collection: {
      supportedMethods: ['GET'],
      init: function(url, data, sendResponseCallback) {
        var q = url.query.id.split(':');
        q = {group: q.shift(), collection: q.shift()};
        if (!q.group || !q.collection) { return sendResponseCallback(500, 'text/plain', 'Unexpected OPDS collection ' + url.query.id); }

        var library = (q.group == '0' ? null : Zotero.Groups.getLibraryIDFromGroupID(q.group));
        var collection =  Zotero.Collections.getByLibraryAndKey(library, q.collection);
        var updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) || collection.dateModified;

        var doc = new Zotero.OPDS.Feed('Zotero Library Collection ' + collection.name, updated, Zotero.OPDS.buildurl('/opds/collection', url.query), url.query.kind || 'navigation');

        if (url.query.kind == 'acquisition') {
          items = (new Zotero.ItemGroup('collection', collection)).getItems();
          (items || []).forEach(function(item) {
            doc.item(q.group, item);
          });
        } else {
          (collection.getChildCollections() || []).forEach(function(collection) {
            var updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) || collection.dateModified;
            doc.entry(collection.name, '/opds/collection?id=' + q.group + ':' + collection.key);
          });
          doc.entry('Items', Zotero.OPDS.buildurl('/opds/collection', {id: url.query.id, kind: 'acquisition'}), updated);
        }

        sendResponseCallback(200, 'application/atom+xml', doc.serialize());
      }
    }
  }
};


// Initialize the utility
window.addEventListener('load', function(e) { Zotero.OPDS.init(); }, false);
