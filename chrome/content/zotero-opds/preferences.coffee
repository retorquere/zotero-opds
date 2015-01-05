serverURL = (collectionsView, extension) ->
  return  unless collectionsView
  itemGroup = collectionsView._getItemAtRow(collectionsView.selection.currentIndex)
  return  unless itemGroup
  serverPort = null
  try
    serverPort = Zotero.OPDS.prefs.zotero.getIntPref("httpServer.port")
  catch err
    return
  isLibrary = true
  
  for type in [ "Collection", "Search", "Trash", "Duplicates", "Unfiled", "Header", "Bucket" ]
    if itemGroup["is" + type]()
      isLibrary = false
      break
  url = null
  if itemGroup.isCollection()
    collection = collectionsView.getSelectedCollection()
    url = "collection?/" + (collection.libraryID or 0) + "/" + collection.key + extension
  if isLibrary
    libid = collectionsView.getSelectedLibraryID()
    if libid
      url = "library?/" + libid + "/library" + extension
    else
      url = "library?library" + extension
  return  unless url
  "http://localhost:" + serverPort + "/opds/" + url

updatePreferences = (load) ->
  serverCheckbox = document.getElementById("id-opds-preferences-server-enabled")
  serverEnabled = serverCheckbox.checked
  serverCheckbox.setAttribute "hidden", (Zotero.isStandalone and serverEnabled)
  
  # var url = serverURL();
  # if (!url) { serverEnabled = false; }
  document.getElementById("id-zotero-opds-server-warning").setAttribute "hidden", serverEnabled
  document.getElementById("id-zotero-opds-recursive-warning").setAttribute "hidden", not document.getElementById("id-opds-preferences-getCollections").checked
  document.getElementById("id-opds-preferences-fancyURLs-warning").setAttribute "hidden", not document.getElementById("id-opds-preferences-fancyURLs").checked
  return
