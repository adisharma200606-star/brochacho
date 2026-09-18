import Foundation
import XCTest
@testable import BrochachoCore

/// The timer and the living bookmarks must reproduce fixtures/extras.json.
final class ExtrasTests: XCTestCase {

    private struct DurationFixture: Decodable {
        let text: String
        let seconds: Int?
    }

    private struct FormatFixture: Decodable {
        let ms: Int
        let text: String
    }

    private struct BookmarkFixture: Decodable {
        let url: String
        let result: String
        let names: [String]
    }

    private struct FileFixture: Decodable {
        let durations: [DurationFixture]
        let formats: [FormatFixture]
        let catalog: [CatalogEntry]
        let bookmarks: [BookmarkFixture]
    }

    func testDurationsAgreeWithTheReference() throws {
        let file = try Fixtures.load(FileFixture.self, "extras.json")
        XCTAssertGreaterThanOrEqual(file.durations.count, 35)
        for d in file.durations {
            XCTAssertEqual(DurationParser.parse(d.text), d.seconds, "\"\(d.text)\"")
        }
    }

    func testCountdown() throws {
        let file = try Fixtures.load(FileFixture.self, "extras.json")
        for f in file.formats {
            XCTAssertEqual(CountdownTimer.format(remainingMs: f.ms), f.text, "\(f.ms) ms")
        }
        let timer = CountdownTimer(seconds: 600, nowMs: 1_000)
        XCTAssertEqual(timer.status(nowMs: 1_000), TimerStatus(remainingMs: 600_000, fraction: 1, done: false, text: "10:00"))
        XCTAssertEqual(timer.status(nowMs: 301_000), TimerStatus(remainingMs: 300_000, fraction: 0.5, done: false, text: "5:00"))
        XCTAssertEqual(timer.status(nowMs: 601_000), TimerStatus(remainingMs: 0, fraction: 0, done: true, text: "0:00"))
        XCTAssertTrue(timer.status(nowMs: 999_999).done)
    }

    func testBookmarksAgreeWithTheReference() throws {
        let file = try Fixtures.load(FileFixture.self, "extras.json")
        for b in file.bookmarks {
            let names: [String]
            let result: String
            switch LivingBookmarks.find(for: b.url, in: file.catalog) {
            case .update(let entry):
                result = "update"
                names = [entry.name]
            case .ambiguous(let entries):
                result = "ambiguous"
                names = entries.map { $0.name }
            case .noMatch:
                result = "none"
                names = []
            }
            XCTAssertEqual(result, b.result, b.url)
            XCTAssertEqual(names, b.names, b.url)
        }
    }

    func testMovingAnEntryKeepsEverythingElse() throws {
        let file = try Fixtures.load(FileFixture.self, "extras.json")
        let moved = LivingBookmarks.move("bat", to: "https://reader.example/manga/absolute-batman/chapter-14", in: file.catalog)
        let bat = try XCTUnwrap(moved.first { $0.name == "bat" })
        XCTAssertEqual(bat.target, "https://reader.example/manga/absolute-batman/chapter-14")
        XCTAssertTrue(bat.living)
        XCTAssertEqual(moved.first { $0.name == "berserk" }, file.catalog.first { $0.name == "berserk" })
    }

    func testURLParts() {
        XCTAssertEqual(LivingBookmarks.parts(of: "https://www.Example.com:8080/a/b/?q=1#frag"),
                       LivingBookmarks.URLParts(host: "example.com:8080", segments: ["a", "b"]))
        XCTAssertEqual(LivingBookmarks.parts(of: "https://user:pw@example.com/x"),
                       LivingBookmarks.URLParts(host: "example.com", segments: ["x"]))
        XCTAssertEqual(LivingBookmarks.parts(of: "example.com"), LivingBookmarks.URLParts(host: "example.com", segments: []))
    }

    func testLivingFlagIsOnlyWrittenWhenOn() throws {
        let plain = CatalogEntry(name: "youtube", kind: .site, target: "https://www.youtube.com")
        let living = CatalogEntry(name: "bat", kind: .site, target: "https://reader.example/x", living: true)
        let plainJSON = String(decoding: try JSONFile.encoder().encode(plain), as: UTF8.self)
        let livingJSON = String(decoding: try JSONFile.encoder().encode(living), as: UTF8.self)
        XCTAssertFalse(plainJSON.contains("living"))
        XCTAssertTrue(livingJSON.contains("\"living\" : true"))
        XCTAssertEqual(try JSONDecoder().decode(CatalogEntry.self, from: Data(livingJSON.utf8)), living)
    }
}
