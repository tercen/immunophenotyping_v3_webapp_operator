# Type 3 App — Design Summary

> Condensed reference for Type 3 skills. Full rationale in `_local/type3-design-decisions.md`.

---

## What Is a Type 3 App?

A **workflow manager** that wraps a Tercen template workflow. It does not visualise cross-tab projections (Type 1) or compute and write back results (Type 2). Instead it:

1. Wraps a Tercen template workflow for data analysis
2. Sets up the project (creates Tercen objects: project, data uploads, connectors)
3. Manages workflow inputs (operator properties, data files, multi-stage interaction)
4. Orchestrates execution (start/stop workflow steps, display status/progress)
5. Presents a report (on-screen + downloadable)
6. Supports scenarios (run loops — run with Setting A, change to Setting B, compare)

**Template model:** An app may use multiple templates, chain them, or offer the user a choice.

---

## Three-Panel Layout

```
┌─ Status Panel ─┬─ Header Panel ───────────────────┐
│ (left, always)  │  [context label]       [actions]  │
│                 ├───────────────────────────────────┤
│ ACTIONS         │                                   │
│ [Run] [Stop]    │  Content Panel                    │
│ [Reset]         │  (scrollable)                     │
│                 │                                   │
│ STATUS          │  INPUT mode content               │
│ ● Running       │    or                             │
│ ■■■░░ 60%      │  DISPLAY mode content              │
│ Step: 3 of 5    │    or                             │
│                 │  RUNNING overlay                   │
│ CURRENT RUN     │                                   │
│ Files: data.fcs │                                   │
│ Seed: 42        │                                   │
│                 │                                   │
│ HISTORY         │                                   │
│  Run 1 - Done   │                                   │
│  Run 2 - Done   │                                   │
│                 │                                   │
│ INFO            │                                   │
└─────────────────┴───────────────────────────────────┘
```

Structure: `Row → [LeftPanel, Expanded(Column → [HeaderPanel, Content])]`

Header Panel sits inside the right column, NOT spanning full app width.

---

## Status Panel (Left, Always Visible)

Uses existing skeleton left panel mechanics (collapse, expand, resize). 5 sections:

1. **ACTIONS** — Run/Stop/Reset buttons. State-driven enabled/disabled. Re-Run is NOT here (it's in Header Panel Display mode).
2. **STATUS** — Colour-coded state indicator, progress bar, current step label. Shows what app is waiting for when in Waiting state.
3. **CURRENT RUN** — Read-only summary of files uploaded and parameter values. Updates live as user provides input.
4. **HISTORY** — List of past runs (most recent first). Click to view results. Each entry: name/number, timestamp, status.
5. **INFO** — GitHub link, version, app name. Mandatory, always at bottom.

---

## Header Panel (48px Fixed Strip)

Two zones: left-aligned context label, right-aligned action buttons.

| Mode | Left Zone | Right Zone |
|------|-----------|------------|
| Input | Page heading (e.g. "Select channels") | Primary action button ("Continue", "Upload", "Run") |
| Display | Cloned workflow name (run identifier) | Re-Run, Export, Delete |
| Running | Dimmed (keeps current label) | Dimmed (no active buttons) |

Header Panel is DO-NOT-MODIFY. Apps configure it via AppStateProvider (mode, heading text, button labels).

---

## Content Panel Modes

### Input Mode — Two-Column Layout

```
Header Panel: "Select channels for analysis"          [Continue]
┌─ Content Panel ──────────────────────────────────────────────┐
│  Description: optional context text                          │
│  ┌─ Form (left) ────────────┬─ Viz (right, optional) ─────┐│
│  │ SECTION LABEL             │ Data step output             ││
│  │ Control 1                 │ (read-only, informs          ││
│  │ Control 2                 │  the user's choices)         ││
│  │ SECTION LABEL             │                              ││
│  │ Control 3                 │                              ││
│  └───────────────────────────┴──────────────────────────────┘│
└──────────────────────────────────────────────────────────────┘
```

Rules: heading in Header Panel, description at top of Content Panel, form sections use same typography/control types as Type 1/2. When no viz, form goes full width. No nesting.

### Display Mode — Scrollable Results

```
Header Panel: "Run 3 — Immunophenotyping"    [Re-Run] [Export] [Delete]
┌─ Content Panel ──────────────────────────────────────────────┐
│  Results / Visualisations / Report                           │
│  (app-specific layout, defined in spec)                      │
│  Display controls inline if needed (filters, view toggles)   │
└──────────────────────────────────────────────────────────────┘
```

Re-Run returns to Input mode with settings pre-loaded. Export is app-specific. Delete removes the cloned workflow + results (confirmation required).

---

## App States

Two hard states:
- **Running** — app is doing work. AbsorbPointer blocks Header + Content Panels. Visual dimming + .gif animation in Content Panel. Status Panel stays fully active.
- **Waiting** — app is stopped. Either needs input or showing results. User acts at own pace.

No mid-step pause. Stop cancels the running data step (resets it). Completed steps keep results.

---

## Running State Overlay

- `AbsorbPointer` wraps Header + Content Panels
- Visual dimming via reduced opacity
- .gif animation centred in Content Panel (default: `assets/images/running.gif`)
- Status Panel remains fully active (progress, Stop button)
- Triggered by `AppStateProvider.isRunning`
- On completion: overlay removed instantly, no widget rebuild

---

## Data Context & Launch Modes

- No `taskId` — works at project level with `projectId`
- `createServiceFactoryForWebApp()` for auth (standalone) or `createServiceFactoryForWebApp(tercenToken: token)` (orchestrated)
- `sci_tercen_client` is the sole API — no `sci_tercen_context` / `OperatorContext`
- Phase 3 uses Flow E: workflow execution pattern

Two launch modes (apps support both by default):
1. **Standalone** — reads `projectId` from URL query parameters, creates factory from embedded auth
2. **In-project** (orchestrated) — receives credentials and projectId via `init-context` postMessage from orchestrator

### Phase 3 Integration Pattern (Flow E)

- main.dart: create factory from URL params or postMessage → pass factory + projectId to setupServiceLocator
- service_locator: register `ServiceFactory` + `TercenWorkflowService(factory, projectId)`
- Real service receives factory + projectId, calls workflow/task/event services directly
- No OperatorContext at any point
- Step output reading: navigate `step.computedRelation` → `_getSimpleRelations()` → `tableSchemaService.select()`

### Key Services Used

| Service | Purpose |
|---------|---------|
| `workflowService` | Clone template (`copyApp`), get/update workflow, read steps |
| `taskService` | Create `RunWorkflowTask`, `runTask`, `cancelTask`, `waitDone` |
| `eventService` | `listenTaskChannel` for progress/state streams |
| `fileService` | Upload input files, download result files |
| `tableSchemaService` | Read step output data (via `computedRelation`) |
| `projectDocumentService` | List workflows in project (run history) |
| `projectService` | Get/create project metadata |

---

## App-Workflow Control Boundary

The app is a **runner layer**:

**CAN:** Start/stop execution, provide data files, set operator properties, read workflow state, read step outputs.

**CANNOT:** Run steps out of sequence, change operators, modify connections/links, add/remove steps, pause mid-calculation.

---

## Run Storage

Each run = cloned Tercen workflow via `workflowService.copyApp()`. Results stored as Tercen objects. Run config stored as workflow metadata (key-value pairs). History reads workflows from the project.

---

## AppStateProvider Shape (Type 3)

```
- App state: Running / Waiting
- Content mode: Input / Display
- Current input stage (for multi-stage)
- Current run settings (map of parameter names → values)
- Run history (list of past runs with status)
- Selected history entry
- Input completion state (are all required inputs provided?)
- Header panel config (heading text, button labels per mode)
- Methods: startRun(), stopRun(), resetApp(), selectHistoryEntry(),
           updateSetting(), navigateToStage(), initiateReRun()
```

---

## Mock Rules (Phase 2)

- Mock demonstrates the **full logical flow** without real execution
- **No simulated Running state** — transitions are immediate
- Status Panel wired to provider: buttons change state, status shows current state
- Content Panel Input mode: real form layouts, controls wired to provider
- Content Panel Display mode: real result data from assets
- Mock data from real completed workflows (not synthetic)
- 2-3 pre-built runs for history browsing

### Mock Service Interface

```
getInputConfig(stage) → input configuration for current stage
getResults(runId) → result data for a given run
getRunHistory() → list of pre-built runs
submitInput(settings) → records settings, returns next stage or "ready to run"
getRun(runId) → full run details (settings + results)
```

Stateful — tracks current stage and inputs in memory.

### Mock Logical Flow

1. App starts in Waiting, Content Panel shows first Input screen
2. User fills inputs → presses Continue → next Input screen (or final)
3. User presses Run → immediate transition to Display mode (no Running sim)
4. User views results, can Re-Run (returns to Input with settings pre-loaded)
5. History entries pre-populated for clicking between past runs

### Mock Wiring Rules

```
Input:    control.onChanged → provider.updateSetting(key, value) → notifyListeners()
Actions:  button.onPressed → provider.startRun()/stopRun()/resetApp() → notifyListeners()
History:  item.onTap → provider.selectHistoryEntry(runId) → notifyListeners()
Display:  reRun.onPressed → provider.initiateReRun(runId) → notifyListeners()
```
