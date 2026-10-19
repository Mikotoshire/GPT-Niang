import fs from 'node:fs';
import path from 'node:path';

export const MAX_LOG_BYTES=256*1024;
const events=new Set(['worker_start','query_start','query','snapshot_write_failed']);
const stages=new Set(['initialize','account','rate_limits']);
const codes=new Set(['SPAWN_FAILED','SERVICE_EXIT','CONNECTION_CLOSED','CONNECTION_WRITE_FAILED','INITIALIZE_FAILED','ACCOUNT_READ_FAILED','ACCOUNT_STATE_WRITE_FAILED','OK','TIMEOUT','QUERY_FAILED','INVALID_LIMITS','INVALID_WINDOWS','NO_WINDOWS','RATE_LIMITS_READ_FAILED','AUTH_MODE_UNSUPPORTED','ENOENT','EACCES','EPERM','IO']);
// Strict allowlist: never serialize account objects, RPC messages, paths or errors.
export function sanitizeDiagnostic(input={}) {
  if(!events.has(input.event))return null;
  const result={at:new Date().toISOString(),event:input.event};
  if(stages.has(input.stage))result.stage=input.stage;
  if(typeof input.ok==='boolean')result.ok=input.ok;
  if(typeof input.recovered==='boolean')result.recovered=input.recovered;
  for(const key of ['durationMs','stageMs','timeoutMs'])if(Number.isFinite(input[key])&&input[key]>=0)result[key]=Math.min(Math.round(input[key]),86400000);
  if(input.code!==undefined)result.code=codes.has(input.code)?input.code:'QUERY_FAILED';
  return result;
}
export function appendDiagnostic(dataDir,input,{maxBytes=MAX_LOG_BYTES}={}) {
  try {
    const record=sanitizeDiagnostic(input);if(!record)return false;
    const file=path.join(dataDir,'quota-diagnostics.jsonl'),backup=file+'.1';
    fs.mkdirSync(dataDir,{recursive:true});
    const line=JSON.stringify(record)+'\n';
    if(fs.existsSync(file)&&fs.statSync(file).size+Buffer.byteLength(line)>maxBytes){
      fs.rmSync(backup,{force:true});fs.renameSync(file,backup);
    }
    fs.appendFileSync(file,line,{encoding:'utf8',mode:0o600});return true;
  }catch{return false;} // Diagnostics cannot break a quota query.
}
export function readDiagnostics(dataDir,limit=100) {
  const count=Number.isInteger(limit)?Math.max(1,Math.min(limit,1000)):100;
  const records=[];
  for(const suffix of ['.1','']) {
    try {
      const file=path.join(dataDir,'quota-diagnostics.jsonl'+suffix);
      const fd=fs.openSync(file,'r');
      try {
        const size=fs.fstatSync(fd).size,start=Math.max(0,size-MAX_LOG_BYTES);
        const buffer=Buffer.alloc(Math.min(size,MAX_LOG_BYTES));fs.readSync(fd,buffer,0,buffer.length,start);
        const lines=buffer.toString('utf8').split('\n');if(start)lines.shift();
        for(const line of lines)try {
          const raw=JSON.parse(line),safe=sanitizeDiagnostic(raw);
          if(safe&&typeof raw.at==='string'&&/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(raw.at)){safe.at=raw.at;records.push(safe);}
        }catch{}
      }finally{fs.closeSync(fd);}
    }catch{}
  }
  return records.slice(-count);
}
