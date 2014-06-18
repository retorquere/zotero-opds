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

    for (var endpoint of Object.keys(Zotero.OPDS.endpoints)) {
      var url = "/opds/" + endpoint;
      Zotero.OPDS.log('Registering endpoint ' + url);
      var ep = Zotero.Server.Endpoints[url] = function() {};
      ep.prototype = Zotero.OPDS.endpoints[endpoint];
    }
    Zotero.OPDS.log('Done!');
  },

  indent: function(doc) {
    var xml = Zotero.OPDS.serializer.serializeToString(doc);
    var formatted = '';
    var reg = /(>)(<)(\/*)/g;
    xml = xml.replace(reg, '$1\r\n$2$3');
    var pad = 0;
    xml.split('\r\n').forEach(function(node) {
      var indent = 0;
      if (node.match( /.+<\/\w[^>]*>$/ )) {
          indent = 0;
      } else if (node.match( /^<\/\w/ )) {
          if (pad != 0) { pad -= 1; }
      } else if (node.match( /^<\w[^>]*[^\/]>.*$/ )) {
        indent = 1;
      } else {
        indent = 0;
      }
 
      var padding = '';
      for (var i = 0; i < pad; i++) {
        padding += '  ';
      }
 
      formatted += padding + node + '\r\n';
      pad += indent;
    });
 
    return formatted;
  },

  endpoints: {
    index: {
      supportedMethods: ['GET'],

      init: function(url, data, sendResponseCallback) {

        var dc = 'http://purl.org/dc/terms/';
        var opds = 'http://opds-spec.org/2010/catalog';
        var atom = 'http://www.w3.org/2005/Atom';

        var doc = Zotero.OPDS.document.implementation.createDocument(atom, 'feed', null);
        doc.documentElement.setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns:dc', dc);
        doc.documentElement.setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns:opds', opds);

        var newnode = function(container, name, text, namespace) {
          var node = doc.createElementNS(namespace || atom, name);
          if (text) {
            node.appendChild(Zotero.OPDS.document.createTextNode(text));
          }
          container.appendChild(node);
          return node
        }

        newnode(doc.documentElement, 'title', 'Zotero library');
        newnode(doc.documentElement, 'subtitle', 'Your bibliography, served by Zotero-OPDS ' + Zotero.OPDS.release);
        var author = newnode(doc.documentElement, 'author');
          newnode(author, 'name', 'zotero');
          newnode(author, 'uri', 'https://github.com/AllThatIsTheCase/zotero-opds');
        newnode(doc.documentElement, 'id', 'urn:zotero-opds:main');
        newnode(doc.documentElement, 'updated', '2014-06-18T08:33:09Z');
        var link = newnode(doc.documentElement, 'link');
          link.setAttribute('href', '/opds/index');
          link.setAttribute('type', 'application/atom+xml');
          link.setAttribute('rel', 'start');

        ['Date', 'Title', 'Author', 'Publisher', 'Tags'].forEach(function(sortby) {
          var entry = newnode(doc.documentElement, 'entry');
            newnode(entry, 'title', 'By ' + sortby);
            newnode(entry, 'id', 'zotero-opds:by-' + sortby.toLowerCase());
            newnode(entry, 'updated', '2014-06-18T08:33:09Z');
            newnode(entry, 'content', 'Books sorted by ' + sortby.toLowerCase());
            var link = newnode(entry, 'link');
              link.setAttribute('href', '/opds/by-' + sortby.toLowerCase());
              link.setAttribute('type', 'application/atom+xml');
        });

        sendResponseCallback(200, 'application/atom+xml', Zotero.OPDS.indent(doc));
      }
    }
  }
};

// Initialize the utility
window.addEventListener('load', function(e) { Zotero.OPDS.init(); }, false);
