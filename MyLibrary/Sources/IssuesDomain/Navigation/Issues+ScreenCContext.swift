import ComposableArchitecture
import NavigationCore

extension Issues {
    /// Deep-link action name: `demoapp://issues?action=screenCContext`.
    public static let screenCContextAction = "screenCContext"

    /// Pushes Screen C in compose mode and writes every text it sends into `.screenCText`, which
    /// the issues list shows in its Context chip. Returns when Screen C leaves.
    ///
    /// The one implementation behind both the Context chip and the deep-link action.
    @MainActor
    static func pushScreenCWithContext(navigator: any Navigator) async {
        let request = NavigationRequest(intent: .compose(.screenC, prompt: "I have been pushed from the issues list"))
        @Shared(.screenCText) var screenCText
        for await result in navigator.pushForResults(request) {
            if case let .message(text) = result {
                $screenCText.withLock { $0 = text }
            }
        }
    }
}
