const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'gsx-jetway-bell/html_ui/Pages/VCockpit/Instruments/GSXJetwayBell');
const sandbox={console,WebSocket,setTimeout,clearTimeout,setInterval,clearInterval,URLSearchParams,
 location:{protocol:'coui:',search:'',host:''},
 SimVar:{GetSimVarValue(){return 8744;}},
 RegisterViewListener(){throw new Error('CommBus must not be selected for desktop Couatl');}
};
sandbox.window=sandbox;sandbox.addEventListener=()=>{};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root,'GSXTransport.js'),'utf8'),sandbox);
vm.runInContext(fs.readFileSync(path.join(root,'BellState.js'),'utf8'),sandbox);
const state=new sandbox.GSXJetwayBellState();
setTimeout(()=>{console.error('FAIL: no live GSX snapshot received');process.exit(1);},8000);
sandbox.createGsxBellConnection({onMessage(m){state.apply(m);if(m.type==='snapshot'){
 const service=m.services.find(s=>s.id==='OperateJetways');
 if(!service){console.error('FAIL: no OperateJetways service');process.exit(1);}
 console.log('PASS: packaged transport from an in-sim coui context receives live GSX hello/snapshot.');
 console.log(JSON.stringify({jetwayState:service.state,raw:service.stateRaw,bellActive:state.active()}));
 process.exit(0);
}}});