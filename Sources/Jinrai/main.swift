import AppKit

// --check-config: 設定を読み込んで結果だけ表示して終了(CI・動作確認用)
if CommandLine.arguments.contains("--check-config") {
    do {
        let config = try ConfigLoader.load()
        var enabled: [String] = []
        if config.focusBorder != nil { enabled.append("focusBorder") }
        if config.focusBack != nil { enabled.append("focusBack") }
        if config.windowHints != nil { enabled.append("windowHints") }
        if config.windowMover != nil { enabled.append("windowMover") }
        if config.applicationHints != nil { enabled.append("applicationHints") }
        print("OK: \(ConfigLoader.configFileURL.path)")
        print("enabled: \(enabled.joined(separator: ", "))")
        if let mover = config.windowMover {
            print("windowMover hotkeys: \(mover.commandHotkeys.count) commands")
        }
        exit(0)
    } catch {
        print("NG: \(error)")
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
