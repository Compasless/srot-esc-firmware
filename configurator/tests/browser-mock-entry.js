import {createSrotBoard} from './helpers/srot-board.mjs';
export function install(images){
 const board=createSrotBoard(images);
 const api=new EventTarget();
 api.requestPort=async()=>board.port;
 api.getPorts=async()=>[board.port];
 Object.defineProperty(navigator,'serial',{configurable:true,value:api});
 window.__srotTest={board,writeCount:()=>board.backends.reduce((n,item)=>n+(item?.stats.writes||0),0),
 mode:index=>board.backends[index].memory[board.backends[index].eeprom+11],
 setting:(index,offset)=>board.backends[index].memory[board.backends[index].eeprom+offset]};
}
