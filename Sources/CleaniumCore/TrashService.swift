import Foundation

public struct DeletionOutcome: Equatable, Sendable {
    public var path: String
    public var success: Bool
    public var error: String?
}

public final class TrashService {
    private let fm: FileManager

    public init(fileManager: FileManager = .default) {
        self.fm = fileManager
    }

    public func trash(paths: [String]) -> [DeletionOutcome] {
        paths.map { path in
            do {
                try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                return DeletionOutcome(path: path, success: true, error: nil)
            } catch {
                return DeletionOutcome(path: path, success: false,
                                       error: error.localizedDescription)
            }
        }
    }

    public func permanentlyDelete(paths: [String]) -> [DeletionOutcome] {
        paths.map { path in
            do {
                try fm.removeItem(atPath: path)
                return DeletionOutcome(path: path, success: true, error: nil)
            } catch {
                return DeletionOutcome(path: path, success: false,
                                       error: error.localizedDescription)
            }
        }
    }
}
