-- Postgres init script run on first cluster startup.
-- POSTGRES_USER / POSTGRES_DB env vars (set on the StatefulSet) create the role
-- and database. The backend manages the schema via EF Core EnsureCreated().
-- This file only seeds a few example rows after the schema exists.
--
-- Runs inside the application database. Idempotent so re-running is safe.

CREATE TABLE IF NOT EXISTS tasks (
  "Id" SERIAL PRIMARY KEY,
  "Title" VARCHAR(500) NOT NULL,
  "Done" BOOLEAN NOT NULL DEFAULT FALSE,
  "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO tasks ("Title", "Done")
SELECT v.title, v.done FROM (VALUES
  ('Bootstrap the cluster', true),
  ('Explain the demo', false),
  ('Look at CVE counts in Grafana', false),
  ('Create a new task through this UI', false),
  ('Restart the frontend/backend', false),
  ('Ensure database state is maintained', false),
  ('Migrate the frontend to Chainguard', false),
  ('Migrate the backend to Chainguard', false),
  ('Migrate the database to Chainguard', false),
  ('Migrate ingress-nginx to Chainguard', false),
  ('Migrate cert-manager to Chainguard', false),
  ('Migrate trivy-operator to Chainguard', false),
  ('Migrate kube-prometheus-stack to Chainguard', false),
  ('Look at CVE counts again', false)
) AS v(title, done)
WHERE NOT EXISTS (SELECT 1 FROM tasks);
