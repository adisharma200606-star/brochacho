import AppKit
import BrochachoCore
import Foundation

/// "play beabadoobee", "pause", "next", "louder", "volume 30". The Google Home part.
///
/// Spotify can be told to play a particular thing by AppleScript, but only if you already know its
/// address ("spotify:artist:…"). Finding that address from words needs Spotify's own search, which needs a
/// free developer key (developer.spotify.com → Create app; copy the Client ID and Client secret into
/// settings). Without the key, "play beabadoobee" opens Spotify's search for it instead, one click short.
///
/// Apple Music needs no key: it searches your library by AppleScript and plays the first match.
enum MusicPlayer {

    enum Outcome {
        case playing(String)
        case searching(String)
        case failed(String)
    }

    static let clientIDAccount = "spotify-client-id"
    static let clientSecretAccount = "spotify-client-secret"

    // MARK: playing something by name

    static func play(_ words: String, player: String) async -> Outcome {
        let query = words.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return playPause(player: player) ? .playing("") : .failed("Nothing to play.")
        }
        if player == "music" { return playFromLibrary(query) }

        if let id = AskClient.Keychain.read(account: clientIDAccount), let secret = AskClient.Keychain.read(account: clientSecretAccount),
           !id.isEmpty, !secret.isEmpty {
            do {
                if let found = try await SpotifySearch.best(for: query, clientID: id, secret: secret) {
                    if runScript("tell application \"Spotify\" to play track \"\(escaped(found.uri))\"") {
                        return .playing(found.name)
                    }
                    return .failed("Spotify would not play. Check Privacy, Automation.")
                }
                return .failed("Spotify found nothing called \(query).")
            } catch {
                NSLog("Brochacho: Spotify search failed: \(error)")
                // Fall through to the search page, which still gets him there.
            }
        }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        if let url = URL(string: "spotify:search:\(encoded)"), NSWorkspace.shared.open(url) {
            return .searching(query)
        }
        return .failed("Spotify is not installed.")
    }

    private static func playFromLibrary(_ query: String) -> Outcome {
        let source = """
        tell application "Music"
            set found to (search playlist "Library" for "\(escaped(query))")
            if found is {} then return ""
            play item 1 of found
            return name of item 1 of found
        end tell
        """
        guard let name = runScriptForString(source) else { return .failed("Music would not play. Check Privacy, Automation.") }
        return name.isEmpty ? .failed("Nothing in your library called \(query).") : .playing(name)
    }

    // MARK: controls

    private static func appName(_ player: String) -> String {
        return player == "music" ? "Music" : "Spotify"
    }

    @discardableResult
    static func playPause(player: String) -> Bool {
        return runScript("tell application \"\(appName(player))\" to playpause")
    }

    @discardableResult
    static func next(player: String) -> Bool {
        return runScript("tell application \"\(appName(player))\" to next track")
    }

    /// The Mac's own volume, by `step` out of 100. Works whatever is playing.
    @discardableResult
    static func nudgeVolume(by step: Int) -> Bool {
        return runScript("set volume output volume ((output volume of (get volume settings)) + (\(step)))")
    }

    /// "volume 30". Nil when the words are not a number from 0 to 100.
    static func setVolume(_ words: String) -> Int? {
        let digits = words.filter { $0.isNumber }
        guard let level = Int(digits), (0...100).contains(level) else { return nil }
        return runScript("set volume output volume \(level)") ? level : nil
    }

    // MARK: AppleScript

    private static func escaped(_ text: String) -> String {
        return text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    @discardableResult
    private static func runScript(_ source: String) -> Bool {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error = error {
            NSLog("Brochacho: music script failed: \(error)")
            return false
        }
        return true
    }

    private static func runScriptForString(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error = error {
            NSLog("Brochacho: music script failed: \(error)")
            return nil
        }
        return result?.stringValue ?? ""
    }
}

/// Spotify's search, with the "client credentials" kind of key: no logging in, it only looks things up.
private enum SpotifySearch {
    struct Found {
        let uri: String
        let name: String
    }

    private struct Token: Decodable {
        let access_token: String
    }

    private struct Results: Decodable {
        struct Item: Decodable {
            let uri: String
            let name: String
        }
        struct Page: Decodable {
            let items: [Item?]
        }
        let artists: Page?
        let tracks: Page?
        let playlists: Page?
    }

    /// An artist when the words are the artist's name ("beabadoobee"), otherwise the best song, then a playlist.
    static func best(for query: String, clientID: String, secret: String) async throws -> Found? {
        let token = try await fetchToken(clientID: clientID, secret: secret)
        var parts = URLComponents(string: "https://api.spotify.com/v1/search")
        parts?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "artist,track,playlist"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = parts?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let results = try JSONDecoder().decode(Results.self, from: data)

        let wanted = TextTools.normalize(query)
        if let artist = results.artists?.items.compactMap({ $0 }).first, TextTools.normalize(artist.name) == wanted {
            return Found(uri: artist.uri, name: artist.name)
        }
        if let track = results.tracks?.items.compactMap({ $0 }).first { return Found(uri: track.uri, name: track.name) }
        if let artist = results.artists?.items.compactMap({ $0 }).first { return Found(uri: artist.uri, name: artist.name) }
        if let list = results.playlists?.items.compactMap({ $0 }).first { return Found(uri: list.uri, name: list.name) }
        return nil
    }

    private static func fetchToken(clientID: String, secret: String) async throws -> String {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        let basic = Data("\(clientID):\(secret)".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("grant_type=client_credentials".utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.userAuthenticationRequired) }
        return try JSONDecoder().decode(Token.self, from: data).access_token
    }
}
