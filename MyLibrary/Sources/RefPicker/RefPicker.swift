import ComposableArchitecture
import NavigationCore
import NavigatorDependency

/// A list of references, with "Add Reference". Shared by any feature, and knows only NavigationCore:
/// every reference carries the request that opens it, built by the module that owns it, and the
/// modules it can pick from are the pickers their registrations offer (`navigationPickers`).
/// Adding pushes the pick request of the one picker — or of the one the user chooses, when there
/// are several — and appends what comes back.
@Reducer
public struct RefPicker {
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
    @Dependency(\.navigationPickers) var pickers

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .referenceTapped(item):
                let navigator = navigator
                return .run { _ in await navigator.push(item.open) }

            case .addReferenceTapped:
                switch pickers.count {
                case 0:
                    return .none
                case 1:
                    return pick(pickers[0])
                default:
                    state.chooser = ConfirmationDialogState(title: { TextState("Add Reference") }) {
                        for picker in pickers {
                            ButtonState(action: .source(picker.target)) { TextState(picker.title) }
                        }
                    }
                    return .none
                }

            case let .chooser(.presented(.source(target))):
                guard let picker = pickers.first(where: { $0.target == target }) else { return .none }
                return pick(picker)

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

    private func pick(_ picker: NavigationPicker) -> Effect<Action> {
        let navigator = navigator
        return .run { send in
            let result = await navigator.pushForResult(picker.request)
            if case let .selectedEntity(entity) = result {
                await send(.referenceAdded(entity))
            }
        }
    }
}
