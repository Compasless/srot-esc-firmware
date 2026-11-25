// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Compasless contributors
import {BenchSerial,FIELDS,targetFor,checkedFirmware,editedSettings,srotSource} from './protocol.js';

const root=document.querySelector('#app'),dialog=document.querySelector('#flash-dialog');
const state={manifest:null,escs:Array(4).fill(null),selected:0,pwm:48,connected:false,busy:false,
  serial:null,port:null,count:4,reading:-1,view:'workbench',notice:null,logs:[],progress:0,
  localFile:null,pending:null,flashing:false,library:{family:'H',layout:'A',deadtime:5,pwm:48}};
const html=value=>String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const paths={
 chip:'M7 4v3M12 4v3M17 4v3M7 17v3M12 17v3M17 17v3M4 7h3M4 12h3M4 17h3M17 7h3M17 12h3M17 17h3M7 7h10v10H7z',
 usb:'M12 21V5m0 0-3 3m3-3 3 3M12 15l-5-4V8m5 10 5-4v-3M5 5h4v3H5zm10 3h4v3h-4z',
 board:'M4 5h16v14H4zM8 9h5v6H8zM16 9h1m-1 3h1m-1 3h1',
 library:'M4 5h4v15H4zm6-2h4v17h-4zm6 3 4-1 3 14-4 1z',
 book:'M3 5c3-1 6-1 9 1 3-2 6-2 9-1v15c-3-1-6-1-9 1-3-2-6-2-9-1zm9 1v15',
 activity:'M3 12h4l3-7 4 14 3-7h4',
 shield:'m12 3 8 3v6c0 4-4 7-8 9-4-2-8-5-8-9V6zm-4 9 3 3 5-6'
};
const icon=(name,cls='')=>'<svg class="'+cls+'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="'+(paths[name]||paths.chip)+'"/></svg>';
const disabled=condition=>condition?'disabled':'';
function log(message){
 state.logs.unshift({time:new Date().toLocaleTimeString([], {hour12:false}),message});
 state.logs=state.logs.slice(0,100);
 const list=document.querySelector('#activity-list');
 if(list)list.innerHTML=logList();
}
function notify(message,type='info'){state.notice={message,type};render();}
function logList(){return state.logs.length?state.logs.map(item=>'<li><time>'+html(item.time)+'</time><span>'+html(item.message)+'</span></li>').join(''):'<li><span>No activity yet. Connect the USB flasher to begin.</span></li>';}
function isSrot(esc){return srotSource.isValidName(esc?.settings?.NAME)&&esc?.layoutRevision==='208';}
function selectedEsc(){return state.escs[state.selected];}
function selectedRecord(){
 if(!state.manifest||!selectedEsc())return null;
 try{return targetFor(selectedEsc(),state.pwm,state.manifest);}catch{return null;}
}
function activity(){return '<details class="panel activity" open><summary class="panel-content">Activity log</summary><div class="panel-content"><ol id="activity-list">'+logList()+'</ol><button class="button subtle" data-action="export-log">Export log</button></div></details>';}
function slot(esc,index){
 const status=state.reading===index?'Reading…':esc?'Detected':state.connected?'No response':'Not connected';
 return '<button class="esc-slot '+(esc?'detected ':'')+(state.selected===index?'selected':'')+'" data-action="select-esc" data-index="'+index+'" '+disabled(state.busy||!esc)+' aria-pressed="'+(state.selected===index)+'"><span class="esc-number">ESC '+(index+1)+'</span><span class="slot-chip"></span><span class="status">'+status+'</span><span class="target">'+html(esc?.settings?.LAYOUT?.trim().replaceAll('#','')||'—')+'</span></button>';
}
function fieldControl(field,esc){
 const value=esc?.settings?.[field.key]??'';
 const off=disabled(!state.connected||state.busy||!isSrot(esc));
 if(field.type==='select')return '<label class="field">'+field.label+'<select data-setting="'+field.key+'" '+off+'>'+field.options.map(([key,label])=>'<option value="'+key+'" '+(Number(value)===key?'selected':'')+'>'+html(label)+'</option>').join('')+'</select></label>';
 return '<label class="field">'+field.label+'<input data-setting="'+field.key+'" type="number" min="'+field.min+'" max="'+field.max+'" step="1" value="'+html(value)+'" '+off+'><span class="help">Stored value · '+field.min+'–'+field.max+'</span></label>';
}
function devicePanel(){
 const esc=selectedEsc();
 if(!esc)return '<div class="empty-state">'+icon('usb')+'<h3>'+(state.connected?'Read your ESCs':'Connect your bench flasher')+'</h3><p>'+(state.connected?'Power the ESCs separately, share ground with the flasher, then read the connected channels.':'Connect the SROT ESC flasher by USB. Read up to four channels before choosing a firmware image.')+'</p><button class="button '+(state.connected?'':'primary')+'" data-action="'+(state.connected?'scan':'connect')+'" '+disabled(state.busy||(!state.connected&&!('serial'in navigator)))+'>'+(state.connected?'Read ESCs':'Connect flasher')+'</button></div>';
 const own=isSrot(esc);
 return '<div class="device-heading"><div><h3>ESC '+(esc.index+1)+' settings</h3><p>'+html(esc.settings.LAYOUT?.trim())+' · '+html(esc.settings.MCU?.trim().replaceAll('#',''))+'</p></div><span class="badge '+(own?'cyan':'')+'">'+(own?'Compasless SROT':'Existing firmware')+'</span></div>'+
  '<div class="mode-line"><span>'+(own?'Motor operating mode':'Current firmware')+'</span><strong>'+(own?'Forward / reverse · 3D fixed':html(esc.settings.NAME?.trim()||esc.firmwareName))+'</strong></div>'+
  (!own?'<p class="quiet">Flash Compasless SROT firmware to configure its parameters here. Existing settings can be exported first.</p>':'')+
  '<div class="form-grid">'+FIELDS.map(field=>fieldControl(field,esc)).join('')+'</div>'+
  '<div class="panel-actions"><button class="button subtle" data-action="export-settings" '+disabled(state.busy)+'>Export settings</button><button class="button" data-action="read-selected" '+disabled(state.busy||!state.connected)+'>Read again</button><button class="button primary" data-action="save-settings" '+disabled(state.busy||!state.connected||!own)+'>Save settings</button></div>';
}
function firmwarePanel(){
 const esc=selectedEsc(),record=selectedRecord();
 let reason='Connect and read an ESC to select its exact hardware target.';
 if(esc&&!record){try{targetFor(esc,state.pwm,state.manifest);}catch(error){reason=error.message;}}
 return '<section class="panel"><div class="panel-header"><h2>Firmware</h2><span class="badge dev">Bench release</span></div><div class="panel-content"><div class="eyebrow">COMPASLESS SROT ESC</div><div class="firmware-title">3D thruster firmware</div><p class="quiet">v0.4.0 · Source-built and verified</p><div class="firmware-info"><div><span>Operating mode</span><strong>3D only</strong></div><div><span>Hardware target</span><strong>'+html(record?.target||'Awaiting ESC')+'</strong></div><div><span>Channels</span><strong>One image per ESC</strong></div><div><span>Integrity</span><strong>SHA-256 verified</strong></div></div>'+
 '<div class="firmware-stack"><label class="field">PWM frequency<select id="pwm" '+disabled(state.busy)+'>'+[24,48,96].map(value=>'<option value="'+value+'" '+(state.pwm===value?'selected':'')+'>'+value+' kHz</option>').join('')+'</select></label><button class="button primary full" data-action="prepare-flash" '+disabled(state.busy||!state.connected||!record)+'>Flash ESC '+(state.selected+1)+'</button><button class="button full" data-action="download-selected" '+disabled(state.busy||!record)+'>Download matching HEX</button><div class="secondary-links"><a href="https://github.com/Compasless/srot-esc-firmware/releases/tag/v0.4.0" target="_blank" rel="noopener">Release notes</a><a href="https://esc-configurator.com/" target="_blank" rel="noopener">Public configurator</a></div></div>'+
 (!record?'<p class="help">'+html(reason)+'</p>':'<p class="help">The layout, MCU and deadtime must match. Hardware checks stay enabled.</p>')+
 '<div class="local-file"><label>Choose local HEX<input id="local-hex" type="file" accept=".hex"></label><span>'+html(state.localFile?.name||'Optional')+'</span></div>'+
 '<div class="progress-area" '+(state.flashing?'':'hidden')+'><span id="flash-progress-label">Writing and verifying '+Math.round(state.progress)+'%</span><progress id="flash-progress" max="100" value="'+state.progress+'"></progress></div></div></section>'+
 '<section class="panel" style="margin-top:18px"><div class="panel-content"><div class="eyebrow">BEFORE YOU FLASH</div><p class="quiet">Remove propellers or disconnect thrusters. Keep ESC power stable throughout the write.</p><p class="help">Software verified. Hardware and underwater qualification remain pending.</p><a href="#" data-view="guide" class="quiet">Wiring and compatibility guide</a></div></section>';
}
function workbench(){return '<div class="workspace-grid"><div><section class="panel"><div class="panel-header"><h2>Connected ESCs</h2><button class="button subtle" data-action="scan" '+disabled(!state.connected||state.busy)+'>Read ESCs</button></div><div class="panel-content"><div class="esc-grid">'+state.escs.map(slot).join('')+'</div>'+devicePanel()+'</div></section>'+activity()+'</div><aside>'+firmwarePanel()+'</aside></div>';}
function libraryRecord(){const q=state.library;return state.manifest?.targets.find(item=>item.mcu===q.family&&item.layout===q.layout&&item.deadtime===Number(q.deadtime)&&item.pwm_khz===Number(q.pwm));}
function library(){
 const q=state.library,records=state.manifest?.targets||[],layouts=[...new Set(records.filter(r=>r.mcu===q.family).map(r=>r.layout))];
 const record=libraryRecord();
 return '<section class="panel guide"><div class="panel-content"><div class="eyebrow">VERIFIED RELEASE</div><h2>Firmware library</h2><p>Download a separate HEX image for your exact ESC target. These files also work with the public configurator’s local-file flashing flow.</p><div class="chip-row"><span class="chip">v0.4.0</span><span class="chip">1,008 targets</span><span class="chip">3D only</span></div><div class="library-controls">'+
 '<label class="field">MCU family<select data-library="family"><option value="H" '+(q.family==='H'?'selected':'')+'>H · EFM8BB21</option><option value="X" '+(q.family==='X'?'selected':'')+'>X · EFM8BB51</option></select></label>'+
 '<label class="field">Layout<select data-library="layout">'+layouts.map(value=>'<option '+(q.layout===value?'selected':'')+'>'+html(value)+'</option>').join('')+'</select></label>'+
 '<label class="field">Deadtime<select data-library="deadtime">'+[0,5,10,15,20,25,30,40,50,70,90,120].map(value=>'<option '+(Number(q.deadtime)===value?'selected':'')+'>'+value+'</option>').join('')+'</select></label>'+
 '<label class="field">PWM frequency<select data-library="pwm">'+[24,48,96].map(value=>'<option '+(Number(q.pwm)===value?'selected':'')+'>'+value+'</option>').join('')+'</select></label></div><div class="target-preview">'+html(record?.filename||'No matching target')+'</div><button class="button primary" data-action="download-library" '+disabled(!record||state.busy)+'>Download HEX</button> <a class="button" href="https://github.com/Compasless/srot-esc-firmware/releases/download/v0.4.0/Compasless-SROT-ESC-v0.4.0.zip">Download all targets</a>'+
 '<h3>Using esc-configurator.com</h3><ol><li>Connect the SROT USB flasher and read the ESCs.</li><li>Choose Flash, then Select File Locally, and open the matching HEX.</li><li>Leave Ignore MCU layout and Migrate settings unchecked.</li></ol><p>The public site can flash these files but does not provide Compasless parameter editing. It may display BLHeli_S or UNKNOWN after flashing. Return to this configurator for recognized firmware and settings.</p><p>A 4-in-1 board still has four independently addressed ESCs. Read their identities; do not choose a layout from the board’s channel count.</p></div></section>';
}
function guide(){return '<section class="panel guide"><div class="panel-content"><div class="eyebrow">SROT USB FLASHER</div><h2>Your bench connection</h2><p>Use Chrome or Edge on a desktop computer. The SROT ESP32 flasher connects over USB at 115200 baud and exposes up to four ESC channels.</p><table><thead><tr><th>ESP32 DevKit</th><th>Connection</th></tr></thead><tbody><tr><td>GP16</td><td>ESC 1 signal</td></tr><tr><td>GP17</td><td>ESC 2 signal</td></tr><tr><td>GP18</td><td>ESC 3 signal</td></tr><tr><td>GP19</td><td>ESC 4 signal</td></tr><tr><td>GND</td><td>Common ESC ground</td></tr></tbody></table><p>Power the ESCs from their own supply. The USB flasher does not provide ESC power. Close serial monitors before connecting here.</p><h3>Connect, read, flash</h3><ol><li>Remove propellers or disconnect thrusters, and connect the signal and ground wires.</li><li>Connect the USB flasher, choose Connect flasher, then read the ESCs.</li><li>Select a detected channel. Its exact layout, MCU and deadtime select the firmware target.</li><li>Flash the verified build and wait for writing and readback verification to finish.</li></ol><h3>Fixed 3D operation</h3><p>Compasless SROT has only forward/reverse 3D operation. Other operating-mode commands are ignored. The operating mode cannot be changed from this interface.</p><h3>Qualification</h3><p>This is a development bench release. The inherited 3D startup/performance issue remains unresolved, and physical ESC and underwater qualification have not been completed. Compilation and simulated protocol checks do not replace those tests.</p><h3>Troubleshooting</h3><p>If no ESC answers, check its separate power and shared ground, and use the SROT flasher diagnostic build. A layout or MCU mismatch blocks flashing; resolve the identity instead of bypassing the check.</p><div class="panel-actions"><a class="button" href="https://github.com/Compasless/srot-esc-flasher" target="_blank" rel="noopener">Flasher hardware project</a><a class="button" href="https://github.com/Compasless/srot-esc-firmware/blob/main/docs/COMPATIBILITY.md" target="_blank" rel="noopener">Firmware compatibility</a></div></div></section>';}
function render(){
 const found=state.escs.filter(Boolean).length;
 root.innerHTML='<div class="shell"><aside class="sidebar"><div class="brand"><svg viewBox="0 0 44 44" aria-hidden="true"><path d="m22 2 18 20-18 20L4 22z" fill="none" stroke="#376875"/><path d="m27 8-3 16-16 3 13-9z" fill="#69e0d0"/><path d="m17 36 3-16 16-3-13 9z" fill="#276b7a"/></svg><div><div class="brand-word">SROT</div><small>COMPASLESS</small></div></div><nav class="nav" aria-label="Main navigation">'+[['workbench','board','Workbench'],['library','library','Firmware library'],['guide','book','Hardware guide'],['activity','activity','Activity']].map(([key,symbol,title])=>'<button data-view="'+key+'" class="'+(state.view===key?'active':'')+'">'+icon(symbol)+title+'</button>').join('')+'</nav><div class="sidebar-bottom"><strong>Designed for the bench</strong>SROT USB 4-way flasher<br>Configurator v0.1.0</div></aside><main class="main"><header class="topbar"><div><div class="breadcrumb"><span>ESC TOOLS</span> / Configurator</div><h1>ESC Configurator</h1><p class="subtitle">Read, configure and flash reversible thruster ESCs.</p></div><div class="top-actions"><span class="badge '+(state.connected?'connected':'')+'">'+(state.connected?'Flasher connected':'Disconnected')+'</span><button class="button '+(state.connected?'':'primary')+'" data-action="'+(state.connected?'disconnect':'connect')+'" '+disabled(state.busy||(!state.connected&&!('serial'in navigator)))+'>'+(state.busy&&!state.connected?'Connecting…':state.connected?'Disconnect':'Connect flasher')+'</button></div></header>'+
 '<div class="summary-grid"><div class="summary-card"><span class="summary-icon">'+icon('usb')+'</span><div><p class="summary-label">USB interface</p><div class="summary-value">'+(state.connected?'SROT 4-way':'Awaiting connection')+'</div><div class="summary-note">115200 baud · USB serial</div></div></div><div class="summary-card"><span class="summary-icon">'+icon('chip')+'</span><div><p class="summary-label">Detected channels</p><div class="summary-value">'+found+' / '+state.count+' ESCs</div><div class="summary-note">Independent hardware targets</div></div></div><div class="summary-card"><span class="summary-icon">'+icon('shield')+'</span><div><p class="summary-label">Firmware profile</p><div class="summary-value">Forward / reverse 3D</div><div class="summary-note">Fixed mode · Compasless SROT</div></div></div></div>'+
 (state.notice?'<div class="notice '+html(state.notice.type)+'" role="'+(state.notice.type==='error'?'alert':'status')+'"><span>'+html(state.notice.message)+'</span><button data-action="dismiss" aria-label="Dismiss message">×</button></div>':'')+
 (state.view==='workbench'?workbench():state.view==='library'?library():state.view==='guide'?guide():activity())+
 '<footer class="footer"><span>Compasless SROT · Browser-based bench tools</span><span><a href="https://github.com/Compasless/srot-esc-firmware/tree/main/configurator" target="_blank" rel="noopener">Source code</a> · <a href="./NOTICE" target="_blank">Credits</a> · <a href="./LICENSE" target="_blank">AGPL-3.0</a></span></footer></main></div>';
}
async function action(name,handler){
 if(state.busy)return;
 state.busy=true;state.notice=null;render();log(name);
 try{await handler();}catch(error){state.notice={message:error.message||String(error),type:'error'};log('Error: '+(error.message||error));}
 finally{state.busy=false;state.reading=-1;state.flashing=false;render();}
}
async function scan(){
 state.escs=Array(4).fill(null);
 for(let index=0;index<state.count;index++){
  state.reading=index;render();
  try{
   const esc=await state.serial.getFourWayInterfaceInfo(index);
   esc.index=index;state.escs[index]=esc;
   log('ESC '+(index+1)+': '+(esc.settings.LAYOUT||'unknown layout')+' · '+(esc.settings.NAME||esc.firmwareName));
  }catch(error){log('ESC '+(index+1)+' did not respond: '+error.message);}
 }
 state.reading=-1;
 const first=state.escs.findIndex(Boolean);
 if(first>=0){state.selected=first;const pwm=Number(state.escs[first].settings.PWM_FREQUENCY);if([24,48,96].includes(pwm))state.pwm=pwm;state.notice={message:'ESCs read. Select a channel to inspect its settings or flash matching firmware.',type:'success'};}
 else state.notice={message:'No ESC responded. Check separate ESC power, signal wires and shared ground.',type:'error'};
}
async function connect(){
 if(!('serial'in navigator))throw new Error('Web Serial is unavailable. Open this page in desktop Chrome or Edge.');
 if(!state.manifest)throw new Error('The firmware catalog is not available yet.');
 const port=await navigator.serial.requestPort();
 const serial=new BenchSerial(port);
 state.port=port;state.serial=serial;
 try{
  await serial.open(115200);
  serial.setLogCallback((key,params)=>log(key.replace(/([a-z])([A-Z])/g,'$1 $2')+(params?.index?' · ESC '+params.index:'')));
  await new Promise(resolve=>setTimeout(resolve,1200));
  await serial.getApiVersion();
  const info=await serial.enable4WayInterface();
  if(!Number.isInteger(info?.connectedESCs)||info.connectedESCs<1||info.connectedESCs>4)throw new Error('This interface did not report one to four ESC channels.');
  state.count=info.connectedESCs;state.connected=true;
  serial.startFourWayInterface();
  log('USB MSP/4-way interface connected at 115200 baud.');
  await scan();
 }catch(error){await serial.close();state.connected=false;state.serial=null;state.port=null;throw error;}
}
async function disconnect(){
 if(state.serial)await state.serial.close();
 state.connected=false;state.serial=null;state.port=null;state.escs=Array(4).fill(null);log('Flasher disconnected.');
}
async function firmwareBytes(record){const response=await fetch('./firmware/'+encodeURIComponent(record.filename));if(!response.ok)throw new Error('Could not load the firmware file.');return new Uint8Array(await response.arrayBuffer());}
function download(bytes,name,type='application/octet-stream'){
 const blob=new Blob([bytes],{type}),url=URL.createObjectURL(blob),link=document.createElement('a');
 link.href=url;link.download=name;link.click();setTimeout(()=>URL.revokeObjectURL(url),2000);
}
async function downloadRecord(record){
 if(!record)throw new Error('Choose a valid target first.');
 const bytes=await firmwareBytes(record);
 const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),value=>value.toString(16).padStart(2,'0')).join('');
 if(hash!==record.sha256)throw new Error('The downloaded firmware checksum is invalid.');
 download(bytes,record.filename,'text/plain');log('Downloaded verified HEX: '+record.filename);
}
async function prepareFlash(){
 const esc=selectedEsc(),record=targetFor(esc,state.pwm,state.manifest);
 state.pending={esc,record,file:state.localFile};
 document.querySelector('#flash-summary').textContent='ESC '+(esc.index+1)+' · '+record.target+' · Compasless SROT v0.4.0 · 3D only';
 document.querySelector('#bench-confirm').checked=false;
 document.querySelector('#confirm-flash').disabled=true;
 dialog.returnValue='cancel';dialog.showModal();
}
async function flash(pending){
 const {esc,record,file}=pending;
 if(!state.connected||state.escs[esc.index]!==esc)throw new Error('Read the ESC again before flashing.');
 const bytes=file?new Uint8Array(await file.arrayBuffer()):await firmwareBytes(record);
 const hex=await checkedFirmware(record,bytes,esc);
 state.flashing=true;state.progress=0;render();
 await state.serial.flashPreflight(esc,hex,false);
 const result=await state.serial.writeHex(esc.index,esc,hex,false,false,progress=>{
  state.progress=Math.min(100,progress);
  const bar=document.querySelector('#flash-progress'),label=document.querySelector('#flash-progress-label');
  if(bar)bar.value=state.progress;if(label)label.textContent='Writing and verifying '+Math.round(state.progress)+'%';
 });
 if(!result||!isSrot(result)||state.progress<99)throw new Error('The write did not complete with verified Compasless firmware. Keep the ESC available for recovery.');
 result.index=esc.index;state.escs[esc.index]=result;state.localFile=null;
 state.notice={message:'ESC '+(esc.index+1)+' flashed and readback verified. Compasless 3D is detected.',type:'success'};
 log('ESC '+(esc.index+1)+' firmware verified after flash: '+record.filename);
}
async function saveSettings(values){
 const esc=selectedEsc();
 const settings=editedSettings(esc,values);
 await state.serial.writeSettings(esc.index,esc,settings);
 const fresh=await state.serial.getFourWayInterfaceInfo(esc.index);
 fresh.index=esc.index;state.escs[esc.index]=fresh;
 if(fresh.settings.MOTOR_DIRECTION!==3)throw new Error('The fixed 3D setting was not read back correctly.');
 state.notice={message:'ESC '+(esc.index+1)+' settings saved and verified. Operating mode remains 3D.',type:'success'};
}
root.addEventListener('click',event=>{
 const navigation=event.target.closest('[data-view]');
 if(navigation){event.preventDefault();if(!state.busy){state.view=navigation.dataset.view;render();}return;}
 const target=event.target.closest('[data-action]');
 if(!target||target.disabled)return;
 event.preventDefault();const name=target.dataset.action;
 if(name==='dismiss'){state.notice=null;render();return;}
 if(name==='select-esc'){state.selected=Number(target.dataset.index);state.localFile=null;const value=Number(selectedEsc()?.settings.PWM_FREQUENCY);if([24,48,96].includes(value))state.pwm=value;render();return;}
 if(name==='connect')return action('Connecting USB flasher',connect);
 if(name==='disconnect')return action('Disconnecting',disconnect);
 if(name==='scan')return action('Reading connected ESCs',scan);
 if(name==='prepare-flash')return prepareFlash().catch(error=>notify(error.message,'error'));
 if(name==='save-settings'){
  const values={};for(const input of root.querySelectorAll('[data-setting]'))values[input.dataset.setting]=input.value;
  return action('Saving settings',()=>saveSettings(values));
 }
 if(name==='read-selected')return action('Reading selected ESC',async()=>{const esc=await state.serial.getFourWayInterfaceInfo(state.selected);esc.index=state.selected;state.escs[state.selected]=esc;});
 if(name==='download-selected')return action('Downloading matching HEX',()=>downloadRecord(selectedRecord()));
 if(name==='download-library')return action('Downloading firmware HEX',()=>downloadRecord(libraryRecord()));
 if(name==='export-settings'){const esc=selectedEsc();if(esc)download(JSON.stringify({channel:esc.index+1,settings:esc.settings,exported_at:new Date().toISOString()},null,2),'SROT-ESC-'+(esc.index+1)+'-settings.json','application/json');return;}
 if(name==='export-log')download(state.logs.map(item=>item.time+' '+item.message).reverse().join('\n'),'SROT-configurator-log.txt','text/plain');
});
root.addEventListener('change',event=>{
 if(event.target.id==='pwm'){state.pwm=Number(event.target.value);state.localFile=null;render();}
 if(event.target.id==='local-hex'){state.localFile=event.target.files[0]||null;render();}
 if(event.target.dataset.library){
  state.library[event.target.dataset.library]=event.target.value;
  if(event.target.dataset.library==='family')state.library.layout='A';
  render();
 }
});
document.querySelector('#bench-confirm').addEventListener('change',event=>{document.querySelector('#confirm-flash').disabled=!event.target.checked;});
dialog.addEventListener('close',()=>{
 const pending=state.pending;state.pending=null;
 if(dialog.returnValue==='flash'&&document.querySelector('#bench-confirm').checked&&pending)action('Flashing ESC '+(pending.esc.index+1),()=>flash(pending));
});
window.addEventListener('beforeunload',event=>{if(state.flashing){event.preventDefault();event.returnValue='';}});
navigator.serial?.addEventListener('disconnect',event=>{
 if(event.target===state.port||event.port===state.port){
  const serial=state.serial;state.serial=null;state.port=null;state.connected=false;
  serial?.close(true).catch(()=>{});
  state.notice={message:'The USB flasher disconnected. Reconnect and read the ESCs before continuing.',type:'error'};
  log('USB connection lost.');render();
 }
});
render();
try{
 const response=await fetch('./firmware/manifest.json');
 if(!response.ok)throw new Error('Firmware catalog unavailable.');
 state.manifest=await response.json();
 if(state.manifest.version!=='0.4.0'||state.manifest.targets?.length!==1008)throw new Error('Unexpected firmware catalog.');
 if(!('serial'in navigator))state.notice={message:'Firmware downloads are available. USB connection requires desktop Chrome or Edge with Web Serial.',type:'info'};
 render();
}catch(error){notify(error.message,'error');}
