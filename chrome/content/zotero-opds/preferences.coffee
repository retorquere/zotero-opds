S4 = -> (((1 + Math.random()) * 0x10000) | 0).toString(16).substring(1)

newSecret = ->
  Zotero.Prefs.set('opds.secret', Zotero.OPDS.TOTP.b32encode((S4() + S4() + "-" + S4() + "-4" + S4().substr(0,3) + "-" + S4() + "-" + S4() + S4() + S4()).toLowerCase()))
  refresh()
  return

refresh = ->
  secret = Zotero.Prefs.get('opds.secret')
  url = "otpauth://totp/Zotero%20OPDS?secret=#{secret}"
  # document.getElementById('id-opds-preferences-secret').value = secret
  # document.getElementById('id-opds-preferences-url').value = url
  Zotero.OPDS.QR.canvas({ canvas: document.getElementById('id-opds-qr'), value: url})
  return

updatePreferences = ->
  if Zotero.Prefs.get('opds.secret') == ''
    newSecret()
  else
    refresh()
  return
