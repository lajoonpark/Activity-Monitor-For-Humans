import Foundation

/// Typo-tolerant lookup over `ProcessGlossary`.
///
/// The hard case is not a misspelled name — it is someone who never knew the
/// name and is typing what they see or what hurts ("lots of windows", "fan
/// loud"). So matching runs over names, aliases, bundle identifiers and the
/// plain-language `knownFor` phrases, and a small edit distance covers the
/// typos. Matching collapses spacing and case, so "windows server",
/// "WindowServer" and "windowsserver" are the same thing.
enum ProcessGlossarySearch {
    struct Match: Identifiable, Sendable {
        let entry: ProcessGlossaryEntry
        let score: Int
        var id: String { entry.id }
    }

    /// Score at or above which a match is strong enough to present as *the*
    /// answer to "what is this?". Below it we admit we don't know instead.
    static let confidentMatchScore = 900

    /// Ranked matches, best first. An empty query returns everything so the
    /// wiki can show a browsable list.
    static func search(_ query: String, in entries: [ProcessGlossaryEntry] = ProcessGlossary.all) -> [Match] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return entries
                .sorted { $0.name < $1.name }
                .map { Match(entry: $0, score: 0) }
        }

        let normalized = normalize(trimmed)
        let squashed = squash(trimmed)
        let tokens = tokenize(trimmed)

        return entries
            .compactMap { entry -> Match? in
                let score = score(entry: entry, normalized: normalized, squashed: squashed, tokens: tokens)
                return score > 0 ? Match(entry: entry, score: score) : nil
            }
            .sorted {
                $0.score == $1.score
                    ? $0.entry.name < $1.entry.name
                    : $0.score > $1.score
            }
    }

    /// Resolves a running process to an entry, or nil when we can't say with
    /// confidence. Callers show a fallback rather than guessing.
    static func bestMatch(forName name: String, bundleIdentifier: String?) -> ProcessGlossaryEntry? {
        if let exact = ProcessGlossary.entry(forName: name, bundleIdentifier: bundleIdentifier) {
            return exact
        }
        guard let best = search(name).first, best.score >= confidentMatchScore else { return nil }
        return best.entry
    }

    // MARK: - Scoring

    private static func score(entry: ProcessGlossaryEntry, normalized: String, squashed: String, tokens: [String]) -> Int {
        var best = 0

        // Bundle identifiers are unambiguous, so they outrank everything.
        for bundle in entry.bundleIdentifiers where squash(bundle) == squashed {
            best = max(best, 1000)
        }

        let names = entry.executableNames + [entry.name]
        for name in names {
            let nameNormalized = normalize(name)
            let nameSquashed = squash(name)
            if nameNormalized == normalized || nameSquashed == squashed {
                best = max(best, 950)
            } else if nameSquashed.hasPrefix(squashed) || nameNormalized.hasPrefix(normalized) {
                best = max(best, 820)
            }
        }

        for alias in entry.aliases {
            let aliasSquashed = squash(alias)
            if aliasSquashed == squashed {
                best = max(best, 900)
            } else if aliasSquashed.hasPrefix(squashed) && squashed.count >= 4 {
                best = max(best, 800)
            }
        }

        // Every word the person typed shows up somewhere in the entry. This is
        // what catches "windows server" and "spotlight indexing".
        if !tokens.isEmpty {
            let fieldTokens = Set((names + entry.aliases + entry.knownFor).flatMap(tokenize))
            if tokens.allSatisfy({ fieldTokens.contains($0) }) {
                best = max(best, 700)
            }
        }

        for phrase in entry.knownFor where normalize(phrase) == normalized {
            best = max(best, 680)
        }

        if best < 800, squashed.count >= 3 {
            let maxDistance = squashed.count <= 4 ? 1 : 2
            let closest = (names + entry.aliases)
                .compactMap { boundedDistance(squashed, squash($0), limit: maxDistance) }
                .min()
            if let closest {
                best = max(best, 600 - closest * 60)
            }
        }

        // Symptom phrases, only once the query is long enough to mean something.
        if best == 0, squashed.count >= 5 {
            for phrase in entry.knownFor {
                let phraseSquashed = squash(phrase)
                if phraseSquashed.contains(squashed) || squashed.contains(phraseSquashed) {
                    best = max(best, 420)
                    break
                }
            }
        }

        return best
    }

    // MARK: - Text handling

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Everything squashed into one lowercase run, so spacing and case stop mattering.
    private static func squash(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Optimal string alignment distance, or nil when it exceeds `limit`.
    /// Counts an adjacent transposition as one edit, since that is the typo
    /// people make most ("widnows").
    static func boundedDistance(_ a: String, _ b: String, limit: Int) -> Int? {
        let s = Array(a)
        let t = Array(b)
        guard limit >= 0 else { return nil }
        if abs(s.count - t.count) > limit { return nil }
        if s.isEmpty { return t.count <= limit ? t.count : nil }
        if t.isEmpty { return s.count <= limit ? s.count : nil }

        var previousPrevious = Array(0...t.count)
        var previous = Array(0...t.count)
        var current = Array(repeating: 0, count: t.count + 1)

        for i in 1...s.count {
            current[0] = i
            var rowMin = current[0]
            for j in 1...t.count {
                let substitution = previous[j - 1] + (s[i - 1] == t[j - 1] ? 0 : 1)
                var value = min(previous[j] + 1, current[j - 1] + 1, substitution)
                if i > 1, j > 1, s[i - 1] == t[j - 2], s[i - 2] == t[j - 1] {
                    value = min(value, previousPrevious[j - 2] + 1)
                }
                current[j] = value
                rowMin = min(rowMin, value)
            }
            if rowMin > limit { return nil }
            previousPrevious = previous
            previous = current
            current = Array(repeating: 0, count: t.count + 1)
        }
        return previous[t.count] <= limit ? previous[t.count] : nil
    }
}
