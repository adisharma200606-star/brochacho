import Foundation

// The timer and "living" bookmarks. Pure logic, ported from `reference-js/extras.js`.

// MARK: - Durations

public enum DurationParser {
    private static let unitSeconds: [String: Double] = [
        "h": 3600, "hr": 3600, "hrs": 3600, "hour": 3600, "hours": 3600,
        "m": 60, "min": 60, "mins": 60, "minute": 60, "minutes": 60,
        "s": 1, "sec": 1, "secs": 1, "second": 1, "seconds": 1
    ]
    private static let ignoredWords: Set<String> = ["for", "of", "about", "a", "an", "and"]
    private static let maxSeconds = 24 * 3600

    /// How long did he mean? Whole seconds, or nil when it cannot be read.
    ///   "10" is 10 minutes (a bare number means minutes), "1.5" is 90 seconds,
    ///   "90s", "10 min", "1h", "1h30", "5m30", "1 hour 30 minutes", "1:30", "1:30:00",
    ///   and small words are ignored: "for 10 minutes".
    /// Anything under one second or over 24 hours is refused.
    public static func parse(_ text: String) -> Int? {
        let cleaned = removeIgnoredWords(text.lowercased().replacingOccurrences(of: ",", with: " "))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return nil }

        var total: Double
        if let clock = parseClock(cleaned) {
            total = clock
        } else if let spoken = parseUnits(cleaned) {
            total = spoken
        } else {
            return nil
        }
        let seconds = Int((total + 0.5).rounded(.down))
        if seconds < 1 || seconds > maxSeconds { return nil }
        return seconds
    }

    private static func isWordCharacter(_ c: Character) -> Bool {
        return c.isASCII && (c.isLetter || c.isNumber || c == "_")
    }

    /// Replaces whole words from `ignoredWords` with a space. A "word" is a run of letters, digits and "_",
    /// which is exactly what \b means in the JavaScript reference.
    private static func removeIgnoredWords(_ text: String) -> String {
        var out = ""
        var word = ""
        func flush() {
            if word.isEmpty { return }
            out += ignoredWords.contains(word) ? " " : word
            word = ""
        }
        for c in text {
            if isWordCharacter(c) {
                word.append(c)
            } else {
                flush()
                out.append(c)
            }
        }
        flush()
        return out
    }

    /// "m:ss" or "h:mm:ss". The first part is one or two digits, the others exactly two.
    private static func parseClock(_ text: String) -> Double? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if parts.count != 2 && parts.count != 3 { return nil }
        for (index, part) in parts.enumerated() {
            let lengthOK = index == 0 ? (part.count >= 1 && part.count <= 2) : part.count == 2
            if !lengthOK || !part.allSatisfy({ $0.isASCII && $0.isNumber }) { return nil }
        }
        let numbers = parts.compactMap { Double($0) }
        if numbers.count != parts.count { return nil }
        return parts.count == 2 ? numbers[0] * 60 + numbers[1] : numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
    }

    /// A run of "number, optional unit" pieces: "1h 30m", "5m30", "90 sec".
    private static func parseUnits(_ text: String) -> Double? {
        let chars = Array(text)
        var i = 0
        var total = 0.0
        var lastUnit: Double? = nil
        var sawAny = false

        while i < chars.count {
            if chars[i] == " " || chars[i] == "\t" || chars[i] == "\n" {
                i += 1
                continue
            }
            // A number: digits, optionally a dot and more digits.
            var number = ""
            while i < chars.count, chars[i].isASCII, chars[i].isNumber {
                number.append(chars[i])
                i += 1
            }
            if number.isEmpty { return nil }
            if i + 1 < chars.count, chars[i] == ".", chars[i + 1].isASCII, chars[i + 1].isNumber {
                number.append(".")
                i += 1
                while i < chars.count, chars[i].isASCII, chars[i].isNumber {
                    number.append(chars[i])
                    i += 1
                }
            }
            guard let value = Double(number) else { return nil }

            // Optional spaces, then an optional unit made of letters.
            var j = i
            while j < chars.count, chars[j] == " " || chars[j] == "\t" || chars[j] == "\n" { j += 1 }
            var unit = ""
            while j < chars.count, chars[j].isASCII, chars[j].isLetter {
                unit.append(chars[j])
                j += 1
            }

            let per: Double
            if unit.isEmpty {
                // A bare number takes the next unit down: after hours it means minutes, after minutes seconds.
                if lastUnit == 3600 {
                    per = 60
                } else if lastUnit == 60 {
                    per = 1
                } else if lastUnit == 1 {
                    return nil
                } else {
                    per = 60
                }
            } else {
                guard let known = unitSeconds[unit] else { return nil }
                per = known
                i = j
            }
            total += value * per
            lastUnit = per
            sawAny = true
        }
        return sawAny ? total : nil
    }
}

// MARK: - Countdown

public struct TimerStatus: Equatable {
    public let remainingMs: Int
    /// 1 at the start, 0 when done. Drives the thin bar in the closed notch.
    public let fraction: Double
    public let done: Bool
    /// "9:41", "0:07", "1:02:03".
    public let text: String
}

public struct CountdownTimer: Equatable {
    public let startedAt: Int
    public let durationMs: Int

    public init(seconds: Int, nowMs: Int) {
        self.startedAt = nowMs
        self.durationMs = seconds * 1000
    }

    public func status(nowMs: Int) -> TimerStatus {
        let left = Swift.max(0, startedAt + durationMs - nowMs)
        let fraction = durationMs == 0 ? 0 : Double(left) / Double(durationMs)
        return TimerStatus(remainingMs: left, fraction: fraction, done: left == 0, text: CountdownTimer.format(remainingMs: left))
    }

    /// Rounds up, so the display shows 0:01 until the timer is really over.
    public static func format(remainingMs: Int) -> String {
        let seconds = remainingMs <= 0 ? 0 : (remainingMs + 999) / 1000
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        let two: (Int) -> String = { $0 < 10 ? "0\($0)" : "\($0)" }
        return h > 0 ? "\(h):\(two(m)):\(two(s))" : "\(m):\(two(s))"
    }
}

// MARK: - Living bookmarks

public enum BookmarkMatch: Equatable {
    /// Exactly one sensible candidate. Move it.
    case update(CatalogEntry)
    /// Several living entries fit equally well. The app asks which one.
    case ambiguous([CatalogEntry])
    /// Nothing living lives on this site.
    case noMatch
}

public enum LivingBookmarks {

    public struct URLParts: Equatable {
        public let host: String
        public let segments: [String]
    }

    /// Splits a URL into a comparable host (lowercase, no "www.", no login) and its path segments.
    /// Hand-rolled so that it behaves exactly like the JavaScript reference on odd input.
    public static func parts(of url: String) -> URLParts {
        var rest = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if let schemeEnd = rest.range(of: "://") {
            let scheme = rest[rest.startIndex..<schemeEnd.lowerBound]
            let validScheme = scheme.first.map { $0.isASCII && $0.isLetter } == true
                && scheme.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "+" || $0 == "." || $0 == "-") }
            if validScheme { rest = String(rest[schemeEnd.upperBound...]) }
        }

        let hostEnd = rest.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" })
        var host = (hostEnd.map { String(rest[rest.startIndex..<$0]) } ?? rest).lowercased()
        if let at = host.lastIndex(of: "@") {
            host = String(host[host.index(after: at)...])
        }
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }

        var path = hostEnd.map { String(rest[$0...]) } ?? ""
        if let end = path.firstIndex(where: { $0 == "?" || $0 == "#" }) {
            path = String(path[path.startIndex..<end])
        }
        let segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        return URLParts(host: host, segments: segments)
    }

    private static func sharedLeadingSegments(_ a: [String], _ b: [String]) -> Int {
        var n = 0
        while n < a.count && n < b.count && a[n] == b[n] { n += 1 }
        return n
    }

    /// He pressed "remember where I am" on some page. Which entry should move?
    /// Only entries marked `living` are ever touched.
    public static func find(for currentURL: String, in catalog: [CatalogEntry]) -> BookmarkMatch {
        let here = parts(of: currentURL)
        if here.host.isEmpty { return .noMatch }

        let sameHost = catalog.filter { $0.kind == .site && $0.living && parts(of: $0.target).host == here.host }
        if sameHost.isEmpty { return .noMatch }
        if sameHost.count == 1 { return .update(sameHost[0]) }

        var best = -1
        var tied = [CatalogEntry]()
        for entry in sameHost {
            let score = sharedLeadingSegments(here.segments, parts(of: entry.target).segments)
            if score > best {
                best = score
                tied = [entry]
            } else if score == best {
                tied.append(entry)
            }
        }
        if tied.count == 1 { return .update(tied[0]) }
        return .ambiguous(tied.sorted { $0.name < $1.name })
    }

    /// The catalog with one entry pointed at a new page. Everything else about the entry is kept.
    public static func move(_ entryName: String, to newURL: String, in catalog: [CatalogEntry]) -> [CatalogEntry] {
        return catalog.map { entry in
            if entry.name != entryName { return entry }
            var copy = entry
            copy.target = newURL
            return copy
        }
    }
}
