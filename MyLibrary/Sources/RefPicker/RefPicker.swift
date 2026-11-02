import ComposableArchitecture
import IssuesNavigationContract
import NavigationCore
import NavigatorDependency
import RFINavigationContract

/// A list of references, with "Add Reference". Shared by any feature, and hosts implement and pass
/// nothing: every reference carries the request that opens it, built by the module that owns it,
/// and the picker knows which modules it can pick from (`sources`, from their contracts). Adding
/// pushes the pick request of the one source — or of the one the user chooses, when there are
/// several — and appends what comes back.
@Reducer
public struct RefPicker {
    /// A module whose entities can be added as references.
    struct Source: Hashable, Sendable {
        let target: NavigationTarget
        let title: String
        /// Answered with `.selectedEntity`.
        let pick: NavigationRequest
    }

    /// Every module the picker can pick from. Supporting a new one means importing its contract and
    /// listing its pick route here.
    static let sources = [
        Source(target: .issues, title: "Issue", pick: NavigationRequest(IssuesNavigationContract.Route.pick)),
        Source(target: .rfi, title: "RFI", pick: NavigationRequest(RFINavigationContract.Route.pick)),
    ]

    @ObservableState
    public struct State: Equatable {
        public var references: [ReferenceItem]
        /// Asks which module to pick from, when there is more than one.
        @Presents var chooser: ConfirmationDialogState<Action.Chooser>?

        public init(references: [ReferenceItem] = []) {
            self.references = references
        }
    }

    public enum Action {
        case referenceTapped(ReferenceItem)
        case addReferenceTapped
        case chooser(PresentationAction<Chooser>)
        case referenceAdded(EntityRef)

        @CasePathable
        public enum Chooser: Equatable {
            case source(NavigationTarget)
        }
    }

    @Dependency(\.navigator) var navigator
    private let sources: [Source]

    public init() {
        self.init(sources: Self.sources)
    }

    init(sources: [Source]) {
        self.sources = sources
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .referenceTapped(item):
                let navigator = navigator
                return .run { _ in await navigator.push(item.open) }

            case .addReferenceTapped:
                switch sources.count {
                case 0:
                    return .none
                case 1:
                    return pick(sources[0])
                default:
                    state.chooser = ConfirmationDialogState(title: { TextState("Add Reference") }) {
                        for source in sources {
                            ButtonState(action: .source(source.target)) { TextState(source.title) }
                        }
                    }
                    return .none
                }

            case let .chooser(.presented(.source(target))):
                guard let source = sources.first(where: { $0.target == target }) else { return .none }
                return pick(source)

            case .chooser:
                return .none

            case let .referenceAdded(entity):
                let item = ReferenceItem(entity)
                guard !state.references.contains(item) else { return .none }
                state.references.append(item)
                return .none
            }
        }
        .ifLet(\.$chooser, action: \.chooser)
    }

    private func pick(_ source: Source) -> Effect<Action> {
        let navigator = navigator
        return .run { send in
            let result = await navigator.pushForResult(source.pick)
            if case let .selectedEntity(entity) = result {
                await send(.referenceAdded(entity))
            }
        }
    }
}
