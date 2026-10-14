import NavigationCore
import UIKit

public final class ScreenD2ViewController: UIViewController {
    private let navigator: any Navigator

    public init(navigator: any Navigator) {
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
        [
            navigationButton("Open Issues") { [navigator] in
                navigator.push(NavigationRequest(intent: .browse(.issues)))
            },
            navigationButton("Open Screen B") { [navigator] in
                navigator.push(NavigationRequest(intent: .browse(.screenB)))
            },
        ]
    }
}
