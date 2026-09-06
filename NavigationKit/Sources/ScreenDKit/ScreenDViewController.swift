import AppRoutes
import UIKit

public final class ScreenDViewController: UIViewController {
    private let navigator: Navigator

    public init(navigator: Navigator) {
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
            UIAction { [weak self, navigator] _ in
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
        Route.allCases.filter { $0 != .screenD }.map { route in
            let button = UIButton(type: .system)
            button.setTitle("Go to \(route.title)", for: .normal)
            button.addAction(UIAction { [navigator] _ in navigator.push(route) }, for: .touchUpInside)
            return button
        }
    }

    @objc
    private func infoButtonTapped() {
        let alert = UIAlertController(title: "Screen D", message: "UIKit view controller.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
