// How two features talk without knowing each other — the whole architecture in one file.
// Run it:  swift docs/NavigationInOneFile.swift
//
// In the real app each "MODULE" below is a separate SwiftPM target, so the compiler enforces who
// may see whom. Here they share a file, so the rules are written in each header instead:
//
//   NavigationCore     ← everyone imports this (the shared vocabulary)
//   FeatureBContract   ← FeatureB's public "menu": what you can ask of it, what it answers
//   FeatureB           imports NavigationCore, FeatureBContract
//   FeatureA           imports NavigationCore, FeatureBContract   (never FeatureB itself!)
//   App                imports everything — the only place that knows every feature
//
// The story: FeatureA asks FeatureB for some text. FeatureB shows a text field; every time the
// user taps Send, the text travels back to FeatureA as an action. FeatureA never creates,
// imports, or holds FeatureB — it only sends a *request* and listens for *outputs*.

// ═════════════════════════════════════════════════════════════════════════════════════════════
// MARK: - MODULE: NavigationCore  (imports nothing — shared by everyone)
// ═════════════════════════════════════════════════════════════════════════════════════════════

/// One case per feature. The only list every module shares.
enum NavigationTarget: String {
    case featureA
    case featureB
}

/// *What* the caller wants, in words every feature understands.
enum NavigationIntent {
    case browse(NavigationTarget)                    // "show your main screen"
    case compose(NavigationTarget, prompt: String)   // "ask the user for text, and send it to me"
}

struct NavigationRequest {
    let intent: NavigationIntent

    var target: NavigationTarget {
        switch intent {
        case let .browse(target), let .compose(target, _): target
        }
    }
}

/// A typed value sent back by a screen. Boxed, so NavigationCore needs no feature's types.
struct NavigationOutput {
    let value: Any
    func `as`<T>(_: T.Type) -> T? { value as? T }
}

/// What a screen reports to whoever opened it: any number of outputs, then `.dismissed`.
enum NavigationResult {
    case output(NavigationOutput)
    case dismissed
}

/// Stand-in for UIViewController.
@MainActor
protocol Screen: AnyObject {
    var title: String { get }
}

/// The only way a feature moves around. Features never call each other — they call this.
@MainActor
protocol Navigator: AnyObject {
    func push(_ request: NavigationRequest, onResult: ((NavigationResult) -> Void)?)
    /// Called by the top screen: send a result to whoever pushed it, and stay on screen.
    func send(_ result: NavigationResult)
    func pop()
}

extension Navigator {
    /// Push, and get back only the outputs of type `T`, as an async stream that ends when the
    /// pushed screen leaves. This is what a reducer loops over in its effect.
    func pushForOutputs<T>(_ request: NavigationRequest, as _: T.Type) -> AsyncStream<T> {
        let (stream, continuation) = AsyncStream<T>.makeStream()
        push(request) { result in
            switch result {
            case let .output(output):
                if let value = output.as(T.self) { continuation.yield(value) }
            case .dismissed:
                continuation.finish()
            }
        }
        return stream
    }
}

/// How a feature plugs in: "I am `target`, and this is how I turn a request into my screen."
struct NavigationRegistration {
    let target: NavigationTarget
    let makeScreen: @MainActor (NavigationRequest, Navigator) -> Screen
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// MARK: - MODULE: FeatureBContract  (imports NavigationCore)
// FeatureB's public menu. Tiny, no screens, no logic — just the words both sides agree on.
// ═════════════════════════════════════════════════════════════════════════════════════════════

enum FeatureBContract {
    static let target = NavigationTarget.featureB

    /// What FeatureB sends back. The struct both features depend on.
    enum Output {
        case textSubmitted(String)
    }

    /// The request that opens FeatureB asking for text.
    static func compose(prompt: String) -> NavigationRequest {
        NavigationRequest(intent: .compose(target, prompt: prompt))
    }
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// MARK: - MODULE: FeatureB  (imports NavigationCore, FeatureBContract)
// Knows nothing about FeatureA. It answers whoever opened it, through the navigator.
// ═════════════════════════════════════════════════════════════════════════════════════════════

@MainActor
final class FeatureB: Screen {
    let title = "Feature B"
    private let navigator: Navigator
    private let prompt: String

    init(navigator: Navigator, prompt: String) {
        self.navigator = navigator
        self.prompt = prompt
        print("   FeatureB shows prompt: “\(prompt)”")
    }

    /// The user typed into the text field and tapped Send.
    func userTappedSend(text: String) {
        print("   FeatureB → navigator.send(.textSubmitted(“\(text)”))")
        navigator.send(.output(NavigationOutput(value: FeatureBContract.Output.textSubmitted(text))))
    }

    func userTappedBack() {
        navigator.pop()
    }

    /// FeatureB owns its registration; the App only lists it.
    static let registration = NavigationRegistration(target: FeatureBContract.target) { request, navigator in
        if case let .compose(_, prompt) = request.intent {
            return FeatureB(navigator: navigator, prompt: prompt)
        }
        return FeatureB(navigator: navigator, prompt: "Hello")
    }
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// MARK: - MODULE: FeatureA  (imports NavigationCore, FeatureBContract — NOT FeatureB)
// Written like a TCA reducer: state, actions, and one `send(_:)` that handles them.
// ═════════════════════════════════════════════════════════════════════════════════════════════

@MainActor
final class FeatureA: Screen {
    let title = "Feature A"
    private let navigator: Navigator

    // State
    private(set) var textFromB: String?

    // Actions — note the data from B arrives as an action carrying B's typed Output.
    enum Action {
        case askFeatureBTapped
        case featureB(FeatureBContract.Output)
    }

    init(navigator: Navigator) {
        self.navigator = navigator
    }

    func send(_ action: Action) {
        switch action {
        case .askFeatureBTapped:
            // The "effect": push B, then turn every output it sends into an action.
            let request = FeatureBContract.compose(prompt: "Feature A wants some text")
            let outputs = navigator.pushForOutputs(request, as: FeatureBContract.Output.self)
            Task {
                for await output in outputs {
                    self.send(.featureB(output))
                }
                print("   FeatureA: B left, effect finished")
            }

        case let .featureB(.textSubmitted(text)):
            textFromB = text
            print("   FeatureA received action .featureB(.textSubmitted(“\(text)”)) → state.textFromB = “\(text)”")
        }
    }

    static let registration = NavigationRegistration(target: .featureA) { _, navigator in
        FeatureA(navigator: navigator)
    }
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// MARK: - MODULE: App  (imports everything — the composition root)
// The only class that knows every feature exists. It is the Navigator: it turns requests into
// screens through the registrations, keeps the stack, and routes results back.
// ═════════════════════════════════════════════════════════════════════════════════════════════

@MainActor
final class App: Navigator {
    private var registrations: [NavigationTarget: NavigationRegistration] = [:]
    /// The back stack: each screen, plus the handler of whoever pushed it.
    private(set) var stack: [(screen: Screen, onResult: ((NavigationResult) -> Void)?)] = []

    init() {
        // The ONE place that lists the features.
        for registration in [FeatureA.registration, FeatureB.registration] {
            registrations[registration.target] = registration
        }
    }

    func start(with request: NavigationRequest) {
        push(request, onResult: nil)
    }

    func push(_ request: NavigationRequest, onResult: ((NavigationResult) -> Void)?) {
        guard let registration = registrations[request.target] else { return }
        let screen = registration.makeScreen(request, self)
        stack.append((screen, onResult))
        printStack()
    }

    func send(_ result: NavigationResult) {
        stack.last?.onResult?(result)       // to whoever pushed the top screen
    }

    func pop() {
        guard let top = stack.popLast() else { return }
        top.onResult?(.dismissed)           // always tell the caller it's over
        printStack()
    }

    private func printStack() {
        print("   App stack: " + stack.map(\.screen.title).joined(separator: " → "))
    }
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// MARK: - Run it — simulating the user's taps
// ═════════════════════════════════════════════════════════════════════════════════════════════

/// Lets the async stream deliver (in the real app, the run loop does this).
func settle() async { for _ in 0..<10 { await Task.yield() } }

@MainActor
func main() async {
    let app = App()

    print("1. App launches with Feature A")
    app.start(with: NavigationRequest(intent: .browse(.featureA)))
    let featureA = app.stack[0].screen as! FeatureA

    print("\n2. User taps “Ask Feature B” in Feature A")
    featureA.send(.askFeatureBTapped)
    await settle()
    let featureB = app.stack[1].screen as! FeatureB   // only the demo peeks; A never does

    print("\n3. User types “Hello” in Feature B and taps Send")
    featureB.userTappedSend(text: "Hello")
    await settle()

    print("\n4. User sends again — B stays on screen")
    featureB.userTappedSend(text: "Hello again")
    await settle()

    print("\n5. User taps Back")
    featureB.userTappedBack()
    await settle()

    print("\nFeature A ends with textFromB = “\(featureA.textFromB ?? "nil")”")
}

await main()
