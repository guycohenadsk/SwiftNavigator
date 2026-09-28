import AppRoutes
import ComposableArchitecture
import Foundation
import NavigatorDependency

@Reducer
public struct IssuesDetail {
    /// The fields below the title, in the order they render. Production reads this order from
    /// `GGIssueTypeModel.fieldsMetadata` per issue type; here it is fixed in code.
    public enum Field: String, CaseIterable, Equatable, Sendable {
        case status
        case type
        case issueDescription
        case assignee
        case location
        case locationDetails
        case dueDate
        case startDate
        case rootCause

        public var label: String {
            switch self {
            case .status: "Status"
            case .type: "Type"
            case .issueDescription: "Description"
            case .assignee: "Assigned to"
            case .location: "Location"
            case .locationDetails: "Location details"
            case .dueDate: "Due date"
            case .startDate: "Start date"
            case .rootCause: "Root cause"
            }
        }

        /// Status and type always render inline — they can never fall into the empty section.
        var isGroupable: Bool {
            switch self {
            case .status, .type: false
            default: true
            }
        }
    }

    @ObservableState
    public struct State: Equatable {
        /// Points into the persisted array. Every edit here is an edit to the stored issue.
        @Shared public var issue: Issue
        public var isEmptyFieldsExpanded = false
        public var expandedDateField: Field?
        public var isDescriptionExpanded = false
        public var isLocationDetailsExpanded = false
        public var isTitleFocused = false
        @Presents public var alert: AlertState<Action.Alert>?

        public init(issue: Shared<Issue>) {
            self._issue = issue
        }

        public func isEmpty(_ field: Field) -> Bool {
            switch field {
            case .status, .type: false
            case .issueDescription: issue.issueDescription.isEmpty
            case .assignee: issue.assigneeName == nil
            case .location: issue.location == nil
            case .locationDetails: issue.locationDetails?.isEmpty ?? true
            case .dueDate: issue.dueDate == nil
            case .startDate: issue.startDate == nil
            case .rootCause: issue.rootCause == nil
            }
        }

        public var emptyFields: [Field] {
            Field.allCases.filter { $0.isGroupable && isEmpty($0) }
        }

        /// Draft issues show everything inline; otherwise the empty fields collapse, but only
        /// once there are enough of them to be worth collapsing.
        public var isGroupingEmptyFields: Bool {
            issue.status != .draft && emptyFields.count > Self.minimumEmptyFieldsForGrouping
        }

        public var inlineFields: [Field] {
            guard isGroupingEmptyFields else { return Field.allCases }
            return Field.allCases.filter { !$0.isGroupable || !isEmpty($0) }
        }

        public var isTitleOverLimit: Bool {
            issue.title.count > issue.maxTitleLength
        }

        static let minimumEmptyFieldsForGrouping = 2
    }

    public enum Action {
        case navigateButtonTapped(Route)
        case titleChanged(String)
        case titleFocusChanged(Bool)
        case statusSelected(IssueStatus)
        case typeCodeSelected(String?)
        case assigneeSelected(String?)
        case locationSelected(String?)
        case rootCauseSelected(String?)
        case descriptionChanged(String)
        case locationDetailsChanged(String)
        case dueDateChanged(Date?)
        case startDateChanged(Date?)
        case dateFieldTapped(Field)
        case descriptionExpandToggled
        case locationDetailsExpandToggled
        case emptyFieldsToggled
        case deleteButtonTapped
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        @CasePathable
        public enum Alert: Equatable {
            case confirmDelete
        }

        @CasePathable
        public enum Delegate: Equatable {
            /// The detail screen only holds one issue — removing it from the array is the list's job.
            case deleteRequested
        }
    }

    @Dependency(\.navigator) var navigator

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .navigateButtonTapped(route):
                let navigator = navigator
                return .run { _ in await navigator.push(route) }

            case let .titleChanged(title):
                state.$issue.withLock { $0.title = title }
                return .none

            case let .titleFocusChanged(isFocused):
                state.isTitleFocused = isFocused
                return .none

            case let .statusSelected(status):
                state.$issue.withLock { $0.status = status }
                return .none

            case let .typeCodeSelected(code):
                state.$issue.withLock { $0.typeCode = code }
                return .none

            case let .assigneeSelected(name):
                state.$issue.withLock { $0.assigneeName = name }
                return .none

            case let .locationSelected(location):
                state.$issue.withLock { $0.location = location }
                return .none

            case let .rootCauseSelected(cause):
                state.$issue.withLock { $0.rootCause = cause }
                return .none

            case let .descriptionChanged(text):
                state.$issue.withLock { $0.issueDescription = text }
                return .none

            case let .locationDetailsChanged(text):
                state.$issue.withLock { $0.locationDetails = text.isEmpty ? nil : text }
                return .none

            case let .dueDateChanged(date):
                state.$issue.withLock { $0.dueDate = date }
                return .none

            case let .startDateChanged(date):
                state.$issue.withLock { $0.startDate = date }
                return .none

            case let .dateFieldTapped(field):
                state.expandedDateField = state.expandedDateField == field ? nil : field
                return .none

            case .descriptionExpandToggled:
                state.isDescriptionExpanded.toggle()
                return .none

            case .locationDetailsExpandToggled:
                state.isLocationDetailsExpanded.toggle()
                return .none

            case .emptyFieldsToggled:
                state.isEmptyFieldsExpanded.toggle()
                return .none

            case .deleteButtonTapped:
                state.alert = AlertState {
                    TextState("Delete issue?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) { TextState("Delete") }
                    ButtonState(role: .cancel) { TextState("Cancel") }
                } message: {
                    TextState("This removes the issue from shared storage. It cannot be undone.")
                }
                return .none

            case .alert(.presented(.confirmDelete)):
                return .send(.delegate(.deleteRequested))

            case .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
