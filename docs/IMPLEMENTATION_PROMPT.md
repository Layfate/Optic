# Optic — Roblox Performance Profiler

Build a production-minded first release of **Optic**, a native Roblox Studio plugin that helps Roblox developers find expensive scripts, connection lifecycle risks, and memory growth, then act on clear recommendations.

## Experience

Create a polished dockable Studio panel branded **Optic — Roblox Performance Profiler**. Use a comfortable charcoal interface, restrained lavender accents matching the user's supplied purple logo, Builder Sans UI typography (13 px minimum, 14–15 px body), readable metric cards, severity badges, useful empty states, and responsive layouts. Preserve the supplied logo and use it in the header and toolbar. Include Overview, Findings, CPU, Memory, and Report views. Every control must work; never display invented measurements.

## Required capabilities

1. **Project scanning:** scan all project scripts or the current selection. Read current editor contents through ScriptEditorService with protected fallbacks. Report file, line, severity, confidence, evidence, explanation, and a specific optimization. Ignore comments and string contents when matching code. Detect connection creation inside loops, high-frequency callbacks that need lifecycle review, expensive descendant traversal in repeated execution, and deprecated scheduling APIs. These are static heuristics, never proof of a leak or measured CPU cost. Allow searching, severity filtering, cancellation, and opening the affected script.
2. **Live session metrics:** sample real Studio-session frame time, memory, instance count, and selected DeveloperMemoryTag categories at a modest rate. Clearly state the scope and unavailable metrics. Keep history bounded. Pause sampling when the panel is closed and clean up all owned connections on unload.
3. **Memory investigation:** take and compare baselines, show category deltas, and identify sustained observed growth over a sufficiently long sampling window. Call growth a signal for investigation, not a confirmed memory leak.
4. **CPU profiling:** use documented ScriptProfilerService APIs for client or server capture during Play mode. Provide start/stop, a bounded capture duration, asynchronous data handling, timeout/error states, and ranked function results. Preserve microsecond-to-millisecond units and inclusive time semantics. Exclude plugin functions from game results. Handle unavailable service access gracefully. Do not instrument or rewrite game scripts.
5. **Reports:** generate honest JSON and Markdown reports containing scope, coverage, real measurements, static findings, recommendations, and CPU capture results. Exclude source text. Provide a selectable report text field for copying and remember only small, non-sensitive preferences through plugin settings.
6. **Delivery:** deliver modular Luau source, a reproducible build command, an installable `dist/Optic.rbxmx`, a bundled local plugin script, automated behavioral tests, and a README with installation, workflow, permissions, limitations, and Studio acceptance checks.

## Engineering constraints

- Use only documented Roblox APIs; no exploit APIs, arbitrary filesystem claims, fake connection counts, or fabricated per-script memory attribution.
- Keep analysis local. Do not send project code or metrics to external services.
- Do not auto-fix scripts, inject runtime agents, publish assets, or modify the user's game.
- Scan in yielding batches and bound source/file/finding/result/history sizes so the tool does not become the performance problem.
- Test scanner false positives, line mapping, numerical edge cases, profiler units/filtering, lifecycle cleanup, capture failures/timeouts, report escaping, and package reproducibility.
- Clearly distinguish automated verification from checks requiring a running Roblox Studio.

Implement this brief in `C:\Users\corti\Documents\All Projects\Optic` and leave the built artifacts ready to install.
