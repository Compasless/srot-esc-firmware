// SPDX-License-Identifier: AGPL-3.0-only
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {unzipSync} from 'fflate';
import {build} from 'esbuild';

export const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const pin=JSON.parse(await fs.readFile(path.join(ROOT,'upstream.lock.json'),'utf8'));
const cache=path.join(ROOT,'.cache');
await fs.mkdir(cache,{recursive:true});
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
async function download(url,file,expected) {
  let bytes;
  try{bytes=await fs.readFile(file);}catch{
    console.log('Downloading '+new URL(url).hostname+' asset');
    const response=await fetch(url);
    if(!response.ok) throw new Error('Download failed: '+response.status+' '+url);
    bytes=Buffer.from(await response.arrayBuffer());
    if(digest(bytes)!==expected)throw new Error('Download checksum mismatch: '+url);
    await fs.writeFile(file,bytes);
  }
  if(digest(bytes)!==expected)throw new Error('Cached asset checksum mismatch: '+file);
  return bytes;
}
function replaceOnce(text,oldValue,newValue) {
  if(text.split(oldValue).length!==2)throw new Error('Upstream patch context differs');
  return text.replace(oldValue,newValue);
}
export async function prepare() {
  const archive=await download('https://codeload.github.com/stylesuxx/esc-configurator/zip/'+pin.commit,
    path.join(cache,'upstream.zip'),pin.archive_sha256);
  const upstream=path.join(cache,'upstream');
  const entries=unzipSync(archive);
  for(const [name,bytes]of Object.entries(entries)){
    if(!bytes.length&&name.endsWith('/'))continue;
    const relative=name.split('/').slice(1).join('/');
    if(!relative)continue;
    const target=path.resolve(upstream,relative);
    if(!target.startsWith(upstream+path.sep))throw new Error('Unsafe archive entry');
    await fs.mkdir(path.dirname(target),{recursive:true});
    await fs.writeFile(target,bytes);
  }
  const sources=path.join(upstream,'src','sources','index.js');
  let text=await fs.readFile(sources,'utf8');
  text="import {SrotSource,srotSource} from 'srot-firmware-source';\n"+text;
  text=replaceOnce(text,'const sources = [','const sources = [\n  srotSource,');
  text=replaceOnce(text,'const classes = {','const classes = {\n  SrotSource,');
  text=replaceOnce(text,'export {\n','export {\n  srotSource,');
  await fs.writeFile(sources,text);
  const fourWay=path.join(upstream,'src','utils','FourWay.js');
  text=await fs.readFile(fourWay,'utf8');
  text=replaceOnce(text,'  bluejaySource,','  bluejaySource,\n  srotSource,');
  text=replaceOnce(text,
    '        // Check if Bluejay\n        if(bluejaySource.isValidName(info.settings.NAME)) {',
    "        // Compasless has its own identity and the preserved layout 208.\n"+
    "        if(srotSource.isValidName(info.settings.NAME)) {\n"+
    "          source = srotSource;\n          info.layout = source.getLayout();\n"+
    "          info.layoutSize = source.getLayoutSize();\n"+
    "          settingsArray = (await this.read(eepromOffset, info.layoutSize)).params;\n"+
    "          info.settingsArray = Array.from(settingsArray);\n"+
    "          info.settings = Convert.arrayToSettingsObject(settingsArray, info.layout);\n"+
    "        } else if(bluejaySource.isValidName(info.settings.NAME)) {");
  await fs.writeFile(fourWay,text);
  return upstream;
}
export function bundlingOptions(upstream) {
 const source=name=>path.join(upstream,'src',name);
 return {bundle:true,target:['chrome109','edge109'],platform:'browser',format:'esm',
   alias:{'srot-firmware-source':path.join(ROOT,'src','firmware-source.js'),
     'esc-sources':source('sources/Bluejay/index.js'),'esc-eeprom':source('sources/Bluejay/eeprom.js'),
     'esc-settings':source('sources/Bluejay/settings.js'),'esc-layouts':source('sources/BlheliS/escs.json'),
     'esc-extra-layouts':source('sources/Bluejay/escs.json'),'esc-serial':source('utils/Serial.js'),
     'esc-fourway':source('utils/FourWay.js'),
     'esc-flash':source('utils/helpers/Flash.js'),'esc-general':source('utils/helpers/General.js')},
   plugins:[{name:'standalone-state',setup(builder){
     builder.onResolve({filter:/\/store$/},()=>({path:path.join(ROOT,'src','state-adapter.js')}));
     builder.onResolve({filter:/\/Statusbar\/statusSlice$/},()=>({path:path.join(ROOT,'src','state-adapter.js')}));
   }}]};
}
export async function buildSite() {
 const upstream=await prepare();
 const dist=path.join(ROOT,'dist');
 await fs.mkdir(dist,{recursive:true});
 const firmware=await download(pin.firmware.url,path.join(cache,'firmware.zip'),pin.firmware.sha256);
 const files=unzipSync(firmware);
 const manifest=JSON.parse(new TextDecoder().decode(files['build-manifest.json']));
 if(manifest.source_commit!==pin.firmware.source_commit||manifest.targets.length!==1008)throw new Error('Unexpected firmware provenance');
 const firmwareDir=path.join(dist,'firmware');
 await fs.mkdir(firmwareDir,{recursive:true});
 for(const record of manifest.targets){
   const data=files['hex/'+record.filename];
   if(!data||digest(data)!==record.sha256)throw new Error('Firmware checksum mismatch: '+record.target);
   await fs.writeFile(path.join(firmwareDir,record.filename),data);
 }
 await fs.writeFile(path.join(firmwareDir,'manifest.json'),JSON.stringify(manifest));
 for(const name of ['COPYING','NOTICE'])await fs.writeFile(path.join(firmwareDir,name),files[name]);
 for(const name of ['index.html','styles.css'])await fs.copyFile(path.join(ROOT,'src',name),path.join(dist,name));
 for(const name of ['LICENSE','NOTICE','upstream.lock.json'])await fs.copyFile(path.join(ROOT,name),path.join(dist,name));
 await build({...bundlingOptions(upstream),entryPoints:[path.join(ROOT,'src','app.js')],
   outfile:path.join(dist,'app.js'),minify:true,legalComments:'linked'});
 console.log('Built Compasless configurator with '+manifest.targets.length+' verified HEX targets.');
}
if(path.resolve(process.argv[1]||'')===fileURLToPath(import.meta.url))await buildSite();
