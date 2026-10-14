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

extension SharedReaderKey where Self == InMemoryKey<String?>.Default {
    /// The last text Screen C sent back to the issues list. Shared rather than per-store, so the
    /// header shows it whichever path started the flow — the Context chip or a deep link.
    public static var screenCText: Self {
        Self[.inMemory("issues.screenCText"), default: nil]
    }
}
