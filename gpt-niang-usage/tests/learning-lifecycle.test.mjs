import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {Researcher} from '../runtime/learning-research.mjs';
function stub(unsafe=false){
 const calls=[];const args=[];
 class Client extends EventEmitter{
  constructor(){super();this.exited=Promise.resolve();}
  async init(){}
  close(){this.closed=true;this.emit('closed');}
  async call(method,params){calls.push({method,params});
   if(method==='config/read')return {config:{plugins:{sample:{}},mcp_servers:{sample:{}},apps:{sample:{}}}};
   if(method==='thread/start')return {thread:{id:'fictional'},sandbox:{type:unsafe?'dangerFullAccess':'readOnly',networkAccess:false},approvalPolicy:'never'};
   if(method==='turn/start'){
    queueMicrotask(()=>{this.emit('notification',{method:'item/completed',params:{threadId:'fictional',item:{type:'agentMessage',text:JSON.stringify({novel:true,sources:['https://example.org'],note:'actual fictional body'})}}});this.emit('notification',{method:'turn/completed',params:{threadId:'fictional',turn:{status:'completed'}}});});return {turn:{id:'turn'}};
   }
  }
 }
 return {calls,args,make:a=>{args.push(a);return new Client();}};
}
test('successful read-only protocol uses cached gate and disables external integrations',async()=>{
 const s=stub();const r=new Researcher('.',async()=>({on:true}),s.make);
 const result=await r.research({signal:new AbortController().signal,history:''});assert.equal(result.novel,true);
 assert.deepEqual(s.calls.map(c=>c.method),['config/read','thread/start','turn/start']);
 assert.ok(s.args[1].includes('plugins."sample".enabled=false'));assert.ok(s.args[1].includes('mcp_servers."sample".enabled=false'));assert.ok(s.args[1].includes('apps._default.enabled=false'));
 assert.equal(s.calls[1].params.sandbox,'read-only');assert.equal(s.calls[2].params.sandboxPolicy.networkAccess,false);
});
test('unsafe sandbox and disabled gate never start a model turn',async()=>{
 const s=stub(true);const r=new Researcher('.',async()=>({on:true}),s.make);await assert.rejects(r.research({signal:new AbortController().signal,history:''}),/sandbox/);assert.ok(!s.calls.some(c=>c.method==='turn/start'));
 const disabled=stub();await assert.rejects(new Researcher('.',async()=>({on:false}),disabled.make).research({signal:new AbortController().signal,history:''}));assert.equal(disabled.calls.length,0);
});

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {Rpc} from '../runtime/learning-rpc.mjs';
test('owned invisible stdio child actually exits on close',async()=>{
 const rpc=new Rpc(process.execPath,['-e',`process.stdin.resume();setInterval(()=>{},1000);`]);
 const exit=rpc.exited;rpc.close();await exit;assert.ok(rpc.child.exitCode!==null || rpc.child.signalCode!==null);
});
test('worker preserves the single quota reader and research has no account polling methods',()=>{
 const watch=fs.readFileSync(new URL('../runtime/watch.mjs',import.meta.url),'utf8');
 assert.equal((watch.match(/await readUsageWithRetry\(/g)??[]).length,1);
 const research=fs.readFileSync(new URL('../runtime/learning-research.mjs',import.meta.url),'utf8');
 assert.ok(!research.includes("'account/read'"));assert.ok(!research.includes('account/rateLimits/read'));
 const manifest=JSON.parse(fs.readFileSync(new URL('../runtime/install-files.json',import.meta.url),'utf8'));
 for(const file of ['learning.ps1','learning-controller.mjs','learning-research.mjs','learning-rpc.mjs'])assert.ok(manifest.includes('runtime/'+file));
});
