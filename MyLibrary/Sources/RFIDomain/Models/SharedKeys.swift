import ComposableArchitecture
import Foundation
import IdentifiedCollections

extension SharedReaderKey
where Self == FileStorageKey<IdentifiedArrayOf<RFIItem>>.Default {
    /// Every RFI in the app, persisted to `Documents/rfis.json`, with the seed as the default so
    /// first launch has data without any seeding code.
    public static var rfis: Self {
        Self[
            .fileStorage(.documentsDirectory.appending(component: "rfis.json")),
            default: RFIItem.seed
        ]
    }
}
