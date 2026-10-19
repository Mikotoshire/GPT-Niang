import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {EventEmitter} from 'node:events';
import {PassThrough} from 'node:stream';
import {appendDiagnostic,readDiagnostics} from '../runtime/diagnostics.mjs';
import {readUsage} from '../runtime/usage.mjs';

test('diagnostics rotate, tolerate corruption, and discard all private or arbitrary fields',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'quota-diagnostics-test-'));
 try {
  for(let i=0;i<20;i++)assert.equal(appendDiagnostic(dir,{event:'query',ok:false,stage:'account',code:'private-secret',error:'private-secret',accountKey:'private-secret',windows:[99],path:'private-secret'},{maxBytes:400}),true);
  assert.equal(fs.existsSync(path.join(dir,'quota-diagnostics.jsonl.1')),true);
  for(const name of fs.readdirSync(dir))assert.ok(!fs.readFileSync(path.join(dir,name),'utf8').includes('private-secret'));
  fs.appendFileSync(path.join(dir,'quota-diagnostics.jsonl'),'broken\n');
  for(const name of fs.readdirSync(dir))assert.ok(fs.statSync(path.join(dir,name)).size<=400);
  fs.appendFileSync(path.join(dir,'quota-diagnostics.jsonl'),JSON.stringify({at:new Date().toISOString(),event:'query',code:'private-secret',error:'private-secret'})+'\n');
  assert.ok(!JSON.stringify(readDiagnostics(dir)).includes('private-secret'));
  const records=readDiagnostics(dir,2);assert.equal(records.length,2);
  assert.equal(records[0].code,'QUERY_FAILED');assert.equal(records[0].stage,'account');
  assert.deepEqual(readDiagnostics(path.join(dir,'absent')),[]);
  assert.equal(appendDiagnostic(dir,{event:'private-secret'}),false);
  const file=path.join(dir,'file');fs.writeFileSync(file,'');assert.equal(appendDiagnostic(file,{event:'worker_start'}),false);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});

test('a query timeout records its actual RPC stage and contains no response payload',async()=>{
 let record;
 const spawnProcess=()=>{
  const proc=new EventEmitter();proc.stdin=new PassThrough();proc.stdout=new PassThrough();proc.stderr=new PassThrough();proc.kill=()=>{};
  proc.stdin.on('data',chunk=>{const message=JSON.parse(chunk.toString());if(message.id===1)queueMicrotask(()=>proc.stdout.write(JSON.stringify({id:1,result:{}})+'\n'));});
  return proc;
 };
 const result=await readUsage('fictional',{timeoutMs:30,spawnProcess,onDiagnostic:value=>{record=value;}});
 assert.equal(result.errorCode,'TIMEOUT');assert.equal(record.stage,'account');assert.equal(record.code,'TIMEOUT');assert.equal(record.ok,false);assert.ok(record.durationMs>=20);
 const second=await readUsage('fictional',{timeoutMs:10,spawnProcess,onDiagnostic:()=>{throw new Error('diagnostic unavailable');}});
 assert.equal(second.errorCode,'TIMEOUT');
});


test('real worker persists failure then recovery without storing private RPC data',async()=>{
 const {spawn}=await import('node:child_process');
 const {once}=await import('node:events');
 const {fileURLToPath}=await import('node:url');
 const {requestRefresh}=await import('../runtime/refresh-client.mjs');
 const {healthyWorker}=await import('../runtime/worker-state.mjs');
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'quota-worker-diagnostics-'));
 let child;
 try {
  const cli=`const fs=require('node:fs');require('node:readline').createInterface({input:process.stdin}).on('line',line=>{
   const m=JSON.parse(line);if(!m.id)return;
   const result=m.id===1?{}:m.id===2?{account:{type:'chatgpt',email:'private@example.test',planType:'plus'}}:{rateLimits:{primary:{usedPercent:13,windowDurationMins:300,resetsAt:2000000000}}};
   console.log(JSON.stringify(m.id===3&&!fs.existsSync('recover')?{id:m.id,error:{message:'private-rpc-error'}}:{id:m.id,result}));
  });`;
  fs.writeFileSync(path.join(dir,'app-server'),cli);
  const config={dataDir:dir,codexPath:process.execPath};
  const configPath=path.join(dir,'installation.json');fs.writeFileSync(configPath,JSON.stringify(config));
  child=spawn(process.execPath,[fileURLToPath(new URL('../runtime/watch.mjs',import.meta.url)),configPath,String(process.pid)],{cwd:dir,windowsHide:true,stdio:'ignore'});
  const waitUntil=async predicate=>{const until=Date.now()+5000;while(!predicate()&&Date.now()<until)await new Promise(resolve=>setTimeout(resolve,20));assert.ok(predicate());};
  await waitUntil(()=>healthyWorker(dir)&&readDiagnostics(dir).some(row=>row.event==='query'&&!row.ok));
  fs.writeFileSync(path.join(dir,'recover'),'');
  const result=await requestRefresh(config,configPath,{timeoutMs:4000,startWorker:()=>{}});assert.equal(result.queryOk,true);
  const records=readDiagnostics(dir);assert.ok(records.some(row=>row.event==='query_start'));
  assert.ok(records.some(row=>row.event==='query'&&row.code==='RATE_LIMITS_READ_FAILED'&&row.stage==='rate_limits'));
  assert.ok(records.some(row=>row.event==='query'&&row.ok&&row.recovered));
  const text=fs.readFileSync(path.join(dir,'quota-diagnostics.jsonl'),'utf8');
  for(const secret of ['private@example.test','private-rpc-error','accountKey','usedPercent'])assert.ok(!text.includes(secret));
 }finally{
  if(child&&child.exitCode===null&&child.signalCode===null){const ended=once(child,'exit');child.kill();await ended;}
  fs.rmSync(dir,{recursive:true,force:true});
 }
});
