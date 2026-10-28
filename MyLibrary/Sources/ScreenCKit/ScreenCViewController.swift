import NavigationCore
import ScreenCNavigationContract
import UIKit

public final class ScreenCViewController: UIViewController {
    private let navigator: any Navigator
    /// Set when opened with `.compose`: shown above a text field whose Send reports back.
    private let prompt: String?

    public init(navigator: any Navigator, prompt: String? = nil) {
        self.navigator = navigator
        self.prompt = prompt
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Screen C"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(infoButtonTapped)
        )

        let heading = UILabel()
        heading.text = "Screen C · UIKit"
        heading.font = .preferredFont(forTextStyle: .headline)

        let pushLocalButton = UIButton(type: .system)
        pushLocalButton.setTitle("Push to Screen C2", for: .normal)
        pushLocalButton.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }
                navigationController?.pushViewController(ScreenC2ViewController(navigator: navigator), animated: true)
            },
            for: .touchUpInside
        )

        let stack = UIStackView(
            arrangedSubviews: [heading] + makeComposeViews() + [pushLocalButton] + makeButtons()
        )
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

    /// Compose mode: the caller's prompt, and a text field whose Send reports the text back as
    /// `Output.textSubmitted` — without leaving, so the user can send again before going back.
    private func makeComposeViews() -> [UIView] {
        guard let prompt else { return [] }

        let promptLabel = UILabel()
        promptLabel.text = prompt
        promptLabel.font = .preferredFont(forTextStyle: .subheadline)
        promptLabel.textColor = .secondaryLabel
        promptLabel.numberOfLines = 0

        let textField = UITextField()
        textField.placeholder = "Message to caller"
        textField.borderStyle = .roundedRect
        textField.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let sendButton = navigationButton("Send") { [navigator, weak textField] in
            navigator.send(.output(NavigationOutput(ScreenCNavigationContract.Output.textSubmitted(textField?.text ?? ""))))
        }

        let row = UIStackView(arrangedSubviews: [textField, sendButton])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center

        return [promptLabel, row]
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
        ]
    }

    @objc
    private func infoButtonTapped() {
        let alert = UIAlertController(title: "Screen C", message: "UIKit view controller.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
