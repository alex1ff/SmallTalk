const fs = require('node:fs');
const path = require('node:path');
const {createHash, randomUUID} = require('node:crypto');
const {execFileSync, spawn} = require('node:child_process');

function git(root, ...args) {
  return execFileSync('git', args, {cwd: root, encoding: 'utf8'}).trimEnd();
}

function snapshot(root) {
  const names = execFileSync('git', [
    'ls-files', '-z', '--cached', '--others', '--exclude-standard',
  ], {cwd: root, encoding: 'utf8'}).split('\0').filter(Boolean);
  const digest = createHash('sha256');
  for (const name of [...new Set(names)].sort()) {
    const file = path.join(root, name);
    digest.update(JSON.stringify(name));
    try {
      const stat = fs.lstatSync(file);
      digest.update(String(stat.mode));
      if (stat.isSymbolicLink()) {
        digest.update(fs.readlinkSync(file));
      } else if (stat.isFile()) {
        digest.update(fs.readFileSync(file));
      } else {
        throw new Error(`Unsupported gate input: ${name}`);
      }
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      digest.update('missing');
    }
    digest.update('\0');
  }
  return {
    commit: git(root, 'rev-parse', 'HEAD'),
    branch: git(root, 'branch', '--show-current'),
    status: git(root, 'status', '--porcelain=v1', '--untracked-files=all'),
    fingerprint: digest.digest('hex'),
  };
}

async function runGate(root) {
  const before = snapshot(root);
  const base = path.resolve(root, git(root, 'rev-parse', '--git-path', 'local-ci'));
  const directory = path.join(base, `${Date.now()}-${randomUUID()}`);
  fs.mkdirSync(directory, {recursive: true, mode: 0o700});
  const reportPath = path.join(directory, 'result.json');
  const logPath = path.join(directory, 'checks.log');
  const report = {
    schemaVersion: 1,
    startedAt: new Date().toISOString(),
    status: 'running',
    command: 'bash scripts/local_ci.sh --checks',
    before,
    logPath,
  };
  const saveReport = () => fs.writeFileSync(
    reportPath, JSON.stringify(report, null, 2) + '\n', {mode: 0o600},
  );
  saveReport();
  console.log(`Local gate report: ${reportPath}`);
  // Use one file descriptor for both streams: child failures cannot be hidden
  // by tee/pipeline exit codes, and the log is available even after interruption.
  const log = fs.openSync(logPath, 'wx', 0o600);
  let child;
  let interrupted = null;
  const forwardSignal = (signal) => {
    interrupted = signal;
    if (!child?.pid) return;
    try {
      process.kill(-child.pid, signal);
    } catch (error) {
      if (error.code !== 'ESRCH') throw error;
    }
  };
  const onInterrupt = () => forwardSignal('SIGINT');
  const onTerminate = () => forwardSignal('SIGTERM');
  process.on('SIGINT', onInterrupt);
  process.on('SIGTERM', onTerminate);
  try {
    const outcome = await new Promise((resolve, reject) => {
      child = spawn('bash', ['scripts/local_ci.sh', '--checks'], {
        cwd: root,
        detached: true,
        stdio: ['ignore', log, log],
      });
      child.once('error', reject);
      child.once('close', (code, signal) => resolve({code, signal}));
    });
    report.checksExitCode = outcome.code;
    report.signal = interrupted || outcome.signal;
    report.after = snapshot(root);
    report.inputsUnchanged = before.commit === report.after.commit &&
      before.fingerprint === report.after.fingerprint;
    report.exitCode = report.signal ? (report.signal === 'SIGINT' ? 130 : 143) :
      outcome.code !== 0 ? (outcome.code ?? 1) : report.inputsUnchanged ? 0 : 1;
    report.status = report.exitCode === 0 ? 'passed' : 'failed';
    if (!report.inputsUnchanged) report.reason = 'Inputs changed; rerun the gate.';
  } catch (error) {
    report.exitCode = 1;
    report.status = 'failed';
    report.reason = error.message;
  } finally {
    fs.closeSync(log);
    process.removeListener('SIGINT', onInterrupt);
    process.removeListener('SIGTERM', onTerminate);
    report.finishedAt = new Date().toISOString();
    saveReport();
  }
  console.log(`Local gate ${report.status}; exit=${report.exitCode}`);
  if (report.reason) console.error(report.reason);
  console.log(`Checks log: ${logPath}`);
  return report.exitCode;
}

if (require.main === module) {
  const root = path.resolve(__dirname, '..');
  runGate(root).then((code) => { process.exitCode = code; }).catch((error) => {
    console.error(`Local gate failed: ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = {runGate, snapshot};
