import ComposableArchitecture
import Foundation
import RefPicker

@Reducer
public struct RFIDetail {
    @ObservableState
    public struct State: Equatable {
        /// Points into the persisted array. Every edit here is an edit to the stored RFI.
        @Shared public var rfi: RFIItem
        public var isDueDateExpanded = false
        @Presents public var alert: AlertState<Action.Alert>?
        /// Related entities, kept for this visit only (not persisted).
        public var references = RefPicker.State()

        public init(rfi: Shared<RFIItem>) {
            self._rfi = rfi
        }
    }

    public enum Action {
        case subjectChanged(String)
        case statusSelected(RFIStatus)
        case assigneeSelected(String?)
        case questionChanged(String)
        case dueDateChanged(Date?)
        case dueDateTapped
        case deleteButtonTapped
        case alert(PresentationAction<Alert>)
        case references(RefPicker.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Alert: Equatable {
            case confirmDelete
        }

        @CasePathable
        public enum Delegate: Equatable {
            /// The detail only holds one RFI: removing it from storage is its host's job.
            case deleteRequested
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.references, action: \.references) {
            RefPicker()
        }
        Reduce { state, action in
            switch action {
            case let .subjectChanged(subject):
                state.$rfi.withLock { $0.subject = subject }
                return .none

            case let .statusSelected(status):
                state.$rfi.withLock { $0.status = status }
                return .none

            case let .assigneeSelected(name):
                state.$rfi.withLock { $0.assigneeName = name }
                return .none

            case let .questionChanged(text):
                state.$rfi.withLock { $0.question = text }
                return .none

            case let .dueDateChanged(date):
                state.$rfi.withLock { $0.dueDate = date }
                return .none

            case .dueDateTapped:
                state.isDueDateExpanded.toggle()
                return .none

            case .deleteButtonTapped:
                state.alert = AlertState {
                    TextState("Delete RFI?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) { TextState("Delete") }
                    ButtonState(role: .cancel) { TextState("Cancel") }
                } message: {
                    TextState("This removes the RFI from shared storage. It cannot be undone.")
                }
                return .none

            case .alert(.presented(.confirmDelete)):
                return .send(.delegate(.deleteRequested))

            case .alert, .delegate, .references:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
