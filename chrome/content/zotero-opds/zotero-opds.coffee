Components.utils.import("resource://gre/modules/Services.jsm")

Zotero.OPDS =
  document: Components.classes["@mozilla.org/xul/xul-document;1"].getService(Components.interfaces.nsIDOMDocument)
  serializer: Components.classes["@mozilla.org/xmlextras/xmlserializer;1"].createInstance(Components.interfaces.nsIDOMSerializer)
  parser: Components.classes["@mozilla.org/xmlextras/domparser;1"].createInstance(Components.interfaces.nsIDOMParser)
  # xslt: Components.classes["@mozilla.org/document-transformer;1?type=xslt"].createInstance(Components.interfaces.nsIXSLTProcessor)

  QR: qr.noConflict()

  # courtesy http://blog.tinisles.com/2011/10/google-authenticator-one-time-password-algorithm-in-javascript/
  TOTP:
    # courtesy http://forthescience.org/blog/2010/11/30/base32-encoding-in-javascript/
    b32encode: (s, pad) ->
      alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'

      parts = []
      quanta = Math.floor((s.length / 5))
      leftover = s.length % 5

      if leftover != 0
        s += '\x00' for i in [0...5 - leftover]
        quanta += 1

      for i in [0...quanta]
        parts.push(alphabet.charAt(s.charCodeAt(i * 5) >> 3))
        parts.push(alphabet.charAt( ((s.charCodeAt(i * 5) & 0x07) << 2) | (s.charCodeAt(i * 5 + 1) >> 6)))
        parts.push(alphabet.charAt( ((s.charCodeAt(i * 5 + 1) & 0x3F) >> 1) ))
        parts.push(alphabet.charAt( ((s.charCodeAt(i * 5 + 1) & 0x01) << 4) | (s.charCodeAt(i * 5 + 2) >> 4)))
        parts.push(alphabet.charAt( ((s.charCodeAt(i * 5 + 2) & 0x0F) << 1) | (s.charCodeAt(i * 5 + 3) >> 7)))
        parts.push(alphabet.charAt( ((s.charCodeAt(i * 5 + 3) & 0x7F) >> 2)))
        parts.push(alphabet.charAt( ((s.charCodeAt(i * 5 + 3) & 0x03) << 3) | (s.charCodeAt(i * 5 + 4) >> 5)))
        parts.push(alphabet.charAt( ((s.charCodeAt(i * 5 + 4) & 0x1F) )))

      replace = switch leftover
        when 1 then 6
        when 2 then 4
        when 3 then 3
        when 4 then 1
        else 0

      parts.pop() for i in [0...replace]
      parts.push('=') for i in [0...replace] if pad

      return parts.join('')

    dec2hex: (s) -> (if s < 15.5 then '0' else '') + Math.round(s).toString(16)

    hex2dec: (s) -> parseInt(s, 16)

    base32tohex: (base32) ->
      base32chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
      bits = (@leftpad(base32chars.indexOf(c).toString(2), 5, '0') for c in base32.toUpperCase()).join('')
      hex = (parseInt(bits.substr(i, 4), 2).toString(16) for i in [0..bits.length] by 4).join('')
      return hex

    leftpad: (str, len, pad) ->
      return str if len > str.length
      return Array(len + 1 - str.length).join(pad) + str

    otp: ->
      secret = Zotero.Prefs.get('opds.secret')
      return if secret == ''

      key = @base32tohex(secret)
      epoch = Math.round(new Date().getTime() / 1000.0)
      time = @leftpad(@dec2hex(Math.floor(epoch / 30)), 16, '0')
      hmac = (new jsSHA(time, 'HEX')).getHMAC(key, 'HEX', 'SHA-1', 'HEX')
      throw(hmac) if hmac == 'KEY MUST BE IN BYTE INCREMENTS'

      offset = @hex2dec(hmac.substring(hmac.length - 1))
      otp = (@hex2dec(hmac.substr(offset * 2, 8)) & @hex2dec('7fffffff')) + ''
      otp = otp.substr(otp.length - 6, 6)
      return otp

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
    catch
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
        if !(Zotero.OPDS.clients[transport.host]?)
          response = prompt("Client #{transport.host} wants to access the Zotero embedded webserver.\nEnter authentication code to confirm", '')
          if response?
            challenge = Zotero.OPDS.TOTP.otp()
            Zotero.debug("TOTP: challenge = #{challenge}, response = #{response}")
            Zotero.OPDS.clients[transport.host] = true if challenge == response
          else
            Zotero.OPDS.clients[transport.host] = false

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

    for endpoint in Object.keys(Zotero.OPDS.endpoints)
      url = (if endpoint == "index" then "/opds" else "/opds/#{endpoint}")
      Zotero.OPDS.log("Registering endpoint #{url}")
      ep = Zotero.Server.Endpoints[url] = ->

      ep:: = Zotero.OPDS.endpoints[endpoint]
    return

  Feed: class
    constructor: (@name, @updated, @url, @kind) ->
      @id = @url
      @root = Zotero.OPDS.url()
      @url = @root + @url
      for key in [ "id", "name", "updated", "kind", "url" ]
        throw ("Feed needs #{key}")  unless @[key]

      @doc = Zotero.OPDS.document.implementation.createDocument(@namespace.atom, "feed", null)
      @clearstack()
      @doc.documentElement.setAttributeNS("http://www.w3.org/2000/xmlns/", "xmlns:dc", @namespace.dc)
      @doc.documentElement.setAttributeNS("http://www.w3.org/2000/xmlns/", "xmlns:opds", @namespace.opds)
      @newnode("title", @name || "Zotero library")
      @newnode("subtitle", "Your bibliography, served by Zotero-OPDS #{Zotero.OPDS.release}")
      @push(@newnode("author"))
      @newnode("name", "zotero")
      @newnode("uri", "https://github.com/AllThatIsTheCase/zotero-opds")
      @pop()
      @newnode("updated", @date(@updated))
      @newnode("id", "urn:zotero-opds:#{@id}")
      link = @newnode("link")
      link.setAttribute("rel", "self")
      link.setAttribute("href", @url)
      link.setAttribute("type", "application/atom+xml;profile=opds-catalog;kind=#{@kind}")
      link = @newnode("link")
      link.setAttribute("rel", "start")
      link.setAttribute("href", "#{@root}/opds")
      link.setAttribute("type", "application/atom+xml;profile=opds-catalog;kind=#{@kind}")

    rjust: (v) ->
      v = "0" + v
      return v.slice(v.length - 2, v.length)

    date: (timestamp) ->
      timestamp = Zotero.Date.sqlToDate(timestamp)  if typeof timestamp == "string"
      return (timestamp or new Date()).toISOString()

    namespace:
      dc: "http://purl.org/dc/terms/"
      opds: "http://opds-spec.org/2010/catalog"
      atom: "http://www.w3.org/2005/Atom"

    comment: (text) ->
      @stack[0].appendChild(@doc.createComment(text))
      return

    newnode: (name, text, namespace) ->
      node = @doc.createElementNS(namespace or @namespace.atom, name)
      node.appendChild(Zotero.OPDS.document.createTextNode(text))  if text
      @stack[0].appendChild(node)
      return node

    push: (node) ->
      @stack.unshift(node)
      return node

    pop: ->
      return stack[0]  if @stack.length == 1
      return @stack.shift()

    clearstack: ->
      @stack = [@doc.documentElement]
      return

    item: (group, item) ->
      attachments = []
      if item.isAttachment()
        attachments = [item]
      else
        attachments = item.getAttachments() or []
      attachments = (a for a in attachments when a.attachmentMIMEType? != "text/html")
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
        link.setAttribute("href", "#{@root}/opds/item?id=#{group}:#{a.key}")
        link.setAttribute("type", a.attachmentMIMEType)

      @pop()
      return

    entry: (title, url, updated) ->
      @comment("entry: #{title}")
      @push(@newnode("entry"))
      @newnode("title", title)
      @newnode("id", "zotero-opds:#{url}")
      link = @newnode("link")
      link.setAttribute("href", "#{@root}#{url}")

      link.setAttribute("type", "application/atom+xml;profile=opds-catalog;kind=navigation")
      @newnode("updated", @date(updated))
      @pop()
      return

    serialize: -> Zotero.OPDS.serializer.serializeToString(@doc)

  sql:
    index: "select max(dateModified) from items"
    group: "select max(dateModified) from items where libraryID = ?"
    collection: "with recursive collectiontree (collection) as (values (?) union all select c.collectionID from collections c join collectiontree ct on c.parentCollectionID = ct.collection) select max(dateModified) from collectiontree ct join collectionItems ci on ct.collection = ci.collectionID join items i on ci.itemID = i.itemID"

  buildurl: (base, q) ->
    url = "#{@root}#{base}?id=#{q.id}"
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

          doc.entry("Items", Zotero.OPDS.buildurl("/opds/group", { id: url.query.id, kind: "acquisition"}), updated)
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
