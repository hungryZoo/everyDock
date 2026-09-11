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
                    Text("Your Dock. On every display.").foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.displays.count == 1 ? "1 display" : "\(model.displays.count) displays")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.quaternary, in: Capsule())
            }
            .padding(24)
            Divider()
            Form {
                Section("Appearance") {
                    Toggle("Follow macOS Dock Size and Magnification", isOn: $model.preferences.followNativeSize)
                    if model.preferences.followNativeSize {
                        LabeledContent("Effective Size", value: "\(Int(model.iconSize)) pt → \(Int(model.iconSize * model.magnification)) pt")
                    }
                    Picker("Position", selection: $model.preferences.edge) {
                        ForEach(DockEdge.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    LabeledContent("Icon Size") {
                        Slider(value: $model.preferences.iconSize, in: 32...72, step: 4)
                        Text("\(Int(model.preferences.iconSize)) pt").monospacedDigit().frame(width: 45)
                    }.disabled(model.preferences.followNativeSize)
                    LabeledContent("Distance from Screen Edge") {
                        Slider(value: $model.preferences.inset, in: 0...40, step: 2)
                        Text("\(Int(model.preferences.inset)) pt").monospacedDigit().frame(width: 45)
                    }.disabled(model.preferences.followNativeSize)
                    Toggle("Show Running Apps", isOn: $model.preferences.showRunningApps)
                    LabeledContent("Magnification") {
                        Slider(value: $model.preferences.magnification, in: 1...4, step: 0.05)
                        Text(String(format: "%.2f×", model.preferences.magnification)).monospacedDigit().frame(width: 45)
                    }.disabled(model.preferences.followNativeSize)
                    Toggle("Show over Full-Screen Apps", isOn: $model.preferences.showOnFullScreen)
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
                } header: { Text("Displays") }
                  footer: { Text("New displays get a Dock automatically. If you disable every display, use the menu bar or reopen everyDock to enable them again.") }

                Section {
                    ForEach(model.apps.filter(\.isPinned)) { app in
                        HStack {
                            if app.isSeparator {
                                Image(systemName: "line.3.horizontal.decrease").frame(width: 26, height: 26)
                                Text("Separator").foregroundStyle(.secondary)
                                Divider().frame(maxWidth: 80)
                            } else {
                                Image(nsImage: app.icon).resizable().frame(width: 26, height: 26)
                                Text(app.name)
                            }
                            Spacer()
                            Button { model.movePin(app, offset: -1) } label: { Image(systemName: "chevron.up") }
                                .help("Move Earlier").disabled(model.apps.first?.id == app.id)
                            Button { model.movePin(app, offset: 1) } label: { Image(systemName: "chevron.down") }
                                .help("Move Later").disabled(model.apps.last(where: \.isPinned)?.id == app.id)
                            Button { model.togglePin(app) } label: { Image(systemName: "minus.circle") }
                                .help(app.isSeparator ? "Remove Separator" : "Unpin")
                        }.buttonStyle(.borderless)
                    }
                    HStack {
                        Button("Add Apps…", systemImage: "plus", action: model.chooseApps)
                        Button("Add Separator", systemImage: "plus") { model.addSeparator() }
                        Spacer()
                        Button("Import from macOS Dock", action: model.importNativeDock)
                    }
                } header: { Text("Pinned Apps") }
                  footer: { Text("Reorder or remove pinned apps and separators here, or ⌘-drag them in the Dock. Drag a running app into the pinned section to pin it, or a pinned app into the running section to unpin it. Right-click an icon or a gap between pinned apps to add a separator.") }

                Section("General") {
                    Button("Open Setup Guide…") { model.showOnboarding?() }
                    Toggle("Hide Menu Bar Icon", isOn: $model.preferences.hideMenuBarIcon)
                    Text("To open Settings, find everyDock in Apps and launch it. Settings opens even if everyDock is already running.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Click Active App to Minimize", isOn: $model.preferences.clickToMinimize)
                    LabeledContent("Minimize and Restore") {
                        Text(model.permissions.accessibility.title)
                        Button("System Settings…", action: model.requestAccessibility)
                    }
                    Text("Uses the window’s yellow minimize button for the macOS animation. If access is missing, everyDock asks you to allow it. The animation follows the macOS Dock’s minimize effect setting.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Show Window Previews on Hover", isOn: $model.preferences.showPreviews)
                    LabeledContent("Preview Delay") {
                        Slider(value: $model.preferences.previewDelay, in: 0.2...1.5, step: 0.05)
                        Text(String(format: "%.2f s", model.preferences.previewDelay)).monospacedDigit()
                    }
                    LabeledContent("Preview Images") {
                        Text(model.permissions.capture.title)
                        Button("Allow Screen Recording…", action: model.requestScreenCapture)
                    }
                    Text("Previews stay in memory and are never saved or sent anywhere. Select a preview to switch to that window.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(model.permissions.checking ? "Checking…" : "Check Permission Status", action: model.recheckPermissions)
                            .disabled(model.permissions.checking)
                        Button("Show App Location", action: model.revealCurrentApp)
                    }
                    if let detail = model.permissions.detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    if let detail = model.permissions.accessibilityDetail {
                        Text("Window control: \(detail)").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("If macOS denies access even with permission enabled, quit everyDock, remove its old entry in System Settings, and add the app shown by Show App Location. Then launch it again. Updating an ad-hoc signed build can invalidate an earlier approval.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Launch everyDock at Login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLoginEnabled($0) }))
                    if model.loginNeedsApproval {
                        Button("Approve Login Item in System Settings…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                    Toggle("Hide All Docks", isOn: $model.paused)
                    Toggle("Hide macOS Dock While everyDock Is Running", isOn: $model.preferences.manageNativeDock)
                    Text("Saves your macOS Dock settings and enables auto-hide. Quitting, hiding all Docks, or a crash restores those settings. The macOS Dock restarts when this changes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development") · Apple Silicon · macOS 26+").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(minWidth: 540, idealWidth: 580, minHeight: 620, idealHeight: 760)
        .onAppear { model.refreshLoginStatus() }
        .alert("everyDock", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}
