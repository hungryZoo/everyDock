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
                    Text("everyDock 시작하기").font(.title.bold())
                    Text("모든 화면의 Dock을 편하게 사용할 준비를 해요.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(24)
            Form {
                Section {
                    permissionHeader("창 제어", symbol: "hand.raised", status: model.permissions.accessibility)
                    Text("앱 창을 선택하고 최소화·복원하려면 손쉬운 사용 권한이 필요합니다. 시스템 설정에서 everyDock을 허용해 주세요.")
                    Button("손쉬운 사용 설정 열기", action: model.requestAccessibility)
                    if let detail = model.permissions.accessibilityDetail {
                        Text("창 제어 결과: \(detail)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    permissionHeader("창 미리보기", symbol: "rectangle.on.rectangle", status: model.permissions.capture)
                    Text("마우스를 올렸을 때 창 이미지를 보려면 화면 녹화 권한이 필요합니다. 이미지는 메모리에만 보관하며 오디오는 녹음하지 않습니다.")
                    Button("화면 녹화 권한 확인", action: model.requestScreenCapture)
                        .disabled(model.permissions.checking)
                    if let detail = model.permissions.detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Toggle("로그인 시 everyDock 자동 실행", isOn: $wantsLogin)
                    Text("‘시작하기’를 누르면 이 선택을 적용합니다. 나중에 설정에서 바꿀 수 있습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    if model.loginNeedsApproval {
                        Text("자동 실행 등록이 시스템 승인을 기다리고 있습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("로그인 항목 승인 설정 열기") { SMAppService.openSystemSettingsLoginItems() }
                    }
                    if let message = model.message {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.formStyle(.grouped)
            Divider()
            HStack {
                Button("나중에 설정", action: complete)
                Spacer()
                Text("권한은 나중에 허용해도 됩니다.").font(.caption).foregroundStyle(.secondary)
                Button("시작하기") {
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
