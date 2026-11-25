// SPDX-License-Identifier: AGPL-3.0-only
import fs from 'node:fs/promises';
import fsSync from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {spawn} from 'node:child_process';
import {chromium} from 'playwright';
import {build} from 'esbuild';
import {ROOT} from '../scripts/build.mjs';

const origin=process.env.SROT_PREVIEW_URL||'http://127.0.0.1:4173';
let ownedServer;
try{await fetch(origin);}catch{
 ownedServer=spawn(process.execPath,[path.join(ROOT,'scripts/serve.mjs')],{cwd:ROOT,windowsHide:true,stdio:'pipe'});
 for(let i=0;i<80;i++){try{await fetch(origin);break;}catch{await new Promise(r=>setTimeout(r,100));}}
}
const manifest=JSON.parse(await fs.readFile(path.join(ROOT,'dist/firmware/manifest.json'),'utf8'));
const fromHex=text=>{
 const memory=new Uint8Array(65536).fill(255);let base=0;
 for(const line of text.trim().split(/\r?\n/)){
  const n=parseInt(line.slice(1,3),16),address=parseInt(line.slice(3,7),16),type=parseInt(line.slice(7,9),16);
  if(type===4)base=parseInt(line.slice(9,13),16)<<16;
  if(type===0)for(let i=0;i<n;i++)memory[base+address+i]=parseInt(line.slice(9+i*2,11+i*2),16);
 }
 return memory;
};
const record=manifest.targets.find(item=>item.target==='A_H_5_48');
const source=await fs.readFile(path.join(ROOT,'dist/firmware',record.filename));
const original=fromHex(source.toString());
const xRecord=manifest.targets.find(item=>item.target==='A_X_5_48');
const xImage=fromHex(await fs.readFile(path.join(ROOT,'dist/firmware',xRecord.filename),'utf8'));
const oldImage=original.slice();
oldImage.set(new TextEncoder().encode('Bluejay (.0)    '),0x1A60);oldImage[0x1A01]=21;oldImage[0x1A0B]=1;
await build({bundle:true,platform:'browser',format:'iife',globalName:'SrotTestModule',
 entryPoints:[path.join(ROOT,'tests/browser-mock-entry.js')],outfile:path.join(ROOT,'.cache/browser-mock.js')});
const mock=await fs.readFile(path.join(ROOT,'.cache/browser-mock.js'),'utf8');
const images=[{image:Array.from(oldImage),family:'H'},{image:Array.from(xImage),family:'X'},
 {image:Array.from(original),family:'H'},{image:Array.from(original),family:'H'}];
const chromeCandidates=[process.env.SROT_BROWSER_PATH,
 'C:/Program Files/Google/Chrome/Application/chrome.exe',
 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].filter(Boolean);
const executable=chromeCandidates.find(name=>fsSync.existsSync(name));
const browser=await chromium.launch({headless:true,...(executable?{executablePath:executable}:{})});
const context=await browser.newContext({viewport:{width:1440,height:1080},acceptDownloads:true});
const page=await context.newPage(),errors=[];
page.on('pageerror',error=>errors.push(error.message));
await fs.mkdir(path.join(ROOT,'test-results'),{recursive:true});
try{
 await page.addInitScript({content:mock+'\nSrotTestModule.install('+JSON.stringify(images)+');'});
 await page.goto(origin,{waitUntil:'networkidle'});
 await page.waitForFunction(()=>document.querySelector('#pwm'));
 await page.screenshot({path:path.join(ROOT,'test-results/desktop-disconnected.png'),fullPage:true});
 await page.getByRole('button',{name:'Connect flasher',exact:true}).first().click();
 await page.waitForFunction(()=>document.querySelectorAll('.esc-slot.detected').length===4,{timeout:15000});
 assert.equal(await page.locator('.device-heading h3').textContent(),'ESC 1 settings');
 await page.getByRole('button',{name:'Flash ESC 1',exact:true}).click();
 await page.locator('#flash-dialog').waitFor({state:'visible'});
 await page.locator('#bench-confirm').check();
 await page.locator('#confirm-flash').click();
 await page.waitForFunction(()=>document.querySelector('.notice.success')?.textContent.includes('flashed and readback verified'),{timeout:30000});
 assert.equal(await page.evaluate(()=>window.__srotTest.mode(0)),3);
 assert.ok(await page.evaluate(()=>window.__srotTest.writeCount())>0);
 await page.locator('[data-setting="STARTUP_POWER_MAX"]').fill('7');
 await page.getByRole('button',{name:'Save settings',exact:true}).click();
 await page.waitForFunction(()=>document.querySelector('.notice.success')?.textContent.includes('settings saved and verified'));
 assert.equal(await page.evaluate(()=>window.__srotTest.setting(0,7)),7);
 assert.equal(await page.evaluate(()=>window.__srotTest.mode(0)),3);
 assert.equal(await page.locator('[data-setting="MOTOR_DIRECTION"]').count(),0);
 const writesBefore=await page.evaluate(()=>window.__srotTest.writeCount());
 const wrong=manifest.targets.find(item=>item.target==='B_H_5_48');
 await page.locator('#local-hex').setInputFiles(path.join(ROOT,'dist/firmware',wrong.filename));
 await page.getByRole('button',{name:'Flash ESC 1',exact:true}).click();
 await page.locator('#bench-confirm').check();await page.locator('#confirm-flash').click();
 await page.waitForFunction(()=>document.querySelector('.notice.error')?.textContent.includes('checksum'));
 assert.equal(await page.evaluate(()=>window.__srotTest.writeCount()),writesBefore);
 await page.getByRole('button',{name:'Firmware library',exact:true}).click();
 const event=page.waitForEvent('download');
 await page.getByRole('button',{name:'Download HEX',exact:true}).click();
 const download=await event;
 assert.equal(download.suggestedFilename(),record.filename);
 const downloaded=await fs.readFile(await download.path());
 assert.equal(createHash('sha256').update(downloaded).digest('hex'),record.sha256);
 await page.getByRole('button',{name:'Workbench',exact:true}).click();
 await page.screenshot({path:path.join(ROOT,'test-results/desktop-connected.png'),fullPage:true});
 await page.setViewportSize({width:390,height:844});
 await page.screenshot({path:path.join(ROOT,'test-results/mobile-connected.png'),fullPage:true});
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'Mobile view overflows horizontally');
 await page.setViewportSize({width:1440,height:1080});
 await page.getByRole('button',{name:'Disconnect',exact:true}).click();
 await page.waitForFunction(()=>document.querySelector('.top-actions .badge')?.textContent==='Disconnected');
 assert.deepEqual(errors,[]);
 console.log('Browser QA passed: connect, scan four channels, local flash, verification, settings save, fixed mode, checksum rejection, download, responsive layout and disconnect.');
}finally{await browser.close();if(ownedServer)ownedServer.kill();}
