// SPDX-License-Identifier: AGPL-3.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {unzipSync} from 'fflate';
import {build} from 'esbuild';
import {ROOT,bundlingOptions} from '../scripts/build.mjs';
import memoryBackend from './helpers/memory-esc.cjs';

console.debug=()=>{};
const upstream=path.join(ROOT,'.cache/stock-upstream');
const entries=unzipSync(await fs.readFile(path.join(ROOT,'.cache/upstream.zip')));
for(const [name,data]of Object.entries(entries)){
 const relative=name.split('/').slice(1).join('/');
 if(!relative||name.endsWith('/'))continue;
 const target=path.resolve(upstream,relative);
 assert.ok(target.startsWith(upstream+path.sep));
 await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,data);
}
const entry=path.join(ROOT,'.cache/stock-entry.js'),bundle=path.join(ROOT,'.cache/stock-driver.cjs');
const modulePath=name=>JSON.stringify(path.join(upstream,'src',name).replaceAll('\\','/'));
await fs.writeFile(entry,'export {default as FourWay} from '+modulePath('utils/FourWay.js')+';\nexport {default as Flash} from '+modulePath('utils/helpers/Flash.js')+';');
await build({...bundlingOptions(upstream),platform:'node',format:'cjs',entryPoints:[entry],outfile:bundle});
const {FourWay,Flash}=createRequire(import.meta.url)(bundle);
const manifest=JSON.parse(await fs.readFile(path.join(ROOT,'dist/firmware/manifest.json'),'utf8'));
const load=async record=>await fs.readFile(path.join(ROOT,'dist/firmware',record.filename),'utf8');
const image=hex=>Flash.fillImage(Flash.parseHex(hex),65536,0);

test('public configurator protocol flashes and reflashes all 1008 targets without forced layout checks or settings migration',async()=>{
 let total=0,unknown=0;
 for(const record of manifest.targets){
  const hex=await load(record),expected=image(hex),old=expected.slice(),eeprom=record.mcu==='X'?0x3000:0x1A00;
  old.set(new TextEncoder().encode('Bluejay (.0)    '),eeprom+0x60);old[eeprom+1]=21;old[eeprom+11]=1;
  const backend=memoryBackend.createMemoryEscBackend({image:old,family:record.mcu});
  const driver=new FourWay(backend.serial);
  let esc=await driver.getInfo(0);esc.index=0;
  for(let repeat=0;repeat<2;repeat++){
   esc=await driver.writeHex(0,esc,hex,false,false,()=>{});
   assert.ok(esc,record.target);esc.index=0;
   assert.equal(esc.settings.NAME,'Compasless 3D');
   assert.deepEqual(backend.memory.slice(0,backend.applicationEnd),expected.slice(0,backend.applicationEnd));
   const protectedStart=record.mcu==='X'?0xF000:0x1C00;
   assert.deepEqual(backend.memory.slice(protectedStart),old.slice(protectedStart));
   total++;
  }
  if(esc.firmwareName==='UNKNOWN')unknown++;
 }
 assert.equal(total,2016);assert.equal(unknown,84);
});
test('public configurator blocks mismatched layout and MCU before erase or write',async()=>{
 const record=manifest.targets.find(item=>item.target==='A_H_5_48');
 const hex=await load(record),base=image(hex);
 for(const offset of [0x1A41,0x1A5D]){
  const mismatch=base.slice();mismatch[offset]^=1;
  const backend=memoryBackend.createMemoryEscBackend({image:mismatch});
  const driver=new FourWay(backend.serial);
  const esc={index:0,isSiLabs:true,isArm:false,firmwareName:'BLHeli_S',meta:{interfaceMode:1,signature:0xE8B2}};
  await driver.writeHex(0,esc,hex,false,false,()=>{});
  assert.equal(backend.stats.writes,0);assert.equal(backend.stats.erases,0);
 }
});
