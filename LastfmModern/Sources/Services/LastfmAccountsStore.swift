import Foundation

struct LastfmStoredAccounts: Codable, Equatable {
    var activeUsername: String?
    var sessions: [LastfmSession]
}

protocol LastfmAccountsStoring {
    func save(_ session: LastfmSession)
    func load() -> LastfmSession?
    func clear()
    func allSessions() -> [LastfmSession]
    func setActive(username: String?)
    func remove(username: String)
}

final class LastfmSessionStore: LastfmAccountsStoring {
    private let fileManager: FileManager
    private let storageFileURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LastfmModern", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storageFileURL = dir.appendingPathComponent("accounts.json")
    }

    func save(_ session: LastfmSession) {
        var storage = loadStorage()
        storage.sessions.removeAll { $0.name.caseInsensitiveCompare(session.name) == .orderedSame }
        storage.sessions.append(session)
        storage.sessions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        storage.activeUsername = session.name
        persist(storage)
    }

    func load() -> LastfmSession? {
        let storage = loadStorage()
        guard let activeUsername = storage.activeUsername else {
            return storage.sessions.first
        }
        return storage.sessions.first { $0.name.caseInsensitiveCompare(activeUsername) == .orderedSame }
    }

    func clear() {
        var storage = loadStorage()
        guard let activeUsername = storage.activeUsername else {
            return
        }
        storage.sessions.removeAll { $0.name.caseInsensitiveCompare(activeUsername) == .orderedSame }
        storage.activeUsername = storage.sessions.first?.name
        persist(storage)
    }

    func allSessions() -> [LastfmSession] {
        loadStorage().sessions
    }

    func setActive(username: String?) {
        var storage = loadStorage()
        guard let username else {
            storage.activeUsername = nil
            persist(storage)
            return
        }
        guard storage.sessions.contains(where: { $0.name.caseInsensitiveCompare(username) == .orderedSame }) else {
            return
        }
        storage.activeUsername = username
        persist(storage)
    }

    func remove(username: String) {
        var storage = loadStorage()
        storage.sessions.removeAll { $0.name.caseInsensitiveCompare(username) == .orderedSame }
        if storage.activeUsername?.caseInsensitiveCompare(username) == .orderedSame {
            storage.activeUsername = storage.sessions.first?.name
        }
        persist(storage)
    }

    private func loadStorage() -> LastfmStoredAccounts {
        guard let data = try? Data(contentsOf: storageFileURL),
              let storage = try? JSONDecoder().decode(LastfmStoredAccounts.self, from: data) else {
            return LastfmStoredAccounts(activeUsername: nil, sessions: [])
        }
        return storage
    }

    private func persist(_ storage: LastfmStoredAccounts) {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: storageFileURL, options: .atomic)
    }
}
