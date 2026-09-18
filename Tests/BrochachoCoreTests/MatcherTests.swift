import Foundation
import XCTest
@testable import BrochachoCore

/// The matcher must reproduce fixtures/matcher.json, which the JavaScript reference wrote.
final class MatcherTests: XCTestCase {

    private struct PlanFixture: Decodable {
        let type: String
        let url: String?
        let profile: String?
        let bundleID: String?
        let path: String?
        let tool: String?
        let argument: String?
        let entry: String
    }

    private struct ResultFixture: Decodable {
        let name: String
        let band: String
    }

    private struct CaseFixture: Decodable {
        let input: String
        let usage: [String: Int]
        let mode: String
        let confident: Bool
        let query: String?
        let results: [ResultFixture]
        let plan: PlanFixture?
    }

    private struct FileFixture: Decodable {
        let catalog: [CatalogEntry]
        let cases: [CaseFixture]
    }

    func testEveryGoldenCase() throws {
        let file = try Fixtures.load(FileFixture.self, "matcher.json")
        XCTAssertGreaterThanOrEqual(file.cases.count, 60)

        for c in file.cases {
            let label = "input \"\(c.input)\" usage \(c.usage)"
            let decision = Matcher.match(c.input, catalog: file.catalog, usage: c.usage)

            XCTAssertEqual(decision.mode.rawValue, c.mode, "mode for \(label)")
            XCTAssertEqual(decision.confident, c.confident, "confident for \(label)")
            XCTAssertEqual(decision.query, c.query, "query for \(label)")
            XCTAssertEqual(decision.results.map { $0.entry.name }, c.results.map { $0.name }, "result names for \(label)")
            XCTAssertEqual(decision.results.map { $0.band.name }, c.results.map { $0.band }, "bands for \(label)")

            let plan = ActionPlan.make(from: decision)
            switch (plan, c.plan) {
            case (nil, nil):
                break
            case (.some(.openURL(let url, let profile, let entry)), .some(let expected)):
                XCTAssertEqual(expected.type, "openURL", "plan type for \(label)")
                XCTAssertEqual(url, expected.url, "plan url for \(label)")
                XCTAssertEqual(profile, expected.profile, "plan profile for \(label)")
                XCTAssertEqual(entry, expected.entry, "plan entry for \(label)")
            case (.some(.openApp(let bundleID, let entry)), .some(let expected)):
                XCTAssertEqual(expected.type, "openApp", "plan type for \(label)")
                XCTAssertEqual(bundleID, expected.bundleID, "plan bundle for \(label)")
                XCTAssertEqual(entry, expected.entry, "plan entry for \(label)")
            case (.some(.openPath(let path, let entry)), .some(let expected)):
                XCTAssertEqual(expected.type, "openPath", "plan type for \(label)")
                XCTAssertEqual(path, expected.path, "plan path for \(label)")
                XCTAssertEqual(entry, expected.entry, "plan entry for \(label)")
            case (.some(.openTool(let tool, let argument, let entry)), .some(let expected)):
                XCTAssertEqual(expected.type, "openTool", "plan type for \(label)")
                XCTAssertEqual(tool, expected.tool, "plan tool for \(label)")
                XCTAssertEqual(argument, expected.argument, "plan argument for \(label)")
                XCTAssertEqual(entry, expected.entry, "plan entry for \(label)")
            default:
                XCTFail("one side has a plan and the other does not, for \(label)")
            }
        }
    }

    func testDefaultCatalogMatchesTheSharedJSON() throws {
        let file = try Fixtures.load(FileFixture.self, "matcher.json")
        XCTAssertEqual(DefaultCatalog.entries, file.catalog, "run scripts/gen_default_catalog.py")
    }

    func testTextHelpers() {
        XCTAssertEqual(Text.normalize("You-Tube! 2"), "youtube2")
        XCTAssertEqual(Text.words("VS Code, the editor"), ["vs", "code", "the", "editor"])
        XCTAssertEqual(Text.editDistance("kitten", "sitting"), 3)
        XCTAssertEqual(Text.editDistance("", "abc"), 3)
        XCTAssertEqual(Text.subsequenceSpan("ytb", in: "youtube"), 6)
        XCTAssertNil(Text.subsequenceSpan("xyz", in: "youtube"))
        XCTAssertEqual(Text.encodeQuery("café ☕ & co"), "caf%C3%A9%20%E2%98%95%20%26%20co")
    }

    func testSearchURLs() {
        let catalog = DefaultCatalog.entries
        let plan = ActionPlan.make(from: Matcher.match("yt berserk & guts: 1997 ost", catalog: catalog))
        XCTAssertEqual(plan, .openURL(url: "https://www.youtube.com/results?search_query=berserk%20%26%20guts%3A%201997%20ost",
                                      profile: "personal", entry: "youtube"))
    }

    func testTappingARowOpensThatRow() {
        let catalog = DefaultCatalog.entries
        let decision = Matcher.match("", catalog: catalog, usage: ["steam": 9, "gmail": 4])
        XCTAssertEqual(decision.results.map { $0.entry.name }, ["steam", "gmail", "claude", "desktop"])
        XCTAssertNil(ActionPlan.make(from: decision), "nothing typed and nothing chosen opens nothing")
        XCTAssertEqual(ActionPlan.make(from: decision, choosing: 1),
                       .openURL(url: "https://mail.google.com", profile: "personal", entry: "gmail"))
        XCTAssertNil(ActionPlan.make(from: decision, choosing: 9))
    }
}
