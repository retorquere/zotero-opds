S4: -> (((1 + Math.random()) * 0x10000) | 0).toString(16).substring(1)

newSecret: ->
  secret = (S4() + S4() + "-" + S4() + "-4" + S4().substr(0,3) + "-" + S4() + "-" + S4() + S4() + S4()).toLowerCase()
  Zotero.Prefs.set('opds.secret', secret)
  document.getElementById('id-opds-preferences-secret').value = secret
  Zotero.OPDS.QR.canvas({ canvas: document.getElementById('id-opds-qr'), value: "otpauth://totp/Zotero%20OPDS%3Fsecret%3D#{secret}"})
  return

updatePreferences = ->
  secret = document.getElementById('id-opds-preferences-secret').value
  if secret == ''
    newSecret()
  else
    Zotero.OPDS.QR.canvas({ canvas: document.getElementById('id-opds-qr'), value: "otpauth://totp/Zotero%20OPDS%3Fsecret%3D#{secret}"})
  return
