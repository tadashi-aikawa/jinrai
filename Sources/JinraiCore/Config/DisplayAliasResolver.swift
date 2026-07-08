import Foundation

enum DisplayAliasResolver {
    private static let uuidPattern =
        #"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"#

    static func aliases(from root: [String: Any]) throws -> [String: String] {
        guard let raw = root["displayAliases"] else { return [:] }
        guard let rawAliases = raw as? [String: Any] else {
            throw ConfigError("[jinrai.displayAliases] オブジェクトである必要があります")
        }

        var aliases: [String: String] = [:]
        for (name, value) in rawAliases {
            guard !name.isEmpty else {
                throw ConfigError("[jinrai.displayAliases] 別名は空にできません")
            }
            guard !isUUID(name) else {
                throw ConfigError("[jinrai.displayAliases] 別名 '\(name)' はUUID形式にできません")
            }
            guard let uuid = value as? String, isUUID(uuid) else {
                throw ConfigError(
                    "[jinrai.displayAliases] '\(name)' にはディスプレイUUID文字列が必要です")
            }
            aliases[name] = uuid.uppercased()
        }
        return aliases
    }

    static func resolveProfileDisplays(
        in root: [String: Any], aliases: [String: String]
    ) throws -> [String: Any] {
        guard let rawProfiles = root["profiles"] as? [Any] else { return root }
        var resolved = root
        resolved["profiles"] = try rawProfiles.enumerated().map { index, rawProfile in
            guard var profile = rawProfile as? [String: Any],
                let displays = profile["displays"] as? [String]
            else {
                return rawProfile
            }
            profile["displays"] = try displays.map {
                try resolve($0, aliases: aliases, context: "profiles[\(index)].displays")
            }
            return profile
        }
        return resolved
    }

    static func resolveDisplayReferences(
        in root: [String: Any], aliases: [String: String]
    ) throws -> [String: Any] {
        var resolved = root
        resolved.removeValue(forKey: "displayAliases")
        try resolveAreaHints(in: &resolved, aliases: aliases)
        try resolveWindowLayouts(in: &resolved, aliases: aliases)
        return resolved
    }

    private static func resolveAreaHints(
        in root: inout [String: Any], aliases: [String: String]
    ) throws {
        guard var areaHints = root["areaHints"] as? [String: Any],
            let rawScreens = areaHints["screens"] as? [String: Any]
        else { return }

        var screens: [String: Any] = [:]
        for (display, mapping) in rawScreens {
            let uuid = try resolve(display, aliases: aliases, context: "areaHints.screens")
            if screens[uuid] != nil {
                throw ConfigError(
                    "[jinrai.areaHints] screens に同じディスプレイUUID '\(uuid)' の設定が複数あります")
            }
            screens[uuid] = mapping
        }
        areaHints["screens"] = screens
        root["areaHints"] = areaHints
    }

    private static func resolveWindowLayouts(
        in root: inout [String: Any], aliases: [String: String]
    ) throws {
        guard var windowLayouts = root["windowLayouts"] as? [String: Any],
            let rawLayouts = windowLayouts["layouts"] as? [String: Any]
        else { return }

        var layouts = rawLayouts
        for (layoutName, rawLayout) in rawLayouts {
            guard var layout = rawLayout as? [String: Any] else { continue }

            if let rawWindows = layout["windows"] as? [[String: Any]] {
                var windows: [[String: Any]] = []
                for (index, rawWindow) in rawWindows.enumerated() {
                    var window = rawWindow
                    if let screen = window["screen"] as? String {
                        window["screen"] = try resolve(
                            screen, aliases: aliases,
                            context: "windowLayouts.layouts['\(layoutName)'].windows[\(index)].screen")
                    }
                    windows.append(window)
                }
                layout["windows"] = windows
            }

            if var unlisted = layout["unlistedWindows"] as? [String: Any],
                let screen = unlisted["screen"] as? String
            {
                unlisted["screen"] = try resolve(
                    screen, aliases: aliases,
                    context: "windowLayouts.layouts['\(layoutName)'].unlistedWindows.screen")
                layout["unlistedWindows"] = unlisted
            }

            layouts[layoutName] = layout
        }
        windowLayouts["layouts"] = layouts
        root["windowLayouts"] = windowLayouts
    }

    private static func resolve(
        _ value: String, aliases: [String: String], context: String
    ) throws -> String {
        if let uuid = aliases[value] {
            return uuid
        }
        guard isUUID(value) else {
            throw ConfigError(
                "[jinrai.\(context)] 未定義のディスプレイ別名 '\(value)' です。displayAliases に定義するかUUIDを指定してください")
        }
        return value.uppercased()
    }

    private static func isUUID(_ value: String) -> Bool {
        value.range(of: uuidPattern, options: .regularExpression) != nil
    }
}
