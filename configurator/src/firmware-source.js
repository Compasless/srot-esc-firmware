// SPDX-License-Identifier: AGPL-3.0-only
import BluejaySource from 'esc-sources';
import eeprom from 'esc-eeprom';
import originalSettings from 'esc-settings';
import blheliLayouts from 'esc-layouts';
import extraLayouts from 'esc-extra-layouts';

// Metadata contains conditional functions. Copy entries without serializing them.
const settings = {...originalSettings, DEFAULTS:{...originalSettings.DEFAULTS},
  INDIVIDUAL:Object.fromEntries(Object.entries(originalSettings.INDIVIDUAL).map(([revision,groups])=>
    [revision,Object.fromEntries(Object.entries(groups).map(([name,entries])=>
      [name,entries.map(entry=>entry.name==='MOTOR_DIRECTION'
        ? {...entry,options:[{value:'3',label:'Forward / reverse (3D, fixed)'}]} : {...entry})]))]))};
settings.DEFAULTS['208'] = {...settings.DEFAULTS['208'], MOTOR_DIRECTION:3,
  STARTUP_POWER_MIN:21, STARTUP_POWER_MAX:5};

export class SrotSource extends BluejaySource {
  isValidName(name) { return typeof name === 'string' && name.trim() === 'Compasless 3D'; }
  canMigrateTo() { return false; } // Keep flashed defaults; settings backup is explicit.
  buildDisplayName(info, make) {
    return make + ' - Compasless 3D, ' + info.settings.MAIN_REVISION + '.' +
      info.settings.SUB_REVISION + ', ' + info.settings.PWM_FREQUENCY + ' kHz';
  }
  async getVersions() {
    return [{name:'Compasless SROT ESC v0.4.0',key:'v0.4.0',url:'./firmware/',
      releaseUrl:'https://github.com/Compasless/srot-esc-firmware/releases/tag/v0.4.0',prerelease:true}];
  }
  getSkipSettings() { return ['MOTOR_DIRECTION']; }
}
export const srotSource = new SrotSource('Compasless SROT',eeprom,settings,{
  layouts:{...blheliLayouts.layouts,...extraLayouts.layouts}
});
