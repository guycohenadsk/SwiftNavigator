import UIKit

/// A plain system button that runs `action` when tapped — the cross-module buttons on this
/// module's screens are all built from this.
@MainActor
func navigationButton(_ title: String, action: @escaping @MainActor () -> Void) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle(title, for: .normal)
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
}
