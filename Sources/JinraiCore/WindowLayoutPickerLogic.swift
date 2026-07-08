import Foundation

/// Window Layouts ピッカーの検索・選択状態(純ロジック)。
/// UI(WindowLayoutPicker)はこの状態を描画へ反映するだけにする。
public struct WindowLayoutPickerLogic: Sendable {
    /// ピッカーに表示する1件(Layout から name/description を抜き出したもの)
    public struct Item: Equatable, Sendable {
        public var name: String
        public var description: String?

        public init(name: String, description: String? = nil) {
            self.name = name
            self.description = description
        }
    }

    /// 検索クエリ(name と description への大文字小文字無視の部分一致)
    public private(set) var query: String = ""
    /// filtered 内の選択インデックス(filtered が空のときは無効)
    public private(set) var selectedIndex: Int = 0
    /// 表示窓の先頭インデックス(filtered 基準)
    public private(set) var scrollOffset: Int = 0

    public let maxVisibleRows: Int
    public let items: [Item]

    public init(items: [Item], maxVisibleRows: Int) {
        self.items = items
        self.maxVisibleRows = max(1, maxVisibleRows)
    }

    /// クエリでフィルタした一覧(空クエリなら全件)
    public var filtered: [Item] {
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.name.range(of: query, options: .caseInsensitive) != nil
                || item.description?.range(of: query, options: .caseInsensitive) != nil
        }
    }

    /// 表示窓に入る項目(scrollOffset から最大 maxVisibleRows 件)
    public var visibleItems: [Item] {
        let filtered = filtered
        guard scrollOffset < filtered.count else { return [] }
        return Array(filtered[scrollOffset..<min(scrollOffset + maxVisibleRows, filtered.count)])
    }

    /// 現在選択中の項目(0件なら nil)
    public var selectedItem: Item? {
        let filtered = filtered
        guard filtered.indices.contains(selectedIndex) else { return nil }
        return filtered[selectedIndex]
    }

    public mutating func append(_ character: String) {
        query += character
        resetSelection()
    }

    public mutating func setQuery(_ query: String) {
        self.query = query
        resetSelection()
    }

    public mutating func deleteBackward() {
        guard !query.isEmpty else { return }
        query.removeLast()
        resetSelection()
    }

    public mutating func moveDown() {
        move(by: 1)
    }

    public mutating func moveUp() {
        move(by: -1)
    }

    private mutating func move(by delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
        // 表示窓を選択行に追従させる
        if selectedIndex < scrollOffset {
            scrollOffset = selectedIndex
        } else if selectedIndex >= scrollOffset + maxVisibleRows {
            scrollOffset = selectedIndex - maxVisibleRows + 1
        }
    }

    private mutating func resetSelection() {
        selectedIndex = 0
        scrollOffset = 0
    }
}
