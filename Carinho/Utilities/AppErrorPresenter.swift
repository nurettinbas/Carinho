import Foundation
import SwiftUI

@MainActor
@Observable
final class AppErrorPresenter {
    static let shared = AppErrorPresenter()

    var message: String?
    var isPresented = false

    func present(_ message: String) {
        self.message = message
        isPresented = true
    }

    func dismiss() {
        isPresented = false
        message = nil
    }
}

struct AppErrorAlertModifier: ViewModifier {
    @Bindable private var presenter = AppErrorPresenter.shared

    func body(content: Content) -> some View {
        content.alert("Hata", isPresented: $presenter.isPresented) {
            Button("Tamam", role: .cancel) { presenter.dismiss() }
        } message: {
            Text(presenter.message ?? "")
        }
    }
}

extension View {
    func appErrorAlert() -> some View {
        modifier(AppErrorAlertModifier())
    }
}
