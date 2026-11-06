import AppKit
import Foundation

struct MemoryFile: Equatable {
    let url: URL
    let relPath: String
    let categoryID: String
    let categoryName: String
    let title: String
    let preview: String
    let modified: Date
    let size: Int64
    let ext: String

    var id: String { relPath }
    var icon: String { Theme.symbol(for: ext) }
    var tint: NSColor { Theme.color(for: ext) }

    var kindName: String {
        switch ext.lowercased() {
        case "md", "markdown", "mdown": return "Markdown"
        case "txt", "text": return "文本"
        case "rtf": return "富文本"
        case "pdf": return "PDF"
        case "doc", "docx": return "Word"
        case "pages": return "Pages"
        case "json": return "JSON"
        case "yaml", "yml": return "YAML"
        case "csv": return "CSV"
        case "xls", "xlsx": return "表格"
        case "numbers": return "Numbers"
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "图片"
        default: return ext.isEmpty ? "文件" : ext.uppercased()
        }
    }
}

struct MemoryGroup: Equatable {
    let id: String
    let name: String
    let url: URL
    var files: [MemoryFile]
}

@MainActor
final class MemoryStore {
    static let shared = MemoryStore()

    private let fm = FileManager.default
    private let defaults = UserDefaults.standard
    private let workspaceKey = "MemoryDock.workspacePath"

    private(set) var workspaceURL: URL
    private(set) var groups: [MemoryGroup] = []
    private(set) var lastRefreshed = Date()
    private var monitorTimer: Timer?
    private var fingerprint = ""

    var onChange: (() -> Void)?
    var onWorkspaceChange: (() -> Void)?

    var allFiles: [MemoryFile] {
        groups.flatMap(\.files)
    }

    var totalCount: Int { allFiles.count }

    var workspaceDisplayPath: String {
        (workspaceURL.path as NSString).abbreviatingWithTildeInPath
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: workspaceKey),
           FileManager.default.fileExists(atPath: saved) {
            workspaceURL = URL(fileURLWithPath: saved)
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory())
            workspaceURL = docs.appendingPathComponent("记忆坞", isDirectory: true)
        }
    }

    func bootstrap() {
        createWorkspaceIfNeeded(at: workspaceURL)
        seedStarterContentIfEmpty()
        refresh(force: true)
        startWatching()
    }

    // MARK: - Workspace

    func setWorkspace(_ url: URL) {
        let normalized = url.standardizedFileURL
        guard normalized.path != workspaceURL.path else { return }
        workspaceURL = normalized
        defaults.set(normalized.path, forKey: workspaceKey)
        createWorkspaceIfNeeded(at: normalized)
        seedStarterContentIfEmpty()
        refresh(force: true)
        onWorkspaceChange?()
    }

    @discardableResult
    func createWorkspaceIfNeeded(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue
        }
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            NSLog("MemoryDock: cannot create workspace: \(error)")
            return false
        }
    }

    private func seedStarterContentIfEmpty() {
        guard createWorkspaceIfNeeded(at: workspaceURL) else { return }
        let visible = (try? fm.contentsOfDirectory(at: workspaceURL, includingPropertiesForKeys: [.isHiddenKey], options: [.skipsHiddenFiles])) ?? []
        if !visible.isEmpty { return }

        let seeds: [(String, String, String)] = [
            ("01_身份", "身份底稿.md", """
            # 身份底稿

            - 称呼：YG
            - 常用语言：简体中文
            - 时区：Asia/Shanghai
            - 回答偏好：直接、具体、先给结论，再给步骤。

            > 这是一张示例记忆卡。双击打开编辑，或拖到任意 AI 对话框作为上下文附件。
            """),
            ("02_偏好", "沟通与输出偏好.md", """
            # 沟通与输出偏好

            - 默认用简体中文回答。
            - 少寒暄，先执行，再说明结果。
            - 代码、命令、日志保留原文。
            - 长任务先列计划，再逐步完成。
            """),
            ("03_项目", "项目上下文.md", """
            # 项目上下文

            - 项目名称：［填写项目名］
            - 当前目标：［一句话描述］
            - 技术栈：［例如 Swift / Python / TypeScript］
            - 关键约束：［截止时间、风格、环境限制］
            - 相关目录：［本地路径］
            """),
            ("04_写作", "写作风格.md", """
            # 写作风格

            - 语气：专业、克制、有判断。
            - 段落短，信息密度高。
            - 避免套话和空泛总结。
            - 重点内容优先用列表或表格呈现。
            """),
            ("05_模板", "记忆卡模板.md", """
            # 记忆卡模板

            ## 适用场景
            ［这张记忆卡在什么任务中使用］

            ## 背景
            ［必要背景，不写无关信息］

            ## 规则
            1. ［规则一］
            2. ［规则二］

            ## 示例
            ［输入 → 期望输出］
            """),
        ]

        for (folder, filename, content) in seeds {
            let dir = workspaceURL.appendingPathComponent(folder, isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent(filename)
            try? content.write(to: file, atomically: true, encoding: .utf8)
        }
    }

    func revealWorkspace() {
        NSWorkspace.shared.open(workspaceURL)
    }

    // MARK: - Refresh

    func refresh(force: Bool = false) {
        guard createWorkspaceIfNeeded(at: workspaceURL) else { return }
        let newFingerprint = computeFingerprint()
        if !force && newFingerprint == fingerprint {
            return
        }
        fingerprint = newFingerprint

        var newGroups: [MemoryGroup] = []
        let dirs = categoryDirectories()
        for dir in dirs {
            let name = dir.lastPathComponent
            let files = files(in: dir, categoryID: name, categoryName: name)
            newGroups.append(MemoryGroup(id: name, name: name, url: dir, files: files))
        }
        newGroups.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let rootFiles = files(in: workspaceURL, categoryID: "__root__", categoryName: "未分类")
        if !rootFiles.isEmpty {
            newGroups.append(MemoryGroup(id: "__root__", name: "未分类", url: workspaceURL, files: rootFiles))
        }

        groups = newGroups
        lastRefreshed = Date()
        onChange?()
    }

    private func categoryDirectories() -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isHiddenKey]
        let items = (try? fm.contentsOfDirectory(
            at: workspaceURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return items.filter { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return false }
            return values.isDirectory == true && values.isPackage != true && !url.lastPathComponent.hasPrefix(".")
        }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private func files(in directory: URL, categoryID: String, categoryName: String) -> [MemoryFile] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey, .contentModificationDateKey, .fileSizeKey]
        let items = (try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return items.compactMap { url -> MemoryFile? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            guard values.isRegularFile == true, values.isHidden != true else { return nil }
            let name = url.lastPathComponent
            guard !name.hasPrefix("."), name != "Icon\r" else { return nil }
            let modified = values.contentModificationDate ?? Date.distantPast
            let ext = url.pathExtension.lowercased()
            let parsed = Self.parseText(url: url, ext: ext)
            return MemoryFile(
                url: url,
                relPath: relativePath(for: url),
                categoryID: categoryID,
                categoryName: categoryName,
                title: parsed.title.isEmpty ? url.deletingPathExtension().lastPathComponent : parsed.title,
                preview: parsed.preview,
                modified: modified,
                size: Int64(values.fileSize ?? 0),
                ext: ext
            )
        }.sorted { $0.modified > $1.modified }
    }

    private func relativePath(for url: URL) -> String {
        let base = workspaceURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path.hasPrefix(base + "/") {
            return String(path.dropFirst(base.count + 1))
        }
        return url.lastPathComponent
    }

    private func computeFingerprint() -> String {
        var entries: [String] = []
        let direct = (try? fm.contentsOfDirectory(
            at: workspaceURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for item in direct {
            let name = item.lastPathComponent
            guard !name.hasPrefix(".") else { continue }
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
            if values?.isDirectory == true {
                entries.append("D:\(name):\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)")
                let children = (try? fm.contentsOfDirectory(
                    at: item,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
                for child in children where !child.lastPathComponent.hasPrefix(".") {
                    let cv = try? child.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey])
                    if cv?.isDirectory == true { continue }
                    entries.append("F:\(name)/\(child.lastPathComponent):\(cv?.contentModificationDate?.timeIntervalSince1970 ?? 0):\(cv?.fileSize ?? 0)")
                }
            } else {
                entries.append("F:\(name):\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0):\(values?.fileSize ?? 0)")
            }
        }
        return entries.sorted().joined(separator: "|")
    }

    private func startWatching() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        if let monitorTimer {
            RunLoop.main.add(monitorTimer, forMode: .common)
        }
    }

    // MARK: - File content

    private static func parseText(url: URL, ext: String) -> (title: String, preview: String) {
        let textual: Set<String> = ["md", "markdown", "mdown", "txt", "text", "json", "yaml", "yml", "csv", "xml", "plist", "rtf", "log"]
        guard textual.contains(ext) else {
            let label: String
            switch ext {
            case "pdf": label = "PDF 文档"
            case "doc", "docx": label = "Word 文档"
            case "pages": label = "Pages 文档"
            case "xls", "xlsx": label = "Excel 表格"
            case "numbers": label = "Numbers 表格"
            case "png", "jpg", "jpeg", "gif", "webp", "heic": label = "图片文件"
            case "": label = "文件"
            default: label = "\(ext.uppercased()) 文件"
            }
            return ("", "\(label) · 拖到 AI 即可作为附件")
        }

        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return ("", "无法读取内容")
        }
        let prefix = data.prefix(64 * 1024)
        guard var raw = String(data: prefix, encoding: .utf8) else {
            return ("", "二进制内容")
        }
        raw = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var lines = raw.components(separatedBy: "\n")

        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            if let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
                lines = Array(lines.dropFirst(end + 1))
            }
        }

        var title = ""
        var headingIndex: Int?
        for (i, line) in lines.prefix(16).enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            if t.hasPrefix("#") {
                title = t.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                headingIndex = i
                break
            }
        }

        let bodyLines = lines.dropFirst(headingIndex.map { $0 + 1 } ?? 0)
        let body = bodyLines.joined(separator: " ")
            .replacingOccurrences(of: "```.*?```", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[#>*_`\\[\\]()~-]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = String(body.prefix(180))
        return (title.trimmingCharacters(in: .whitespaces), preview.isEmpty ? "空白记忆卡" : preview)
    }

    func fullText(for file: MemoryFile) -> String? {
        let textual: Set<String> = ["md", "markdown", "mdown", "txt", "text", "json", "yaml", "yml", "csv", "xml", "plist", "log"]
        guard textual.contains(file.ext) else { return nil }
        return try? String(contentsOf: file.url, encoding: .utf8)
    }

    func copyToPasteboard(_ file: MemoryFile) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let text = fullText(for: file) {
            return pb.setString(text, forType: .string)
        }
        return pb.writeObjects([file.url as NSURL])
    }

    // MARK: - Mutations

    @discardableResult
    func createMemory(title: String, content: String, categoryID: String?) -> MemoryFile? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }
        let folder: URL
        if let categoryID, categoryID != "__root__" {
            folder = workspaceURL.appendingPathComponent(categoryID, isDirectory: true)
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        } else {
            folder = workspaceURL
        }

        var safe = cleanTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
        if safe.count > 60 { safe = String(safe.prefix(60)) }
        if safe.isEmpty { safe = "未命名记忆" }

        var url = folder.appendingPathComponent("\(safe).md")
        var n = 2
        while fm.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(safe) \(n).md")
            n += 1
        }

        let body: String
        if content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#") {
            body = content
        } else {
            body = "# \(cleanTitle)\n\n\(content)"
        }
        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
            refresh(force: true)
            return allFiles.first { $0.url.standardizedFileURL == url.standardizedFileURL }
        } catch {
            NSLog("MemoryDock: create memory failed: \(error)")
            return nil
        }
    }

    func delete(_ file: MemoryFile, completion: ((Bool) -> Void)? = nil) {
        NSWorkspace.shared.recycle([file.url]) { _, error in
            DispatchQueue.main.async {
                if error == nil {
                    Task { @MainActor in self.refresh(force: true) }
                    completion?(true)
                } else {
                    NSLog("MemoryDock: delete failed: \(error!)")
                    completion?(false)
                }
            }
        }
    }

    var categoryNames: [String] {
        groups.filter { $0.id != "__root__" }.map(\.name)
    }
}
