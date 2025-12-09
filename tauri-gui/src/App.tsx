import { useEffect, useMemo, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import "./App.css";

type KeyboardLayoutInfo = {
  name: string;
  rows: number;
  columns: number;
  knobs: number;
  description: string;
};

type ValidationSummary = {
  layers: number;
  buttons: number;
  knobs: number;
};

function App() {
  const [layouts, setLayouts] = useState<KeyboardLayoutInfo[]>([]);
  const [selectedIndex, setSelectedIndex] = useState<number>(0);
  const [yaml, setYaml] = useState("");
  const [initialYaml, setInitialYaml] = useState("");
  const [status, setStatus] = useState<string>("");
  const [keys, setKeys] = useState<Set<number>>(new Set());
  const [knobs, setKnobs] = useState<Set<number>>(new Set());

  useEffect(() => {
    async function bootstrap() {
      const [supported, example] = await Promise.all([
        invoke<KeyboardLayoutInfo[]>("cmd_supported_layouts"),
        invoke<string>("cmd_example_config"),
      ]);
      setLayouts(supported);
      setYaml(example);
      setInitialYaml(example);
      setSelectedIndex(0);
    }
    bootstrap().catch((err) => setStatus(`Failed to load: ${err}`));
  }, []);

  const selected = useMemo(
    () => layouts[selectedIndex],
    [layouts, selectedIndex]
  );

  const toggleKey = (idx: number) => {
    setKeys((prev) => {
      const next = new Set(prev);
      next.has(idx) ? next.delete(idx) : next.add(idx);
      return next;
    });
  };

  const toggleKnob = (idx: number) => {
    setKnobs((prev) => {
      const next = new Set(prev);
      next.has(idx) ? next.delete(idx) : next.add(idx);
      return next;
    });
  };

  const handleValidate = async () => {
    try {
      const summary = await invoke<ValidationSummary>("cmd_validate_config", {
        yaml,
      });
      setStatus(
        `Valid ✓ — layers: ${summary.layers}, buttons: ${summary.buttons}, knobs: ${summary.knobs}`
      );
    } catch (err) {
      setStatus(`Validation failed: ${err}`);
    }
  };

  return (
    <main className="container">
      <header>
        <div>
          <p className="eyebrow">CH57x keyboard configurator</p>
          <h1>Visualize and validate your layout</h1>
          <p className="muted">
            Desktop prototype powered by Tauri + React. Pick a layout, click
            keys/knobs to mirror hardware, edit YAML, and validate before
            uploading.
          </p>
        </div>
        <div className="actions">
          <button onClick={handleValidate}>Validate YAML</button>
        </div>
      </header>

      <section className="panel">
        <div className="panel-header">
          <div>
            <p className="label">Keyboard model</p>
            <select
              value={selectedIndex}
              onChange={(e) => {
                setSelectedIndex(Number(e.target.value));
                setKeys(new Set());
                setKnobs(new Set());
              }}
            >
              {layouts.map((layout, idx) => (
                <option key={layout.name} value={idx}>
                  {layout.name} — {layout.description}
                </option>
              ))}
            </select>
          </div>
          {selected && (
            <div className="summary">
              <span>
                {selected.rows}×{selected.columns} keys · {selected.knobs} knobs
              </span>
            </div>
          )}
        </div>

        {selected && (
          <div className="layout-grid">
            <div
              className="grid"
              style={{
                gridTemplateColumns: `repeat(${selected.columns}, minmax(80px, 1fr))`,
              }}
            >
              {Array.from({
                length: selected.rows * selected.columns,
              }).map((_, idx) => {
                const active = keys.has(idx);
                return (
                  <button
                    key={idx}
                    className={`key ${active ? "active" : ""}`}
                    onClick={() => toggleKey(idx)}
                  >
                    K{idx + 1}
                  </button>
                );
              })}
            </div>
            {selected.knobs > 0 && (
              <div className="knobs">
                {Array.from({ length: selected.knobs }).map((_, idx) => {
                  const active = knobs.has(idx);
                  return (
                    <button
                      key={idx}
                      className={`knob ${active ? "active" : ""}`}
                      onClick={() => toggleKnob(idx)}
                    >
                      Knob {idx + 1}
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        )}
      </section>

      <section className="panel">
        <div className="panel-header">
          <div>
            <p className="label">Mapping YAML</p>
            <p className="muted">
              Paste or edit your mapping. Use Validate to check structure before
              upload.
            </p>
          </div>
          <button onClick={() => setYaml(yaml)}>Reset</button>
          <button onClick={() => setYaml(initialYaml)}>Load example</button>
        </div>
        <textarea
          value={yaml}
          onChange={(e) => setYaml(e.target.value)}
          rows={16}
          spellCheck={false}
        />
        {status && <p className="status">{status}</p>}
      </section>
    </main>
  );
}

export default App;
