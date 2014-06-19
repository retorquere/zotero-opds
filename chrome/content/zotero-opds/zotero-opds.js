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
    Zotero.OPDS.log('Initializing...');
    Zotero.OPDS.xslt.async = false;
    var stylesheet = Zotero.File.getContentsFromURL('resource://zotero-opds/indent.xslt');
    Zotero.OPDS.log('stylesheet: ' + stylesheet);
    stylesheet = Zotero.OPDS.parser.parseFromString(stylesheet, 'text/xml');
    try {
      Zotero.OPDS.xslt.importStylesheet(stylesheet.documentElement);
    } catch (e) {
      Zotero.OPDS.log('could not load stylesheet: ' + e);
    }

    Zotero.OPDS.log('Endpoints...');
    */

    for (var endpoint of Object.keys(Zotero.OPDS.endpoints)) {
      var url = "/opds/" + endpoint;
      Zotero.OPDS.log('Registering endpoint ' + url);
      var ep = Zotero.Server.Endpoints[url] = function() {};
      ep.prototype = Zotero.OPDS.endpoints[endpoint];
    }
    Zotero.OPDS.log('Done!');
  },


  Feed: function(id, name) {
    this.id = id;
    this.name = name;

    this.namespace = {
      dc: 'http://purl.org/dc/terms/',
      opds: 'http://opds-spec.org/2010/catalog',
      atom: 'http://www.w3.org/2005/Atom'
    };

    this.newnode = function(name, text, namespace) {
      var node = this.doc.createElementNS(namespace || this.namespace.atom, name);
      if (text) {
        node.appendChild(Zotero.OPDS.document.createTextNode(text));
      }
      (this._root || this.doc.documentElement).appendChild(node);
      return node;
    };

    this.root = function(node) {
      this._root = node;
      return node;
    }

    this.doc = Zotero.OPDS.document.implementation.createDocument(this.namespace.atom, 'feed', null);
    this.doc.documentElement.setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns:dc', this.namespace.dc);
    this.doc.documentElement.setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns:opds', this.namespace.opds);

    this.newnode('title', this.name || 'Zotero library');
    this.newnode('subtitle', 'Your bibliography, served by Zotero-OPDS ' + Zotero.OPDS.release);
    this.root(this.newnode('author'));
      this.newnode('name', 'zotero');
      this.newnode('uri', 'https://github.com/AllThatIsTheCase/zotero-opds');
    this.root();

    this.newnode('id', 'urn:zotero-opds:' + (this.id || 'main'));
    //var link = this.newnode('link');
    //  link.setAttribute('href', '/opds');
    //  link.setAttribute('type', 'application/atom+xml');
    //  link.setAttribute('rel', 'start');

    this.item = function(group, item) {
      this.root(this.newnode('entry'));
        this.newnode('title', item.getDisplayTitle(true));
        this.newnode('id', 'zotero-opds:' + item.key);

        var abstr = item.getField('abstract');
        if (abstr && abstr.length != 0) {
          this.newnode('summary', abstr);
        }

        var attachments = [];
        if (item.isAttachment()) {
          attachments = [item];
        } else {
          attachments = item.getAttachments();
        }

        var self = this;
        attachments.forEach(function(a) {
          var link = self.newnode('link');
            link.setAttribute('rel', 'http://opds-spec.org/acquisition/open-access');
            link.setAttribute('href', '/opds/attachment?id=' + group + ':' + a.key);
            link.setAttribute('type', a.attachmentMIMEType);
        });

        /*
        var link = this.newnode('link');
          link.setAttribute('href', '/opds/item?id=' + group + ':' + item.key);
          link.setAttribute('type', 'application/atom+xml');
        */
      this.root();
    }

    this.entry = function(title, id, url) {
      this.root(this.newnode('entry'));
        this.newnode('title', title);
        this.newnode('id', 'zotero-opds:' + id);
        var link = this.newnode('link');
          link.setAttribute('href', url);
          link.setAttribute('type', 'application/atom+xml');
      this.root();
    }

    this.serialize = function() {
      return Zotero.OPDS.serializer.serializeToString(this.doc);
    }
  },

  endpoints: {
    index: {
      supportedMethods: ['GET'],

      init: function(url, data, sendResponseCallback) {
        var doc = new Zotero.OPDS.Feed();

        Zotero.getCollections().forEach(function(collection) {
          doc.entry(collection.name, collection.key, '/opds/collection?id=0:' + collection.key);
        });

        // don't forget to add saved searches

        Zotero.Groups.getAll().forEach(function(group) {
          doc.entry(group.name, group.key, '/opds/group?id=' + group.id);
        });

        sendResponseCallback(200, 'application/atom+xml', doc.serialize());
      }
    },

    attachment: {
      supportedMethods: ['GET'],

      init: function(url, data, sendResponseCallback) {
        var root = url.query.id.split(':');
        if (root.length != 2) { return sendResponseCallback(500, 'text/plain', 'Unexpected OPDS root ' + url.query.id); }

        var group = root.shift();
        var library = (group == '0' ? null : Zotero.Groups.getLibraryIDFromGroupID(group));
        root = root.shift();

        var item = Zotero.Items.getByLibraryAndKey(library, root);
        sendResponseCallback(200, item.attachmentMIMEType, Zotero.File.getBinaryContents(item.getFile()));
      }
    },

    group: {
      supportedMethods: ['GET'],

      init: function(url, data, sendResponseCallback) {
        var doc = new Zotero.OPDS.Feed();

        var group = url.query.id;
        var library = Zotero.Groups.getLibraryIDFromGroupID(library);
        var root = Zotero.Groups.getByLibraryID(library);
        collections = root.getCollections();
        root = new Zotero.ItemGroup('group', root);

        (collections || []).forEach(function(collection) {
          doc.entry(collection.name, collection.key, '/opds/collection?id=' + group + ':' + collection.key);
        });

        (root.getItems() || []).forEach(function(item) {
          doc.item(group, item);
        });

        sendResponseCallback(200, 'application/atom+xml', doc.serialize());
      }
    },

    collection: {
      supportedMethods: ['GET'],

      init: function(url, data, sendResponseCallback) {
        var doc = new Zotero.OPDS.Feed();

        var root = url.query.id.split(':');
        if (root.length != 2) { return sendResponseCallback(500, 'text/plain', 'Unexpected OPDS root ' + url.query.id); }

        var group = root.shift();
        var library = (group == '0' ? null : Zotero.Groups.getLibraryIDFromGroupID(group));
        root = root.shift();
        root =  Zotero.Collections.getByLibraryAndKey(library, root);
        collections = root.getChildCollections();
        root = new Zotero.ItemGroup('collection', root);

        (collections || []).forEach(function(collection) {
          doc.entry(collection.name, collection.key, '/opds/collection?id=' + group + ':' + collection.key);
        });

        (root.getItems() || []).forEach(function(item) {
          doc.item(group, item);
        });

        sendResponseCallback(200, 'application/atom+xml', doc.serialize());
      }
    }
  }
};

// Initialize the utility
window.addEventListener('load', function(e) { Zotero.OPDS.init(); }, false);
