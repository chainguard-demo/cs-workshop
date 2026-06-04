import { useEffect, useState } from 'react';

const API = '/api/tasks';

export default function App() {
  const [tasks, setTasks] = useState([]);
  const [title, setTitle] = useState('');
  const [error, setError] = useState(null);

  async function load() {
    try {
      const res = await fetch(API);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setTasks(await res.json());
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }

  useEffect(() => { load(); }, []);

  async function add(e) {
    e.preventDefault();
    if (!title.trim()) return;
    await fetch(API, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ title, done: false }),
    });
    setTitle('');
    load();
  }

  async function toggle(t) {
    await fetch(`${API}/${t.id}`, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ ...t, done: !t.done }),
    });
    load();
  }

  async function remove(id) {
    await fetch(`${API}/${id}`, { method: 'DELETE' });
    load();
  }

  return (
    <main>
      <h1>Taskboard</h1>
      {error && <div className="error">Failed to load: {error}</div>}
      <form onSubmit={add}>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="What needs doing?"
        />
        <button type="submit">Add</button>
      </form>
      <ul>
        {tasks.map((t) => (
          <li key={t.id} className={t.done ? 'done' : ''}>
            <label>
              <input type="checkbox" checked={t.done} onChange={() => toggle(t)} />
              <span>{t.title}</span>
            </label>
            <button onClick={() => remove(t.id)} aria-label="delete">✕</button>
          </li>
        ))}
      </ul>
      {!tasks.length && !error && <p className="empty">No tasks yet.</p>}
    </main>
  );
}
