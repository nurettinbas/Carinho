import SwiftUI
import UIKit

@MainActor
enum KeyboardDismiss {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

@MainActor
enum KeyboardVisibility {
    nonisolated(unsafe) private(set) static var isVisible = false
    nonisolated(unsafe) private static var didStartObserving = false

    nonisolated static func startObservingIfNeeded() {
        guard !didStartObserving else { return }
        didStartObserving = true

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            isVisible = true
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            isVisible = false
        }
    }
}

extension View {
    /// Adds a done button above keyboards that lack a return key (decimal/number pad).
    func keyboardDoneToolbar(label: String = "Tamam") -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(label) {
                    KeyboardDismiss.dismiss()
                }
            }
        }
    }

    func dismissKeyboardOnScroll() -> some View {
        scrollDismissesKeyboard(.interactively)
    }

    /// Dismisses the keyboard when tapping outside text inputs while it is visible.
    func dismissKeyboardOnTap() -> some View {
        dismissKeyboardOnTap(clearFocus: nil)
    }

    func dismissKeyboardOnTap(focus: FocusState<Bool>.Binding) -> some View {
        dismissKeyboardOnTap {
            focus.wrappedValue = false
        }
    }

    func dismissKeyboardOnTap<F: Hashable>(focus: FocusState<F?>.Binding) -> some View {
        dismissKeyboardOnTap {
            focus.wrappedValue = nil
        }
    }

    private func dismissKeyboardOnTap(clearFocus: (() -> Void)?) -> some View {
        background(DismissKeyboardOnTapInstaller(clearFocus: clearFocus))
    }
}

private struct DismissKeyboardOnTapInstaller: UIViewRepresentable {
    let clearFocus: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(clearFocus: clearFocus)
    }

    func makeUIView(context: Context) -> DismissKeyboardTapUIView {
        KeyboardVisibility.startObservingIfNeeded()
        let view = DismissKeyboardTapUIView()
        view.coordinator = context.coordinator
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: DismissKeyboardTapUIView, context: Context) {
        context.coordinator.clearFocus = clearFocus
        uiView.coordinator = context.coordinator
    }

    static func dismantleUIView(_ uiView: DismissKeyboardTapUIView, coordinator: Coordinator) {
        uiView.uninstall()
    }

    @MainActor
    final class Coordinator: NSObject {
        var clearFocus: (() -> Void)?

        init(clearFocus: (() -> Void)?) {
            self.clearFocus = clearFocus
        }

        func dismissIfNeeded() {
            guard KeyboardVisibility.isVisible else { return }
            clearFocus?()
            KeyboardDismiss.dismiss()
        }
    }
}

private final class DismissKeyboardTapUIView: UIView, UIGestureRecognizerDelegate {
    weak var coordinator: DismissKeyboardOnTapInstaller.Coordinator?
    private weak var hostView: UIView?
    private var tapRecognizer: UITapGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, tapRecognizer == nil else { return }
        installRecognizerIfNeeded()
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil {
            uninstall()
        }
        super.willMove(toWindow: newWindow)
    }

    private func installRecognizerIfNeeded() {
        guard tapRecognizer == nil else { return }
        guard let host = enclosingControllerView ?? superview ?? window else { return }
        install(on: host)
    }

    private var enclosingControllerView: UIView? {
        var current: UIView? = self
        while let view = current {
            if let controller = view.next as? UIViewController {
                return controller.view
            }
            current = view.superview
        }
        return nil
    }

    private func install(on view: UIView) {
        guard tapRecognizer == nil else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
        tapRecognizer = tap
        hostView = view
    }

    func uninstall() {
        if let tapRecognizer, let hostView {
            hostView.removeGestureRecognizer(tapRecognizer)
        }
        tapRecognizer = nil
        hostView = nil
    }

    @objc private func handleTap() {
        Task { @MainActor in
            coordinator?.dismissIfNeeded()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !isTextInput(touch.view)
    }

    private func isTextInput(_ view: UIView?) -> Bool {
        var current = view
        while let candidate = current {
            if candidate is UITextField || candidate is UITextView {
                return true
            }
            let typeName = String(describing: type(of: candidate))
            if typeName.contains("TextField") || typeName.contains("TextEditor") {
                return true
            }
            current = candidate.superview
        }
        return false
    }
}
