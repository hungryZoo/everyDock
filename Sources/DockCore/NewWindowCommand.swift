import Foundation

/// Shift-click runs the app's own new-window menu command, such as Finder's New Finder Window.
/// Command-N alone is not enough: Calendar creates an event and editors create a file. A candidate
/// needs a window word in its title and a Command-N (preferred) or Shift-Command-N shortcut.
public enum NewWindowCommand {
    /// Menu titles follow the system language. External names are matched, never translated.
    static let windowWords = ["window", "윈도우", "창", "fenster", "fenêtre", "ventana", "finestra", "janela",
                              "venster", "fönster", "vindue", "vindu", "ウインドウ", "ウィンドウ", "窗口", "視窗"]

    /// AX modifier values: 0 is Command only, 1 adds Shift. Lower rank wins; nil is not a candidate.
    public static func rank(title: String, character: String, modifiers: Int?, enabled: Bool) -> Int? {
        guard enabled, character.uppercased() == "N" else { return nil }
        let lowered = title.lowercased()
        guard windowWords.contains(where: lowered.contains) else { return nil }
        switch modifiers ?? 0 {
        case 0: return 0
        case 1: return 1
        default: return nil
        }
    }
}
