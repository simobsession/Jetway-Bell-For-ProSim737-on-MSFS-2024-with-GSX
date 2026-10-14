const fs=require('node:fs'),assert=require('node:assert/strict');
const path=require('node:path');
const binary=fs.readFileSync(path.join(__dirname,'gsx-jetway-bell/modules/JetwayDistance.wasm'));
const moduleBinary=new WebAssembly.Module(binary);
const runtimeExports=new Set(WebAssembly.Module.exports(moduleBinary).map(e=>e.name));
for(const name of ['malloc','free','mallinfo','mchunkit_begin','mchunkit_next','get_pages_state','mark_decommit_pages','GetSimConnectVersion','GetExtensionVersion','GetExtensionVersionBuffer','module_init','Update_StandAlone','module_deinit']) assert.ok(runtimeExports.has(name),'MSFS runtime export missing: '+name);let instance,dispatchIndex;
const ids=new Map(),values=new Map();let requests=0;
function view(){return new DataView(instance.exports.memory.buffer);}
function string(p){const b=new Uint8Array(instance.exports.memory.buffer);let end=p;while(b[end])end++;return Buffer.from(b.subarray(p,end)).toString();}
const env={
 fsVarsGetUnitId(){return 1;},fsVarsRegisterLVar(p){let name=string(p);if(!ids.has(name))ids.set(name,ids.size+1);return ids.get(name);},
 fsVarsLVarSet(id,unit,value){values.set(id,value);return 0;},fsVarsLVarGet(id,unit,p){view().setFloat64(p,values.get(id)||0,true);return 0;},
 SimConnect_Open(p){view().setBigUint64(p,1n,true);return 0;},SimConnect_AddToDataDefinition(){return 0;},SimConnect_RequestDataOnSimObject(){return 0;},
 SimConnect_CallDispatch(h,index){dispatchIndex=index;return 0;},SimConnect_RequestJetwayData(){requests++;return 0;},SimConnect_Close(){return 0;},__stack_chk_fail(){throw Error('stack corruption');}
};
instance=new WebAssembly.Instance(moduleBinary,{env,wasi_snapshot_preview1:{commit_pages(){return 0;}}});
instance.exports.__wasm_call_ctors();instance.exports.module_init();
const get=name=>values.get(ids.get(name));const set=(name,value)=>values.set(ids.get(name),value);
assert.equal(get('GSX_BELL_DISTANCE_MODULE_LOADED'),1);
set('GSX_BELL_AIRPORT_CODE_1',Buffer.from('KDAL').readUInt32LE());set('GSX_JETWAY_BELL_ACTIVE',1);
function send(buffer){let p=instance.exports.malloc(buffer.length);new Uint8Array(instance.exports.memory.buffer,p,buffer.length).set(buffer);instance.exports.__indirect_function_table.get(dispatchIndex)(p,buffer.length,0);instance.exports.free(p);}
const aircraft=Buffer.alloc(96);aircraft.writeUInt32LE(8,8);aircraft.writeUInt32LE(1,12);aircraft.writeUInt32LE(99,16);[32,-96,150,0,0,0,10].forEach((v,i)=>aircraft.writeDoubleLE(v,40+8*i));send(aircraft);
function geometry(distance,status=1,attached=99){const b=Buffer.alloc(188);b.writeUInt32LE(31,8);b.writeUInt32LE(1,16);b.writeUInt32LE(1,24);b.write('KDAL',28);b.writeInt32LE(50,36);[32,-96,150].forEach((v,i)=>b.writeDoubleLE(v,40+i*8));b.writeInt32LE(status,76);b.writeInt32LE(0,80);b.writeDoubleLE(10+distance,28+80+16);b.writeUInt32LE(123,28+152);b.writeUInt32LE(attached,28+156);send(b);}
instance.exports.Update_StandAlone(.1);
// Check actual targets before smoothing: far-away gain is one quarter of the previous tuning,
// while the close-up gain remains unchanged.
geometry(2);for(let i=0;i<18;i++)instance.exports.Update_StandAlone(.1);
assert.ok(Math.abs(get('GSX_BELL_VOLUME')-100/1.04)<1);
geometry(10);for(let i=0;i<18;i++)instance.exports.Update_StandAlone(.1);
assert.ok(Math.abs(get('GSX_BELL_VOLUME')-6.25)<1);
let previous=Infinity;
for(const d of [2,10,30]){geometry(d);assert.ok(Math.abs(get('GSX_BELL_DISTANCE_METERS')-d)<.001);assert.equal(get('GSX_BELL_DISTANCE_VALID'),1);for(let i=0;i<10;i++)instance.exports.Update_StandAlone(.1);let v=get('GSX_BELL_VOLUME');assert.ok(v<previous,'farther jetway reduces volume');previous=v;}
geometry(2);for(let i=0;i<10;i++)instance.exports.Update_StandAlone(.1);assert.ok(get('GSX_BELL_VOLUME')>previous,'approach raises volume');
for(let i=0;i<40;i++)instance.exports.Update_StandAlone(.1);assert.equal(get('GSX_BELL_DISTANCE_VALID'),0);assert.ok(get('GSX_BELL_VOLUME')>11 && get('GSX_BELL_VOLUME')<14,'missing telemetry preserves the quieter fallback');
set('GSX_JETWAY_BELL_ACTIVE',0);let oldRequests=requests;for(let i=0;i<10;i++)instance.exports.Update_StandAlone(.1);assert.ok(requests>oldRequests,'idle polls for automatic operations');
for(const status of [1,2,3,4,5,6]) {geometry(2,status);assert.equal(get('GSX_BELL_JETWAY_MOVING'),1,'approach, hood and retract phase '+status);}
for(const status of [0,7]) {geometry(2,status);assert.equal(get('GSX_BELL_JETWAY_MOVING'),0,'rest/attached are silent');}
geometry(2,1,101);assert.equal(get('GSX_BELL_JETWAY_MOVING'),0,'another aircraft jetway cannot trigger our bell');
geometry(2,4);for(let i=0;i<25;i++)instance.exports.Update_StandAlone(.1);assert.equal(get('GSX_BELL_JETWAY_MOVING'),0,'stale motion clears');
instance.exports.module_deinit();assert.equal(get('GSX_BELL_DISTANCE_MODULE_LOADED'),0);
console.log('PASS: compiled WASM telemetry replay, approach/retraction volume, stale-data fallback, idle and unload.');
