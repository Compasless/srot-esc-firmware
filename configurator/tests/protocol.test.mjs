// SPDX-License-Identifier: AGPL-3.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {build} from 'esbuild';
import {ROOT,prepare,bundlingOptions} from '../scripts/build.mjs';
import memoryBackend from './helpers/memory-esc.cjs';
import {createSrotBoard} from './helpers/srot-board.mjs';

const upstream=await prepare();
const bundle=path.join(ROOT,'.cache/test-protocol.cjs');
await build({...bundlingOptions(upstream),platform:'node',format:'cjs',entryPoints:[path.join(ROOT,'src/protocol.js')],outfile:bundle});
const require=createRequire(import.meta.url);
const {Flash,FourWay,BenchSerial,targetFor,checkedFirmware,editedSettings,srotSource}=require(bundle);
const manifest=JSON.parse(await fs.readFile(path.join(ROOT,'dist/firmware/manifest.json'),'utf8'));
const bytes=async record=>new Uint8Array(await fs.readFile(path.join(ROOT,'dist/firmware',record.filename)));
const image=hex=>Flash.fillImage(Flash.parseHex(hex),65536,0);
const recordFor=target=>manifest.targets.find(record=>record.target===target);
const basicRecord=recordFor('A_H_5_48');
const basicBytes=await bytes(basicRecord);
const basicImage=image(new TextDecoder().decode(basicBytes));

test('all 1008 released targets are recognized as Compasless 3D and pass checksum/hardware checks',async()=>{
 for(const record of manifest.targets){
  const data=await bytes(record),flash=image(new TextDecoder().decode(data));
  const backend=memoryBackend.createMemoryEscBackend({image:flash,family:record.mcu});
  const driver=new FourWay(backend.serial);
  const esc=await driver.getInfo(0);esc.index=0;
  assert.equal(esc.firmwareName,'Compasless SROT',record.target);
  assert.match(esc.displayName,/Compasless 3D/);
  assert.equal(esc.settings.MOTOR_DIRECTION,3);
  assert.ok(esc.defaultSettings);
  assert.equal(targetFor(esc,record.pwm_khz,manifest).target,record.target);
  await checkedFirmware(record,data,esc);
 }
});
test('wrong layout, MCU, checksum and unsupported family are rejected before flash',async()=>{
 const backend=memoryBackend.createMemoryEscBackend({image:basicImage});
 const driver=new FourWay(backend.serial),esc=await driver.getInfo(0);
 const bad=basicBytes.slice();bad[10]^=1;
 await assert.rejects(checkedFirmware(basicRecord,bad,esc),/checksum/);
 const other=recordFor('B_H_5_48');
 await assert.rejects(checkedFirmware(other,await bytes(other),esc),/layout or MCU/);
 assert.throws(()=>targetFor({...esc,meta:{...esc.meta,signature:0xE8B5}},48,manifest),/signature/);
 assert.throws(()=>targetFor({...esc,settings:{...esc.settings,LAYOUT:'#A_L_05#'}},48,manifest),/not supported/);
 assert.equal(backend.stats.writes,0);assert.equal(backend.stats.erases,0);
});
test('settings edits preserve unedited values and cannot change the 3D mode',async()=>{
 const backend=memoryBackend.createMemoryEscBackend({image:basicImage});
 const driver=new FourWay(backend.serial),esc=await driver.getInfo(0);
 const settings=editedSettings(esc,{STARTUP_POWER_MAX:7,MOTOR_DIRECTION:1,COMMUTATION_TIMING:3});
 assert.equal(settings.MOTOR_DIRECTION,3);assert.equal(settings.STARTUP_POWER_MAX,7);
 assert.equal(settings.BEEP_STRENGTH,esc.settings.BEEP_STRENGTH);
 assert.throws(()=>editedSettings(esc,{STARTUP_POWER_MAX:81}),/Invalid value/);
 assert.throws(()=>editedSettings({...esc,settings:{...esc.settings,NAME:'Other'}},{}),/Flash Compasless/);
 assert.equal(srotSource.getDefaultSettings('208').MOTOR_DIRECTION,3);
});
test('native serial queue completes MSP handshake, reads four slots, flashes H/X and verifies saved settings',async()=>{
 const xRecord=recordFor('A_X_5_48'),xBytes=await bytes(xRecord),xImage=image(new TextDecoder().decode(xBytes));
 const board=createSrotBoard([{image:basicImage,family:'H'},{image:xImage,family:'X'},
  {image:basicImage,family:'H'},{image:basicImage,family:'H'}]);
 const serial=new BenchSerial(board.port);
 await serial.open(115200);
 try{
  const api=await serial.getApiVersion();assert.equal(api.apiVersion,'1.40.0');
  assert.equal((await serial.enable4WayInterface()).connectedESCs,4);
  for(let index=0;index<4;index++)assert.equal((await serial.getFourWayInterfaceInfo(index)).firmwareName,'Compasless SROT');
  for(const [index,data]of [[0,basicBytes],[1,xBytes]]){
   const esc=await serial.getFourWayInterfaceInfo(index);esc.index=index;
   let progress=0;
   const before=board.backends[index].memory.slice();
   const result=await serial.writeHex(index,esc,new TextDecoder().decode(data),false,false,value=>progress=value);
   assert.equal(result.firmwareName,'Compasless SROT');assert.ok(progress>=99);
   const boundary=index===0?0x1C00:0xF000;
   assert.deepEqual(board.backends[index].memory.slice(boundary),before.slice(boundary));
   const settings=editedSettings(result,{STARTUP_POWER_MAX:6,MOTOR_DIRECTION:1});
   await serial.writeSettings(index,result,settings);
   const reread=await serial.getFourWayInterfaceInfo(index);
   assert.equal(reread.settings.STARTUP_POWER_MAX,6);assert.equal(reread.settings.MOTOR_DIRECTION,3);
  }
 }finally{await serial.close();}
});
test('a USB write failure rejects the operation and closes the queue without hanging',async()=>{
 const port={readable:new ReadableStream({}),writable:new WritableStream({write(){throw new Error('USB removed');}}),
  async open(){},async close(){}};
 const serial=new BenchSerial(port);await serial.open(115200);
 try{
  await assert.rejects(serial.executeCommand(new Uint8Array([1]).buffer,null),/USB removed/);
  await assert.rejects(serial.executeCommand(new Uint8Array([1]).buffer,null),/closed/);
 }finally{await serial.close(true);}
});
