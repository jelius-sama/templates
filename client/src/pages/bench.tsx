import { useState, useMemo } from "react";

type Todo = { id: number; text: string; done: boolean };
type BenchStat = { name: string; avg: number; min: number; max: number; stddev: number; runs: number[] };

export default function ReactBenchmarks() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [filter, setFilter] = useState<"all" | "active" | "completed">("all");
  const [results, setResults] = useState<BenchStat[]>([]);
  const [running, setRunning] = useState(false);

  const filtered = useMemo(() => {
    if (filter === "active") return todos.filter(t => !t.done);
    if (filter === "completed") return todos.filter(t => t.done);
    return todos;
  }, [todos, filter]);

  const completedCount = useMemo(
    () => todos.filter(t => t.done).length,
    [todos]
  );

  const wait = () => new Promise(r => setTimeout(r, 0));

  async function measure(name: string, fn: () => void | Promise<void>, repeat = 5) {
    const runs: number[] = [];
    for (let i = 0; i < repeat; i++) {
      const start = performance.now();
      await fn();
      await wait(); // let UI update
      const t = performance.now() - start;
      runs.push(t);
    }
    const avg = runs.reduce((a, b) => a + b, 0) / runs.length;
    const min = Math.min(...runs);
    const max = Math.max(...runs);
    const stddev = Math.sqrt(
      runs.map(x => (x - avg) ** 2).reduce((a, b) => a + b, 0) / runs.length
    );
    setResults(prev => [...prev, { name, avg, min, max, stddev, runs }]);
  }

  async function runAll() {
    setResults([]);
    setRunning(true);
    const N = 5000;

    await measure("1️⃣ Create 5K Todos", () => {
      const items = Array.from({ length: N }, (_, i) => ({
        id: i,
        text: "Todo " + i,
        done: false,
      }));
      setTodos(items);
    });

    await measure("2️⃣ Toggle 50%", () => {
      setTodos(prev => prev.map((t, i) => (i % 2 ? { ...t, done: !t.done } : t)));
    });

    await measure("3️⃣ Filter Switch", async () => {
      setFilter("active"); await wait();
      setFilter("completed"); await wait();
      setFilter("all");
    });

    await measure("4️⃣ Bulk Update Text", () => {
      setTodos(prev => prev.map(t => ({ ...t, text: t.text + " updated" })));
    });

    await measure("5️⃣ Delete 50%", () => {
      setTodos(prev => prev.filter((_, i) => i % 2 === 0));
    });

    await measure("6️⃣ Rerender Stress", () => {
      for (let i = 0; i < 50; i++) setFilter(f => (f === "all" ? "active" : "all"));
    });

    await measure("7️⃣ Compute Derived State", () => {
      for (let i = 0; i < 100; i++) todos.filter(t => t.done).length;
    });

    setRunning(false);
  }

  return (
    <div style={{ fontFamily: "sans-serif", padding: "1rem", maxWidth: 700 }}>
      <h2>⚛️ React Benchmarks</h2>
      <button disabled={running} onClick={runAll}>
        {running ? "Running..." : "Run All Benchmarks"}
      </button>

      <p>Total Todos: {todos.length}</p>
      <p>Visible: {filtered.length}</p>
      <p>Completed: {completedCount}</p>

      {results.length > 0 && (
        <table border={1} cellPadding={6} style={{ marginTop: "1rem", borderCollapse: "collapse" }}>
          <thead>
            <tr>
              <th>Benchmark</th>
              <th>Avg (ms)</th>
              <th>Min</th>
              <th>Max</th>
              <th>StdDev</th>
              <th>Runs</th>
            </tr>
          </thead>
          <tbody>
            {results.map(r => (
              <tr key={r.name}>
                <td>{r.name}</td>
                <td>{r.avg.toFixed(2)}</td>
                <td>{r.min.toFixed(2)}</td>
                <td>{r.max.toFixed(2)}</td>
                <td>{r.stddev.toFixed(2)}</td>
                <td>{r.runs.map(v => v.toFixed(1)).join(", ")}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
