const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
let sockets=[],timers=new Map(),id=0,messages=[],closed=0;
class Socket {constructor(url){this.url=url;this.readyState=0;sockets.push(this);}send(data){this.sent=JSON.parse(data);}close(){this.readyState=3;}}
const scope={WebSocket:Socket,SimVar:{GetSimVarValue:()=>8744},setTimeout:fn=>{timers.set(++id,fn);return id;},clearTimeout:key=>timers.delete(key)};scope.window=scope;
vm.runInNewContext(fs.readFileSync(__dirname+'/gsx-jetway-bell/html_ui/Pages/VCockpit/Instruments/GSXJetwayBell/GSXTransport.js','utf8'),scope);
const client=scope.createGsxBellConnection({onMessage:m=>messages.push(m),onClose:()=>closed++});
let first=sockets[0];assert.equal(first.url,'ws://127.0.0.1:8744/');first.readyState=1;first.onopen();
assert.deepEqual(first.sent,{type:'subscribe',channels:['state']});assert.equal(client.isOpen(),true);
first.onmessage({data:'not json'});assert.equal(messages.length,0);first.onmessage({data:'{"type":"hello"}'});assert.equal(messages.length,1);
first.onclose();assert.equal(client.isOpen(),false);assert.equal(closed,1);assert.equal(timers.size,1);
let retry=[...timers.values()][0];retry();assert.equal(sockets.length,2);assert.equal(first.onmessage,null);
let second=sockets[1];let timeout=[...timers.values()][0];timeout();assert.equal(closed,2);
retry=[...timers.values()][0];retry();assert.equal(sockets.length,3);
client.dispose();assert.equal(timers.size,0);assert.equal(client.isOpen(),false);assert.equal(sockets[2].onmessage,null);
console.log('PASS: read-only subscription, invalid JSON, reconnect, connect timeout and disposal.');