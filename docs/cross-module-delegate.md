# Cross-module delegate communication: Screen A → Screen C

## Background: how the app is built today

NavigationKit is a Swift package split into small, single-purpose targets (see `Package.swift`):

- **`AppRoutes`** — the leaf module every other target depends on, and the only thing they're
  allowed to depend on. It defines:
  - `Route`: a plain, stateless `enum` (`screenA`, `screenB`, `screenC`, `screenD`) that is
    `Hashable`, `Sendable`, and `CaseIterable`.
  - `Navigator`: a `@MainActor` protocol (`push`, `pop`, `popToRoot`, `present`, `dismiss`) — the
    *only* seam a feature is allowed to use to move around the app. Features never import each
    other or the screen resolver directly.
- **`NavigatorDependency`** — exposes `Navigator` as a `@Dependency(\.navigator)` for TCA-based
  features.
- **`ScreenAFeature` / `ScreenBFeature`** — SwiftUI screens driven by Composable Architecture
  reducers. Each has a small in-module child screen (A2, B2) wired via `@Presents` / `.ifLet`.
- **`ScreenCKit` / `ScreenDKit`** — plain UIKit `UIViewController`s, no TCA, no `@Dependency`.
  They receive a `Navigator` through their initializer and call `navigator.push(...)` directly.
- **`AppComposition`** — the composition root. It's the only target allowed to import every
  feature. `ScreenResolver` is a single exhaustive `switch` over `Route` that turns a route into a
  concrete view controller, whichever framework it happens to be built with. `AppNavigator` (a
  plain `@Observable` class, *not* a TCA store) owns one `[Route]` array per tab and mutates
  whichever tab is currently active; `PresentedNavigator` does the same for modal chains.

Navigation state deliberately lives **outside** TCA's own navigation tools (`StackState`,
`@Presents` at the app level) because two of the four screens are plain UIKit with no `State`/
`Store` at all — a hand-rolled `Navigator` was the seam that could serve both worlds. Route
resolution is *lazy*: `Navigator.push(route)` only appends to an array; the actual view controller
for that route is built later, by `ScreenResolver`, whenever `NavigationStackController`'s
`navigationDestination(for: Route.self)` closure runs.

## The problem

We want Screen A to hand Screen C a piece of data when it pushes to it (a subtitle string), and we
want Screen C to be able to notify Screen A when something happens on it (tapping a "parent
button"), without the two feature modules importing each other — mirroring a delegate pattern like:

```swift
struct ListFeatureDelegate {
    enum ActionEvent {
        case navigateToIssue(GGIssueUid, Bool)
    }
    var actionEvent: (ActionEvent) -> Void
}
```

This doesn't fit cleanly into the existing seam, because of two seemingly small constraints that
turn out to matter a lot:

- `Route` must stay `Hashable`/`Equatable` — `NavigationStackController`'s path binding diffs on
  it, and `navigationDestination(for: Route.self)` looks up destinations by it. Closures (the
  natural shape of a delegate) are not `Hashable`/`Equatable`.
- `Route` must stay `CaseIterable` — every screen's "navigate to any other screen" demo button
  list is generated from `Route.allCases`. (This one turns out to be a non-issue: it's used in
  exactly 8 places, all for that one demo button list, and `CaseIterable` can always be
  hand-written instead of synthesized if a case needs to carry a payload.)

So the real question is: does the delegate travel *as part of* the `Route`/`Navigator` push call,
or does it travel *around* it, through a separate mechanism?

## Approach 1 — side-channel dependency, `Route` untouched

Keep `Route` and `Navigator.push(_:)` exactly as they are today. Introduce a second shared,
mutable object — the same idiom `AppNavigator` already uses — that Screen A writes into right
before pushing, and Screen C reads from when `ScreenResolver` constructs it moments later.

```swift
public struct ScreenCDelegate: Sendable {
    public var subtitle: String?
    public var didTapParentButton: @Sendable () -> Void
}

@MainActor
public final class ScreenCDelegateBox {
    public var current: ScreenCDelegate?
}

extension DependencyValues {
    public var screenCDelegateBox: ScreenCDelegateBox { ... } // DependencyKey, liveValue = ScreenCDelegateBox()
}
```

```swift
// ScreenAFeature
case .pushScreenCWithDelegateTapped:
    let navigator = navigator
    let box = screenCDelegateBox
    return .run { send in
        box.current = ScreenCDelegate(subtitle: "Pushed from Screen A") {
            Task { await send(.childActionReceived) }
        }
        await navigator.push(.screenC)   // Route itself never changes
    }
```

```swift
// ScreenCViewController
@Dependency(\.screenCDelegateBox) private var screenCDelegateBox
private lazy var delegate = screenCDelegateBox.current
// subtitleLabel.text = delegate?.subtitle
// parentButton -> delegate?.didTapParentButton()
```

**Pros**
- `Route` stays exactly as-is: still auto-`Hashable`, still auto-`CaseIterable`.
- No change to the nav-stack diffing behavior at all.

**Cons**
- `box.current` is global, mutable, "latest write wins" state that isn't tied to *this specific*
  push. Needs an explicit clear-after-read (or clear-on-dismiss) rule, or a stale delegate can leak
  into an unrelated, later push to Screen C.
- `ScreenCKit` currently depends on nothing but `AppRoutes`. This approach adds a new dependency
  edge: `ScreenCKit → NavigatorDependency → ComposableArchitecture`, just to read one
  `@Dependency`.

## Approach 2 — delegate rides on the `Route` case

Attach the delegate as an associated value on `Route.screenC`, and hand-write the conformances that
can no longer be synthesized.

```swift
public enum Route: Sendable {
    case screenA
    case screenB
    case screenC(delegate: ScreenCDelegate? = nil)
    case screenD
}

extension Route: Equatable {
    public static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.screenA, .screenA), (.screenB, .screenB), (.screenD, .screenD): true
        case (.screenC, .screenC): true   // delegate identity is ignored for equality
        default: false
        }
    }
}
extension Route: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .screenA: hasher.combine(0)
        case .screenB: hasher.combine(1)
        case .screenC: hasher.combine(2)
        case .screenD: hasher.combine(3)
        }
    }
}
extension Route: CaseIterable {
    public static var allCases: [Route] { [.screenA, .screenB, .screenC(), .screenD] }
}
```

```swift
// ScreenAFeature
case .pushScreenCWithDelegateTapped:
    let navigator = navigator
    return .run { send in
        await navigator.push(.screenC(delegate: ScreenCDelegate(
            subtitle: "Pushed from Screen A",
            didTapParentButton: { Task { await send(.childActionReceived) } }
        )))
    }

// ScreenResolver
case let .screenC(delegate):
    ScreenCViewController(navigator: navigator, delegate: delegate)
```

**Pros**
- The delegate is scoped precisely to one push — no leftover global state to manage.
- No new dependency edge: `ScreenCKit` still only needs the delegate value handed to it through its
  initializer.

**Cons**
- `Route`'s equality now deliberately ignores the delegate payload: two different
  `.screenC(delegate:)` values are "equal" as far as the nav stack's diffing is concerned. If
  Screen C is ever pushed twice onto the *same* stack with two different delegates,
  `NavigationStackController`'s diffing (which relies on `Hashable`/`Equatable` to identify stack
  elements) could dedupe or reuse the wrong destination.
- `Hashable`/`Equatable`/`CaseIterable` go from compiler-synthesized to hand-maintained.

## The open question

Approach 1 trades a `Route`/`Hashable` landmine for global-state lifecycle management. Approach 2
trades global state for a hand-rolled, deliberately-lossy `Equatable`. Which one is safer depends
on whether Screen C can ever be pushed twice in a row onto the same stack (stacking C on top of
C) — if that can never happen, Approach 2's lossy equality is harmless; if it can, Approach 1 is
the safer default despite its own lifecycle bookkeeping.
