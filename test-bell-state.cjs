const assert = require('node:assert/strict');
const path = require('node:path');
const { State } = require(path.join(__dirname, 'gsx-jetway-bell/html_ui/Pages/VCockpit/Instruments/GSXJetwayBell/BellState.js'));
const s = new State();
const frame = raw => ({type:'patch',path:'/services',value:[{id:'OperateJetways',stateRaw:raw}]});
assert.equal(s.active(),false);
s.apply({type:'hello',gsxRunning:true});
s.apply({type:'snapshot',services:[{id:'OperateJetways',stateRaw:1}]});
for (let cycle=0;cycle<2;cycle++) {
 for(const raw of [4,5,7]) { s.apply(frame(raw)); assert.equal(s.active(),true,`cycle ${cycle}, state ${raw}`); }
 for(const raw of [6,1]) { s.apply(frame(raw)); assert.equal(s.active(),false); }
}
s.apply({type:'patch',path:'/services',value:[{id:'Boarding',stateRaw:5}]});
assert.equal(s.active(),false);
s.apply(frame(5)); s.disconnect(); assert.equal(s.active(),false);
s.apply({type:'hello',gsxRunning:true}); s.apply({type:'snapshot',services:[{id:'OperateJetways',stateRaw:5}]});
assert.equal(s.active(),true);
s.apply({type:'event',topic:'engine',gsxRunning:false,restarting:true}); assert.equal(s.active(),false);
s.apply({type:'hello',gsxRunning:true}); s.apply({type:'snapshot',services:[{id:'OperateJetways',stateRaw:5}]});
s.apply({type:'patch',path:'/services',value:null}); assert.equal(s.active(),false);
console.log('PASS: connection/retraction cycles, unrelated services, disconnect, restart, cleared state.');
const vm = require('node:vm');
const fs = require('node:fs');
const writes = [];
const variableValues = new Map();
let callbacks, registered;
const sandbox = {
 console: {log(){}},
 BaseInstrument: class { connectedCallback(){} disconnectedCallback(){} Update(){} },
 SimVar: {GetSimVarValue(name){return variableValues.get(name) || 0;},SetSimVarValue(name,unit,value){variableValues.set(name,value);if(name === "L:GSX_JETWAY_BELL_ACTIVE") writes.push(value);return Promise.resolve();}},
 createGsxBellConnection(cb){callbacks=cb;return {isOpen(){return true;}};},
 registerInstrument(name,klass){registered=klass;}
};
sandbox.window=sandbox;
vm.createContext(sandbox);
const gaugeRoot=path.join(__dirname,'gsx-jetway-bell/html_ui/Pages/VCockpit/Instruments/GSXJetwayBell');
vm.runInContext(fs.readFileSync(path.join(gaugeRoot,'BellState.js'),'utf8'),sandbox);
vm.runInContext(fs.readFileSync(path.join(gaugeRoot,'JetwayBell.js'),'utf8'),sandbox);
const gauge=new registered();
gauge.connectedCallback();
callbacks.onMessage({type:'hello',gsxRunning:true});
callbacks.onMessage({type:'snapshot',services:[{id:'OperateJetways',stateRaw:1}]});
for(let cycle=0;cycle<2;cycle++) {
 callbacks.onMessage(frame(4)); callbacks.onMessage(frame(5)); callbacks.onMessage(frame(7)); callbacks.onMessage(frame(6));
}
assert.deepEqual(writes,[0,1,0,1,0]);
callbacks.onMessage(frame(5)); callbacks.onClose(); assert.equal(writes.at(-1),0);
callbacks.onMessage({type:'hello',gsxRunning:true}); callbacks.onMessage({type:'snapshot',services:[{id:'OperateJetways',stateRaw:5}]});
gauge.disconnectedCallback(); callbacks.onMessage(frame(5)); assert.equal(writes.at(-1),0);
console.log('PASS: hidden instrument writes sound variable for both cycles and silences on GSX/aircraft unload.');
gauge.bellDisposed=false;
callbacks.onMessage({type:'snapshot',airport:{icao:'KDAL'},services:[]});
assert.equal(variableValues.get('L:GSX_BELL_AIRPORT_CODE_1'),Buffer.from('KDAL').readUInt32LE());
assert.equal(variableValues.get('L:GSX_BELL_AIRPORT_CODE_2'),0);
callbacks.onMessage({type:'patch',path:'/airport/icao',value:'EGLL'});
assert.equal(variableValues.get('L:GSX_BELL_AIRPORT_CODE_1'),Buffer.from('EGLL').readUInt32LE());
console.log('PASS: airport context follows GSX snapshot and airport patches.');
