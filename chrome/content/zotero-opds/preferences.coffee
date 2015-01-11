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

  url = Zotero.OPDS.url()
  document.getElementById('id-opds-opds-url').value = if url then url + '/opds' else 'Not configured'
  return
