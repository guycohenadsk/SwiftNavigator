# Navigation Contracts — Design

**Branch:** `feature/navigation-contracts` · **Base:** `757bc14`
**Reference:** [dekelmaman/navigation_contract](https://github.com/dekelmaman/navigation_contract)

## Goal

Replace the central screen catalog (`Route`, `Destination`, `ScreenCContext` in `AppRoutes`) and
the per-screen switch (`ScreenResolver`) with navigation_contract's architecture, adapted to this
app's tabs, endless modals, TCA reducers, and UIKit screens:

- features never import each other — they share only `NavigationCore`;
- adding a screen touches only its feature; adding a module touches one enum case and one list;
- in-app taps, tab roots, and deep links go through one pipeline;
- results travel back across modules, and every waiting caller gets an answer;
- wiring mistakes fail in tests, not as blank screens.

## Decisions

| # | Decision |
|---|----------|
| D1 | **Semantic intents only.** Cross-module navigation is `.open(EntityRef)`, `.browse(target)`, `.selectSingle(target)` — as in the reference — plus `.compose(target, prompt:)` for asking a module for text. No typed per-feature factories, no payloads. |
| D2 | **`NavigationTarget` is an enum in `NavigationCore`.** One case per module; adding a module is the one shared edit, and a test fails until it is registered. |
| D3 | **Contracts hold a module's own `target`, `Route`, and the `Output` values it sends back.** The module imports its contract to send; callers import it to read those outputs — never the module's implementation. |
| D4 | **Each feature owns its registration:** `extension <X> { static let navigationRegistration }` in `<X>+NavigationRegistration.swift`. The app shell lists them; no global self-registration. |
| D5 | **The caller chooses the presentation** by calling `push` or `present`. Targets declare nothing about presentation. |
| D6 | **Results: `push`/`present(_:onResult:)` + `send(_:)` / `complete(with:)`.** A handler gets any `.output(NavigationOutput)` updates (sent while the screen stays up, typed by the sender's contract), then exactly one final result — `.selectedEntity(EntityRef)` or `.dismissed`. `complete(with: .output)` delivers the output, then leaves with `.dismissed`. `pushForOutputs(_:as:)` / `presentForOutputs(_:as:)` stream just the typed outputs, so a TCA effect turns each into an action. `.dismissed` also fires on swipe-back, swipe-down, and deep-link resets, so `pushForResult(s)(_:)` / `presentForResult(s)(_:)` (async; final result or a stream of all) are safe to await from a TCA effect. |
| D7 | **Tabs use the same requests:** each tab root is a `NavigationRequest` resolved through the registry. The app shell owns which tabs exist. |
| D8 | **Deep links:** the reference's format and parser, plus `?action=<name>` → `.perform(target, action:)`. One fixed landing rule — dismiss modals, switch to the module's tab (if any) on a fresh stack, then push the request; or, for `.perform`, hand the action name to that stack's root screen through `Navigator.performedActions(for:)` (held until it subscribes). |
| D9 | **Every tab and every modal is one `StackNavigator`** — the shape of the reference's navigator. `AppNavigator` routes each call to the current stack. |
| D10 | **Explicit buttons**, each written out by the screen that shows it — no generated "go anywhere" chips. |
| D11 | **RefPicker** is a shared component, as in the reference: a list of references with Add Reference, knowing only NavigationCore. Issue details host one for related issues (session-only, like the reference's `@State`); Add Reference pushes the picker, as in the reference. It is a small TCA reducer because its host is TCA. |

## Module rules (enforced by `Package.swift`, audited by `scripts/check-boundaries.sh`)

```
NavigationCore              → (nothing in this package)
<X>NavigationContract       → NavigationCore
RefPicker                   → NavigationCore, NavigatorDependency
feature X                   → NavigationCore, NavigatorDependency (TCA), RefPicker, <X>NavigationContract,
                              contracts of screens whose outputs X reads
App target                  → everything (composition root only)
```

## Verified

34 package tests (core, RefPicker, per-module routes, Issues domain incl. picker and Screen C context), 20 app tests
(`AppNavigator` stacks, results, modal dismissal, deep links, every target registered, every tab
root resolves), 7 UI flows in the running app (deep links to an issue, to Screen C, and to the Screen C context action; picker result; dismissed picker; add reference; Screen C context),
boundary audit.

## History

**Revision 1** used typed per-feature contracts (`Issues.Navigation.details(id:)` returning
`Destination<Output>`), an open `NavigationTarget` struct, `AsyncStream` results with a navigation
context, target-declared default presentations, and module-suggested deep-link plans.

It worked, but review showed it was far heavier than the reference — features imported every
contract they called, and the shared code grew instead of shrinking (core 343 lines vs. the
reference's 125; app shell 307 vs. 194 before the work). **Revision 2** (this document) realigned
with the reference: intents only, enum targets, single results, caller-chosen presentation, one
landing rule, and one stack type. Core: 132 lines; app shell: 222.

Screen C's composer demo was first dropped (pure intents couldn't carry its input/output), then
brought back generically: `.compose(target, prompt:)` in, `.message(String)` updates out via
`send(_:)`, with the Issues list reading them through a `@Shared` in-memory key.

**Revision 3** types the outputs and drops the `@Shared` key: `.message(String)` became
`.output(NavigationOutput)`, a box around a value declared in the sender's contract
(`ScreenCNavigationContract.Output.textSubmitted`). The Issues list imports Screen C's contract and
turns each output into a `.screenC(Output)` action — data arrives as actions, not observed state.
Deep-link actions arrive the same way: `NavigationRegistration.actions` is gone, and
`Navigator.performedActions(for:)` streams `.perform` names to the root screen of the stack the link
lands on. The Issues tab's root list turns `screenCContext` into a `.deepLinkAction` and runs the
chip's flow, so Screen C's replies land in that same list.

## Open points

- **URL scheme collision.** navigation_contract's demo app registers the same `demoapp://` scheme;
  on a device with both installed, iOS may route links to the other app.
- **State restoration** — `NavigationRequest` is `Codable`, so the stacks could be persisted later.
- **Codegen of the registration list** (the reference's "Option 3").
