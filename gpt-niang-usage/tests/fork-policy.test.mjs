import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {runUpdate} from '../runtime/update.mjs';

for (const mode of ['manual', 'automatic', 'automatic-enabled', 'cleanup']) {
  test(`personal fork blocks release requests and installation in ${mode} mode without .git`, async t => {
    const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'gpt-niang-fork-')));
    t.after(() => fs.rmSync(root, {recursive: true, force: true}));
    const appDir = path.join(root, 'app');
    const dataDir = path.join(root, 'state');
    fs.mkdirSync(path.join(appDir, 'runtime'), {recursive: true});
    fs.mkdirSync(dataDir);
    fs.writeFileSync(path.join(appDir, 'runtime', 'fork-policy.json'), JSON.stringify({
      repository: 'Mikotoshire/GPT-Niang', releaseUpdates: false,
    }));
    // Even a previously enabled preference must not bypass the fork policy.
    fs.writeFileSync(path.join(dataDir, 'update-preferences.json'), '{"automatic":true}');
    let requests = 0, installs = 0;
    await runUpdate({appDir, dataDir, version: '1.3.4'}, {
      mode, agentDir: path.join(root, 'agent'), cleanup: async () => {},
      fetchBytes: async () => { requests++; return Buffer.from('{"tag_name":"v1.3.4"}'); },
      launch: async () => { installs++; },
    });
    assert.equal(requests, 0, 'must not contact upstream releases');
    assert.equal(installs, 0, 'must not install a release');
    const status = JSON.parse(fs.readFileSync(path.join(dataDir, 'update-status.json'), 'utf8'));
    assert.equal(status.phase, 'source');
    assert.match(status.message, /Mikotoshire\/GPT-Niang/);
  });
}
