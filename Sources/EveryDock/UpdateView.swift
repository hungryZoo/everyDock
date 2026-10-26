import AppKit
import DockCore
import SwiftUI

struct UpdateView: View {
    let info: UpdateInfo
    let onSkip: () -> Void
    let onLater: () -> Void
    let onInstall: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("A new version of everyDock is available")).font(.title3.bold())
                Text(L10n.text("New version \(info.newVersion) (current \(info.currentVersion))")).foregroundStyle(.secondary)
                Text(L10n.text("Release Notes")).font(.headline)
                ScrollView {
                    Text(releaseNotes)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 220)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                Text(installDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link(L10n.text("View Release Page"), destination: info.releaseURL).font(.callout)
                HStack {
                    Button(L10n.text("Skip This Version"), action: onSkip)
                    Spacer()
                    Button(L10n.text("Later"), action: onLater).keyboardShortcut(.cancelAction)
                    Button(L10n.text("Yes"), action: onInstall).keyboardShortcut(.defaultAction)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    /// SwiftUI Text renders inline Markdown only; block syntax is simplified first.
    private var releaseNotes: AttributedString {
        let text = ReleaseNotesFormatter.inlineMarkdown(info.releaseNotes)
        guard !text.isEmpty else { return AttributedString(L10n.text("No release notes.")) }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private var installDescription: String {
        switch info.installMethod {
        case .homebrew:
            L10n.text("Yes quits everyDock, restores the macOS Dock, and runs brew update and brew upgrade --cask \(InstallMethod.caskFullName) in Terminal. Your settings are kept, and the new version opens when Homebrew finishes.")
        case .manual:
            L10n.text("Yes opens the release page in your browser. Download the ZIP, quit everyDock, and replace everyDock.app in Applications.")
        }
    }
}
