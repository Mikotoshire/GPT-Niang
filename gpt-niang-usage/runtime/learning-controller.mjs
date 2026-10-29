import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {atomicJson} from './usage.mjs';
import {readJson} from './worker-state.mjs';

// Consumes the quota worker's cache only. Never queries account or rate limits.
export function learningWindow(snapshot, now=Date.now()) {
  if(!snapshot?.ok || snapshot.queryOk!==true || !snapshot.accountKey || snapshot.error ||
    !Number.isFinite(snapshot.observedAt) || now-snapshot.observedAt<0 || now-snapshot.observedAt>90000)return null;
  const primary=snapshot.windows?.find(w=>w.minutes===300);
  const weekly=snapshot.windows?.find(w=>w.minutes===10080);
  if(!primary || !weekly || ![primary.remaining,weekly.remaining,primary.resetsAt,weekly.resetsAt].every(Number.isFinite) ||
    primary.remaining<0 || primary.remaining>100 || weekly.remaining<0 || weekly.remaining>100 || weekly.resetsAt*1000<=now)return null;
  const key=createHash('sha256').update(snapshot.accountKey+':'+primary.resetsAt).digest('hex');
  return {key,account:snapshot.accountKey,reset:primary.resetsAt*1000,weeklyReset:weekly.resetsAt*1000,primary:primary.remaining,weekly:weekly.remaining};
}
export class LearningController {
  constructor(dataDir,{research,now=Date.now,owner='worker'}={}) {
    this.dir=path.join(dataDir,'learning');fs.mkdirSync(this.dir,{recursive:true});
    this.now=now;this.research=research;this.owner=owner;this.enabled=false;this.running=null;this.window=null;this.closed=false;this.outcomes=new Map();
    // A restart never replays an old ON request, even if its acknowledgement was lost.
    this.requestId=readJson(path.join(this.dir,'request.json'))?.id??null;
    const claimsFile=path.join(this.dir,'claims.json');
    this.claims=readJson(claimsFile);
    if(fs.existsSync(claimsFile) && (!this.claims || typeof this.claims!=='object' || Array.isArray(this.claims)))throw new Error('Invalid learning claims');
    this.claims??={};this.publish('已关闭');
  }
  publish(state){atomicJson(path.join(this.dir,'state.json'),{owner:this.owner,at:this.now(),enabled:this.enabled,state,ack:this.requestId});}
  stop(disable=true) {
    if(disable){this.enabled=false;this.window=null;}
    if(this.running){this.running.abort.abort();this.publish('正在停止');}else this.publish(this.enabled?'等待条件':'已关闭');
  }
  gate(){const current=learningWindow(this.snapshot,this.now());return {on:!this.closed&&this.enabled&&!!current&&current.key===this.window?.key};}
  tick(snapshot) {
    if(this.closed){if(this.running)this.publish('正在停止');return;}
    this.snapshot=snapshot;
    const current=learningWindow(snapshot,this.now());
    const request=readJson(path.join(this.dir,'request.json'));
    if(request?.id && request.id!==this.requestId){
      this.requestId=request.id;
      if(request.enabled===true && current && request.key===current.key){this.enabled=true;this.window=current;}
      else this.stop();
    }
    if(this.enabled && (!current || current.key!==this.window?.key || current.weeklyReset!==this.window?.weeklyReset || this.now()>=current.reset)){this.stop();return;}
    if(this.running){
      if(!this.enabled || this.now()-this.running.started>=15*60000 || this.running.base.primary-current.primary>=10 || this.running.base.weekly-current.weekly>=2)this.stop();
      else this.publish(this.running.abort.signal.aborted?'正在停止':'正在学习');
      return;
    }
    if(!this.enabled){this.publish(this.outcomes.get(current?.key)==='cancelled'?'学习已取消（已关闭）':'已关闭');return;}
    const minutes=(current.reset-this.now())/60000;
    if(minutes<15 || minutes>90 || current.primary<40 || current.weekly<50 || this.claims[current.key]){this.publish(this.claims[current.key]?this.outcomeLabel(current.key):'等待条件');return;}
    // Durable claim precedes deferred model start. Failure is conservative: never retry this window.
    this.claims[current.key]=true;atomicJson(path.join(this.dir,'claims.json'),this.claims);
    const run={abort:new AbortController(),started:this.now(),base:current};this.running=run;this.publish('正在学习');
    run.done=Promise.resolve().then(async()=>{
      if(run.abort.signal.aborted || !this.gate().on)return;
      const history=readJson(path.join(this.dir,'notes.json'))??[];
      const result=await this.research({signal:run.abort.signal,history:JSON.stringify(history).slice(-16000)});
      if(!run.abort.signal.aborted && this.gate().on && result?.novel===true && typeof result.note==='string' && Array.isArray(result.sources) && result.sources.length===1 && typeof result.sources[0]==='string'){
        history.push({at:this.now(),sources:result.sources,note:result.note.slice(0,12000)});
        atomicJson(path.join(this.dir,'notes.json'),history.slice(-100));
        run.outcome='completed';
      } else if(result?.novel===false){run.outcome='no-new-content';}
      else if(!run.abort.signal.aborted && this.gate().on){throw new Error('Invalid research result');}
    }).catch(()=>{run.outcome='failed';}).finally(()=>{
      const outcome=run.abort.signal.aborted?'cancelled':run.outcome??'cancelled';
      this.outcomes.set(run.base.key,outcome);this.running=null;
      try{this.publish(this.enabled?this.outcomeLabel(run.base.key):outcome==='cancelled'?'学习已取消（已关闭）':'已关闭');}catch{}
    });
  }
  outcomeLabel(key){return {completed:'学习完成',failed:'学习失败（本窗口不重试）',cancelled:'学习已取消（本窗口不重试）','no-new-content':'无新增内容（本窗口不重试）'}[this.outcomes.get(key)]??'本窗口已尝试（不重复）';}
  close(){this.closed=true;this.stop();return this.running?.done??Promise.resolve();}
}
