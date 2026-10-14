import ComposableArchitecture
import NavigationCore
import NavigatorDependency

/// A list of references to entities of one target, with "Add Reference". Shared by any feature —
/// it knows only NavigationCore: tapping a reference opens it, and adding one pushes that target's
/// picker (`.selectSingle`) and appends whatever comes back.
@Reducer
public struct RefPicker {
    @ObservableState
    public struct State: Equatable {
        public let target: NavigationTarget
        public var references: [ReferenceItem]

        public init(target: NavigationTarget, references: [ReferenceItem] = []) {
            self.target = target
            self.references = references
        }
    }

    public enum Action {
        case referenceTapped(ReferenceItem)
        case addReferenceTapped
        case referenceAdded(EntityRef)
    }

    @Dependency(\.navigator) var navigator

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .referenceTapped(item):
                let navigator = navigator
                let ref = EntityRef(target: item.target, id: item.id, title: item.title)
                return .run { _ in await navigator.push(NavigationRequest(intent: .open(ref))) }

            case .addReferenceTapped:
                let navigator = navigator
                let target = state.target
                return .run { send in
                    let result = await navigator.pushForResult(NavigationRequest(intent: .selectSingle(target)))
                    if case let .selectedEntity(entity) = result {
                        await send(.referenceAdded(entity))
                    }
                }

            case let .referenceAdded(entity):
                let item = ReferenceItem(id: entity.id, target: entity.target, title: entity.title)
                guard !state.references.contains(item) else { return .none }
                state.references.append(item)
                return .none
            }
        }
    }
}
