// SPDX-License-Identifier: AGPL-3.0-only
import Serial from 'esc-serial';
import Flash from 'esc-flash';
import {isValidFlash} from 'esc-general';
import {srotSource} from './firmware-source.js';

export {Flash,srotSource};
export {default as FourWay} from 'esc-fourway';
export const FIELDS = [
 {key:'COMMUTATION_TIMING',label:'Commutation timing',type:'select',
  options:[[1,'Low'],[2,'Medium low'],[3,'Medium'],[4,'Medium high'],[5,'High']]},
 {key:'DEMAG_COMPENSATION',label:'Demagnetization protection',type:'select',
  options:[[1,'Disabled'],[2,'Low'],[3,'High']]},
 {key:'STARTUP_POWER_MIN',label:'Minimum startup power',type:'number',min:0,max:255},
 {key:'STARTUP_POWER_MAX',label:'Maximum startup power',type:'number',min:0,max:80},
 {key:'TEMPERATURE_PROTECTION',label:'Temperature protection',type:'select',
  options:[[0,'Disabled'],[1,'80 °C'],[2,'90 °C'],[3,'100 °C'],[4,'110 °C'],[5,'120 °C'],[6,'130 °C'],[7,'140 °C']]},
 {key:'BEEP_STRENGTH',label:'Beep volume',type:'number',min:0,max:255},
];
export function targetFor(esc,pwm,manifest) {
  if (!esc?.isSiLabs || !esc.meta?.available) throw new Error('An EFM8 ESC must be detected first.');
  const tag = esc.settings?.LAYOUT?.trim() || '';
  const match = /^#([A-Z]{1,2})_([HX])_([0-9]{2,3})#$/.exec(tag);
  if (!match) throw new Error('This ESC layout is not supported by SROT firmware.');
  const [,layout,mcu,deadtime] = match;
  const expectedSignature = mcu === 'H' ? 0xE8B2 : 0xE8B5;
  if (esc.meta.signature !== expectedSignature) throw new Error('The layout and MCU signature do not match.');
  if (esc.actualMake && esc.actualMake !== esc.make) {
    throw new Error('The configurator detected a timing tag mismatch. Resolve the ESC identity before flashing.');
  }
  const target = layout + '_' + mcu + '_' + Number(deadtime) + '_' + Number(pwm);
  const record = manifest.targets.find(item=>item.target===target);
  if (!record) throw new Error('There is no released firmware for this exact target.');
  return record;
}
export async function checkedFirmware(record,bytes,esc,cryptoApi=globalThis.crypto) {
  const hash = Array.from(new Uint8Array(await cryptoApi.subtle.digest('SHA-256',bytes)),
    value=>value.toString(16).padStart(2,'0')).join('');
  if (hash !== record.sha256) throw new Error('The firmware checksum does not match the published build.');
  const hex = new TextDecoder().decode(bytes);
  const parsed = Flash.parseHex(hex);
  if (!parsed?.endOfFile) throw new Error('The HEX file is incomplete.');
  const flash = Flash.fillImage(parsed,esc.meta.signature===0xE8B5?63485:8192,0);
  if (!flash) throw new Error('The HEX file exceeds the target flash.');
  const offset = esc.meta.signature===0xE8B5?0x3000:0x1A00;
  const ascii = (start,length)=>new TextDecoder().decode(flash.subarray(start,start+length));
  const layout = ascii(offset+0x40,16);
  const mcu = ascii(offset+0x50,16);
  if (layout.trim() !== esc.settings.LAYOUT?.trim() || mcu.trim() !== esc.settings.MCU?.trim()) {
    throw new Error('The firmware layout or MCU does not match this ESC. Flashing is blocked.');
  }
  if (!isValidFlash(mcu,flash) || ascii(offset+0x60,16) !== 'Compasless 3D   ' ||
      flash[offset+11]!==3 || flash[offset]!==0 || flash[offset+1]!==4 || flash[offset+2]!==208) {
    throw new Error('This is not the released Compasless 3D firmware.');
  }
  return hex;
}
export function editedSettings(esc,values) {
  if (!srotSource.isValidName(esc?.settings?.NAME) || esc.layoutRevision!=='208') {
    throw new Error('Flash Compasless SROT firmware before editing settings here.');
  }
  const result={...esc.settings,MOTOR_DIRECTION:3};
  for (const field of FIELDS) {
    if (!Object.hasOwn(values,field.key)) continue;
    const value=Number(values[field.key]);
    if (values[field.key]==='' || !Number.isInteger(value) || (field.type==='number'&&(value<field.min||value>field.max)) ||
        (field.type==='select'&&!field.options.some(option=>option[0]===value))) {
      throw new Error('Invalid value for '+field.label+'.');
    }
    result[field.key]=value;
  }
  return result;
}
export class BenchSerial extends Serial {
  executeCommand(buffer,responseHandler) {
    if(this.closed)return Promise.reject(new Error('The flasher connection is closed.'));
    return this.qp.addCommand(async()=>{
      try{await this.writeBuffer(buffer);}catch(error){this.failPending(error);}
    },responseHandler);
  }
  failPending(error) {
    this.closed=true;this.running=false;
    clearInterval(this.fourWay?.interval);
    const current=this.qp.currentCommand;
    if(current){clearTimeout(current.timeoutFunct);current.rejectCallback(error);}
    const waiting=this.qp.commands.splice(0);
    this.qp.cleanUp();
    for(const command of waiting)command.rejectCallback(error);
  }
  async close(disconnected=false) {
    if (this.closing) return;
    this.closing=true;
    clearInterval(this.fourWay?.interval);
    if(!disconnected&&this.writer&&this.fourWay&&!this.closed){
      try{await Promise.race([this.fourWay.exit(),new Promise(resolve=>setTimeout(resolve,600))]);}catch{}
    }
    this.failPending(new Error('The flasher connection is closed.'));
    const reader=this.reader,writer=this.writer;
    if(reader){try{await reader.cancel();}catch{} try{reader.releaseLock();}catch{}}
    if(writer){try{writer.releaseLock();}catch{}}
    this.reader=null;this.writer=null;
    try{await this.port.close();}catch{}
    this.closing=false;
  }
}
