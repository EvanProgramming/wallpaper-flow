import Foundation

// MARK: - LRC Lyrics Parser

public enum LyricsParser {

    /// Parses LRC format string into an array of LyricLine objects.
    ///
    /// Supports:
    /// - `[mm:ss.xx]` (centiseconds)
    /// - `[mm:ss.xxx]` (milliseconds)
    /// - `[mm:ss]` (no fractional part)
    /// - Multiple timestamps on one line: `[00:01.00][00:15.00] lyrics`
    ///
    /// - Parameter lrcText: The raw LRC-formatted text.
    /// - Returns: An array of `LyricLine` sorted by startTime, with endTime set from the next line.
    public static func parse(lrcText: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let pattern = /\[(\d{1,3}):(\d{2})(?:\.(\d{2,3}))?\](.*)/
        let lineEndings = lrcText.components(separatedBy: .newlines)

        for line in lineEndings {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Collect all timestamps for this line
            var timestamps: [Double] = []
            var lyricText = ""
            var remaining = trimmed[...]

            while let match = try? pattern.firstMatch(in: remaining) {
                let minutes = Double(match.1) ?? 0
                let seconds = Double(match.2) ?? 0
                let fractional = match.3.map { String($0) }

                let fractionalSeconds: Double
                if let frac = fractional {
                    // 2-digit (centiseconds) or 3-digit (milliseconds)
                    fractionalSeconds = Double(frac)! / pow(10, Double(frac.count))
                } else {
                    fractionalSeconds = 0
                }

                let totalSeconds = minutes * 60 + seconds + fractionalSeconds
                timestamps.append(totalSeconds)
                lyricText = String(match.4)
                remaining = remaining[match.range.upperBound...]
            }

            // Only create lines if we found timestamps
            guard !timestamps.isEmpty else { continue }

            for timestamp in timestamps {
                lines.append(LyricLine(startTime: timestamp, text: lyricText))
            }
        }

        // Sort by startTime
        lines.sort { $0.startTime < $1.startTime }

        // Set endTime based on next line's startTime
        for i in 0..<lines.count {
            if i + 1 < lines.count {
                let nextStart = lines[i + 1].startTime
                lines[i].endTime = nextStart
            }
        }

        return lines
    }

    /// Validates whether a string contains valid LRC-formatted content.
    /// - Parameter text: The text to check.
    /// - Returns: `true` if at least one LRC timestamp line is found.
    public static func isValidLRCText(_ text: String) -> Bool {
        let pattern = /\[(\d{1,3}):(\d{2})(?:\.\d{2,3})?\]./
        return text.contains(pattern)
    }
}