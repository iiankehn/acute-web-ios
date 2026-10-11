import SwiftUI
import UIKit

struct PrivateBrowsingShield: UIViewRepresentable {
    let isEnabled: Bool

    final class WindowObserver: UIView {
        var windowChanged: (() -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            windowChanged?()
        }
    }

    @MainActor
    final class Coordinator {
        private var cover: UIView?
        var isEnabled = false

        func update(window: UIWindow?) {
            guard isEnabled, let window else {
                cover?.removeFromSuperview()
                cover = nil
                return
            }
            let view: UIView
            if let cover { view = cover }
            else {
                view = UIView()
                view.backgroundColor = .systemBackground
                view.accessibilityIdentifier = "privateBrowsingCover"
                let image = UIImageView(image: UIImage(systemName: "hand.raised.fill"))
                image.tintColor = .label
                image.contentMode = .scaleAspectFit
                image.heightAnchor.constraint(equalToConstant: 40).isActive = true
                let title = UILabel()
                title.text = "Private Browsing"
                title.font = .preferredFont(forTextStyle: .headline)
                title.adjustsFontForContentSizeCategory = true
                title.textAlignment = .center
                let brand = UILabel()
                brand.text = "Acute Web"
                brand.font = .preferredFont(forTextStyle: .subheadline)
                brand.textColor = .secondaryLabel
                brand.textAlignment = .center
                let stack = UIStackView(arrangedSubviews: [image, title, brand])
                stack.axis = .vertical
                stack.spacing = 14
                stack.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(stack)
                NSLayoutConstraint.activate([
                    stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
                ])
                cover = view
            }
            view.frame = window.bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            if view.superview !== window { window.addSubview(view) }
            window.bringSubviewToFront(view)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WindowObserver {
        let observer = WindowObserver()
        observer.isUserInteractionEnabled = false
        observer.windowChanged = { [weak observer, weak coordinator = context.coordinator] in
            coordinator?.update(window: observer?.window)
        }
        return observer
    }

    func updateUIView(_ observer: WindowObserver, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.update(window: observer.window)
    }

    static func dismantleUIView(_ observer: WindowObserver, coordinator: Coordinator) {
        coordinator.isEnabled = false
        coordinator.update(window: nil)
    }
}
