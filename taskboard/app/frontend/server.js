import { appendFileSync, createWriteStream, mkdirSync } from 'node:fs';
import { spawn } from 'node:child_process';

const podName = process.env.POD_NAME || 'unknown pod';
const LOG_DIR = process.env.LOG_DIR || '/var/log/taskboard';
const LOG_FILE = `${LOG_DIR}/access.log`;

mkdirSync(LOG_DIR, { recursive: true });
appendFileSync(LOG_FILE, `[${new Date().toISOString()}] startup as ${podName}\n`);
const accessLog = createWriteStream(LOG_FILE, { flags: 'a' });

const child = spawn(
  'node',
  ['node_modules/.bin/serve', '-s', 'dist', '-l', '80'],
  { stdio: ['inherit', 'pipe', 'pipe'] },
);
const tee = (chunk) => {
  process.stdout.write(chunk);
  accessLog.write(chunk);
};
child.stdout.on('data', tee);
child.stderr.on('data', tee);
child.on('exit', (code) => process.exit(code ?? 0));
