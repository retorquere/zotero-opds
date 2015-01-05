Components.utils.import("resource://gre/modules/Services.jsm")

Zotero.OPDS =
  document: Components.classes["@mozilla.org/xul/xul-document;1"].getService(Components.interfaces.nsIDOMDocument)
  serializer: Components.classes["@mozilla.org/xmlextras/xmlserializer;1"].createInstance(Components.interfaces.nsIDOMSerializer)
  parser: Components.classes["@mozilla.org/xmlextras/domparser;1"].createInstance(Components.interfaces.nsIDOMParser)
  xslt: Components.classes["@mozilla.org/document-transformer;1?type=xslt"].createInstance(Components.interfaces.nsIXSLTProcessor)
  prefs:
    zotero: Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch("extensions.zotero.")
    opds: Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch("extensions.zotero.opds.")
    dflt: Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getDefaultBranch("extensions.zotero.opds.")

  clients:
    "127.0.0.1": true

  log: (msg, e) ->
    msg = JSON.stringify(msg)  unless typeof msg == "string"
    msg = "[opds] " + msg
    if e
      msg += "\nan error occurred: "
      if e.name
        msg += e.name + ": " + e.message + " \n(" + e.fileName + ", " + e.lineNumber + ")"
      else
        msg += e
      msg += "\n" + e.stack  if e.stack
    Zotero.debug msg
    console.log msg
    return

  pref: (key, dflt, branch) ->
    branch = Zotero.OPDS.prefs[branch or "bbt"]
    try
      switch typeof dflt
        when "boolean"
          return branch.getBoolPref(key)
        when "number"
          return branch.getIntPref(key)
        when "string"
          return branch.getCharPref(key)
    catch err
      return dflt
    return

  init: ->
    
    #
    #    Zotero.OPDS.xslt.async = false;
    #    var stylesheet = Zotero.File.getContentsFromURL('resource://zotero-opds/indent.xslt');
    #    Zotero.OPDS.log('stylesheet: ' + stylesheet);
    #    stylesheet = Zotero.OPDS.parser.parseFromString(stylesheet, 'text/xml');
    #    try {
    #      Zotero.OPDS.xslt.importStylesheet(stylesheet.documentElement);
    #    } catch (e) {
    #      Zotero.OPDS.log('could not load stylesheet: ' + e);
    #    }
    #    
    Zotero.OPDS.Server = Zotero.OPDS.Server or {}
    Zotero.OPDS.Server.SocketListener = Zotero.OPDS.Server.SocketListener or {}
    Zotero.OPDS.Server.SocketListener.onSocketAccepted = Zotero.Server.SocketListener.onSocketAccepted
    Zotero.Server.SocketListener.onSocketAccepted = (socket, transport) ->
      Zotero.OPDS.clients[transport.host] = confirm("Client " + transport.host + " wants to access the Zotero embedded webserver")  if typeof Zotero.OPDS.clients[transport.host] == "undefined"
      if Zotero.OPDS.clients[transport.host]
        Zotero.OPDS.Server.SocketListener.onSocketAccepted.apply this, [
          socket
          transport
        ]
      else
        socket.close()
      return

    Zotero.OPDS.Server.init = Zotero.Server.init
    Zotero.Server.init = (port, bindAllAddr, maxConcurrentConnections) ->
      Zotero.OPDS.log "Zotero server now enabled for non-localhost!"
      Zotero.OPDS.Server.init.apply this, [
        port
        true
        maxConcurrentConnections
      ]

    Zotero.Server.close()
    Zotero.Server.init()
    
    for endpoint in Object.keys(Zotero.OPDS.endpoints)
      url = ((if endpoint == "index" then "/opds" else "/opds/" + endpoint))
      Zotero.OPDS.log "Registering endpoint " + url
      ep = Zotero.Server.Endpoints[url] = ->

      ep:: = Zotero.OPDS.endpoints[endpoint]
    return

  Feed: (name, updated, url, kind) ->
    @id = url
    @name = name
    @updated = updated
    @kind = kind
    @url = url
    for key in [ "id", "name", "updated", "kind", "url" ]
      throw ("Feed needs " + key)  unless @[key]

    @rjust = (v) ->
      v = "0" + v
      v.slice v.length - 2, v.length

    @date = (timestamp) ->
      timestamp = Zotero.Date.sqlToDate(timestamp)  if typeof timestamp == "string"
      (timestamp or new Date()).toISOString()

    @namespace =
      dc: "http://purl.org/dc/terms/"
      opds: "http://opds-spec.org/2010/catalog"
      atom: "http://www.w3.org/2005/Atom"

    @comment = (text) ->
      @stack[0].appendChild @doc.createComment(text)
      return

    @newnode = (name, text, namespace) ->
      node = @doc.createElementNS(namespace or @namespace.atom, name)
      node.appendChild Zotero.OPDS.document.createTextNode(text)  if text
      @stack[0].appendChild node
      node

    @push = (node) ->
      @stack.unshift node
      node

    @pop = ->
      return stack[0]  if @stack.length == 1
      @stack.shift()

    @clearstack = ->
      @stack = [@doc.documentElement]
      return

    @doc = Zotero.OPDS.document.implementation.createDocument(@namespace.atom, "feed", null)
    @clearstack()
    @doc.documentElement.setAttributeNS "http://www.w3.org/2000/xmlns/", "xmlns:dc", @namespace.dc
    @doc.documentElement.setAttributeNS "http://www.w3.org/2000/xmlns/", "xmlns:opds", @namespace.opds
    @newnode "title", @name or "Zotero library"
    @newnode "subtitle", "Your bibliography, served by Zotero-OPDS " + Zotero.OPDS.release
    @push @newnode("author")
    @newnode "name", "zotero"
    @newnode "uri", "https://github.com/AllThatIsTheCase/zotero-opds"
    @pop()
    @newnode "updated", @date(@updated)
    @newnode "id", "urn:zotero-opds:" + @id
    link = @newnode("link")
    link.setAttribute "href", @url
    link.setAttribute "type", "application/atom+xml;profile=opds-catalog;kind=" + @kind
    link.setAttribute "rel", "self"

    @item = (group, item) ->
      attachments = []
      if item.isAttachment()
        attachments = [item]
      else
        attachments = item.getAttachments() or []
      attachments = (a for a in attachments where a.attachmentMIMEType and a.attachmentMIMEType != "text/html")
      return  if attachments.length == 0

      title = item.getDisplayTitle(true)
      @comment("item: #{title}, #{Zotero.ItemTypes.getName(item.itemTypeID)}")
      @push(@newnode("entry"))
      @newnode("title", title)
      @newnode("id", "zotero-opds:#{item.key}")
      @push(@newnode("author"))
      @newnode("name", item.firstCreator)
      @pop()
      @newnode("updated", @date(item.getField("dateModified")))
      abstr = item.getField("abstract")
      @newnode("content", abstr)  if abstr and abstr.length != 0

      for a in attachments
        @comment("attachment: #{a.localPath or a.defaultPath}")
        link = @newnode("link")
        link.setAttribute("rel", "http://opds-spec.org/acquisition")
        link.setAttribute("href", "/opds/item?id=#{group}:#{a.key}")
        link.setAttribute("type", a.attachmentMIMEType)

      @pop()
      return

    @entry = (title, url, updated) ->
      @comment("entry: #{title}")
      @push(@newnode("entry"))
      @newnode("title", title)
      @newnode("id", "zotero-opds:#{url}")
      link = @newnode("link")
      link.setAttribute("href", url)
      link.setAttribute("type", "application/atom+xml")
      @newnode("updated", @date(updated))
      @pop()
      return

    @serialize = -> Zotero.OPDS.serializer.serializeToString(@doc)

    return

  sql:
    index: "select max(dateModified) from items"
    group: "select max(dateModified) from items where libraryID = ?"
    collection: "with recursive collectiontree (collection) as (values (?) union all select c.collectionID from collections c join collectiontree ct on c.parentCollectionID = ct.collection) select max(dateModified) from collectiontree ct join collectionItems ci on ct.collection = ci.collectionID join items i on ci.itemID = i.itemID"

  buildurl: (base, q) ->
    url = "#{base}?id=#{q.id}"
    url += "&kind=acquisition" if q.kind == "acquisition"
    return url

  endpoints:
    index:
      supportedMethods: ["GET"]
      init: (url, data, sendResponseCallback) ->
        updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.index)
        doc = new Zotero.OPDS.Feed("Zotero Library", updated, "/opds", "navigation")

        for collection in Zotero.getCollections()
          updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) or collection.dateModified
          doc.entry(collection.name, "/opds/collection?id=0:#{collection.key}", updated)

        # don't forget to add saved searches
        for group in Zotero.Groups.getAll()
          updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.group, group.id)
          doc.entry(group.name, "/opds/group?id=#{group.id}", updated)

        sendResponseCallback(200, "application/atom+xml", doc.serialize())
        return

    item:
      supportedMethods: ["GET"]
      init: (url, data, sendResponseCallback) ->
        q = url.query.id.split(":")
        q =
          group: q.shift()
          item: q.shift()

        return sendResponseCallback(500, "text/plain", "Unexpected OPDS item " + url.query.id)  if not q.group or not q.item
        library = ((if q.group == "0" then null else Zotero.Groups.getLibraryIDFromGroupID(q.group)))
        item = Zotero.Items.getByLibraryAndKey(library, q.item)
        sendResponseCallback(200, item.attachmentMIMEType, Zotero.File.getBinaryContents(item.getFile()))
        return

    group:
      supportedMethods: ["GET"]
      init: (url, data, sendResponseCallback) ->
        libraryID = Zotero.Groups.getLibraryIDFromGroupID(url.query.id)
        group = Zotero.Groups.getByLibraryID(libraryID)
        collections = group.getCollections()
        updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.group, libraryID)
        doc = new Zotero.OPDS.Feed("Zotero Library Group " + group.name, updated, Zotero.OPDS.buildurl("/opds/group", url.query), url.query.kind or "navigation")
        if url.query.kind == "acquisition"
          items = (new Zotero.ItemGroup("group", group)).getItems()
          for item in items or []
            doc.item(url.query.id, item)

        else
          for collection in collections or []
            updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) or collection.dateModified
            doc.entry(collection.name, "/opds/collection?id=#{url.query.id}:#{collection.key}", updated)

          doc.entry("Items", Zotero.OPDS.buildurl("/opds/group",
            id: url.query.id
            kind: "acquisition"
          ), updated)
        sendResponseCallback(200, "application/atom+xml", doc.serialize())
        return

    collection:
      supportedMethods: ["GET"]
      init: (url, data, sendResponseCallback) ->
        query = url.query.id.split(":")
        q = {}
        q.group = query.shift()
        q.collection = query.shift()

        return sendResponseCallback(500, "text/plain", "Unexpected OPDS collection " + url.query.id)  if not q.group or not q.collection

        library = (if q.group == "0" then null else Zotero.Groups.getLibraryIDFromGroupID(q.group))

        collection = Zotero.Collections.getByLibraryAndKey(library, q.collection)
        updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) or collection.dateModified
        doc = new Zotero.OPDS.Feed("Zotero Library Collection " + collection.name, updated, Zotero.OPDS.buildurl("/opds/collection", url.query), url.query.kind or "navigation")
        if url.query.kind == "acquisition"
          items = (new Zotero.ItemGroup("collection", collection)).getItems()

          for item in items or []
            doc.item(q.group, item)

        else
          for collection in collection.getChildCollections() or []
            updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) or collection.dateModified
            doc.entry(collection.name, "/opds/collection?id=#{q.group}:#{collection.key}")
          doc.entry("Items", Zotero.OPDS.buildurl("/opds/collection", { id: url.query.id, kind: "acquisition"}), updated)

        sendResponseCallback(200, "application/atom+xml", doc.serialize())
        return


# Initialize the utility
window.addEventListener("load", ((e) ->
  Zotero.OPDS.init()
  return
), false)
