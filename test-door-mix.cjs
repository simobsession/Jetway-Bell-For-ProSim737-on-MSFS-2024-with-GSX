const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
let door=0, simulatorDoor=0, distance=60; const values={}; let Instrument;
const context={BaseInstrument:class{},GSXJetwayBellState:class{},registerInstrument:(name,c)=>Instrument=c,SimVar:{GetSimVarValue:name=>name.includes('B738_door_0')?door:name==='INTERACTIVE POINT OPEN:0'?simulatorDoor:distance,SetSimVarValue:(name,unit,value)=>values[name]=value},console};
vm.runInNewContext(fs.readFileSync(__dirname+'/gsx-jetway-bell/html_ui/Pages/VCockpit/Instruments/GSXJetwayBell/JetwayBell.js','utf8'),context);
context.window=context;const instrument=new Instrument();instrument.lastBellValue=1;
for(const [position,closed,open] of [[0,60,0],[100,30,30],[200,0,60],[-10,60,0],[300,0,60],[NaN,60,0]]) {
 door=position; instrument.publishDoorMix();
 assert.equal(values['L:GSX_BELL_CLOSED_VOLUME'],closed);
 assert.equal(values['L:GSX_BELL_OPEN_VOLUME'],open);
}
door=200;distance=2.5;instrument.publishDoorMix();assert.equal(values['L:GSX_BELL_OPEN_VOLUME'],2.5);
distance=NaN;instrument.publishDoorMix();assert.equal(values['L:GSX_BELL_OPEN_VOLUME'],12.5);
door=0;simulatorDoor=100;distance=60;instrument.publishDoorMix();
assert.equal(values['L:GSX_BELL_OPEN_VOLUME'],60);
assert.equal(values['L:GSX_BELL_CLOSED_VOLUME'],0);
simulatorDoor=50;instrument.publishDoorMix();assert.equal(values['L:GSX_BELL_OPEN_VOLUME'],30);
simulatorDoor=0;instrument.publishDoorMix();assert.equal(values['L:GSX_BELL_CLOSED_VOLUME'],60);
console.log('Door mix: closed, partial, open, invalid input and distance fade passed.');