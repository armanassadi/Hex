import XCTest
@testable import HexCore

final class TextFormattingEngineTests: XCTestCase {

	// MARK: - Default Config (all rules on)

	func testEmptyStringReturnsEmpty() {
		let result = TextFormattingEngine.apply("", config: .init())
		XCTAssertEqual(result, "")
	}

	func testWhitespaceOnlyReturnsEmpty() {
		let result = TextFormattingEngine.apply("   ", config: .init())
		XCTAssertEqual(result, "")
	}

	// MARK: - Trailing Period Removal

	func testRemovesTrailingPeriodOnShortPhrase() {
		let result = TextFormattingEngine.apply("awesome.", config: .init())
		XCTAssertEqual(result, "awesome")
	}

	func testRemovesTrailingPeriodAtThreshold() {
		// Default threshold is 5 words
		let result = TextFormattingEngine.apply("That sounds really good.", config: .init())
		// 4 words → short phrase → period removed + lowercased
		XCTAssertEqual(result, "that sounds really good")
	}

	func testKeepsTrailingPeriodOnLongSentence() {
		let result = TextFormattingEngine.apply(
			"I think we should schedule a meeting to discuss this.",
			config: .init()
		)
		// 10 words → not short → period stays, no lowercasing
		XCTAssertEqual(result, "I think we should schedule a meeting to discuss this.")
	}

	func testKeepsEllipsis() {
		let result = TextFormattingEngine.apply("well...", config: .init())
		XCTAssertEqual(result, "well...")
	}

	func testKeepsQuestionMark() {
		let result = TextFormattingEngine.apply("Really?", config: .init())
		// Short phrase, no period → lowercased only
		XCTAssertEqual(result, "really?")
	}

	func testKeepsExclamationMark() {
		let result = TextFormattingEngine.apply("Nice!", config: .init())
		XCTAssertEqual(result, "nice!")
	}

	func testDisabledTrailingPeriodRemoval() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: false
		)
		let result = TextFormattingEngine.apply("awesome.", config: config)
		XCTAssertEqual(result, "awesome.")
	}

	// MARK: - Lowercase Short Phrases

	func testLowercasesShortPhrase() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: true
		)
		let result = TextFormattingEngine.apply("Sounds good", config: config)
		XCTAssertEqual(result, "sounds good")
	}

	func testDoesNotLowercaseLongSentence() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: true
		)
		let result = TextFormattingEngine.apply(
			"I think we should definitely go with that option",
			config: config
		)
		XCTAssertEqual(result, "I think we should definitely go with that option")
	}

	func testProtectsVocabularyWordFromLowercasing() {
		let result = TextFormattingEngine.apply(
			"Arman said hello",
			config: .init(),
			vocabulary: ["Arman"]
		)
		// "Arman" is in vocabulary → first letter stays uppercase
		XCTAssertEqual(result, "Arman said hello")
	}

	func testProtectsI() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: true
		)
		let result = TextFormattingEngine.apply("I agree", config: config)
		XCTAssertEqual(result, "I agree")
	}

	func testAlreadyLowercaseUnchanged() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: true
		)
		let result = TextFormattingEngine.apply("sounds good", config: config)
		XCTAssertEqual(result, "sounds good")
	}

	func testDisabledLowercasing() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: false
		)
		let result = TextFormattingEngine.apply("Sounds good", config: config)
		XCTAssertEqual(result, "Sounds good")
	}

	// MARK: - Combined Rules

	func testBothRulesCombined() {
		let result = TextFormattingEngine.apply("Sounds good.", config: .init())
		XCTAssertEqual(result, "sounds good")
	}

	func testShortPhraseWithVocabularyAndPeriod() {
		let result = TextFormattingEngine.apply(
			"Kubernetes rocks.",
			config: .init(),
			vocabulary: ["Kubernetes"]
		)
		// "Kubernetes" is vocab → no lowercasing, but period is removed
		XCTAssertEqual(result, "Kubernetes rocks")
	}

	// MARK: - Whitespace Normalization

	func testNormalizesDoubleSpaces() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: false
		)
		let result = TextFormattingEngine.apply("hello  world", config: config)
		XCTAssertEqual(result, "hello world")
	}

	func testTrimsLeadingTrailingWhitespace() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: false
		)
		let result = TextFormattingEngine.apply("  hello world  ", config: config)
		XCTAssertEqual(result, "hello world")
	}

	// MARK: - Threshold Configuration

	func testCustomThreshold() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: true,
			lowercaseShortPhrases: true,
			shortPhraseMaxWords: 2
		)
		// 3 words > threshold of 2 → not short
		let result = TextFormattingEngine.apply("Sounds really good.", config: config)
		XCTAssertEqual(result, "Sounds really good.")
	}

	func testThresholdAtExactBoundary() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: true,
			lowercaseShortPhrases: true,
			shortPhraseMaxWords: 3
		)
		// Exactly 3 words = short
		let result = TextFormattingEngine.apply("Sounds really good.", config: config)
		XCTAssertEqual(result, "sounds really good")
	}

	// MARK: - Edge Cases

	func testSingleWord() {
		let result = TextFormattingEngine.apply("Hello.", config: .init())
		XCTAssertEqual(result, "hello")
	}

	func testSingleWordNoTrailingPeriod() {
		let result = TextFormattingEngine.apply("Hello", config: .init())
		XCTAssertEqual(result, "hello")
	}

	func testAcronymNotLowercased() {
		let result = TextFormattingEngine.apply(
			"API is ready",
			config: .init(),
			vocabulary: ["API"]
		)
		XCTAssertEqual(result, "API is ready")
	}

	// MARK: - Config Codable Round-Trip

	func testConfigRoundTrip() throws {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: true,
			shortPhraseMaxWords: 8
		)
		let data = try JSONEncoder().encode(config)
		let decoded = try JSONDecoder().decode(TextFormattingEngine.Config.self, from: data)
		XCTAssertEqual(decoded, config)
	}

	func testDefaultConfigRoundTrip() throws {
		let config = TextFormattingEngine.Config()
		let data = try JSONEncoder().encode(config)
		let decoded = try JSONDecoder().decode(TextFormattingEngine.Config.self, from: data)
		XCTAssertEqual(decoded, config)
	}

	// MARK: - Settings Integration

	func testSettingsWithSmartFormatting() throws {
		let settings = HexSettings(
			smartFormattingEnabled: true,
			smartFormattingConfig: .init(
				removeTrailingPeriod: true,
				lowercaseShortPhrases: false,
				shortPhraseMaxWords: 3
			)
		)
		let data = try JSONEncoder().encode(settings)
		let decoded = try JSONDecoder().decode(HexSettings.self, from: data)
		XCTAssertEqual(decoded.smartFormattingEnabled, true)
		XCTAssertEqual(decoded.smartFormattingConfig.removeTrailingPeriod, true)
		XCTAssertEqual(decoded.smartFormattingConfig.lowercaseShortPhrases, false)
		XCTAssertEqual(decoded.smartFormattingConfig.shortPhraseMaxWords, 3)
	}
}
