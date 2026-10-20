// AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import {fileURLToPath} from 'node:url';
import {requestRefresh} from '../runtime/refresh-client.mjs';
import {readJson} from '../runtime/worker-state.mjs';
import {readDiagnostics} from '../runtime/diagnostics.mjs';
test('real worker retains verified data during fetch and failure, recovers, and clears on account switch',async()=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'quota-cache-worker-'));
  let child;
  try{
    const cli=`const fs=require('node:fs');require('node:readline').createInterface({input:process.stdin}).on('line',line=>{
      const m=JSON.parse(line);if(!m.id)return;const mode=fs.readFileSync('mode','utf8');
      const result=m.id===1?{}:m.id===2?{account:{type:'chatgpt',email:mode==='switch'?'b@example.test':'a@example.test',planType:'plus'}}:{rateLimits:{primary:{usedPercent:mode==='recover'?30:10,windowDurationMins:300,resetsAt:2000000000}}};
      setTimeout(()=>console.log(JSON.stringify(m.id===3&&['fail','switch'].includes(mode)?{id:m.id,error:{message:'fixture'}}:{id:m.id,result})),m.id===3?150:0);
    });`;
    fs.writeFileSync(path.join(dir,'app-server'),cli);fs.writeFileSync(path.join(dir,'mode'),'good');
    const config={dataDir:dir,codexPath:process.execPath};const configPath=path.join(dir,'installation.json');fs.writeFileSync(configPath,JSON.stringify(config));
    child=spawn(process.execPath,[fileURLToPath(new URL('../runtime/watch.mjs',import.meta.url)),configPath,'0'],{cwd:dir,windowsHide:true,stdio:'ignore'});
    const options={timeoutMs:6000,pollMs:10,startWorker:()=>{}};
    const first=await requestRefresh(config,configPath,options);assert.equal(first.windows[0].remaining,90);
    fs.writeFileSync(path.join(dir,'mode'),'fail');
    const failed=requestRefresh(config,configPath,options);
    const deadline=Date.now()+3000;
    while(!readJson(path.join(dir,'status.json'))?.refreshing&&Date.now()<deadline)await new Promise(r=>setTimeout(r,10));
    const fetching=readJson(path.join(dir,'status.json'));assert.equal(fetching.refreshing,true);assert.equal(fetching.windows[0].remaining,90);
    const old=await failed;assert.equal(old.queryOk,false);assert.equal(old.refreshing,false);assert.equal(old.observedAt,first.observedAt);assert.equal(old.windows[0].remaining,90);
    const failures=readDiagnostics(dir).filter(r=>r.event==='query'&&!r.ok);assert.equal(failures.length,2);
    fs.writeFileSync(path.join(dir,'mode'),'recover');
    const next=await requestRefresh(config,configPath,options);assert.equal(next.queryOk,true);assert.equal(next.windows[0].remaining,70);assert.equal(next.error,undefined);
    fs.writeFileSync(path.join(dir,'mode'),'switch');
    const switched=await requestRefresh(config,configPath,options);assert.equal(switched.ok,false);assert.deepEqual(switched.windows,[]);assert.notEqual(switched.accountKey,next.accountKey);
  }finally{
    if(child&&child.exitCode===null&&child.signalCode===null){const ended=once(child,'exit');child.kill();await ended;}
    fs.rmSync(dir,{recursive:true,force:true});
  }
});
