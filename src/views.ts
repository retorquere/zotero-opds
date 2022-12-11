import { Addon } from './addon'
import AddonModule from './module'
const { addonRef } = require('../package.json')

class AddonViews extends AddonModule {
  // You can store some element in the object attributes
  private testButton: XUL.Button
  private progressWindowIcon: object

  constructor(parent: Addon) {
    super(parent)
    this.progressWindowIcon = {
      success: 'chrome://zotero/skin/tick.png',
      fail: 'chrome://zotero/skin/cross.png',
      default: `chrome://${addonRef}/skin/favicon.png`,
    }
  }

  // eslint-disable-next-line @typescript-eslint/explicit-module-boundary-types
  public initViews($Zotero): void {
    // You can init the UI elements that
    // cannot be initialized with overlay.xul
    console.log('Initializing UI')
    const $window: Window = $Zotero.getMainWindow()
    const menuitem = $window.document.createElement('menuitem')
    menuitem.id = 'zotero-itemmenu-addontemplate-test'
    menuitem.setAttribute('label', 'Addon Template')
    menuitem.setAttribute('oncommand', 'alert("Hello World!")')
    menuitem.className = 'menuitem-iconic'
    menuitem.style['list-style-image'] = "url('chrome://addontemplate/skin/favicon@0.5x.png')"
    $window.document.querySelector('#zotero-itemmenu').appendChild(menuitem)
  }

  // eslint-disable-next-line @typescript-eslint/explicit-module-boundary-types
  public unInitViews($Zotero): void {
    console.log('Uninitializing UI')
    const $window: Window = $Zotero.getMainWindow()
    $window.document.querySelector('#zotero-itemmenu-addontemplate-test')?.remove()
  }

  public showProgressWindow(header: string, context: string, type = 'default', t = 5000): void { // eslint-disable-line no-magic-numbers
    // A simple wrapper of the Zotero ProgressWindow
    const progressWindow = new Zotero.ProgressWindow({ closeOnClick: true })
    progressWindow.changeHeadline(header)
    progressWindow.progress = new progressWindow.ItemProgress(
      this.progressWindowIcon[type],
      context
    )
    progressWindow.show()
    if (t > 0) {
      progressWindow.startCloseTimer(t)
    }
  }
}

export default AddonViews
