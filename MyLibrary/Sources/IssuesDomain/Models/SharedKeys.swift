import ComposableArchitecture
import Foundation
import IdentifiedCollections

extension SharedReaderKey
where Self == FileStorageKey<IdentifiedArrayOf<Issue>>.Default {
    /// Every issue in the app, persisted to `Documents/issues.json`.
    ///
    /// The seed is the key's *default*, so first launch has data without any seeding code: the
    /// file doesn't exist, the default is read, and the first mutation writes it to disk.
    public static var issues: Self {
        Self[
            .fileStorage(.documentsDirectory.appending(component: "issues.json")),
            default: Issue.seed
        ]
    }
}
