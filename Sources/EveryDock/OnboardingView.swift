import DockCore
import AppKit
import SwiftUI
import ServiceManagement

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var wantsLogin: Bool
    let complete: () -> Void

    init(model: AppModel, firstLaunch: Bool, complete: @escaping () -> Void) {
        self.model = model
        _wantsLogin = State(initialValue: firstLaunch || model.loginEnabled)
        self.complete = complete
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("Welcome to everyDock")).font(.title.bold())
                    Text(L10n.text("Set up your Dock for every display."))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(24)
            Form {
                Section {
                    permissionHeader(L10n.text("Window Control"), symbol: "hand.raised", status: model.permissions.accessibility)
                    Text(L10n.text("Allow Accessibility access in System Settings to select, minimize, and restore app windows."))
                    Button(L10n.text("Allow Accessibility…"), action: model.requestAccessibility)
                    Button(L10n.text("Open Accessibility Settings"), action: model.openAccessibilitySettings)
                        .buttonStyle(.link)
                    if let detail = model.permissions.accessibilityDetail {
                        Text(L10n.text("Window control: \(detail)")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    permissionHeader(L10n.text("Window Previews"), symbol: "rectangle.on.rectangle", status: model.permissions.capture)
                    Text(L10n.text("Screen Recording permission enables window previews on hover. Images stay in memory; audio is never recorded."))
                    Button(L10n.text("Allow Screen Recording"), action: model.requestScreenCapture)
                        .disabled(model.permissions.checking)
                    Button(L10n.text("Screen Recording Settings…"), action: model.openScreenCaptureSettings)
                        .buttonStyle(.link)
                    if let detail = model.permissions.detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Toggle(L10n.text("Launch everyDock at Login"), isOn: $wantsLogin)
                    Text(L10n.text("Choose Get Started to apply this option. You can change it later in Settings."))
                        .font(.caption).foregroundStyle(.secondary)
                    if model.loginNeedsApproval {
                        Text(L10n.text("The login item is waiting for approval in System Settings."))
                            .font(.caption).foregroundStyle(.secondary)
                        Button(L10n.text("Open Login Item Settings")) { SMAppService.openSystemSettingsLoginItems() }
                    }
                    if let message = model.message {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.formStyle(.grouped)
            Divider()
            HStack {
                Button(L10n.text("Set Up Later"), action: complete)
                Spacer()
                Text(L10n.text("You can grant permissions later.")).font(.caption).foregroundStyle(.secondary)
                Button(L10n.text("Get Started")) {
                    if wantsLogin != model.loginEnabled {
                        model.setLoginEnabled(wantsLogin)
                        guard model.loginEnabled == wantsLogin else { return }
                    }
                    guard !wantsLogin || !model.loginNeedsApproval else { return }
                    complete()
                }.keyboardShortcut(.defaultAction)
            }.padding(20)
        }.frame(minWidth: 540, minHeight: 520)
    }

    private func permissionHeader(_ title: String, symbol: String, status: AppPermissions.Status) -> some View {
        HStack {
            Label(title, systemImage: symbol).font(.headline)
            Spacer()
            Label(status.title, systemImage: status == .allowed ? "checkmark.circle.fill" : "circle")
                .font(.caption).foregroundStyle(status == .allowed ? Color.green : Color.secondary)
        }
    }
}
