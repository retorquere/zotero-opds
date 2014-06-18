Components.utils.import("resource://gre/modules/Services.jsm");

Zotero.OPDS = {
  prefs: {
    zotero: Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch("extensions.zotero."),
    bbt:    Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch("extensions.zotero.translators.opds."),
    dflt:   Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getDefaultBranch("extensions.zotero.translators.opds."),

    legacy: Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch("extensions.zotero-opds.")
  },

  embeddedKeyRE: /bibtex:\s*([^\s\r\n]+)/,
  translators: {},
  threadManager: Components.classes["@mozilla.org/thread-manager;1"].getService(),
  windowMediator: Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(Components.interfaces.nsIWindowMediator),

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
    // migrate options
    Zotero.OPDS.prefs.legacy.clearUserPref('BibLaTex.ASCII');
    Zotero.OPDS.prefs.legacy.clearUserPref('citekeyformat');
    Zotero.OPDS.prefs.legacy.clearUserPref('getCollections');
    for (var option of ['citeCommand', 'citeKeyFormat']) {
      try {
        var value = Zotero.OPDS.prefs.legacy.getCharPref(option);
        if (value) {
          Zotero.OPDS.prefs.bbt.setCharPref(option, value);
          Zotero.OPDS.prefs.legacy.clearUserPref(option);
        }
      } catch (err) {}
    }

    for (var endpoint of Object.keys(Zotero.OPDS.endpoints)) {
      var url = "/opds/" + endpoint;
      Zotero.OPDS.log('Registering endpoint ' + url);
      var ep = Zotero.Server.Endpoints[url] = function() {};
      ep.prototype = Zotero.OPDS.endpoints[endpoint];
    }

    Zotero.OPDS.config = {}
    for (var option of ['citeCommand', 'citeKeyFormat', 'fancyURLs', 'unicode']) {
      var value = null;
      try {
        value = Zotero.OPDS.prefs.bbt.getPref(option);
      } catch(err) {}
      Zotero.OPDS.config[option] = value;
    }

    Zotero.Translators.init();
  },

  displayOptions: function(url) {
    var params = {};
    var hasParams = false;

    ['exportCharset', 'exportNotes?', 'useJournalAbbreviation?'].forEach(function(key) {
      try {
        var isBool = key.match(/[?]$/);
        if (isBool) { key = key.replace(isBool[0], ''); }
        params[key] = url.query[key];
        if (isBool) { params[key] = (['y', 'yes', 'true'].indexOf(params[key].toLowerCase()) >= 0); }
        hasParams = true;
      } catch (e) {}
    });
    Zotero.OPDS.log('displayOptions = ' + JSON.stringify(params));
    return (hasParams ? params : null);
  },

  endpoints: {
    collection: {
      supportedMethods: ['GET'],

      init: function(url, data, sendResponseCallback) {
        var collection;

        try {
          collection = url.query[''];
        } catch (err) {
          collection = null;
        }

        if (!collection) {
          sendResponseCallback(501, "text/plain", "Could not export bibliography: no path");
          return;
        }

        try {
          var path = collection.split('.');

          if (path.length == 1) {
            sendResponseCallback(404, "text/plain", "Could not export bibliography '" + collection + "': no format specified");
            return;
          }
          var translator = path.pop();
          var path = path.join('.');

          var items = []

          Zotero.OPDS.log('exporting: ' + path + ' to ' + translator);
          for (var collectionkey of path.split('+')) {
            if (collectionkey.charAt(0) != '/') { collectionkey = '/0/' + collectionkey; }
            Zotero.OPDS.log('exporting ' + collectionkey);

            var path = collectionkey.split('/');
            path.shift(); // remove leading /

            var libid = parseInt(path.shift());
            if (isNaN(libid)) {
              throw('Not a valid library ID: ' + collectionkey);
            }

            var key = '' + path[0];

            var col = null;
            for (var name of path) {
              var children = Zotero.getCollections(col && col.id, false, libid);
              col = null;
              for (child of children) {
                if (child.name.toLowerCase() == name.toLowerCase()) {
                  col = child;
                  break;
                }
              }
              if (!col) { break; }
            }

            if (!col) {
              col = Zotero.Collections.getByLibraryAndKey(libid, key);
            }

            if (!col) { throw (collectionkey + ' not found'); }

            var _items = col.getChildren(Zotero.OPDS.pref('recursiveCollections', false, 'zotero'), false, 'item');
            items = items.concat(Zotero.Items.get([item.id for (item of _items)]));
          }

          sendResponseCallback(
            200,
            "text/plain",
            Zotero.OPDS.translate(
              Zotero.OPDS.getTranslator(translator),
              items,
              Zotero.OPDS.displayOptions(url)
            )
          );
        } catch (err) {
          Zotero.OPDS.log("Could not export bibliography '" + collection + "'", err);
          sendResponseCallback(404, "text/plain", "Could not export bibliography '" + collection + "': " + err);
        }
      }
    },

    library: {
      supportedMethods: ['GET'],

      init: function(url, data, sendResponseCallback) {
        var library;

        try {
          library = url.query[''];
        } catch (err) {
          library = null;
        }

        if (!library) {
          sendResponseCallback(501, "text/plain", "Could not export bibliography: no path");
          return;
        }

        try {
          var libid = 0;
          var path = library.split('/');
          if (path.length > 1) {
              path.shift(); // leading /
              libid = parseInt(path[0]);
              path.shift();

              if (!Zotero.Libraries.exists(libid)) {
                  sendResponseCallback(404, "text/plain", "Could not export bibliography: library '" + library + "' does not exist");
                  return;
              }
          }

          var path = path.join('/').split('.');

          if (path.length == 1) {
            sendResponseCallback(404, "text/plain", "Could not export bibliography '" + library + "': no format specified");
            return;
          }
          var translator = path.pop();

          sendResponseCallback(
            200,
            "text/plain",
            Zotero.OPDS.translate(
              Zotero.OPDS.getTranslator(translator),
              Zotero.Items.getAll(false, libid, false),
              Zotero.OPDS.displayOptions(url)
            )
          );
        } catch (err) {
          Zotero.OPDS.log("Could not export bibliography '" + library + "'", err);
          sendResponseCallback(404, "text/plain", "Could not export bibliography '" + library + "': " + err);
        }
      }
    }
  },

  translate: function(translator, items, displayOptions) {
    if (!translator) { throw('null translator'); }

    var translation = new Zotero.Translate.Export();
    translation.setItems(items);
    translation.setTranslator(translator);
    translation.setDisplayOptions(displayOptions);

    var status = {finished: false};

    translation.setHandler("done", function(obj, success) {
      status.success = success;
      status.finished = true;
      if (success) { status.data = obj.string; }
    });
    translation.translate();

    while (!status.finished) {}

    if (status.success) {
      return status.data;
    } else {
      throw ('export failed');
    }
  },

  safeLoad: function(translator) {
    try {
      Zotero.OPDS.load(translator);
    } catch (err) {
      Zotero.OPDS.log('Loading ' + translator + ' failed', err);
    }
  },

  load: function(translator) {
    Zotero.OPDS.log('Loading ' + translator);

    var header = null;
    var data = null;
    var start = -1;

    try {
      data = Zotero.File.getContentsFromURL('resource://zotero-opds/translators/' + translator);
      if (data) { start = data.indexOf('{'); }
      if (start >= 0) {
        let len = data.indexOf('}', start);
        if (len > 0) {
          for (len -= start; len < 3000; len++) {
            try {
              header = JSON.parse(data.substring(start, len).trim());
              // comment out header but keep linecount the same -- helps in debugging
              data = data.substring(start + len, data.length);
              break;
            } catch (err) {
            }
          }
        }
      }
    } catch (err) {
      header = null;
    }

    if (!header) {
      Zotero.OPDS.log('Loading ' + translator + ' failed: could not parse header');
      return;
    }

    //header.hiddenPrefs = {}
    //for(var pref in Zotero.OPDS.config) { header.hiddenPrefs[pref]=Zotero.OPDS.config[pref]; }

    Zotero.OPDS.translators[header.label.toLowerCase().replace(/[^a-z]/, '')] = header.translatorID;

    Zotero.OPDS.log("Installing " + header.label);
    Zotero.Translators.save(header, data);
  },

  getTranslator: function(name) {
    name = name.toLowerCase().replace(/[^a-z]/, '');
    var translator = Zotero.OPDS.translators['better' + name] || Zotero.OPDS.translators[name];
    if (!translator) { throw('No translator' + name + '; available: ' + Object.keys(Zotero.OPDS.translators).join(', ')); }
    return translator;
  },

  getCiteKeys: function(items) {
    var translator = Zotero.OPDS.getTranslator('BibTeX Citation Keys');
    if (!translator) { throw('No translator' + translator); }

    try {
      Zotero.OPDS.log('Fetching keys: for ' + items.length + ' items');
      var keys = Zotero.OPDS.translate(translator, [item for (item of items)]);
      Zotero.OPDS.log('Found keys: ' + keys);
      return JSON.parse(keys);
    } catch (err) {
      Zotero.OPDS.log('Cannot retrieve keys: ', err);
      return null;
    }
  },

  setCiteKeys: function() {
    var win = Zotero.OPDS.windowMediator.getMostRecentWindow("navigator:browser");
    var item;
    var items = win.ZoteroPane.getSelectedItems();
    items = Zotero.Items.get([item.id for (item of items)]);
    items = [item for (item of items) if (!(item.isAttachment() || item.isNote()))];

    // clear keys first so the generator can make fresh ones
    for (item of items) {
      var extra = '' + item.getField('extra');
      extra = extra .replace(/bibtex:\s*[^\s\r\n]+/, '');
      extra = extra.trim();
      item.setField('extra', extra);
      item.save();
    }

    var keys = Zotero.OPDS.getCiteKeys(items);
    if (!keys) {
      Zotero.OPDS.log('Cannot set keys');
      return;
    }

    items.forEach(function(item) {
      if (keys[item.id]) {
        Zotero.OPDS.log('Setting key for ' + item.id + ': ' + keys[item.id]);

        var extra = '' + item.getField('extra');
        extra = extra.trim();
        if (extra.length > 0) { extra += "\n"; }
        item.setField('extra', extra + 'bibtex: ' + keys[item.id]);
        item.save();
      }
    });
  }
};

// Initialize the utility
window.addEventListener('load', function(e) { Zotero.OPDS.init(); }, false);
