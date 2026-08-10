import Foundation

struct MealPhotoStore {
    static let shared = MealPhotoStore()

    private let fileManager: FileManager
    private let rootDirectory: URL

    init(fileManager: FileManager = .default, rootDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)
    }

    func save(
        _ data: Data,
        userId: String,
        recordId: String,
        recordVersion: String
    ) throws {
        let userDirectory = directoryURL(userId: userId)
        try fileManager.createDirectory(at: userDirectory, withIntermediateDirectories: true)
        excludeFromBackup(userDirectory)

        let recordPrefix = "\(safeComponent(recordId))--"
        let currentURL = photoURL(
            userId: userId,
            recordId: recordId,
            recordVersion: recordVersion
        )

        if let existingURLs = try? fileManager.contentsOfDirectory(
            at: userDirectory,
            includingPropertiesForKeys: nil
        ) {
            for url in existingURLs where url.lastPathComponent.hasPrefix(recordPrefix) && url != currentURL {
                try? fileManager.removeItem(at: url)
            }
        }

        try data.write(to: currentURL, options: .atomic)
        excludeFromBackup(currentURL)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: currentURL.path
        )
    }

    func data(userId: String, recordId: String, recordVersion: String) -> Data? {
        try? Data(contentsOf: photoURL(
            userId: userId,
            recordId: recordId,
            recordVersion: recordVersion
        ))
    }

    func removeAll(userId: String) throws {
        let userDirectory = directoryURL(userId: userId)
        guard fileManager.fileExists(atPath: userDirectory.path) else { return }
        try fileManager.removeItem(at: userDirectory)
    }

    private func photoURL(userId: String, recordId: String, recordVersion: String) -> URL {
        directoryURL(userId: userId)
            .appendingPathComponent(
                "\(safeComponent(recordId))--\(safeComponent(recordVersion)).jpg",
                isDirectory: false
            )
    }

    private func directoryURL(userId: String) -> URL {
        rootDirectory.appendingPathComponent(safeComponent(userId), isDirectory: true)
    }

    private func safeComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let encoded = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
        return encoded.isEmpty ? "unknown" : encoded
    }

    private func excludeFromBackup(_ url: URL) {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(values)
    }

    private static func defaultRootDirectory(fileManager: FileManager) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return applicationSupport
            .appendingPathComponent("BPHealth", isDirectory: true)
            .appendingPathComponent("MealPhotos", isDirectory: true)
    }
}
