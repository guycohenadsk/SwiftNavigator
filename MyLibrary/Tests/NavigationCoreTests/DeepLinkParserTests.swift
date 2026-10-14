import Foundation
import NavigationCore
import Testing

@Suite("DeepLinkParser")
struct DeepLinkParserTests {
    @Test("A bare target browses that module")
    func browse() throws {
        let request = try DeepLinkParser.parse(#require(URL(string: "demoapp://screenB")))
        #expect(request.intent == .browse(.screenB))
    }

    @Test("A target with an id opens that entity")
    func open() throws {
        let request = try DeepLinkParser.parse(#require(URL(string: "demoapp://issues/issue-1")))
        #expect(request.intent == .open(EntityRef(target: .issues, id: "issue-1", title: "")))
    }

    @Test("An action query asks the module to perform it")
    func action() throws {
        let request = try DeepLinkParser.parse(#require(URL(string: "demoapp://issues?action=screenCContext")))
        #expect(request.intent == .perform(.issues, action: "screenCContext"))
    }

    @Test("An empty action query is ignored")
    func emptyAction() throws {
        let request = try DeepLinkParser.parse(#require(URL(string: "demoapp://issues?action=")))
        #expect(request.intent == .browse(.issues))
    }

    @Test("Another scheme is rejected")
    func wrongScheme() throws {
        #expect(throws: DeepLinkError.unsupportedScheme) {
            try DeepLinkParser.parse(#require(URL(string: "https://issues/issue-1")))
        }
    }

    @Test("An unknown target is rejected")
    func unknownTarget() throws {
        #expect(throws: DeepLinkError.unknownTarget) {
            try DeepLinkParser.parse(#require(URL(string: "demoapp://nope")))
        }
    }
}
