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
		/// Fix random mid-sentence capitalization from the speech model.
		public var fixMidSentenceCapitalization: Bool
		/// Convert spoken numbers to digits (e.g. "twenty-three" → "23").
		public var convertNumbersToDigits: Bool
		/// Format currency expressions (e.g. "five dollars" → "$5").
		public var formatCurrency: Bool
		/// Format percentages (e.g. "fifty percent" → "50%").
		public var formatPercentages: Bool
		/// Format time expressions (e.g. "three thirty PM" → "3:30 PM").
		public var formatTimes: Bool
		/// Remove duplicate adjacent words (e.g. "the the" → "the").
		public var deduplicateWords: Bool
		/// Format spoken email addresses (e.g. "name at gmail dot com" → "name@gmail.com").
		public var formatEmails: Bool
		public init(
			removeTrailingPeriod: Bool = true,
			lowercaseShortPhrases: Bool = true,
			shortPhraseMaxWords: Int = 5,
			fixMidSentenceCapitalization: Bool = true,
			convertNumbersToDigits: Bool = true,
			formatCurrency: Bool = true,
			formatPercentages: Bool = true,
			formatTimes: Bool = true,
			deduplicateWords: Bool = true,
			formatEmails: Bool = true
		) {
			self.removeTrailingPeriod = removeTrailingPeriod
			self.lowercaseShortPhrases = lowercaseShortPhrases
			self.shortPhraseMaxWords = shortPhraseMaxWords
			self.fixMidSentenceCapitalization = fixMidSentenceCapitalization
			self.convertNumbersToDigits = convertNumbersToDigits
			self.formatCurrency = formatCurrency
			self.formatPercentages = formatPercentages
			self.formatTimes = formatTimes
			self.deduplicateWords = deduplicateWords
			self.formatEmails = formatEmails
		}

		private enum CodingKeys: String, CodingKey {
			case removeTrailingPeriod, lowercaseShortPhrases, shortPhraseMaxWords,
				fixMidSentenceCapitalization, convertNumbersToDigits, formatCurrency,
				formatPercentages, formatTimes, deduplicateWords, formatEmails
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let d = Config()
			self.removeTrailingPeriod = try container.decodeIfPresent(Bool.self, forKey: .removeTrailingPeriod) ?? d.removeTrailingPeriod
			self.lowercaseShortPhrases = try container.decodeIfPresent(Bool.self, forKey: .lowercaseShortPhrases) ?? d.lowercaseShortPhrases
			self.shortPhraseMaxWords = try container.decodeIfPresent(Int.self, forKey: .shortPhraseMaxWords) ?? d.shortPhraseMaxWords
			self.fixMidSentenceCapitalization = try container.decodeIfPresent(Bool.self, forKey: .fixMidSentenceCapitalization) ?? d.fixMidSentenceCapitalization
			self.convertNumbersToDigits = try container.decodeIfPresent(Bool.self, forKey: .convertNumbersToDigits) ?? d.convertNumbersToDigits
			self.formatCurrency = try container.decodeIfPresent(Bool.self, forKey: .formatCurrency) ?? d.formatCurrency
			self.formatPercentages = try container.decodeIfPresent(Bool.self, forKey: .formatPercentages) ?? d.formatPercentages
			self.formatTimes = try container.decodeIfPresent(Bool.self, forKey: .formatTimes) ?? d.formatTimes
			self.deduplicateWords = try container.decodeIfPresent(Bool.self, forKey: .deduplicateWords) ?? d.deduplicateWords
			self.formatEmails = try container.decodeIfPresent(Bool.self, forKey: .formatEmails) ?? d.formatEmails
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

		// Deduplication first (remove "the the" before other processing)
		if config.deduplicateWords {
			output = deduplicateAdjacentWords(output)
		}

		// Email formatting early (before number conversion eats "at" patterns)
		if config.formatEmails {
			output = formatEmailExpressions(output)
		}

		// Time formatting before number conversion (so "three thirty" isn't
		// converted to "3 30" before we can recognize it as a time)
		if config.formatTimes {
			output = formatTimeExpressions(output)
		}

		// Number and currency formatting (before capitalization fixes
		// since these rules consume multi-word spans like "twenty three")
		if config.formatCurrency {
			output = formatCurrencyExpressions(output)
		}
		if config.formatPercentages {
			output = formatPercentageExpressions(output)
		}
		if config.convertNumbersToDigits {
			output = convertSpokenNumbersToDigits(output)
		}

		// Add commas to large bare digit numbers (e.g. "1033" → "1,033")
		if config.convertNumbersToDigits {
			output = addThousandsSeparators(output)
		}

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

		if config.fixMidSentenceCapitalization {
			output = fixMidSentenceCaps(output, vocabulary: vocabulary)
		}

		// Always: normalize whitespace
		output = normalizeWhitespace(output)

		return output
	}

	// MARK: - Capitalization Rules

	/// Strip a single trailing period from short, informal phrases.
	///
	/// Preserves ellipsis ("..."), abbreviations ("U.S.A."), and
	/// exclamation/question marks.
	private static func removeTrailingPeriodIfShort(_ text: String) -> String {
		guard text.hasSuffix("."), !text.hasSuffix("..") else { return text }
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

		let firstWord: String
		if let spaceIndex = text.firstIndex(of: " ") {
			firstWord = String(text[text.startIndex..<spaceIndex])
		} else {
			firstWord = text
		}

		let stripped = firstWord.trimmingCharacters(in: .punctuationCharacters)
		if isProtectedWord(stripped, vocabulary: vocabulary) {
			return text
		}

		return text.prefix(1).lowercased() + text.dropFirst()
	}

	/// Fix words that are randomly capitalized mid-sentence by the speech model.
	///
	/// Walks each word and lowercases it if:
	/// - It's not the first word of a sentence (after . ! ?)
	/// - It's not in the vocabulary list
	/// - It's not "I"
	/// - It's not fully uppercased (likely an acronym like "API")
	private static func fixMidSentenceCaps(
		_ text: String,
		vocabulary: [String]
	) -> String {
		let words = text.components(separatedBy: " ")
		guard words.count > 1 else { return text }

		var result: [String] = []
		var previousEndedSentence = true // First word is sentence start

		for word in words {
			if previousEndedSentence {
				result.append(word)
			} else {
				let stripped = word.trimmingCharacters(in: .punctuationCharacters)

				if stripped.isEmpty || !stripped.first!.isUppercase {
					// Already lowercase or empty
					result.append(word)
				} else if isProtectedWord(stripped, vocabulary: vocabulary) {
					// Vocabulary word, "I", or acronym — keep as-is
					result.append(word)
				} else {
					// Random mid-sentence capital — lowercase it
					let leading = String(word.prefix(while: { $0.isPunctuation }))
					let rest = String(word.dropFirst(leading.count))
					let fixed = leading + rest.prefix(1).lowercased() + String(rest.dropFirst())
					result.append(fixed)
				}
			}

			// Check if this word ends a sentence
			let trimmed = word.trimmingCharacters(in: .whitespaces)
			previousEndedSentence = trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?")
		}

		return result.joined(separator: " ")
	}

	/// Check if a word should be protected from lowercasing.
	private static func isProtectedWord(_ word: String, vocabulary: [String]) -> Bool {
		// Protect "I"
		if word == "I" { return true }

		// Protect fully-uppercased words (likely acronyms): "API", "CEO", "AI"
		if word.count >= 2 && word == word.uppercased() && word.allSatisfy({ $0.isLetter }) {
			return true
		}

		// Protect vocabulary words
		for vocab in vocabulary {
			let trimmed = vocab.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { continue }
			if word.caseInsensitiveCompare(trimmed) == .orderedSame {
				return true
			}
		}

		return false
	}

	// MARK: - Number Conversion

	/// Map of single number words to their integer values.
	private static let onesMap: [String: Int] = [
		"zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
		"five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
		"ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
		"fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17,
		"eighteen": 18, "nineteen": 19
	]

	private static let tensMap: [String: Int] = [
		"twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
		"sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
	]

	private static let scaleMap: [String: Int] = [
		"hundred": 100, "thousand": 1_000, "million": 1_000_000,
		"billion": 1_000_000_000, "trillion": 1_000_000_000_000
	]

	/// All words that are part of number expressions.
	/// Note: "a" is NOT included — it's handled contextually to avoid
	/// converting "a meeting" → "1 meeting".
	private static let allNumberWords: Set<String> = {
		var words = Set<String>()
		words.formUnion(onesMap.keys)
		words.formUnion(tensMap.keys)
		words.formUnion(scaleMap.keys)
		words.insert("and")
		return words
	}()

	/// Ordinal suffixes for spoken ordinals.
	private static let ordinalWords: [String: (Int, String)] = [
		"first": (1, "st"), "second": (2, "nd"), "third": (3, "rd"),
		"fourth": (4, "th"), "fifth": (5, "th"), "sixth": (6, "th"),
		"seventh": (7, "th"), "eighth": (8, "th"), "ninth": (9, "th"),
		"tenth": (10, "th"), "eleventh": (11, "th"), "twelfth": (12, "th"),
		"thirteenth": (13, "th"), "fourteenth": (14, "th"), "fifteenth": (15, "th"),
		"sixteenth": (16, "th"), "seventeenth": (17, "th"), "eighteenth": (18, "th"),
		"nineteenth": (19, "th"), "twentieth": (20, "th"), "thirtieth": (30, "th"),
		"fortieth": (40, "th"), "fiftieth": (50, "th"), "sixtieth": (60, "th"),
		"seventieth": (70, "th"), "eightieth": (80, "th"), "ninetieth": (90, "th"),
		"hundredth": (100, "th"), "thousandth": (1_000, "th"),
		"millionth": (1_000_000, "th"), "billionth": (1_000_000_000, "th"),
	]

	/// Compound ordinals like "twenty-first", "thirty-second", etc.
	private static let compoundOrdinalSuffixes: [String: (Int, String)] = [
		"first": (1, "st"), "second": (2, "nd"), "third": (3, "rd"),
		"fourth": (4, "th"), "fifth": (5, "th"), "sixth": (6, "th"),
		"seventh": (7, "th"), "eighth": (8, "th"), "ninth": (9, "th"),
	]

	/// Parse a sequence of number words into an integer.
	///
	/// Handles patterns like:
	/// - "twenty three" → 23
	/// - "one hundred" → 100
	/// - "seven million five hundred twenty seven thousand" → 7,527,000
	/// - "a hundred" → 100
	/// - "one hundred and fifty" → 150
	static func parseNumberWords(_ words: [String]) -> Int? {
		guard !words.isEmpty else { return nil }

		// Filter out "and" connectors
		let cleaned = words.filter { $0 != "and" }
		guard !cleaned.isEmpty else { return nil }

		var total = 0
		var current = 0

		for word in cleaned {
			let lower = word.lowercased()
			if lower == "a" {
				// "a hundred", "a thousand" — treat as 1
				current = 1
			} else if let value = onesMap[lower] {
				current += value
			} else if let value = tensMap[lower] {
				current += value
			} else if lower == "hundred" {
				current = (current == 0 ? 1 : current) * 100
			} else if let scale = scaleMap[lower], scale >= 1000 {
				current = (current == 0 ? 1 : current) * scale
				total += current
				current = 0
			} else {
				return nil // Unknown word
			}
		}

		total += current
		return total > 0 || words.contains(where: { $0.lowercased() == "zero" }) ? total : nil
	}

	/// Convert spoken number words in text to digit form.
	///
	/// Scans for contiguous runs of number words and replaces them.
	/// Handles hyphenated forms like "twenty-three".
	static func convertSpokenNumbersToDigits(_ text: String) -> String {
		// First, expand hyphenated number words: "twenty-three" → "twenty three"
		var expanded = text
		let hyphenPattern = "\\b(" +
			tensMap.keys.joined(separator: "|") +
			")-(one|two|three|four|five|six|seven|eight|nine)\\b"
		if let regex = try? NSRegularExpression(pattern: hyphenPattern, options: .caseInsensitive) {
			let range = NSRange(expanded.startIndex..., in: expanded)
			expanded = regex.stringByReplacingMatches(in: expanded, range: range, withTemplate: "$1 $2")
		}

		// Also expand hyphenated ordinals: "twenty-first" → "twenty first"
		let hyphenOrdPattern = "\\b(" +
			tensMap.keys.joined(separator: "|") +
			")-(" +
			compoundOrdinalSuffixes.keys.joined(separator: "|") +
			")\\b"
		if let regex = try? NSRegularExpression(pattern: hyphenOrdPattern, options: .caseInsensitive) {
			let range = NSRange(expanded.startIndex..., in: expanded)
			expanded = regex.stringByReplacingMatches(in: expanded, range: range, withTemplate: "$1 $2")
		}

		let words = expanded.components(separatedBy: " ")
		var result: [String] = []
		var numberBuffer: [String] = []

		func flushBuffer() {
			guard !numberBuffer.isEmpty else { return }

			// Check if the last word is an ordinal
			let lastWord = numberBuffer.last!.lowercased()
			var isOrdinal = false
			var ordinalSuffix = ""
			var ordinalValue = 0

			if let (val, suffix) = ordinalWords[lastWord] {
				isOrdinal = true
				ordinalSuffix = suffix
				ordinalValue = val
			} else if let (val, suffix) = compoundOrdinalSuffixes[lastWord] {
				isOrdinal = true
				ordinalSuffix = suffix
				ordinalValue = val
			}

			if isOrdinal {
				let prefixWords = Array(numberBuffer.dropLast())
				if prefixWords.isEmpty {
					// Standalone ordinal like "first", "tenth"
					result.append("\(ordinalValue)\(ordinalSuffix)")
				} else if let prefixNum = parseNumberWords(prefixWords) {
					// Compound ordinal like "twenty first" → prefix=20, ordinal=1
					let total = prefixNum + ordinalValue
					result.append("\(formatWithCommas(total))\(ordinalSuffix)")
				} else {
					// Can't parse prefix, just convert the ordinal part
					result.append("\(ordinalValue)\(ordinalSuffix)")
				}
			} else if let number = parseNumberWords(numberBuffer) {
				result.append(formatWithCommas(number))
			} else {
				// Couldn't parse — put original words back
				result.append(contentsOf: numberBuffer)
			}
			numberBuffer.removeAll()
		}

		for word in words {
			let lower = word.lowercased()
			let strippedLower = lower.trimmingCharacters(in: .punctuationCharacters)
			let trailingPunct = word.suffix(from: word.index(word.startIndex, offsetBy: strippedLower.count))

			let isNumberWord = allNumberWords.contains(strippedLower)
			// Ordinals only count as number words when buffer already has
			// number words (e.g. "twenty first") — not standalone "first"
			let isOrdinalInContext = !numberBuffer.isEmpty &&
				(ordinalWords[strippedLower] != nil || compoundOrdinalSuffixes[strippedLower] != nil)

			if isNumberWord || isOrdinalInContext {
				// "and" is only a number word if we already have a buffer
				if strippedLower == "and" && numberBuffer.isEmpty {
					flushBuffer()
					result.append(word)
					continue
				}

				numberBuffer.append(strippedLower)

				// If there's trailing punctuation, flush now
				if !trailingPunct.isEmpty {
					flushBuffer()
					if !result.isEmpty {
						result[result.count - 1] = result.last! + trailingPunct
					}
				}
			} else {
				flushBuffer()
				result.append(word)
			}
		}

		flushBuffer()
		return result.joined(separator: " ")
	}

	// MARK: - Currency Formatting

	/// Match patterns like "X dollars", "X dollars and Y cents",
	/// and convert to "$X.YY" format.
	static func formatCurrencyExpressions(_ text: String) -> String {
		var output = text

		// Pattern: [number words] dollars (and [number words] cents)
		// We'll do this with a regex that finds "dollars" and works backwards
		let dollarPattern = "\\bdollars?\\b"
		guard let dollarRegex = try? NSRegularExpression(pattern: dollarPattern, options: .caseInsensitive) else {
			return output
		}

		// Process from right to left so indices stay valid
		let matches = dollarRegex.matches(in: output, range: NSRange(output.startIndex..., in: output))
		for match in matches.reversed() {
			guard let dollarRange = Range(match.range, in: output) else { continue }

			// Check for "and X cents" after "dollars"
			var cents = 0
			var endRange = dollarRange.upperBound
			let afterDollar = String(output[dollarRange.upperBound...])
			let centsPattern = "^\\s+and\\s+(\\w[\\w\\s-]*)\\s+cents?"
			if let centsRegex = try? NSRegularExpression(pattern: centsPattern, options: .caseInsensitive),
			   let centsMatch = centsRegex.firstMatch(in: afterDollar, range: NSRange(afterDollar.startIndex..., in: afterDollar)),
			   let centsWordRange = Range(centsMatch.range(at: 1), in: afterDollar) {
				let centsWords = afterDollar[centsWordRange].components(separatedBy: " ")
					.flatMap { $0.components(separatedBy: "-") }
				if let centsValue = parseNumberWords(centsWords), centsValue < 100 {
					cents = centsValue
					if let fullCentsRange = Range(centsMatch.range, in: afterDollar) {
						endRange = output.index(dollarRange.upperBound, offsetBy: afterDollar.distance(from: afterDollar.startIndex, to: fullCentsRange.upperBound))
					}
				}
			}

			// Look backwards for number words before "dollars"
			let beforeDollar = String(output[output.startIndex..<dollarRange.lowerBound]).trimmingCharacters(in: .whitespaces)
			let beforeWords = beforeDollar.components(separatedBy: " ")

			// Find how many trailing words form a number
			var numberWordCount = 0
			for i in stride(from: beforeWords.count - 1, through: 0, by: -1) {
				let expanded = beforeWords[i].lowercased().trimmingCharacters(in: .punctuationCharacters)
					.components(separatedBy: "-")
				let isNumber = expanded.allSatisfy { allNumberWords.contains($0) }
				if isNumber {
					numberWordCount = beforeWords.count - i
				} else {
					break
				}
			}

			guard numberWordCount > 0 else { continue }

			let numberStartIdx = beforeWords.count - numberWordCount
			let numberWords = Array(beforeWords[numberStartIdx...])
				.flatMap { $0.components(separatedBy: "-") }
				.map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }

			guard let dollarAmount = parseNumberWords(numberWords) else { continue }

			// Build the formatted string
			let formatted: String
			if cents > 0 {
				formatted = "$\(formatWithCommas(dollarAmount)).\(String(format: "%02d", cents))"
			} else {
				formatted = "$\(formatWithCommas(dollarAmount))"
			}

			// Calculate the full range to replace
			let prefixWords = beforeWords[0..<numberStartIdx].joined(separator: " ")
			let prefixWithSpace = prefixWords.isEmpty ? "" : prefixWords + " "
			let replacement = prefixWithSpace + formatted + String(output[endRange...])
			output = replacement
		}

		return output
	}

	// MARK: - Percentage Formatting

	/// Convert "X percent" to "X%".
	/// Uses backward-looking approach from "percent" to find number words.
	static func formatPercentageExpressions(_ text: String) -> String {
		var output = text
		let percentPattern = "\\bpercent\\b"
		guard let regex = try? NSRegularExpression(pattern: percentPattern, options: .caseInsensitive) else {
			return output
		}

		let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
		for match in matches.reversed() {
			guard let percentRange = Range(match.range, in: output) else { continue }

			// Look backwards for number words or digits before "percent"
			let beforePercent = String(output[output.startIndex..<percentRange.lowerBound])
				.trimmingCharacters(in: .whitespaces)
			let beforeWords = beforePercent.components(separatedBy: " ")

			// Find how many trailing words form a number
			var numberWordCount = 0
			for i in stride(from: beforeWords.count - 1, through: 0, by: -1) {
				let word = beforeWords[i].trimmingCharacters(in: .punctuationCharacters)
				// Check if it's a plain digit
				if Int(word) != nil {
					numberWordCount = beforeWords.count - i
					break // digits don't chain backwards
				}
				let expanded = word.lowercased().components(separatedBy: "-")
				let isNumber = expanded.allSatisfy { allNumberWords.contains($0) }
				if isNumber {
					numberWordCount = beforeWords.count - i
				} else {
					break
				}
			}

			guard numberWordCount > 0 else { continue }

			let numberStartIdx = beforeWords.count - numberWordCount
			let rawNumberWords = Array(beforeWords[numberStartIdx...])
			let numberWords = rawNumberWords
				.flatMap { $0.components(separatedBy: "-") }
				.map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }

			// Try parsing as number words
			let value: Int?
			if let parsed = parseNumberWords(numberWords) {
				value = parsed
			} else if numberWords.count == 1, let parsed = Int(numberWords[0]) {
				value = parsed
			} else {
				value = nil
			}

			guard let amount = value else { continue }

			// Build the replacement
			let prefixWords = beforeWords[0..<numberStartIdx].joined(separator: " ")
			let prefixWithSpace = prefixWords.isEmpty ? "" : prefixWords + " "
			let replacement = prefixWithSpace + "\(formatWithCommas(amount))%" + String(output[percentRange.upperBound...])
			output = replacement
		}

		return output
	}

	// MARK: - Thousands Separators

	/// Add commas to bare numbers >= 1000 that don't already have them.
	/// e.g. "1033" → "1,033", but leaves "$1,033" alone.
	static func addThousandsSeparators(_ text: String) -> String {
		let pattern = "(?<!\\d)(?<!\\$)(?<!,)\\b(\\d{4,})\\b(?!,\\d)"
		guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

		var output = text
		let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
		for match in matches.reversed() {
			guard let range = Range(match.range(at: 1), in: output) else { continue }
			let digits = String(output[range])
			if let number = Int(digits) {
				output.replaceSubrange(range, with: formatWithCommas(number))
			}
		}
		return output
	}

	// MARK: - Time Formatting

	/// Convert spoken time expressions to formatted times.
	///
	/// Handles patterns like:
	/// - "three thirty PM" → "3:30 PM"
	/// - "twelve fifteen AM" → "12:15 AM"
	/// - "seven PM" → "7 PM"
	/// - "three p.m." → "3 PM"
	/// Also normalizes AM/PM to uppercase without periods.
	static func formatTimeExpressions(_ text: String) -> String {
		var output = text

		// Normalize all AM/PM variants to uppercase no-period form
		let ampmNormalize: [(String, String)] = [
			("a\\.m\\.", "AM"), ("p\\.m\\.", "PM"),
			("a\\.m", "AM"), ("p\\.m", "PM"),
			("am", "AM"), ("pm", "PM"),
		]
		for (pattern, replacement) in ampmNormalize {
			if let regex = try? NSRegularExpression(pattern: "\\b\(pattern)\\b", options: .caseInsensitive) {
				output = regex.stringByReplacingMatches(
					in: output,
					range: NSRange(output.startIndex..., in: output),
					withTemplate: replacement
				)
			}
		}

		// Pattern: [number word for hour] [number word for minutes] AM/PM
		// e.g. "three thirty PM" → "3:30 PM"
		let hourWords = Array(onesMap.keys) + Array(tensMap.keys)
		let hourPattern = "\\b(" + hourWords.joined(separator: "|") + ")\\s+(" +
			hourWords.joined(separator: "|") + ")\\s+(AM|PM)\\b"
		if let regex = try? NSRegularExpression(pattern: hourPattern, options: .caseInsensitive) {
			let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
			for match in matches.reversed() {
				guard let fullRange = Range(match.range, in: output),
					  let hourRange = Range(match.range(at: 1), in: output),
					  let minRange = Range(match.range(at: 2), in: output),
					  let ampmRange = Range(match.range(at: 3), in: output) else { continue }

				let hourWord = String(output[hourRange]).lowercased()
				let minWord = String(output[minRange]).lowercased()
				let ampm = String(output[ampmRange]).uppercased()

				if let hour = onesMap[hourWord] ?? tensMap[hourWord],
				   let minutes = onesMap[minWord] ?? tensMap[minWord],
				   hour >= 1, hour <= 12, minutes >= 0, minutes <= 59 {
					let formatted = "\(hour):\(String(format: "%02d", minutes)) \(ampm)"
					output.replaceSubrange(fullRange, with: formatted)
				}
			}
		}

		// Pattern: [number word for hour] AM/PM (no minutes)
		// e.g. "seven PM" → "7 PM"
		let hourOnlyPattern = "\\b(" + hourWords.joined(separator: "|") + ")\\s+(AM|PM)\\b"
		if let regex = try? NSRegularExpression(pattern: hourOnlyPattern, options: .caseInsensitive) {
			let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
			for match in matches.reversed() {
				guard let fullRange = Range(match.range, in: output),
					  let hourRange = Range(match.range(at: 1), in: output),
					  let ampmRange = Range(match.range(at: 2), in: output) else { continue }

				let hourWord = String(output[hourRange]).lowercased()
				let ampm = String(output[ampmRange]).uppercased()

				if let hour = onesMap[hourWord] ?? tensMap[hourWord],
				   hour >= 1, hour <= 12 {
					output.replaceSubrange(fullRange, with: "\(hour) \(ampm)")
				}
			}
		}

		// Pattern: digit hour + digit minutes + AM/PM (e.g. "3 30 PM" → "3:30 PM")
		let digitTimePattern = "\\b(1[0-2]|[1-9])\\s+(\\d{2})\\s+(AM|PM)\\b"
		if let regex = try? NSRegularExpression(pattern: digitTimePattern, options: .caseInsensitive) {
			let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
			for match in matches.reversed() {
				guard let fullRange = Range(match.range, in: output),
					  let hourRange = Range(match.range(at: 1), in: output),
					  let minRange = Range(match.range(at: 2), in: output),
					  let ampmRange = Range(match.range(at: 3), in: output) else { continue }

				let hour = String(output[hourRange])
				let min = String(output[minRange])
				let ampm = String(output[ampmRange]).uppercased()

				if let minVal = Int(min), minVal <= 59 {
					output.replaceSubrange(fullRange, with: "\(hour):\(min) \(ampm)")
				}
			}
		}

		return output
	}

	// MARK: - Deduplication

	/// Remove duplicate adjacent words caused by model stutter.
	/// e.g. "the the quick brown" → "the quick brown"
	static func deduplicateAdjacentWords(_ text: String) -> String {
		let words = text.components(separatedBy: " ")
		guard words.count > 1 else { return text }

		var result: [String] = [words[0]]
		for i in 1..<words.count {
			let current = words[i].lowercased().trimmingCharacters(in: .punctuationCharacters)
			let previous = words[i - 1].lowercased().trimmingCharacters(in: .punctuationCharacters)
			if current != previous || current.isEmpty {
				result.append(words[i])
			}
		}
		return result.joined(separator: " ")
	}

	// MARK: - Email Formatting

	/// Convert spoken email addresses to proper format.
	/// Handles multiple Parakeet output styles:
	/// - Fully spoken: "john at yahoo dot com" → "john@yahoo.com"
	/// - Domain already joined: "john at yahoo.com" → "john@yahoo.com"
	/// - Dotted local part: "john dot doe at company dot com" → "john.doe@company.com"
	static func formatEmailExpressions(_ text: String) -> String {
		var output = text
		let tlds = "com|org|net|edu|gov|io|ai|co|dev|me|info|biz"

		// Pattern 1: Domain already has real period — "john at yahoo.com"
		let joinedPattern = "\\b([\\w]+(?:\\s+dot\\s+[\\w]+)*)\\s+at\\s+([\\w]+(?:\\.[\\w]+)*\\.(?:\(tlds)))\\b"
		if let regex = try? NSRegularExpression(pattern: joinedPattern, options: .caseInsensitive) {
			let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
			for match in matches.reversed() {
				guard let fullRange = Range(match.range, in: output),
					  let localRange = Range(match.range(at: 1), in: output),
					  let domainRange = Range(match.range(at: 2), in: output) else { continue }

				let localPart = String(output[localRange])
					.replacingOccurrences(of: " dot ", with: ".", options: .caseInsensitive)
					.lowercased()
				let domain = String(output[domainRange]).lowercased()

				output.replaceSubrange(fullRange, with: "\(localPart)@\(domain)")
			}
		}

		// Pattern 2: Fully spoken — "john at yahoo dot com"
		let spokenPattern = "\\b([\\w]+(?:\\s+dot\\s+[\\w]+)*)\\s+at\\s+([\\w]+(?:\\s+dot\\s+[\\w]+)*)\\s+dot\\s+(\(tlds))\\b"
		if let regex = try? NSRegularExpression(pattern: spokenPattern, options: .caseInsensitive) {
			let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
			for match in matches.reversed() {
				guard let fullRange = Range(match.range, in: output),
					  let localRange = Range(match.range(at: 1), in: output),
					  let domainRange = Range(match.range(at: 2), in: output),
					  let tldRange = Range(match.range(at: 3), in: output) else { continue }

				let localPart = String(output[localRange])
					.replacingOccurrences(of: " dot ", with: ".", options: .caseInsensitive)
					.lowercased()
				let domainPart = String(output[domainRange])
					.replacingOccurrences(of: " dot ", with: ".", options: .caseInsensitive)
					.lowercased()
				let tld = String(output[tldRange]).lowercased()

				output.replaceSubrange(fullRange, with: "\(localPart)@\(domainPart).\(tld)")
			}
		}

		return output
	}

	// MARK: - Helpers

	/// Format an integer with thousands separators.
	static func formatWithCommas(_ number: Int) -> String {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.groupingSeparator = ","
		return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
	}

	/// Collapse runs of whitespace into single spaces, trim edges.
	private static func normalizeWhitespace(_ text: String) -> String {
		text.replacingOccurrences(of: "[ \t]{2,}", with: " ", options: .regularExpression)
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
