newSecret = ->
  Zotero.Prefs.set('opds.secret', Zotero.OPDS.TOTP.b32encode( (String.fromCharCode(Math.round(32 + (Math.random() * 94))) for i in [1..10]).join('') ))
  refresh()
  return

refresh = ->
  secret = Zotero.Prefs.get('opds.secret')
  url = "otpauth://totp/Zotero%20OPDS?secret=#{secret}"
  # document.getElementById('id-opds-preferences-secret').value = secret
  # document.getElementById('id-opds-preferences-url').value = url
  Zotero.OPDS.QR.canvas({ canvas: document.getElementById('id-opds-qr'), value: url})

  url = Zotero.OPDS.url()
  document.getElementById('id-opds-opds-url').value = if url then url + '/opds' else 'Not configured'
  return

applyAttributes = (node, attrs) ->
  for own key, value of attrs || {}
    node.setAttribute(key, value)
  return

XUL = "http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul"
newElement = (host, name, attrs) ->
  node = document.createElementNS(XUL, name)
  applyAttributes(node, attrs)
  host.appendChild(node)
  return node

initPreferences = ->
  clients = document.getElementById('client-acl')
  for own client, access of Zotero.OPDS.clients
    Zotero.debug("OPDS CLIENT #{client}: #{access}")
    attrs =
      id: client
      label: client
      'class': "access-#{if access then 'allowed' else 'denied'}"
    newElement(clients, 'listitem', attrs)

  if Zotero.Prefs.get('opds.secret') == ''
    newSecret()
  else
    refresh()
  return
