# Only create main object once
unless Zotero.OPDS
  loader = Components.classes["@mozilla.org/moz/jssubscript-loader;1"].getService(Components.interfaces.mozIJSSubScriptLoader)
  loader.loadSubScript("chrome://zotero-opds/content/sha.js")
  loader.loadSubScript("chrome://zotero-opds/content/qr.js")
  loader.loadSubScript("chrome://zotero-opds/content/zotero-opds.js")
  loader.loadSubScript("chrome://zotero-opds/content/version.js")
