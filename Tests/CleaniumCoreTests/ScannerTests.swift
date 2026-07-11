import XCTest
@testable import CleaniumCore

final class ScannerTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cleanium-scan-\(UUID().uuidString)")
        // Fixture tree:
        // root/projA/node_modules/dep/big.bin   (2 KB)   -> candidate (rule nm)
        // root/projA/src/main.js                (10 B)   -> plain file
        // root/unknownBig/blob.bin              (4 KB)   -> unknown dir
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("projA/node_modules/dep"),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("projA/src"),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("unknownBig"),
                               withIntermediateDirectories: true)
        try Data(count: 2048).write(to: root.appendingPathComponent("projA/node_modules/dep/big.bin"))
        try Data(count: 10).write(to: root.appendingPathComponent("projA/src/main.js"))
        try Data(count: 4096).write(to: root.appendingPathComponent("unknownBig/blob.bin"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func makeScanner(minSize: Int64 = 0, llmMin: Int64 = 1024) -> CleaniumCore.Scanner {
        let nm = Rule(id: "nm", pattern: "node_modules", category: .devArtifact,
                      risk: .rebuildable, context: "c", restoreNote: "r")
        return CleaniumCore.Scanner(engine: RuleEngine(bundled: [nm], learned: []),
                                    minSizeBytes: minSize, llmMinSizeBytes: llmMin)
    }

    func testFindsCandidateAndDoesNotDescendIntoIt() {
        let result = makeScanner().scan(roots: [root.path], progress: nil, isCancelled: { false })
        XCTAssertEqual(result.candidates.count, 1)
        let c = result.candidates[0]
        XCTAssertTrue(c.path.hasSuffix("node_modules"))
        XCTAssertGreaterThanOrEqual(c.sizeBytes, 2048)
    }

    func testMinSizeFloorFiltersCandidates() {
        let result = makeScanner(minSize: 10_000).scan(roots: [root.path],
                                                       progress: nil, isCancelled: { false })
        XCTAssertEqual(result.candidates.count, 0)
    }

    func testUnknownBigDirSurfaced() {
        let result = makeScanner().scan(roots: [root.path], progress: nil, isCancelled: { false })
        XCTAssertEqual(result.unknownDirs.map { ($0.path as NSString).lastPathComponent },
                       ["unknownBig"])
        XCTAssertGreaterThanOrEqual(result.unknownDirs[0].sizeBytes, 4096)
    }

    func testProjWithCandidateNotInUnknownDirs() {
        let result = makeScanner().scan(roots: [root.path], progress: nil, isCancelled: { false })
        XCTAssertFalse(result.unknownDirs.contains { $0.path.hasSuffix("projA") })
    }

    func testCancellationStopsEarly() {
        let result = makeScanner().scan(roots: [root.path], progress: nil, isCancelled: { true })
        XCTAssertEqual(result.candidates.count, 0)
    }

    func testMissingRootGoesToSkipped() {
        let result = makeScanner().scan(roots: ["/nonexistent-cleanium-root"],
                                        progress: nil, isCancelled: { false })
        XCTAssertEqual(result.skipped, ["/nonexistent-cleanium-root"])
    }
}
