function serverURL(collectionsView, extension)
{
  if (!collectionsView) { return; }
  var itemGroup = collectionsView._getItemAtRow(collectionsView.selection.currentIndex);
  if (!itemGroup) { return; }

  var serverPort = null;
  try {
    serverPort = Zotero.OPDS.prefs.zotero.getIntPref('httpServer.port');
  } catch(err) {
    return;
  }

  var isLibrary = true;
  for (var type of ['Collection', 'Search', 'Trash', 'Duplicates', 'Unfiled', 'Header', 'Bucket']) {
    if (itemGroup['is' + type]()) {
      isLibrary = false;
      break;
    }
  }

  var url = null;

  if (itemGroup.isCollection()) {
    collection = collectionsView.getSelectedCollection();
    url = 'collection?/' + (collection.libraryID || 0) + '/' + collection.key + extension;
  }

  if (isLibrary) {
    var libid = collectionsView.getSelectedLibraryID();
    if (libid) {
        url = 'library?/' + libid + '/library' + extension;
    } else {
        url = 'library?library' + extension;
    }
  }

  if (!url) { return; }

  return 'http://localhost:' + serverPort + '/opds/' + url
}

function updatePreferences(load) {
  var serverCheckbox = document.getElementById('id-opds-preferences-server-enabled');
  var serverEnabled = serverCheckbox.checked;
  serverCheckbox.setAttribute('hidden', (Zotero.isStandalone && serverEnabled));

  // var url = serverURL();
  // if (!url) { serverEnabled = false; }

  document.getElementById('id-zotero-opds-server-warning').setAttribute('hidden', serverEnabled);

  document.getElementById('id-zotero-opds-recursive-warning').setAttribute('hidden', !document.getElementById('id-opds-preferences-getCollections').checked);
  document.getElementById('id-opds-preferences-fancyURLs-warning').setAttribute('hidden', !document.getElementById('id-opds-preferences-fancyURLs').checked);
}
