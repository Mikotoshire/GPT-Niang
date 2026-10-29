import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {LearningController,learningWindow} from '../runtime/learning-controller.mjs';
const now=1800000000000;
const snapshot=(extra={})=>({ok:true,queryOk:true,accountKey:'fictional',observedAt:now,windows:[{minutes:300,remaining:80,resetsAt:(now+3600000)/1000},{minutes:10080,remaining:90,resetsAt:(now+86400000)/1000}],...extra});
function fixture(t,research=async()=>({novel:false})){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'learning-test-'));let clock=now;
 const c=new LearningController(dir,{now:()=>clock,research});
 t.after(async()=>{await c.close();fs.rmSync(dir,{recursive:true,force:true});});
 let id=0;
 return {c,dir,setTime:v=>clock=v,on:(enabled=true,s=snapshot())=>fs.writeFileSync(path.join(dir,'learning/request.json'),JSON.stringify({id:String(++id),enabled,key:learningWindow(s,clock)?.key}))};
}
test('default OFF never invokes research; thresholds and invalid data fail closed',async t=>{
 let calls=0;const f=fixture(t,async()=>{calls++;return {novel:false};});
 f.c.tick(snapshot());await Promise.resolve();assert.equal(calls,0);
 for(const bad of [null,snapshot({queryOk:false}),snapshot({error:'failure'}),snapshot({observedAt:now-90001}),snapshot({accountKey:null})])assert.equal(learningWindow(bad,now),null);
 for(const [minutes,primary,weekly] of [[91,80,90],[14,80,90],[60,39,90],[60,80,49]]){
  const s=snapshot();s.windows[0].resetsAt=(now+minutes*60000)/1000;s.windows[0].remaining=primary;s.windows[1].remaining=weekly;
  f.on(true,s);f.c.tick(s);await Promise.resolve();assert.equal(calls,0);
 }
});
test('OFF revokes deferred start; claims survive restart and ON requests do not replay',async t=>{
 let calls=0;const f=fixture(t,async()=>{calls++;return {novel:false};});
 f.on();f.c.tick(snapshot());f.on(false);f.c.tick(snapshot());await f.c.running.done;assert.equal(calls,0);
 const restarted=new LearningController(f.dir,{now:()=>now,research:async()=>{calls++;}});
 assert.equal(restarted.enabled,false);f.on();restarted.tick(snapshot());await Promise.resolve();assert.equal(calls,0);await restarted.close();
});
test('repeated ON has one run; OFF waits for cancellation cleanup',async t=>{
 let calls=0,finish;const f=fixture(t,({signal})=>new Promise(resolve=>{calls++;signal.addEventListener('abort',()=>{finish=resolve;});}));
 f.on();f.c.tick(snapshot());await Promise.resolve();f.on();f.c.tick(snapshot());assert.equal(calls,1);
 f.on(false);f.c.tick(snapshot());assert.equal(JSON.parse(fs.readFileSync(path.join(f.dir,'learning/state.json'))).state,'正在停止');assert.ok(f.c.running);
 finish({novel:false});await f.c.running.done;assert.equal(f.c.running,null);
});
test('failed/stale/account/reset and soft budgets cancel; private notes saved only on success',async t=>{
 for(const change of ['failed','stale','account','reset','weeklyReset','primary','weekly','duration']){
  let aborted=false;const f=fixture(t,({signal})=>new Promise(resolve=>signal.addEventListener('abort',()=>{aborted=true;resolve({novel:true,sources:['https://example.org'],note:'discard'});})));f.on();f.c.tick(snapshot());await Promise.resolve();
  const s=snapshot();if(change==='failed')s.queryOk=false;if(change==='stale')s.observedAt=now-90001;if(change==='account')s.accountKey='other';if(change==='reset')s.windows[0].resetsAt+=300;
  if(change==='weeklyReset')s.windows[1].resetsAt+=300;
  if(change==='primary')s.windows[0].remaining-=10;if(change==='weekly')s.windows[1].remaining-=2;if(change==='duration'){f.setTime(now+900000);s.observedAt=now+900000;}
  f.c.tick(s);assert.ok(aborted,change);await f.c.running.done;assert.equal(fs.existsSync(path.join(f.dir,'learning/notes.json')),false);
 }
 const f=fixture(t,async()=>({novel:true,sources:['https://example.org'],note:'fictional fact'}));f.on();f.c.tick(snapshot());await f.c.running.done;assert.equal(JSON.parse(fs.readFileSync(path.join(f.dir,'learning/notes.json'))).length,1);
});
test('research does not block refresh queue and shutdown cancels its own run',async t=>{
 const {createRefreshQueue}=await import('../runtime/refresh-queue.mjs');let cancelled=false;
 const f=fixture(t,({signal})=>new Promise(resolve=>signal.addEventListener('abort',()=>{cancelled=true;resolve({novel:false});})));
 f.on();let queries=0;const queue=createRefreshQueue(async()=>{queries++;f.c.tick(snapshot());});await queue.request();await queue.request();assert.equal(queries,2);assert.equal(queue.busy,false);assert.ok(f.c.running);await f.c.close();assert.ok(cancelled);
});

test('running and stopping heartbeats remain fresh beyond the menu five-second age limit',async t=>{
 let finish,aborted=false;
 const f=fixture(t,({signal})=>new Promise(resolve=>{finish=resolve;signal.addEventListener('abort',()=>{aborted=true;});}));
 const state=()=>JSON.parse(fs.readFileSync(path.join(f.dir,'learning/state.json')));
 f.on();f.c.tick(snapshot());await Promise.resolve();
 for(const elapsed of [6000,7000,12000]){
  f.setTime(now+elapsed);f.c.tick(snapshot());const ui=state();
  assert.ok(now+elapsed-ui.at<5000);assert.equal(ui.enabled,true);assert.equal(ui.state,'正在学习');
 }
 // The fresh enabled state keeps the real checkbox actionable as an OFF request.
 f.on(false);f.c.tick(snapshot());assert.ok(aborted);
 for(const elapsed of [18000,19000]){
  f.setTime(now+elapsed);f.c.tick(snapshot());const ui=state();assert.ok(now+elapsed-ui.at<5000);assert.equal(ui.enabled,false);assert.equal(ui.state,'正在停止');
 }
 finish({novel:false});await f.c.running.done;f.c.tick(snapshot());assert.equal(state().state,'学习已取消（已关闭）');
});
test('terminal failure, no-new-content and completion survive later heartbeats without another attempt',async t=>{
 for(const [result,label] of [
  [new Error('fictional failure'),'学习失败（本窗口不重试）'],
  [{novel:false},'无新增内容（本窗口不重试）'],
  [{novel:true,sources:['https://example.org'],note:'fictional fact'},'学习完成']
 ]){
  let calls=0;const f=fixture(t,async()=>{calls++;if(result instanceof Error)throw result;return result;});
  f.on();f.c.tick(snapshot());await f.c.running.done;
  for(const elapsed of [0,6000,12000]){f.setTime(now+elapsed);f.c.tick(snapshot());assert.equal(JSON.parse(fs.readFileSync(path.join(f.dir,'learning/state.json'))).state,label);}
  f.on();f.c.tick(snapshot());assert.equal(calls,1);
  const restarted=new LearningController(f.dir,{now:()=>now+12000,research:async()=>{calls++;}});assert.equal(restarted.enabled,false);f.on();restarted.tick(snapshot());assert.equal(calls,1);assert.equal(JSON.parse(fs.readFileSync(path.join(f.dir,'learning/state.json'))).state,'本窗口已尝试（不重复）');await restarted.close();
 }
});
