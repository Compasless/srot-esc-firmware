'use strict';
// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Compasless contributors
// Research-only ESC flash memory transport. No serial-device access and no firmware logic stubs.
function crc16(bytes) {
  let crc=0;
  for(const byte of bytes) {
    crc^=byte<<8;
    for(let bit=0;bit<8;bit++) crc=((crc&0x8000)?(crc<<1)^0x1021:crc<<1)&0xffff;
  }
  return crc;
}
function createMemoryEscBackend({image,family='H',signature=family==='X'?0xE8B5:0xE8B2,mode=1,strictFlash=true}={}) {
  if(!image)throw Error('image is required');
  const memory=Uint8Array.from(image), pageSize=family==='X'?2048:512;
  const stats={packets:0,reads:0,writes:0,erases:0,writeAddresses:[],eraseAddresses:[]};
  const events=[];
  function processPacket(input) {
    const packet=input instanceof Uint8Array?input:new Uint8Array(input);
    if(packet[0]!==0x2f)throw Error('Expected 4-way request start 0x2f; MSP requests must be handled separately');
    const count=packet[4]||256;
    if(packet.length!==7+count)throw Error('Incomplete 4-way request');
    if(crc16(packet.subarray(0,-2))!==((packet[packet.length-2]<<8)|packet[packet.length-1]))throw Error('Request CRC mismatch');
    const command=packet[1],address=(packet[2]<<8)|packet[3],params=packet.slice(5,5+count);
    stats.packets++;
    let result;
    switch(command) {
      case 0x30: result=Uint8Array.of(0);break; // InterfaceTestAlive
      case 0x31: result=Uint8Array.of(108);break; // 4-way protocol version 108
      case 0x32: result=new TextEncoder().encode('MEMORY');break;
      case 0x33: result=Uint8Array.of(0,1);break;
      case 0x34: return null; // InterfaceExit does not return a response
      case 0x35: result=Uint8Array.of(0);break; // DeviceReset
      case 0x37:
        if(params[0]!==0)throw Error('This backend models only ESC index 0');
        result=Uint8Array.of(signature&255,signature>>8,0,mode);break;
      case 0x3a: {
        const amount=params[0]||256;
        if(address+amount>memory.length)throw Error('Read outside memory');
        result=memory.slice(address,address+amount);stats.reads++;break;
      }
      case 0x3b: {
        if(address+params.length>memory.length)throw Error('Write outside memory');
        if(strictFlash)for(let i=0;i<params.length;i++)if((memory[address+i]&params[i])!==params[i])throw Error('Write changes flash bit from 0 to 1 without erase');
        memory.set(params,address);stats.writes++;stats.writeAddresses.push([address,params.length]);result=Uint8Array.of(0);break;
      }
      case 0x39: {
        const eraseAddress=family==='X'?Math.floor(params[0]/4)*2048:params[0]*512;
        if(eraseAddress+pageSize>memory.length)throw Error('Erase outside memory');
        memory.fill(255,eraseAddress,eraseAddress+pageSize);stats.erases++;stats.eraseAddresses.push([eraseAddress,pageSize]);result=Uint8Array.of(0);break;
      }
      default: throw Error('Unsupported memory backend command 0x'+command.toString(16));
    }
    events.push({command,address,params:Array.from(params),resultLength:result.length});
    const reply=new Uint8Array(8+result.length);
    reply.set([0x2e,command,address>>8,address&255,result.length===256?0:result.length]);reply.set(result,5);reply[5+result.length]=0;
    const crc=crc16(reply.subarray(0,-2));reply[reply.length-2]=crc>>8;reply[reply.length-1]=crc&255;
    return reply;
  }
  async function serial(request,parseMessage) {
    const reply=processPacket(request);
    if(!reply)return undefined;
    return new Promise((resolve,reject)=>parseMessage(reply.buffer,resolve,reject));
  }
  function createWebSerialPort() {
    let readerController;
    const readable=new ReadableStream({start(controller){readerController=controller;}});
    const writable=new WritableStream({write(chunk){const reply=processPacket(chunk);if(reply)readerController.enqueue(reply);}});
    return {readable,writable,async open(){},async close(){},getInfo(){return {usbVendorId:0,usbProductId:0};},async getSignals(){return {};},async setSignals(){}};
  }
  return {memory,stats,events,processPacket,serial,createWebSerialPort,pageSize,eeprom:family==='X'?0x3000:0x1a00,applicationEnd:family==='X'?0x3800:0x1c00};
}
module.exports={createMemoryEscBackend,crc16};
