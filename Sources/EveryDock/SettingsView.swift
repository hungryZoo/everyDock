import AppKit
import DockCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "dock.rectangle")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 17))
                VStack(alignment: .leading, spacing: 4) {
                    Text("everyDock").font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("모든 화면에, 언제나 나의 Dock.").foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(model.displays.count)개 디스플레이")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.quaternary, in: Capsule())
            }
            .padding(24)
            Divider()
            Form {
                Section("Dock 모양") {
                    Toggle("기본 Dock의 크기·확대 설정 따르기", isOn: $model.preferences.followNativeSize)
                    if model.preferences.followNativeSize {
                        LabeledContent("현재 적용 크기", value: "\(Int(model.iconSize)) pt → \(Int(model.iconSize * model.magnification)) pt")
                    }
                    Picker("위치", selection: $model.preferences.edge) {
                        ForEach(DockEdge.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    LabeledContent("아이콘 크기") {
                        Slider(value: $model.preferences.iconSize, in: 32...72, step: 4)
                        Text("\(Int(model.preferences.iconSize)) pt").monospacedDigit().frame(width: 45)
                    }.disabled(model.preferences.followNativeSize)
                    LabeledContent("화면 가장자리 간격") {
                        Slider(value: $model.preferences.inset, in: 0...40, step: 2)
                        Text("\(Int(model.preferences.inset)) pt").monospacedDigit().frame(width: 45)
                    }.disabled(model.preferences.followNativeSize)
                    Toggle("실행 중인 앱도 표시", isOn: $model.preferences.showRunningApps)
                    LabeledContent("포인터 확대") {
                        Slider(value: $model.preferences.magnification, in: 1...4, step: 0.05)
                        Text(String(format: "%.2f×", model.preferences.magnification)).monospacedDigit().frame(width: 45)
                    }.disabled(model.preferences.followNativeSize)
                    Toggle("전체 화면 앱 위에도 표시", isOn: $model.preferences.showOnFullScreen)
                }

                Section {
                    ForEach(model.displays) { display in
                        Toggle(isOn: Binding(
                            get: { !model.preferences.hiddenDisplayIDs.contains(display.id) },
                            set: { enabled in
                                if enabled { model.preferences.hiddenDisplayIDs.remove(display.id) }
                                else { model.preferences.hiddenDisplayIDs.insert(display.id) }
                            }
                        )) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(display.name)
                                    Text(display.size).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: { Image(systemName: "display") }
                        }
                        .accessibilityLabel("\(display.name), \(display.size)")
                    }
                } header: { Text("표시할 디스플레이") }
                  footer: { Text("새 모니터를 연결하면 자동으로 Dock이 나타납니다. 화면을 모두 꺼도 메뉴 막대에서 다시 켤 수 있습니다.") }

                Section {
                    ForEach(model.apps.filter(\.isPinned)) { app in
                        HStack {
                            if app.isSeparator {
                                Image(systemName: "line.3.horizontal.decrease").frame(width: 26, height: 26)
                                Text("구분선").foregroundStyle(.secondary)
                                Divider().frame(maxWidth: 80)
                            } else {
                                Image(nsImage: app.icon).resizable().frame(width: 26, height: 26)
                                Text(app.name)
                            }
                            Spacer()
                            Button { model.movePin(app, offset: -1) } label: { Image(systemName: "chevron.up") }
                                .help("앞으로 이동").disabled(model.apps.first?.id == app.id)
                            Button { model.movePin(app, offset: 1) } label: { Image(systemName: "chevron.down") }
                                .help("뒤로 이동").disabled(model.apps.last(where: \.isPinned)?.id == app.id)
                            Button { model.togglePin(app) } label: { Image(systemName: "minus.circle") }
                                .help(app.isSeparator ? "구분선 삭제" : "고정 해제")
                        }.buttonStyle(.borderless)
                    }
                    HStack {
                        Button("앱 추가…", systemImage: "plus", action: model.chooseApps)
                        Button("구분선 추가", systemImage: "plus") { model.addSeparator() }
                        Spacer()
                        Button("기본 Dock에서 가져오기", action: model.importNativeDock)
                    }
                } header: { Text("고정 앱") }
                  footer: { Text("고정 앱과 구분선을 같은 목록에서 이동·삭제할 수 있습니다. Dock에서 ⌘ 키를 누른 채 드래그하면 순서가 바뀝니다. 실행 앱을 고정 영역으로 끌어오면 그 위치에 고정됩니다. 고정 앱 사이 또는 아이콘을 우클릭해 구분선을 추가하세요.") }

                Section("일반") {
                    Toggle("활성 앱을 다시 클릭하면 최소화", isOn: $model.preferences.clickToMinimize)
                    LabeledContent("창 최소화·복원") {
                        Text(model.permissions.accessibility.title)
                        Button("시스템 설정…", action: model.requestAccessibility)
                    }
                    Text("창의 노란 최소화 버튼을 통해 macOS 애니메이션을 실행합니다. 권한이 없을 때는 창을 숨기는 대신 권한을 안내합니다. 요술램프 효과는 시스템 Dock의 ‘윈도우 최소화 효과’ 설정을 따릅니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("마우스를 올리면 창 미리보기", isOn: $model.preferences.showPreviews)
                    LabeledContent("미리보기 대기 시간") {
                        Slider(value: $model.preferences.previewDelay, in: 0.2...1.5, step: 0.05)
                        Text(String(format: "%.2f초", model.preferences.previewDelay)).monospacedDigit()
                    }
                    LabeledContent("미리보기 이미지") {
                        Text(model.permissions.capture.title)
                        Button("접근 확인…", action: model.requestScreenCapture)
                    }
                    Text("미리보기는 메모리에서만 처리하며 파일로 저장하거나 전송하지 않습니다. 미리보기 창을 클릭하면 해당 창으로 전환합니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(model.permissions.checking ? "확인 중…" : "권한 다시 확인", action: model.recheckPermissions)
                            .disabled(model.permissions.checking)
                        Button("현재 앱 위치 보기", action: model.revealCurrentApp)
                    }
                    if let detail = model.permissions.detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    if let detail = model.permissions.accessibilityDetail {
                        Text("창 제어 결과: \(detail)").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("권한 스위치가 켜져 있는데 macOS가 접근을 거부하면 everyDock을 종료하고 시스템 설정에서 기존 항목을 제거한 뒤, ‘현재 앱 위치 보기’의 앱을 다시 등록하고 실행해 주세요. 임시 서명 빌드를 교체하면 기존 허용이 유지되지 않을 수 있습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("로그인 시 everyDock 실행", isOn: Binding(get: { model.loginEnabled }, set: { model.setLoginEnabled($0) }))
                    if model.loginNeedsApproval {
                        Button("시스템 설정에서 로그인 항목 승인…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                    Toggle("모든 Dock 일시 숨기기", isOn: $model.paused)
                    Toggle("everyDock 사용 중 기본 Dock 숨기기", isOn: $model.preferences.manageNativeDock)
                    Text("원래 Dock 설정을 저장하고 자동 숨김을 적용합니다. everyDock 종료·일시 숨기기·비정상 종료 시 원래 설정을 복원합니다. 변경 시 기본 Dock이 한 번 재시작됩니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "개발") · Apple Silicon · macOS 26+").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("종료") { NSApp.terminate(nil) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(minWidth: 540, idealWidth: 580, minHeight: 620, idealHeight: 760)
        .onAppear { model.refreshLoginStatus() }
        .alert("everyDock", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("확인", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}
