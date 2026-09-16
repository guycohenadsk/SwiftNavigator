import AppRoutes
import UIKit

public final class ScreenD2ViewController: UIViewController {
    private let navigator: Navigator

    public init(navigator: Navigator) {
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Screen D2"
        view.backgroundColor = .systemBackground

        let heading = UILabel()
        heading.text = "Screen D2 · pushed locally from Screen D"
        heading.font = .preferredFont(forTextStyle: .headline)
        heading.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [heading] + makeButtons())
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    private func makeButtons() -> [UIButton] {
        Route.allCases.filter { $0 != .screenD }.map { route in
            let button = UIButton(type: .system)
            button.setTitle("Go to \(route.title)", for: .normal)
            button.addAction(UIAction { [navigator] _ in navigator.push(route) }, for: .touchUpInside)
            return button
        }
    }
}
