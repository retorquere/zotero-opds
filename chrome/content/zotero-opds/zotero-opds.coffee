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

    # Enable outside connections
    Zotero.Server.init = ((original) ->
      return (port, bindAllAddr, maxConcurrentConnections) ->
        Zotero.OPDS.log("Zotero server now enabled for non-localhost!")
        return original.apply(this, [port, true, maxConcurrentConnections])
      )(Zotero.Server.init)

    # verify outside connections, and set buffer bigger or the webserver will stall on attachments
    Zotero.Server.SocketListener.onSocketAccepted = (socket, transport) ->
      Zotero.OPDS.clients[transport.host] ?= confirm("Client #{transport.host} wants to access the\nZotero embedded webserver.")
      if !Zotero.OPDS.clients[transport.host]
        socket.close()
        return

      # get an input stream
      iStream = transport.openInputStream(0, 0, 0)
      oStream = transport.openOutputStream(Components.interfaces.nsITransport.OPEN_BLOCKING,10000000,100000)

      dataListener = new Zotero.Server.DataListener(iStream, oStream)
      pump = Components.classes["@mozilla.org/network/input-stream-pump;1"].createInstance(Components.interfaces.nsIInputStreamPump)
      pump.init(iStream, -1, -1, 0, 0, false)
      pump.asyncRead(dataListener, null)
      return

    Zotero.MIME.isTextType = ((original) ->
      return (mimeType) ->
        return true if mimeType == 'application/atom+xml'
        return original.apply(this, arguments)
      )(Zotero.MIME.isTextType)

    # Mark binary response data
    Zotero.Server.DataListener.prototype._generateResponse = ((original) ->
      return (status, contentType, body) ->
        response = original.apply(this, arguments)
        if Zotero.MIME.isTextType(contentType) || !body || !contentType
          return response
        else
          return {contentType: contentType, response: response}
      )(Zotero.Server.DataListener.prototype._generateResponse)

    # Unpatched version forces output to UTF-8, reads mark from patched Zotero.Server.DataListener.prototype._generateResponse
    Zotero.Server.DataListener.prototype._requestFinished = ((original) ->
      return (response) ->
        return original.apply(this, arguments) if !response.response
        Zotero.OPDS.log('Serving binary')

        if @_responseSent
          Zotero.debug("Request already finished; not sending another response")
          return
        @_responseSent = true

        # close input stream
        @iStream.close()

        # write response
        #oStream = Components.classes['@mozilla.org/binaryoutputstream;1'].createInstance(Components.interfaces.nsIBinaryOutputStream)
        #try
        #  oStream.setOutputStream(@oStream)
        #  oStream.writeBytes(response.response, response.response.length)
        #finally
        #  @oStream.close()

        Zotero.OPDS.log('Serving binary')
        #response.response = "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n" + (new Array(100000).join(' boo! '))
        @oStream.write(response.response, response.response.length)
        @oStream.close()

        return
      )(Zotero.Server.DataListener.prototype._requestFinished)

    # Close & open the server to trigger the server setup
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

  endpoints:
    index:
      supportedMethods: ["GET"]
      init: (url, data, sendResponseCallback) ->
        updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.index)

        feed = new Zotero.OPDS.Feed('/opds', 'Zotero Library', updated, ->
          for collection in Zotero.getCollections()
            @collection(collection)

          for group in Zotero.Groups.getAll()
            @group(group)

          # TODO: add saved searches
          return)

        sendResponseCallback(200, "application/atom+xml", feed.serialize())
        return

    item:
      supportedMethods: ["GET"]
      init: (url, data, sendResponseCallback) ->
        item = Zotero.Items.getByLibraryAndKey(url.query.library, url.query.key)
        Zotero.OPDS.log('Getting binary')
        body = Zotero.File.getBinaryContents(item.getFile())
        Zotero.OPDS.log('Got it')
        sendResponseCallback(200, item.attachmentMIMEType || 'application/pdf', body)
        Zotero.OPDS.log('Sent it')
        return

    group:
      supportedMethods: ["GET"]
      init: (url, data, sendResponseCallback) ->
        group = Zotero.Groups.getByLibraryID(url.query.id)
        updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.group, url.query.id)

        feed = new Zotero.OPDS.Feed("/opds/group?id=#{url.query.id}", "Group: #{group.name}", updated, ->
          for collection in group.getCollections() || []
            @collection(collection)

          for item in (new Zotero.ItemGroup('group', group)).getItems() || []
            @item(item)

          return)

        sendResponseCallback(200, "application/atom+xml", feed.serialize())
        return

    collection:
      supportedMethods: ["GET"]
      init: (url, data, sendResponseCallback) ->
        collection = Zotero.Collections.getByLibraryAndKey(url.query.library, url.query.key)
        updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) or collection.dateModified

        feed = new Zotero.OPDS.Feed("/opds/collection?library=#{url.query.library}&key=#{url.query.key}", "Collection: #{collection.name}", updated, ->
          for collection in collection.getChildCollections() or []
            @collection(collection)

          for item in collection.getChildItems(false) || []
            @item(item)

          return)

        sendResponseCallback(200, "application/atom+xml", feed.serialize())
        return

class Zotero.OPDS.XmlNode
  constructor: (@doc, @root, @namespace) ->

  add: (what) ->
    for own name, content of what
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

    return

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
  constructor: (url, title, updated, content) ->
    super('feed', 'http://www.w3.org/2005/Atom', ->)
    @add(id: url)
    @add(link: { rel: 'self', href: url, type: 'application/atom+xml;profile=opds-catalog;kind=navigation' })
    @add(link: { rel: 'start', href: '/opds', type: 'application/atom+xml;profile=opds-catalog;kind=navigation' })
    @add(title: title)
    @add(updated: @date(updated))

    @add(author: ->
      @add(name: 'Zotero OPDS')
      @add(uri: 'http://zotplus.github.io/opds')
      return)
    content.call(@)

  collection: (collection) ->
    updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.collection, collection.id) or collection.dateModified
    @add(entry: ->
      url = "/opds/collection?library=#{collection.libraryID || 0}&key=#{collection.key}"
      @add(title: collection.name)
      @add(link: { rel: 'subsection', href: url, type: 'application/atom+xml;profile=opds-catalog;kind=acquisition' })
      @add(updated: @date(updated))
      @add(id: url)
      @add(content: { type: 'text', '': collection.name })
      return)
    return

  group: (group) ->
    updated = Zotero.DB.valueQuery(Zotero.OPDS.sql.group, group.id)
    libraryID = Zotero.Groups.getLibraryIDFromGroupID(group.id)
    @add(entry: ->
      url = "/opds/group?id=#{libraryID}"
      @add(title: group.name)
      @add(link: { rel: 'subsection', href: url, type: 'application/atom+xml;profile=opds-catalog;kind=acquisition' })
      @add(updated: @date(updated))
      @add(id: url)
      @add(content: { type: 'text', '': group.name })
      return)
    return

  item: (item) ->
    attachments = []
    if item.isAttachment()
      attachments = [item.id]
    else
      attachments = item.getAttachments() or []
      attachments = Zotero.Items.get(attachments) if attachments.length != 0
    attachments = (a for a in attachments when a.attachmentMIMEType? != "text/html")

    return if attachments.length == 0
    @add(entry: ->
      @add(title: item.getDisplayTitle(true))
      @add(id: "/opds/item/#{item.libraryID || 0}:#{item.key}")
      @add(author: ->
        @add(name: item.firstCreator)
        return)
      @add(updated: @date(item.getField('dateModified')))

      abstr = item.getField("abstract")
      @add(summary: {type: 'text', '': abstr}) if abstr && abstr.length != 0

      for attachment in attachments
        @add(link: {
          type: attachment.attachmentMIMEType || 'application/pdf'
          rel: 'http://opds-spec.org/acquisition'
          href: "/opds/item?library=#{attachment.libraryID || 0}&key=#{attachment.key}"
          })

      return)
    return

# Initialize the utility
window.addEventListener("load", ((e) ->
  Zotero.OPDS.init()
  return
), false)
