// AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
import test from 'node:test';
import assert from 'node:assert/strict';
import * as usage from '../runtime/usage.mjs';
import {mergeUsageSnapshot} from '../runtime/refresh-queue.mjs';

test('transient query reconnects once and returns the new result',async()=>{
  let calls=0;const delays=[];
  const result=await usage.readUsageWithRetry('fake',{read:async()=>++calls===1?{ok:false,errorCode:'TIMEOUT'}:{ok:true,queryOk:true},sleep:async ms=>delays.push(ms)});
  assert.equal(calls,2);assert.equal(result.queryOk,true);assert.deepEqual(delays,[750]);
});
test('persistent failure stops after two attempts; another click can try again',async()=>{
  let calls=0;const options={read:async()=>{calls++;return {ok:false,errorCode:'RATE_LIMITS_READ_FAILED'};},sleep:async()=>{}};
  for(let i=0;i<2;i++)assert.equal((await usage.readUsageWithRetry('fake',options)).queryOk,false);
  assert.equal(calls,4);
});
test('unsupported login and malformed data do not reconnect',async()=>{
  for(const errorCode of ['AUTH_MODE_UNSUPPORTED','INVALID_WINDOWS','ENOENT']){
    let calls=0;await usage.readUsageWithRetry('fake',{read:async()=>{calls++;return {ok:false,errorCode};}});assert.equal(calls,1);
  }
});
test('retry shares the total deadline and shortens its second attempt',async()=>{
  let clock=0;const budgets=[];
  await usage.readUsageWithRetry('fake',{now:()=>clock,sleep:async ms=>{clock+=ms;},read:async(_,o)=>{budgets.push(o.timeoutMs);clock+=o.timeoutMs;return {ok:false,errorCode:'TIMEOUT'};}});
  assert.deepEqual(budgets,[24000,13250]);assert.equal(clock,38000);
});
test('failure preserves a complete previous snapshot and identifies stale data',()=>{
  const previous={ok:true,queryOk:true,accountKey:'fixture',observedAt:100,windows:[{remaining:42}],refreshing:true};
  const result=mergeUsageSnapshot(previous,{ok:true,queryOk:false,accountKey:'fixture',observedAt:200,windows:[{remaining:7}],errorCode:'INVALID_WINDOWS',error:'fixture failure'},300);
  assert.deepEqual(result.windows,previous.windows);assert.equal(result.observedAt,100);assert.equal(result.queryOk,false);assert.equal(result.refreshing,false);assert.equal(result.errorCode,'INVALID_WINDOWS');
});
test('confirmed account change never retains the previous account',()=>{
  const previous={ok:true,accountKey:'fixture-a',windows:[{remaining:42}]};
  assert.deepEqual(mergeUsageSnapshot(previous,{ok:false,queryOk:false,accountKey:'fixture-b',windows:[],error:'failed'}).windows,[]);
});
