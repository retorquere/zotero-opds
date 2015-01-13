
# Zotero: OPDS server

Sync your articles with any e-reader that supports OPDS. Currently supports groups & collections, saved search up next

# DynDns support

You can register a dynamic dns name from providers such as DuckDns or Hopper.pw, which will automatically point to your
local (not necessarily public) IP adres. **BE AWARE** that if you point this to a non-routable address you are in
princple susceptible to a DNS re-binding attack. I think the risks in this particular case are minimal, as no secrets
are passing over the wire, but I'm not an expert. My home router (Fritz!Box) refused to map such addresses unless I
specifically gave it permission.

# Installation (one-time)

After installation, the plugin will auto-update to newer releases. Install by downloading the [latest
version](https://zotplus.github.io/opds/zotero-opds-0.0.10.xpi)
(**0.0.10**).
If you are not prompted with a Firefox installation dialog then double-click the
downloaded xpi; Firefox ought to start and present you with the installation dialog.

For standalone Zotero, do the following:

1. In the main menu go to Tools > Add-ons
2. Select 'Extensions'
3. Click on the gear in the top-right corner and choose 'Install Add-on From File...'
4. Choose .xpi that you've just downloaded, click 'Install'
5. Restart Zotero


