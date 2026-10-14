import Foundation
import NavigationCore
import Testing

@Suite("NavigationRequest")
struct NavigationRequestTests {
    @Test("Target is derived from each intent")
    func targetFromIntent() {
        #expect(NavigationRequest(intent: .open(EntityRef(target: .issues, id: "1", title: ""))).target == .issues)
        #expect(NavigationRequest(intent: .browse(.screenB)).target == .screenB)
        #expect(NavigationRequest(intent: .selectSingle(.screenC)).target == .screenC)
        #expect(NavigationRequest(intent: .compose(.screenC, prompt: "Hi")).target == .screenC)
    }

    @Test(
        "Requests survive a JSON round-trip",
        arguments: [
            NavigationIntent.browse(.issues),
            .open(EntityRef(target: .issues, id: "1", title: "Issue 1")),
            .selectSingle(.issues),
            .compose(.screenC, prompt: "Hi"),
            .perform(.issues, action: "go"),
        ]
    )
    func codableRoundTrip(intent: NavigationIntent) throws {
        let request = NavigationRequest(intent: intent)
        let decoded = try JSONDecoder().decode(NavigationRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded == request)
    }
}

@Suite("NavigationResult")
struct NavigationResultTests {
    @Test("Only .message is an update; everything else ends the handler")
    func finality() {
        #expect(!NavigationResult.message("hi").isFinal)
        #expect(NavigationResult.dismissed.isFinal)
        #expect(NavigationResult.selectedEntity(EntityRef(target: .issues, id: "1", title: "")).isFinal)
    }
}
