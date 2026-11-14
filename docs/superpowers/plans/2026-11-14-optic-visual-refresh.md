# Optic Visual Refresh Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the native Optic interface more readable, comfortable and visually consistent using the user's logo.

**Architecture:** Keep the production service and reporting interfaces intact. Add a Brand module for the asset reference and replace UI construction/styling with reusable native helpers. Preserve existing controller callbacks and report behavior.

**Tech Stack:** Luau, Roblox native GUI, Builder Sans, Node build pipeline.

**Spec:** `docs/superpowers/specs/2026-11-14-optic-visual-refresh.md`

## Global constraints
- Real metrics and existing profiler semantics remain unchanged.
- Preserve the provided logo; no source-code or report data is sent to the asset uploader.
- Automatic updates remain at 2 Hz; UI connections clean up on unload.
- Native UI must remain usable at 426 px width; original exports stay UTF-8 safe.

## Review focus
- Narrow-width labels and action rows must not overlap or truncate essential text.
- Responsive metric reflow must preserve values and chart ordering.
- Larger fonts and automatic height must not make scrolling or reports unusable.
- All callbacks, filters, paging and cancellation remain functional.
- The logo must render from the uploaded asset; the final install contains no test bridge.

### Task 1: Brand asset and visual foundation
- [x] Preserve the user's logo in `assets/optic-logo.png`, register its Roblox image asset and add `src/Brand.luau`.
- [x] Implement readable font/color/spacing helpers and native button states in `src/UI.luau`.

### Task 2: Redesign all views
- [x] Rebuild header, actions, tabs and responsive Overview.
- [x] Redesign Findings, CPU, Memory and Report while keeping current behavior and copyable paginated output.
- [x] Update `src/App.luau` to use the actual logo and comfortable default dimensions.

### Task 3: Verify and deliver
- [x] Run the full automated suite and build both artifacts.
- [x] Inspect every tab and responsive width in native Studio; verify key actions and source/report flows.
- [x] Request independent review of layout/lifecycle risks and fix important issues.
- [x] Restore clean installed artifact, capture the new UI and update documentation.
