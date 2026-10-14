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

const vm=require('node:vm'),fs=require('node:fs');let clock=1000,callbacks,Instrument;
const values=new Map(),writes=[];
const sandbox={Date:{now:()=>clock},console:{log(){}},BaseInstrument:class{connectedCallback(){}disconnectedCallback(){}Update(){}},
SimVar:{GetSimVarValue:n=>values.get(n)||0,SetSimVarValue(n,u,v){values.set(n,v);writes.push([n,v,clock]);return Promise.resolve();}},
createGsxBellConnection(cb){callbacks=cb;return{isOpen:()=>true,dispose(){}};},registerInstrument(n,c){Instrument=c;}};
sandbox.window=sandbox;vm.createContext(sandbox);
const root=path.join(__dirname,'gsx-jetway-bell/html_ui/Pages/VCockpit/Instruments/GSXJetwayBell');
for(const name of ['BellState.js','JetwayBell.js'])vm.runInContext(fs.readFileSync(path.join(root,name),'utf8'),sandbox);
const gauge=new Instrument();gauge.connectedCallback();
callbacks.onMessage({type:'hello',gsxRunning:true});callbacks.onMessage({type:'snapshot',airport:{icao:'KDAL'},services:[{id:'OperateJetways',stateRaw:1}]});
assert.equal(values.get('L:GSX_BELL_AIRPORT_CODE_1'),Buffer.from('KDAL').readUInt32LE());
values.set('L:GSX_BELL_VOLUME',2.5);
const active=()=>values.get('L:GSX_JETWAY_BELL_ACTIVE');
for(let cycle=0;cycle<2;cycle++){
 callbacks.onMessage(frame(4));assert.equal(active(),0,'prepare with playback off');
 assert.equal(values.get('L:GSX_BELL_CLOSED_VOLUME'),2.5,'correct quiet level prepared');
 clock+=30;gauge.Update();assert.equal(active(),0,'wait for curve propagation');
 clock+=31;gauge.Update();assert.equal(active(),1);
 assert.equal(values.get('L:GSX_BELL_CLOSED_VOLUME'),2.5,'no zero-volume dip at activation');
 const activation=writes.findLastIndex(x=>x[0]==='L:GSX_JETWAY_BELL_ACTIVE'&&x[1]===1);
 assert.ok(writes.slice(0,activation).some(x=>x[0]==='L:GSX_BELL_CLOSED_VOLUME'&&x[1]===2.5&&x[2]<=clock-60));
 callbacks.onMessage(frame(5));callbacks.onMessage(frame(7));assert.equal(active(),1);
 callbacks.onMessage(frame(6));assert.equal(active(),0);assert.equal(values.get('L:GSX_BELL_PLAYBACK_VOLUME'),0,'idle curves silent');
}
callbacks.onMessage({type:'patch',path:'/services',value:[{id:'Boarding',stateRaw:5},{id:'OperateJetways',stateRaw:1}]});
values.set('L:GSX_BELL_JETWAY_MOVING',1);gauge.Update();assert.equal(active(),0);clock+=70;gauge.Update();assert.equal(active(),1,'automatic motion activates');
values.set('L:GSX_BELL_JETWAY_MOVING',0);gauge.Update();assert.equal(active(),0,'stationary boarding silent');
values.set('L:GSX_BELL_JETWAY_MOVING',1);gauge.Update();callbacks.onClose();clock+=70;gauge.Update();assert.equal(active(),0,'disconnect cancels pending start');
callbacks.onMessage({type:'hello',gsxRunning:true});callbacks.onMessage({type:'snapshot',services:[{id:'OperateJetways',stateRaw:5}]});gauge.disconnectedCallback();clock+=70;gauge.Update();assert.equal(active(),0,'unload cancels pending start');
console.log('PASS: pre-start curve preparation, no startup zero dip, manual/automatic timing, idle silence and cancellation.');
values.set('L:GSX_JETWAY_BELL_ACTIVE',0);
sandbox.GSXBellAirports=['KDAL','EGLL'];const selectedGauge=new Instrument();selectedGauge.connectedCallback();
selectedGauge.lastBellValue=1;selectedGauge.publishAirport('KDAL');
assert.equal(values.get('L:GSX_JETWAY_BELL_AIRPORT_KDAL_ACTIVE'),1);
assert.equal(values.get('L:GSX_JETWAY_BELL_DEFAULT_ACTIVE'),0);
selectedGauge.publishAirport('KJFK');assert.equal(values.get('L:GSX_JETWAY_BELL_DEFAULT_ACTIVE'),1);assert.equal(values.get('L:GSX_JETWAY_BELL_AIRPORT_KDAL_ACTIVE'),0);
selectedGauge.publishAirport('EGLL');assert.equal(values.get('L:GSX_JETWAY_BELL_AIRPORT_EGLL_ACTIVE'),1);
selectedGauge.publishBell(false);assert.equal(values.get('L:GSX_JETWAY_BELL_AIRPORT_EGLL_ACTIVE'),0);
console.log('PASS: KDAL/EGLL overrides, generic fallback and exclusive sound selection.');
