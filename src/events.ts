import { Addon, addonName } from './addon'
import AddonModule from './module'

class AddonEvents extends AddonModule {
  private notifierCallback: any
  constructor(parent: Addon) {
    super(parent)
    this.notifierCallback = {
      notify: async (event: string, type: string, ids: string[], extraData: object) => { // eslint-disable-line @typescript-eslint/require-await
        // You can add your code to the corresponding notify type
        if (event === 'select' && type === 'tab' && extraData[ids[0]].type === 'reader') {
          // Select a reader tab
        }
        if (event === 'add' && type === 'item') {
          // Add an item
        }
      },
    }
  }

  public async onInit($Zotero) { // eslint-disable-line @typescript-eslint/require-await
    // This function is the setup code of the addon
    console.log(`${addonName}: init called`)
    $Zotero.debug(`${addonName}: init called`)
    // alert(112233)

    // Reset prefs
    this.resetState()

    // Register the callback in Zotero as an item observer
    const notifierID = $Zotero.Notifier.registerObserver(this.notifierCallback, [
      'tab',
      'item',
      'file',
    ])

    // Unregister callback when the window closes (important to avoid a memory leak)
    $Zotero.getMainWindow().addEventListener('unload', _e => {
      $Zotero.Notifier.unregisterObserver(notifierID)
    }, false)

    this._Addon.views.initViews($Zotero)
  }

  private resetState(): void {
    /*
      For prefs that could be simply set to a static default value,
      Please use addon/defaults/preferences/defaults.js
      Reset other preferrences here.
      Uncomment to use the example code.
    */
    // let testPref = Zotero.Prefs.get('addonTemplate.testPref')
    // if (typeof testPref === 'undefined') {
    //   Zotero.Prefs.set('addonTemplate.testPref', true)
    // }
  }

  public onUnInit($Zotero): void {
    console.log(`${addonName}: uninit called`)
    $Zotero.debug(`${addonName}: uninit called`)
    //  Remove elements and do clean up
    this._Addon.views.unInitViews($Zotero)
    // Remove addon object
    $Zotero.AddonTemplate = undefined
  }
}

export default AddonEvents
