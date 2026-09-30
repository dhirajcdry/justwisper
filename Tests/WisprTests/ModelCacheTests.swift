import XCTest
@testable import Wispr

final class ModelCacheTests: XCTestCase {
    private let components = ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc"]

    func testFindsExactCompleteFolder() throws {
        let root = try makeRoot()
        let folder = root.appendingPathComponent("openai_whisper-small.en")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for component in components { try FileManager.default.createDirectory(at: folder.appendingPathComponent(component), withIntermediateDirectories: false) }
        XCTAssertEqual(ModelCache.cachedFolder(for: "small.en", in: root)?.path, folder.path)
    }

    func testMissingComponentReturnsNil() throws {
        let root = try makeRoot()
        let folder = root.appendingPathComponent("openai_whisper-small")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for component in components.dropLast() { try FileManager.default.createDirectory(at: folder.appendingPathComponent(component), withIntermediateDirectories: false) }
        XCTAssertNil(ModelCache.cachedFolder(for: "small", in: root))
    }

    func testFindsWhisperKitRepositoryCache() throws {
        let root = try makeRoot()
        let folder = root.appendingPathComponent("models/argmaxinc/whisperkit-coreml/openai_whisper-base.en")
        try populate(folder)
        XCTAssertEqual(ModelCache.cachedFolder(for: "base.en", in: root)?.standardizedFileURL,
                       folder.standardizedFileURL)
    }

    func testWrongVariantAndPackageDescendantDoNotMatch() throws {
        let root = try makeRoot()
        try populate(root.appendingPathComponent("openai_whisper-small.en-extra"))
        try populate(root.appendingPathComponent("unrelated.mlmodelc/openai_whisper-small.en"))
        XCTAssertNil(ModelCache.cachedFolder(for: "small.en", in: root))
    }

    func testComponentFileIsNotMistakenForCompiledDirectory() throws {
        let root = try makeRoot()
        let folder = root.appendingPathComponent("openai_whisper-base.en")
        try populate(folder)
        let component = folder.appendingPathComponent(components[0])
        try FileManager.default.removeItem(at: component)
        try Data().write(to: component)
        XCTAssertNil(ModelCache.cachedFolder(for: "base.en", in: root))
    }

    private func populate(_ folder: URL) throws {
        for component in components {
            try FileManager.default.createDirectory(at: folder.appendingPathComponent(component),
                                                    withIntermediateDirectories: true)
        }
    }

    private func makeRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
