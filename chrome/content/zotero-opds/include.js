// Only create main object once
if (!Zotero.OPDS) {
	var loader = Components.classes["@mozilla.org/moz/jssubscript-loader;1"].getService(Components.interfaces.mozIJSSubScriptLoader);
	loader.loadSubScript("chrome://zotero-opds/content/zotero-opds.js");
	loader.loadSubScript("chrome://zotero-opds/content/version.js");
}
