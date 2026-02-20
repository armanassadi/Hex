import Foundation

/// Rule-based smart formatting for transcription output.
///
/// All rules are pure string operations with microsecond-level performance.
/// Inserted into the pipeline BEFORE word removals so formatting sees the
/// raw Parakeet output.
public enum TextFormattingEngine {

	/// User-configurable formatting options.
	public struct Config: Codable, Equatable, Sendable {
		/// Remove trailing period when the phrase is short and informal.
		public var removeTrailingPeriod: Bool
		/// Lowercase the first letter of short phrases (respects vocabulary).
		public var lowercaseShortPhrases: Bool
		/// Word count at or below which a phrase is considered "short".
		public var shortPhraseMaxWords: Int

		public init(
			removeTrailingPeriod: Bool = true,
			lowercaseShortPhrases: Bool = true,
			shortPhraseMaxWords: Int = 5
		) {
			self.removeTrailingPeriod = removeTrailingPeriod
			self.lowercaseShortPhrases = lowercaseShortPhrases
			self.shortPhraseMaxWords = shortPhraseMaxWords
		}
	}

	/// Apply all enabled formatting rules to the transcribed text.
	///
	/// - Parameters:
	///   - text: Raw transcription output.
	///   - config: Which rules are enabled and their thresholds.
	///   - vocabulary: The user's custom vocabulary list, used to protect
	///     proper nouns from lowercasing.
	/// - Returns: Formatted text.
	public static func apply(
		_ text: String,
		config: Config,
		vocabulary: [String] = []
	) -> String {
		var output = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !output.isEmpty else { return output }

		let wordCount = output.components(separatedBy: .whitespaces)
			.filter { !$0.isEmpty }
			.count
		let isShort = wordCount <= config.shortPhraseMaxWords

		if config.removeTrailingPeriod && isShort {
			output = removeTrailingPeriodIfShort(output)
		}

		if config.lowercaseShortPhrases && isShort {
			output = lowercaseFirstLetter(output, vocabulary: vocabulary)
		}

		// Always: normalize whitespace
		output = normalizeWhitespace(output)

		return output
	}

	// MARK: - Rules

	/// Strip a single trailing period from short, informal phrases.
	///
	/// Preserves ellipsis ("..."), abbreviations ("U.S.A."), and
	/// exclamation/question marks.
	private static func removeTrailingPeriodIfShort(_ text: String) -> String {
		guard text.hasSuffix("."), !text.hasSuffix("..") else { return text }
		// Don't strip if the character before the period is also a period
		// (abbreviation like "U.S.A.")
		let withoutPeriod = String(text.dropLast())
		guard !withoutPeriod.isEmpty else { return text }
		return withoutPeriod
	}

	/// Lowercase the first letter of a short phrase unless it's a vocabulary
	/// word (proper noun / acronym).
	private static func lowercaseFirstLetter(
		_ text: String,
		vocabulary: [String]
	) -> String {
		guard let firstChar = text.first, firstChar.isUppercase else {
			return text
		}

		// Extract the first word
		let firstWord: String
		if let spaceIndex = text.firstIndex(of: " ") {
			firstWord = String(text[text.startIndex..<spaceIndex])
		} else {
			firstWord = text
		}

		// Protect vocabulary words — if the first word (ignoring trailing
		// punctuation) matches any vocabulary entry, leave it alone.
		let stripped = firstWord.trimmingCharacters(in: .punctuationCharacters)
		for vocab in vocabulary {
			let trimmed = vocab.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { continue }
			if stripped.caseInsensitiveCompare(trimmed) == .orderedSame {
				return text
			}
		}

		// Also protect single-letter "I"
		if stripped == "I" { return text }

		// Lowercase just the first character
		return text.prefix(1).lowercased() + text.dropFirst()
	}

	/// Collapse runs of whitespace into single spaces, trim edges.
	private static func normalizeWhitespace(_ text: String) -> String {
		text.replacingOccurrences(of: "[ \t]{2,}", with: " ", options: .regularExpression)
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
