import NavigationCore
import UIKit

public final class ScreenDViewController: UIViewController {
    private let navigator: any Navigator

    public init(navigator: any Navigator) {
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Screen D"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(infoButtonTapped)
        )

        let heading = UILabel()
        heading.text = "Screen D · UIKit"
        heading.font = .preferredFont(forTextStyle: .headline)

        let pushLocalButton = UIButton(type: .system)
        pushLocalButton.setTitle("Push to Screen D2", for: .normal)
        pushLocalButton.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }
                navigationController?.pushViewController(ScreenD2ViewController(navigator: navigator), animated: true)
            },
            for: .touchUpInside
        )

        let stack = UIStackView(arrangedSubviews: [heading, pushLocalButton] + makeButtons())
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
            navigationButton("Pick an issue, then open it") { [navigator] in
                navigator.present(NavigationRequest(intent: .selectSingle(.issues))) { result in
                    guard case let .selectedEntity(issue) = result else { return }
                    navigator.push(NavigationRequest(intent: .open(issue)))
                }
            },
            navigationButton("Open Screen B · sheet") { [navigator] in
                navigator.present(NavigationRequest(intent: .browse(.screenB)))
            },
            navigationButton("Close") { [navigator] in
                // Closes the top screen — this one — whether it was pushed or presented.
                navigator.complete(with: .dismissed)
            },
        ]
    }

    @objc
    private func infoButtonTapped() {
        let alert = UIAlertController(title: "Screen D", message: "UIKit view controller.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
