# Optic design

## Intent
Make the screenshot's profiler concept into a useful native Studio plugin: evidence-backed diagnostics, measured session data, and practical optimization recommendations. The user selected the name and destination and explicitly requested prompt improvement followed by implementation. Routine product and technical choices below are builder decisions.

## Approaches
- Native plugin with static analysis and documented runtime APIs (chosen): ships as a local Studio plugin and works without a server or account.
- Injected runtime instrumentation: can count explicitly wrapped connections but changes the game and adds measurement overhead. Excluded from this release.
- External dashboard: offers browser UI flexibility but adds installation and transport complexity. Excluded because this is a Studio plugin.

## Architecture
Flat, focused Luau modules under `src/`: Lexer masks comments and literal contents while preserving line offsets; Scanner emits advisory findings; Metrics stores bounded samples and derives trends; Profile normalizes documented profiler snapshots; Capture owns asynchronous profiler state; Report constructs serializable snapshots and Markdown; Studio services coordinate scans and sampling; UI renders the dock widget; App owns lifecycle. `init.server.luau` is the plugin entry point.

Build with Node using only its standard library. Generate a Script-root `.rbxmx` containing ModuleScript children and a self-contained `.plugin.luau` with an equivalent private module loader. Development tests use a pinned Luau WASM interpreter; there are no runtime dependencies.

## Product design
Header: Optic wordmark, Studio context, session status. Actions: Scan project/selection, client/server capture, memory baseline. Tabs: Overview (four metric cards and bounded frame history), Findings (search/severity and actionable rows), CPU (ranked functions and capture state), Memory (baseline deltas/categories), Report (JSON/Markdown, selectable text). Requested minimum panel size 480 × 440; default floating dockable panel 760 × 680. Native testing showed restored docks may ignore the requested minimum, so action widths also adapt at 426 px. Long content scrolls, findings open source on their reported line, and all errors remain visible.

## Contracts and limits
- Scan the DataModel script descendants, yielding every 20 candidates. Limit 2,000 scripts, 256 KiB per source, 500 findings per report; mark truncation, unreadable and skipped files in coverage. Traverse selection descendants with deduplication. No source mutation.
- Sampling interval 0.5 seconds; 120 samples retained. Metrics are explicitly the plugin's current Studio session, not inferred remote client/server totals. Missing APIs yield unavailable values, never zero by substitution.
- Memory growth requires at least 10 valid samples over 10 seconds; report a positive least-squares slope only as an investigation signal. Baselines are in-memory snapshots.
- Capture only in Play mode, default client, fixed 1 kHz, auto-stop after 15 seconds. Native profiler ownership is session scoped: no concurrent Optic captures. Stop only captures Optic started. Request one final snapshot; timeout after 8 seconds; ignore other-player data and unsolicited snapshots. Capture ends on Play exit/panel close/unload; late timers and callbacks cannot revive it.
- Profiler schema: Version, SessionStartTime/SessionEndTime in ms, Functions[].TotalDuration in microseconds, Flags bit 1 means plugin execution. Present inclusive sampled function time; never sum inclusive costs to claim total CPU usage. Reject malformed input, handle missing metadata, bound result count to 100.
- Static analysis is conservative and advisory, does not prove excessive live connections or identify all expensive scripts. Long strings/comments cannot create findings. Show severity and confidence separately. No per-script memory claims.
- Reports include schema version, capture timestamp, context, coverage, findings, memory/metric summary, and CPU status/results. Exclude Instances, callbacks, source text and editor contents. JSON uses HttpService:JSONEncode; Markdown escapes table cells.
- UI updates at most twice a second and renders at most 100 findings and 100 CPU results, with visible counts. No background scanning or external networking. Preferences: scope, CPU target, report format only. All sampling and GUI handlers have an owner and are disconnected/destroyed on unload.

## Goals and non-goals
Goal: locally installable, useful and honest first release with working scan, capture, baseline and export flows. Non-goals: live-game telemetry, connection enumeration, automated source rewriting, leak proof, cross-session storage of project data, Marketplace publishing. Keep the built artifacts in the exact user folder; no separate worktree is needed for this empty, non-git destination.

## Validation
Run actual Luau behavioral tests via a pinned WASM interpreter, compile all modules and the bundle, test the build/package contract, and request an independent source review. Studio became available during the follow-up; native acceptance results and remaining checks are recorded in README, `docs/superpowers/VERIFICATION.md`, and `test-results/studio-acceptance.json`. API references are linked in the README.
