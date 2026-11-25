// SPDX-License-Identifier: AGPL-3.0-only
import memoryBackend from './memory-esc.cjs';
const {createMemoryEscBackend,crc16}=memoryBackend;
function reply(command,params,ack=0,address=0){
 const data=new Uint8Array(8+params.length);
 data.set([0x2E,command,address>>8,address&255,params.length===256?0:params.length]);data.set(params,5);data[5+params.length]=ack;
 const crc=crc16(data.subarray(0,-2));data[data.length-2]=crc>>8;data[data.length-1]=crc&255;return data;
}
export function createSrotBoard(images){
 const backends=images.map(item=>item?createMemoryEscBackend(item):null);
 let selected=0,controller,closed=false;
 const events=[];
 const port={
  readable:new ReadableStream({start(c){controller=c;},cancel(){closed=true;}}),
  writable:new WritableStream({async write(input){
   const packet=new Uint8Array(input),response=process(packet);
   if(response&&!closed){
    // Fragment frames to exercise the actual serial queue/parser.
    setTimeout(()=>{if(!closed){controller.enqueue(response.slice(0,3));controller.enqueue(response.slice(3));}},1);
   }
  }}),
  async open(options){if(options.baudRate!==115200)throw Error('Unexpected baud');events.push({kind:'open'});},
  async close(){closed=true;events.push({kind:'close'});},
  getInfo(){return {usbVendorId:0x10C4,usbProductId:0xEA60};},
  async setSignals(){},async getSignals(){return {};}
 };
 function process(packet){
  if(packet[0]===0x24){
   const size=packet[3],command=packet[4];
   let checksum=size^command;
   for(const byte of packet.slice(5,5+size))checksum^=byte;
   if(checksum!==packet[5+size])throw Error('Invalid MSP checksum');
   const params=command===1?[0,1,40]:command===245?[4]:null;
   if(!params)throw Error('Unexpected MSP command '+command);
   events.push({kind:'msp',command});
   const data=Uint8Array.from([0x24,0x4D,0x3E,params.length,command,...params,0]);
   data[data.length-1]=data.slice(3,-1).reduce((a,b)=>a^b,0);return data;
  }
  if(packet[1]===0x37)selected=packet[5];
  const backend=backends[selected];
  if(!backend)return reply(packet[1],Uint8Array.of(0),0x0F);
  if(packet[1]===0x37){
   packet=packet.slice();packet[5]=0;const crc=crc16(packet.subarray(0,-2));packet[packet.length-2]=crc>>8;packet[packet.length-1]=crc&255;
  }
  return backend.processPacket(packet);
 }
 return {port,backends,events,process};
}
