import Foundation
import XCTest
@testable import BrochachoCore

final class ConfigTests: XCTestCase {

    func testAMissingFileIsCreatedWithDefaults() throws {
        let url = try temporaryDirectory().appendingPathComponent("config.json")
        let loaded = ConfigStore.load(from: url)
        XCTAssertNil(loaded.problem)
        XCTAssertEqual(loaded.config, Config())
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(ConfigStore.load(from: url).config, Config(), "defaults must survive a round trip through JSON")
    }

    func testAPartialConfigKeepsDefaultsForEverythingElse() throws {
        let url = try temporaryDirectory().appendingPathComponent("config.json")
        let json = """
        {
          "hotkeys": { "open": "ctrl+space" },
          "theme": { "motion": { "stiffness": 400 }, "look": { "phosphor": "#7CFF6B" } },
          "catalog": [ { "name": "reddit", "kind": "site", "target": "https://www.reddit.com" } ]
        }
        """
        try Data(json.utf8).write(to: url)

        let config = ConfigStore.load(from: url).config
        XCTAssertEqual(config.hotkeys.openBox, "ctrl+space")
        XCTAssertEqual(config.hotkeys.talk, Hotkeys().talk)
        XCTAssertEqual(config.theme.motion.stiffness, 400)
        XCTAssertEqual(config.theme.motion.damping, MotionTheme().damping)
        XCTAssertEqual(config.theme.look.phosphor, "#7CFF6B")
        XCTAssertEqual(config.theme.voice, VoiceTheme())
        XCTAssertEqual(config.brave, BraveConfig())
        XCTAssertEqual(config.catalog.count, 1)
        XCTAssertEqual(config.catalog[0].aliases, [])
    }

    func testABrokenConfigIsLeftAloneAndDefaultsAreUsed() throws {
        let url = try temporaryDirectory().appendingPathComponent("config.json")
        let broken = Data("{ \"hotkeys\": oops".utf8)
        try broken.write(to: url)

        let loaded = ConfigStore.load(from: url)
        XCTAssertEqual(loaded.config, Config())
        XCTAssertNotNil(loaded.problem)
        XCTAssertEqual(try Data(contentsOf: url), broken, "a typo in the config must never wipe it")
    }

    func testPhosphorColourParsing() {
        XCTAssertEqual(LookTheme(phosphor: "#FF0000").phosphorRGB.red, 1)
        XCTAssertEqual(LookTheme(phosphor: "#FF0000").phosphorRGB.green, 0)
        XCTAssertEqual(LookTheme(phosphor: "00ff00").phosphorRGB.green, 1)
        XCTAssertEqual(LookTheme(phosphor: "nonsense").phosphorRGB.red, 1)
        XCTAssertEqual(LookTheme(phosphor: "nonsense").phosphorRGB.blue, 0)
    }

    func testProfilesAndTilde() {
        let brave = BraveConfig(personalProfileDir: "Default", workProfileDir: "Profile 2")
        XCTAssertEqual(brave.profileDirectory(for: "work"), "Profile 2")
        XCTAssertEqual(brave.profileDirectory(for: "personal"), "Default")
        XCTAssertEqual(brave.profileDirectory(for: "anything else"), "Default")
        XCTAssertTrue(BrochachoPaths.expandTilde("~/Downloads").hasSuffix("/Downloads"))
        XCTAssertFalse(BrochachoPaths.expandTilde("~/Downloads").hasPrefix("~"))
        XCTAssertEqual(BrochachoPaths.expandTilde("/tmp/x"), "/tmp/x")
    }
}
