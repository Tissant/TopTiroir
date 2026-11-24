import Foundation
import Observation
import os

private let notesLog = Logger(subsystem: "local.toptiroir.app", category: "Notes")

/// 메모·할 일을 이 맥의 앱 지원 폴더에 JSON으로 저장한다. 네트워크로는 보내지 않는다.
/// 입력이 멈추고 0.8초 뒤에 한 번만 쓴다(글자마다 쓰지 않음).
@MainActor
@Observable
final class NotesStore {
    private(set) var document = NotesDocument()
    /// 파일을 읽지 못해 옆으로 옮겨 두었을 때 보여 줄 안내
    private(set) var notice: String?

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var dirty = false
    /// 읽지 못한 파일을 옮기지도 못했으면 덮어쓰지 않는다.
    @ObservationIgnored private var saveBlocked = false
    @ObservationIgnored private let saveDelay: Duration = .milliseconds(800)

    init(fileURL: URL = NotesStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    /// ~/Library/Application Support/TopTiroir/notes.json
    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "TopTiroir", directoryHint: .isDirectory).appending(path: "notes.json")
    }

    // MARK: 바꾸기

    func setMemo(_ text: String) {
        guard text != document.memo else { return }
        document.memo = text
        scheduleSave()
    }

    func addTodo(_ text: String) -> Bool {
        guard document.addTodo(text) else { return false }
        scheduleSave()
        return true
    }

    func updateTodo(_ id: UUID, text: String) {
        guard document.updateTodo(id: id, text: text) else { return }
        scheduleSave()
    }

    func toggleTodo(_ id: UUID) {
        document.toggleTodo(id: id)
        scheduleSave()
    }

    func moveTodo(_ id: UUID, toSlot slot: Int) {
        guard document.moveTodo(id: id, toSlot: slot) else { return }
        scheduleSave()
    }

    func removeTodo(_ id: UUID) {
        document.removeTodo(id: id)
        scheduleSave()
    }

    func removeCompleted() {
        guard document.completedCount > 0 else { return }
        document.removeCompleted()
        scheduleSave()
    }

    // MARK: 비우기 (설정 › 관리)

    /// 비우기 직전 상태를 notes.backup.json 한 개로 남기고(덮어씀) 메모를 비운다. 백업에 실패하면 지우지 않는다.
    @discardableResult
    func clearMemo() -> Bool {
        guard backup() else { return false }
        document.memo = ""
        dirty = true
        saveNow()
        return true
    }

    @discardableResult
    func clearTodos() -> Bool {
        guard backup() else { return false }
        document.todos = []
        dirty = true
        saveNow()
        return true
    }

    // MARK: 가져오기 (설정 › 관리)

    /// 백업 파일의 메모·할 일로 바꾼다. 바꾸기 직전 상태를 notes.backup.json에 남기고, 백업에 실패하면 바꾸지 않는다.
    /// 원래 파일을 읽지 못해 저장을 멈춘 상태면 그 파일을 지키려고 바꾸지 않는다.
    @discardableResult
    func replace(with doc: NotesDocument) -> Bool {
        guard !saveBlocked, backup() else { return false }
        document = doc
        dirty = true
        saveNow()
        return true
    }

    var backupFileURL: URL { fileURL.deletingLastPathComponent().appending(path: "notes.backup.json") }

    private func backup() -> Bool {
        do {
            try write(document, to: backupFileURL)
            return true
        } catch {
            notesLog.error("백업 실패: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: 저장

    private func scheduleSave() {
        dirty = true
        saveTask?.cancel()
        saveTask = Task { [weak self, saveDelay] in
            try? await Task.sleep(for: saveDelay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// 미뤄 둔 저장을 바로 한다(서랍 닫기·앱 종료 때).
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard dirty, !saveBlocked else { return }
        do {
            try write(document, to: fileURL)
            dirty = false
        } catch {
            // 내용은 로그에 남기지 않는다(개인 메모).
            notesLog.error("메모 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 폴더·파일 모두 내 계정만 읽고 쓰게 한다.
    private func write(_ doc: NotesDocument, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        try doc.encoded().write(to: url, options: [.atomic])
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return } // 처음 실행: 파일 없음
        if let doc = NotesDocument.decode(data) {
            document = doc
            return
        }
        // 읽을 수 없는 파일은 지우지 않고 이름을 바꿔 옆에 둔다. 새 파일은 빈 상태로 시작.
        let stamp = Int(Date().timeIntervalSince1970)
        let aside = fileURL.deletingLastPathComponent().appending(path: "notes-읽기실패-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: aside)
            notice = String(localized: "예전 메모 파일을 읽지 못해 \(aside.lastPathComponent)로 보관했어요.")
        } catch {
            notice = String(localized: "메모 파일을 읽지 못했어요. 파일을 지키려고 이번에는 저장하지 않아요.")
            saveBlocked = true
        }
    }
}
