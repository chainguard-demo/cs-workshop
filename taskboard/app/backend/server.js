// Taskboard backend — Express + node-postgres.
// API surface matches the React frontend: GET/POST/PUT/DELETE /api/tasks
// and a /healthz endpoint for the kubelet probe.

import express from 'express';
import pg from 'pg';

const PORT = parseInt(process.env.PORT || '8080', 10);
const CONNECTION_STRING = process.env.CONNECTION_STRING;
if (!CONNECTION_STRING) {
  console.error('CONNECTION_STRING env var not set');
  process.exit(1);
}

const pool = new pg.Pool({ connectionString: CONNECTION_STRING });

// Postgres may take a few seconds to start when the pod first comes up.
// Retry the initial schema-ensure for up to a minute before giving up.
async function ensureSchema() {
  for (let attempt = 1; attempt <= 30; attempt++) {
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS tasks (
          "Id" SERIAL PRIMARY KEY,
          "Title" VARCHAR(500) NOT NULL,
          "Done" BOOLEAN NOT NULL DEFAULT FALSE,
          "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `);
      console.log('database ready');
      return;
    } catch (err) {
      console.warn(`db not ready (attempt ${attempt}): ${err.message}`);
      await new Promise((r) => setTimeout(r, 2000));
    }
  }
  throw new Error('database never came up');
}

const TASK_COLUMNS =
  '"Id" AS id, "Title" AS title, "Done" AS done, "CreatedAt" AS "createdAt"';

const app = express();
app.use(express.json());
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.get('/healthz', (_req, res) => res.json({ status: 'ok' }));

app.get('/api/tasks', async (_req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT ${TASK_COLUMNS} FROM tasks ORDER BY "Id"`,
    );
    res.json(rows);
  } catch (err) { next(err); }
});

app.post('/api/tasks', async (req, res, next) => {
  try {
    const { title, done = false } = req.body ?? {};
    const { rows } = await pool.query(
      `INSERT INTO tasks ("Title", "Done") VALUES ($1, $2) RETURNING ${TASK_COLUMNS}`,
      [title, done],
    );
    res.status(201).json(rows[0]);
  } catch (err) { next(err); }
});

app.put('/api/tasks/:id', async (req, res, next) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { title, done } = req.body ?? {};
    const { rows } = await pool.query(
      `UPDATE tasks SET "Title" = $1, "Done" = $2 WHERE "Id" = $3 RETURNING ${TASK_COLUMNS}`,
      [title, done, id],
    );
    if (rows.length === 0) return res.sendStatus(404);
    res.json(rows[0]);
  } catch (err) { next(err); }
});

app.delete('/api/tasks/:id', async (req, res, next) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { rowCount } = await pool.query(
      `DELETE FROM tasks WHERE "Id" = $1`,
      [id],
    );
    if (rowCount === 0) return res.sendStatus(404);
    res.sendStatus(204);
  } catch (err) { next(err); }
});

await ensureSchema();
app.listen(PORT, () => console.log(`taskboard backend listening on :${PORT}`));
