const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync, spawn} = require('node:child_process');
const {runGate, snapshot} = require('./local_ci_runner');

function fixture(t, body) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'smalltalk-gate-test-'));
  t.after(() => fs.rmSync(root, {recursive: true, force: true}));
  fs.mkdirSync(path.join(root, 'scripts'));
  fs.writeFileSync(path.join(root, 'scripts/local_ci.sh'), body);
  fs.writeFileSync(path.join(root, 'input.txt'), 'original');
  const git = (...args) => execFileSync('git', args, {cwd: root, stdio: 'ignore'});
  git('init');
  git('add', '.');
  git('-c', 'user.name=Gate Test', '-c', 'user.email=gate@example.invalid',
    'commit', '-m', 'fixture');
  return root;
}

function report(root) {
  const base = path.join(root, '.git/local-ci');
  const [run] = fs.readdirSync(base);
  return JSON.parse(fs.readFileSync(path.join(base, run, 'result.json'), 'utf8'));
}

test('records successful checks, dirty inputs and both log streams', async (t) => {
  const root = fixture(t, 'echo standard-output; echo error-output >&2');
  fs.writeFileSync(path.join(root, 'new.txt'), 'untracked input');
  const before = snapshot(root);
  assert.equal(await runGate(root), 0);
  const result = report(root);
  assert.equal(result.status, 'passed');
  assert.equal(result.inputsUnchanged, true);
  assert.equal(result.before.fingerprint, before.fingerprint);
  assert.match(result.before.status, /new.txt/);
  assert.equal(result.before.commit, result.after.commit);
  const log = fs.readFileSync(result.logPath, 'utf8');
  assert.match(log, /standard-output/);
  assert.match(log, /error-output/);
  assert.equal(snapshot(root).fingerprint, before.fingerprint);
});

test('preserves failure exit code and log', async (t) => {
  const root = fixture(t, 'echo failing-check; exit 17');
  assert.equal(await runGate(root), 17);
  const result = report(root);
  assert.equal(result.status, 'failed');
  assert.equal(result.checksExitCode, 17);
  assert.match(fs.readFileSync(result.logPath, 'utf8'), /failing-check/);
});

test('rejects green checks when source content changes mid-run', async (t) => {
  const root = fixture(t, 'echo changed > input.txt');
  assert.equal(await runGate(root), 1);
  const result = report(root);
  assert.equal(result.checksExitCode, 0);
  assert.equal(result.inputsUnchanged, false);
  assert.equal(result.status, 'failed');
});

test('fingerprint detects edits to already dirty untracked files', (t) => {
  const root = fixture(t, 'exit 0');
  fs.writeFileSync(path.join(root, 'new.txt'), 'first');
  const before = snapshot(root);
  fs.writeFileSync(path.join(root, 'new.txt'), 'second');
  const after = snapshot(root);
  assert.equal(before.status, after.status);
  assert.notEqual(before.fingerprint, after.fingerprint);
});

test('interruption is recorded as failure, never a passed gate', async (t) => {
  const root = fixture(t, [
    'node -e \'setInterval(() => {}, 1000)\' &',
    'echo $! > child.pid',
    'echo ready',
    'wait',
  ].join('\n'));
  const runner = path.join(__dirname, 'local_ci_runner.js');
  const child = spawn(process.execPath, ['-e',
    'require(process.argv[1]).runGate(process.argv[2]).then(code => process.exitCode = code)',
    runner, root,
  ], {stdio: ['ignore', 'ignore', 'pipe']});
  const exit = new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('close', (code) => resolve(code));
  });
  let checkPid;
  t.after(() => {
    if (child.exitCode === null) child.kill('SIGTERM');
    if (checkPid == null) return;
    try {
      process.kill(checkPid, 'SIGKILL');
    } catch (error) {
      if (error.code !== 'ESRCH') throw error;
    }
  });
  const deadline = Date.now() + 5000;
  let ready = false;
  while (Date.now() < deadline) {
    try {
      ready = fs.readFileSync(report(root).logPath, 'utf8').includes('ready');
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    if (ready) break;
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  assert.equal(ready, true);
  checkPid = Number(fs.readFileSync(path.join(root, 'child.pid'), 'utf8'));
  assert.equal(Number.isInteger(checkPid) && checkPid > 0, true);
  child.kill('SIGTERM');
  assert.equal(await exit, 143);
  assert.equal(report(root).status, 'failed');
  assert.equal(report(root).signal, 'SIGTERM');
  const childExitDeadline = Date.now() + 2000;
  let checkProcessExited = false;
  while (Date.now() < childExitDeadline) {
    try {
      process.kill(checkPid, 0);
    } catch (error) {
      if (error.code === 'ESRCH') {
        checkProcessExited = true;
        break;
      }
      throw error;
    }
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  assert.equal(checkProcessExited, true);
});

test('workflow tee log does not invalidate a successful source snapshot', (t) => {
  const root = fixture(t, 'echo checked');
  const workflow = fs.readFileSync(
    path.join(__dirname, '../.github/workflows/ci.yml'), 'utf8',
  );
  const target = workflow.match(/\.\/scripts\/local_ci\.sh 2>&1 \| tee (\S+)/)[1];
  assert.equal(target, '.git/local-ci-console.log');
  execFileSync('bash', ['-c',
    'set -o pipefail; node -e \'require(process.argv[1]).runGate(process.argv[2]).then(code => process.exitCode = code)\' "$1" "$2" 2>&1 | tee "$3"',
    'gate-test', path.join(__dirname, 'local_ci_runner.js'), root, target,
  ], {cwd: root, stdio: 'pipe'});
  assert.equal(report(root).status, 'passed');
  assert.equal(report(root).inputsUnchanged, true);
  assert.match(fs.readFileSync(path.join(root, target), 'utf8'), /Local gate passed/);
});
