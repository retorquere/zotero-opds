Components.utils.import("resource://gre/modules/Services.jsm")

Zotero.OPDS =
  document: Components.classes["@mozilla.org/xul/xul-document;1"].getService(Components.interfaces.nsIDOMDocument)
  serializer: Components.classes["@mozilla.org/xmlextras/xmlserializer;1"].createInstance(Components.interfaces.nsIDOMSerializer)
  parser: Components.classes["@mozilla.org/xmlextras/domparser;1"].createInstance(Components.interfaces.nsIDOMParser)
  # xslt: Components.classes["@mozilla.org/document-transformer;1?type=xslt"].createInstance(Components.interfaces.nsIXSLTProcessor)

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
    Zotero.debug(msg)
    return

  url: ->
    try
      port = Zotero.Prefs.get('httpServer.port')
    catch err
      Zotero.OPDS.log("Failed to grab server port: #{err.msg}")
      return

    return "http://#{Zotero.Prefs.get('opds.hostname')}:#{port}"

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

    # update dyndns, if any
    dns = Components.classes["@mozilla.org/network/dns-service;1"].createInstance(Components.interfaces.nsIDNSService)
    Zotero.debug("DYNDNS: resolving #{dns.myHostName}")
    dns.asyncResolve(dns.myHostName, 0, {
      onLookupComplete: (req, rec, status) ->
        address = ''
        while rec.hasMore()
          ip = rec.getNextAddrAsString()
          address = ip if ip.indexOf(':') < 0

        Zotero.debug("DYNDNS: resolved to #{address}")
        url = Zotero.Prefs.get('opds.dyndns').trim()
        return if url == ''
        url = url.replace(/<hostname>/ig, Zotero.Prefs.get('opds.hostname'))
        url = url.replace(/<ip>/ig, address)
        xmlhttp = Components.classes["@mozilla.org/xmlextras/xmlhttprequest;1"].createInstance()
        xmlhttp.open('GET', url, true)
        xmlhttp.send(null)
        return
    }, null)

    Zotero.Server.SocketListener.onSocketAccepted = ((original) ->
      return (socket, transport) ->
        Zotero.OPDS.clients[transport.host] ?= confirm("Client #{transport.host} wants to access the\nZotero embedded webserver.")
        if Zotero.OPDS.clients[transport.host]
          return original.apply(this, arguments)
        else
          socket.close()
        return
      )(Zotero.Server.SocketListener.onSocketAccepted)

    Zotero.Server.init = ((original) ->
      return (port, bindAllAddr, maxConcurrentConnections) ->
        Zotero.OPDS.log("Zotero server now enabled for non-localhost!")
        return original.apply(this, [port, true, maxConcurrentConnections])
      )(Zotero.Server.init)

    Zotero.Server.close()
    Zotero.Server.init()

    for own id, endpoint of Zotero.OPDS.endpoints
      url = (if id == "index" then "/opds" else "/opds/#{id}")
      Zotero.OPDS.log("Registering endpoint #{url}")
      ep = Zotero.Server.Endpoints[url] = ->
      ep:: = endpoint

    return

  sql:
    index: "select max(dateModified) from items"
    group: "select max(dateModified) from items where libraryID = ?"
    collection: "with recursive collectiontree (collection) as (values (?) union all select c.collectionID from collections c join collectiontree ct on c.parentCollectionID = ct.collection) select max(dateModified) from collectiontree ct join collectionItems ci on ct.collection = ci.collectionID join items i on ci.itemID = i.itemID"

  buildurl: (base, q) ->
    url = "#{@url()}#{base}?id=#{q.id}"
    url += "&kind=#{q.kind}" if q.kind
    return url

  endpoints:
    index:
      supportedMethods: ["GET"]
      init: (url, data, sendResponseCallback) ->
        updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.index)

        feed = new Zotero.OPDS.XmlDocument('feed', 'http://www.w3.org/2005/Atom', ->
          @add('id', '/opds')
          @add('link', {
            rel: 'self'
            href: '/opds'
            type: 'application/atom+xml;profile=opds-catalog;kind=navigation'
            })
          @add('link', {
            rel: 'start'
            href: '/opds'
            type: 'application/atom+xml;profile=opds-catalog;kind=navigation'
            })

          @add('title', 'Zotero Library')
          @add('updated', @date(updated))
          @add('author', ->
            @add('name', 'Zotero OPDS')
            @add('uri', 'http://ZotPlus')
            return)

          for collection in Zotero.getCollections()
            @collection(collection)

          # TODO: add saved searches
          for group in Zotero.Groups.getAll()
            @group(group)

        sendResponseCallback(200, "application/atom+xml", feed.serialize())
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

        kind = url.query.kind || 'navigation'

        doc = new Zotero.OPDS.Feed("Zotero Library Group '#{group.name}'", updated, Zotero.OPDS.buildurl("/opds/group", url.query), kind)

        if kind == 'acquisition'
          items = (new Zotero.ItemGroup("group", group)).getItems()
          for item in items or []
            doc.item(url.query.id, item)

        else
          for collection in collections or []
            updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) or collection.dateModified
            doc.entry(collection.name, "/opds/collection?id=#{url.query.id}:#{collection.key}", updated)

          doc.entry('::Items', Zotero.OPDS.buildurl('/opds/group', { id: url.query.id, kind: 'acquisition'}), updated)
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
        kind = url.query.kind || 'navigation'

        collection = Zotero.Collections.getByLibraryAndKey(library, q.collection)
        updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) or collection.dateModified
        doc = new Zotero.OPDS.Feed("Zotero Library Collection '#{collection.name}'", updated, Zotero.OPDS.buildurl("/opds/collection", url.query), kind)

        Zotero.OPDS.log("Collection feed type #{kind}")
        if kind == 'acquisition'
          items = (new Zotero.ItemGroup('collection', collection)).getItems()
          for item in items or []
            doc.item(q.group, item)

        else
          for collection in collection.getChildCollections() or []
            updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) or collection.dateModified
            doc.entry(collection.name, "/opds/collection?id=#{q.group}:#{collection.key}")
          doc.entry('::Items', Zotero.OPDS.buildurl('/opds/collection', { id: url.query.id, kind: 'acquisition'}), updated)

        sendResponseCallback(200, "application/atom+xml", doc.serialize())
        return

class Zotero.OPDS.XmlNode
  constructor: (@doc, @root, @namespace) ->

  add: (name, content) ->
    node = @doc.createElementNS(@namespace, name)
    @root.appendChild(node)

    switch typeof content
      when 'function'
        content.call(new Zotero.OPDS.XmlNode(@doc, node, @namespace))

      when 'string'
        node.appendChild(@doc.createTextNode(content))

      else # assume node with attributes
        for own k, v of content
          if k == ''
            node.appendChild(@doc.createTextNode(v))
          else
            node.setAttribute(k, v)

    return node

  date: (timestamp) ->
    timestamp = Zotero.Date.sqlToDate(timestamp)  if typeof timestamp == "string"
    return (timestamp or new Date()).toISOString()

class Zotero.OPDS.XmlDocument extends Zotero.OPDS.XmlNode
  constructor: (root, @namespace, content) ->
    super(null, null, @namespace)
    @doc = Zotero.OPDS.document.implementation.createDocument(@namespace, root, null)
    @root = @doc.documentElement
    content.call(@)

  serialize: -> Zotero.OPDS.serializer.serializeToString(@doc)

class Zotero.OPDS.Feed extends Zotero.OPDS.XmlDocument
  constructor: (content) ->
    super('feed', 'http://www.w3.org/2005/Atom', content)

  collection: (collection) ->
    updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) or collection.dateModified
    @add('entry', ->
      url = "/opds/collection?id=0:#{collection.key}"
      @add('title', collection.name)
      @add('link', {
        rel: 'subsection'
        href: url
        type: 'application/atom+xml;profile=opds-catalog;kind=acquisition'
        })
      @add('updated', @date(updated))
      @add('id', url)
      @add('content', {
        type: 'text'
        '': collection.name
        })
      return)
    return

  group: (group) ->
    updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.group, group.id)
    @add('entry', ->
      url = "/opds/group?id=#{group.id}"
      @add('title', group.name)
      @add('link', {
        rel: 'subsection'
        href: url
        type: 'application/atom+xml;profile=opds-catalog;kind=acquisition'
        })
      @add('updated', @date(updated))
      @add('id', url)
      @add('content', {
        type: 'text'
        '': group.name
        })
      return)
    return

# Initialize the utility
window.addEventListener("load", ((e) ->
  Zotero.OPDS.init()
  return
), false)
