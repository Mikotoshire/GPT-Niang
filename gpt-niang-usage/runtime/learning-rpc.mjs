import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { EventEmitter } from 'node:events';

// Local stdio only. No auth files, tokens, shell or remote transport.
export class Rpc extends EventEmitter {
  constructor(command = 'codex', args = ['app-server', '--stdio']) {
    super();
    this.pending = new Map(); this.seq = 0; this.closed = false;
    this.child = spawn(command, args, { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
    this.child.stderr.resume();
    this.lines = createInterface({ input: this.child.stdout });
    this.lines.on('line', line => {
      let msg; try { msg = JSON.parse(line); } catch { return this.close(); }
      if (msg.id !== undefined && !msg.method) {
        const p = this.pending.get(msg.id); if (!p) return;
        this.pending.delete(msg.id); clearTimeout(p.timer);
        if (msg.error) p.reject(new Error(msg.error.message)); else p.resolve(msg.result);
      } else if (msg.method && msg.id !== undefined) {
        // No approvals, elicitation, dynamic tools, token refresh or delegated actions.
        this.child.stdin.write(JSON.stringify({ id: msg.id, error: { code: -32601, message: 'Not supported' } }) + '\n');
      } else this.emit('notification', msg);
    });
    this.child.on('error', () => this.close());
    this.exited = new Promise(resolve => this.child.once('close', resolve));
    this.child.on('exit', () => this.close());
    this.child.stdout.on('close', () => this.close());
    this.child.stdin.on('error', () => this.close());
  }
  async init() {
    await this.call('initialize', { clientInfo: { name: 'quota_learning_local', version: '0.1.0' }, capabilities: { experimentalApi: true } });
    this.child.stdin.write(JSON.stringify({ method: 'initialized' }) + '\n');
    return this;
  }
  call(method, params = {}, timeout = 15000) {
    if (this.closed) return Promise.reject(new Error('Disconnected'));
    const id = ++this.seq;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error('RPC timeout')); this.close(); }, timeout);
      this.pending.set(id, { resolve, reject, timer });
      this.child.stdin.write(JSON.stringify({ id, method, params }) + '\n');
    });
  }
  close() {
    if (this.closed) return;
    this.closed = true;
    for (const p of this.pending.values()) { clearTimeout(p.timer); p.reject(new Error('Disconnected')); }
    this.pending.clear(); this.lines.close(); this.child.stdin.destroy(); this.child.kill(); this.emit('closed');
  }
}
