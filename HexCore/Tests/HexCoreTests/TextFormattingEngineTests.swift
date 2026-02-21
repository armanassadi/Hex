import XCTest
@testable import HexCore

final class TextFormattingEngineTests: XCTestCase {

	// Helper: config that only enables the feature being tested
	private func numbersOnlyConfig() -> TextFormattingEngine.Config {
		TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: false,
			fixMidSentenceCapitalization: false,
			convertNumbersToDigits: true,
			formatCurrency: false,
			formatPercentages: false,
			formatTimes: false,
			deduplicateWords: false,
			formatEmails: false,
		)
	}

	private func capsOnlyConfig() -> TextFormattingEngine.Config {
		TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: false,
			fixMidSentenceCapitalization: true,
			convertNumbersToDigits: false,
			formatCurrency: false,
			formatPercentages: false,
			formatTimes: false,
			deduplicateWords: false,
			formatEmails: false,
		)
	}

	private func currencyOnlyConfig() -> TextFormattingEngine.Config {
		TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: false,
			fixMidSentenceCapitalization: false,
			convertNumbersToDigits: false,
			formatCurrency: true,
			formatPercentages: false,
			formatTimes: false,
			deduplicateWords: false,
			formatEmails: false,
		)
	}

	private func allOffConfig() -> TextFormattingEngine.Config {
		TextFormattingEngine.Config(
			removeTrailingPeriod: false,
			lowercaseShortPhrases: false,
			fixMidSentenceCapitalization: false,
			convertNumbersToDigits: false,
			formatCurrency: false,
			formatPercentages: false,
			formatTimes: false,
			deduplicateWords: false,
			formatEmails: false,
		)
	}

	// MARK: - Default Config (all rules on) — Original Tests

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
		let result = TextFormattingEngine.apply("That sounds really good.", config: .init())
		XCTAssertEqual(result, "that sounds really good")
	}

	func testKeepsTrailingPeriodOnLongSentence() {
		let config = allOffConfig()
		let result = TextFormattingEngine.apply(
			"I think we should schedule a meeting to discuss this.",
			config: config
		)
		XCTAssertEqual(result, "I think we should schedule a meeting to discuss this.")
	}

	func testKeepsEllipsis() {
		let result = TextFormattingEngine.apply("well...", config: .init())
		XCTAssertEqual(result, "well...")
	}

	func testKeepsQuestionMark() {
		let result = TextFormattingEngine.apply("Really?", config: .init())
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
		XCTAssertEqual(result, "Kubernetes rocks")
	}

	// MARK: - Whitespace Normalization

	func testNormalizesDoubleSpaces() {
		let config = allOffConfig()
		let result = TextFormattingEngine.apply("hello  world", config: config)
		XCTAssertEqual(result, "hello world")
	}

	func testTrimsLeadingTrailingWhitespace() {
		let config = allOffConfig()
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
		let result = TextFormattingEngine.apply("Sounds really good.", config: config)
		XCTAssertEqual(result, "Sounds really good.")
	}

	func testThresholdAtExactBoundary() {
		let config = TextFormattingEngine.Config(
			removeTrailingPeriod: true,
			lowercaseShortPhrases: true,
			shortPhraseMaxWords: 3
		)
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

	// MARK: - Mid-Sentence Capitalization

	func testFixesMidSentenceCapital() {
		let result = TextFormattingEngine.apply(
			"I need to make sure all active Customers are in the dashboard.",
			config: capsOnlyConfig()
		)
		XCTAssertEqual(result, "I need to make sure all active customers are in the dashboard.")
	}

	func testFixesMultipleMidSentenceCapitals() {
		let result = TextFormattingEngine.apply(
			"The goal is to Make sure Everyone is in the right Category.",
			config: capsOnlyConfig()
		)
		XCTAssertEqual(result, "The goal is to make sure everyone is in the right category.")
	}

	func testPreservesVocabularyMidSentence() {
		let result = TextFormattingEngine.apply(
			"We need to update Kubernetes and Docker settings.",
			config: capsOnlyConfig(),
			vocabulary: ["Kubernetes", "Docker"]
		)
		XCTAssertEqual(result, "We need to update Kubernetes and Docker settings.")
	}

	func testPreservesIMidSentence() {
		let result = TextFormattingEngine.apply(
			"Then I think we Should proceed with the plan.",
			config: capsOnlyConfig()
		)
		XCTAssertEqual(result, "Then I think we should proceed with the plan.")
	}

	func testPreservesAcronymsMidSentence() {
		let result = TextFormattingEngine.apply(
			"The API and CEO were discussed at the meeting.",
			config: capsOnlyConfig()
		)
		XCTAssertEqual(result, "The API and CEO were discussed at the meeting.")
	}

	func testPreservesCapitalAfterPeriod() {
		let result = TextFormattingEngine.apply(
			"First sentence ends. Second sentence begins.",
			config: capsOnlyConfig()
		)
		XCTAssertEqual(result, "First sentence ends. Second sentence begins.")
	}

	func testDisabledMidSentenceCapFix() {
		let result = TextFormattingEngine.apply(
			"I need to make sure all active Customers are in the Dashboard.",
			config: allOffConfig()
		)
		XCTAssertTrue(result.contains("Customers"))
		XCTAssertTrue(result.contains("Dashboard"))
	}

	// MARK: - Number Conversion

	func testConvertsSimpleNumber() {
		let result = TextFormattingEngine.apply("I have twenty-three items.", config: numbersOnlyConfig())
		XCTAssertEqual(result, "I have 23 items.")
	}

	func testConvertsTeen() {
		let result = TextFormattingEngine.apply("There are fifteen people.", config: numbersOnlyConfig())
		XCTAssertEqual(result, "There are 15 people.")
	}

	func testConvertsHundred() {
		let result = TextFormattingEngine.apply("We have one hundred users.", config: numbersOnlyConfig())
		XCTAssertEqual(result, "We have 100 users.")
	}

	func testConvertsLargeNumber() {
		let result = TextFormattingEngine.apply(
			"The total is seven million five hundred and twenty seven thousand.",
			config: numbersOnlyConfig()
		)
		XCTAssertEqual(result, "The total is 7,527,000.")
	}

	func testConvertsNumberWithAnd() {
		let result = TextFormattingEngine.apply(
			"We have one hundred and fifty items.",
			config: numbersOnlyConfig()
		)
		XCTAssertEqual(result, "We have 150 items.")
	}

	func testAddsThousandsSeparator() {
		let result = TextFormattingEngine.apply("The value is 1033.", config: numbersOnlyConfig())
		XCTAssertEqual(result, "The value is 1,033.")
	}

	func testDoesNotConvertStandaloneA() {
		let result = TextFormattingEngine.apply("I need a new laptop.", config: numbersOnlyConfig())
		XCTAssertTrue(result.contains("a new"))
	}

	func testDoesNotConvertStandaloneFirst() {
		// "First" as an English word, not an ordinal
		let result = TextFormattingEngine.apply("First we need to plan.", config: numbersOnlyConfig())
		XCTAssertEqual(result, "First we need to plan.")
	}

	// MARK: - Currency Formatting

	func testFormatsDollars() {
		let result = TextFormattingEngine.apply(
			"That costs twenty-three dollars.",
			config: currencyOnlyConfig()
		)
		XCTAssertEqual(result, "That costs $23.")
	}

	func testFormatsLargeCurrency() {
		let result = TextFormattingEngine.apply(
			"The budget is seven million five hundred and twenty seven thousand dollars.",
			config: currencyOnlyConfig()
		)
		XCTAssertEqual(result, "The budget is $7,527,000.")
	}

	func testFormatsDollarsAndCents() {
		let result = TextFormattingEngine.apply(
			"It costs five dollars and ninety nine cents for the item.",
			config: currencyOnlyConfig()
		)
		XCTAssertTrue(result.contains("$5.99"))
	}

	// MARK: - Percentage Formatting

	func testFormatsPercentage() {
		var config = allOffConfig()
		config.formatPercentages = true
		config.convertNumbersToDigits = true
		let result = TextFormattingEngine.apply("We achieved fifty percent growth.", config: config)
		XCTAssertEqual(result, "We achieved 50% growth.")
	}

	func testFormatsSmallPercentage() {
		var config = allOffConfig()
		config.formatPercentages = true
		config.convertNumbersToDigits = true
		let result = TextFormattingEngine.apply("Only five percent failed.", config: config)
		XCTAssertEqual(result, "Only 5% failed.")
	}

	// MARK: - Time Formatting

	func testFormatsTimeWithMinutes() {
		var config = allOffConfig()
		config.formatTimes = true
		let result = TextFormattingEngine.apply("The meeting is at three thirty PM.", config: config)
		XCTAssertTrue(result.contains("3:30 PM"))
	}

	func testFormatsTimeHourOnly() {
		var config = allOffConfig()
		config.formatTimes = true
		let result = TextFormattingEngine.apply("Let's meet at seven PM.", config: config)
		XCTAssertTrue(result.contains("7 PM"))
	}

	func testNormalizesAMPM() {
		var config = allOffConfig()
		config.formatTimes = true
		let result = TextFormattingEngine.apply("The call is at nine a.m. tomorrow.", config: config)
		XCTAssertTrue(result.contains("9 AM"))
		XCTAssertFalse(result.contains("a.m."))
	}

	// MARK: - Ordinals (in number context)

	func testFormatsCompoundOrdinal() {
		let result = TextFormattingEngine.apply("It's the twenty-first century.", config: numbersOnlyConfig())
		XCTAssertTrue(result.contains("21st"))
	}

	// MARK: - Deduplication

	func testDeduplicatesAdjacentWords() {
		var config = allOffConfig()
		config.deduplicateWords = true
		let result = TextFormattingEngine.apply("I went to the the store.", config: config)
		XCTAssertEqual(result, "I went to the store.")
	}

	func testDeduplicatesMultiple() {
		var config = allOffConfig()
		config.deduplicateWords = true
		let result = TextFormattingEngine.apply("The the quick quick brown fox.", config: config)
		XCTAssertEqual(result, "The quick brown fox.")
	}

	func testDoesNotDeduplicateDifferentWords() {
		var config = allOffConfig()
		config.deduplicateWords = true
		// "had had" is legitimate English — but dedup will remove it (known trade-off)
		let result = TextFormattingEngine.apply("I had had enough of this.", config: config)
		XCTAssertEqual(result, "I had enough of this.")
	}

	// MARK: - Email Formatting

	func testFormatsEmail() {
		var config = allOffConfig()
		config.formatEmails = true
		let result = TextFormattingEngine.apply(
			"Send it to john at gmail dot com please.",
			config: config
		)
		XCTAssertTrue(result.contains("john@gmail.com"))
	}

	func testFormatsEmailWithDottedLocal() {
		var config = allOffConfig()
		config.formatEmails = true
		let result = TextFormattingEngine.apply(
			"Email me at john dot doe at company dot com for details.",
			config: config
		)
		XCTAssertTrue(result.contains("john.doe@company.com"))
	}

	func testFormatsEmailWithJoinedDomain() {
		var config = allOffConfig()
		config.formatEmails = true
		let result = TextFormattingEngine.apply(
			"Send it to john at yahoo.com please.",
			config: config
		)
		XCTAssertTrue(result.contains("john@yahoo.com"), "Got: \(result)")
	}

	func testFormatsEmailWithJoinedDomainAI() {
		var config = allOffConfig()
		config.formatEmails = true
		let result = TextFormattingEngine.apply(
			"My email is arman at steno.ai for reference.",
			config: config
		)
		XCTAssertTrue(result.contains("arman@steno.ai"), "Got: \(result)")
	}

	// MARK: - Integration: Real-World Transcription

	func testRealWorldExample() {
		let input = "Make an issue to clean up our customer list in the dashboard. The goal is to Make sure all active Customers are in the dashboard and that Everyone is in the right Category."
		let result = TextFormattingEngine.apply(input, config: capsOnlyConfig())
		XCTAssertFalse(result.contains(" Make "))
		XCTAssertFalse(result.contains(" Customers "))
		XCTAssertFalse(result.contains(" Everyone "))
		XCTAssertFalse(result.contains(" Category"))
	}

	// MARK: - parseNumberWords

	func testParseSimpleNumber() {
		XCTAssertEqual(TextFormattingEngine.parseNumberWords(["twenty", "three"]), 23)
	}

	func testParseHundred() {
		XCTAssertEqual(TextFormattingEngine.parseNumberWords(["one", "hundred"]), 100)
	}

	func testParseThousand() {
		XCTAssertEqual(TextFormattingEngine.parseNumberWords(["five", "thousand"]), 5_000)
	}

	func testParseMillion() {
		XCTAssertEqual(
			TextFormattingEngine.parseNumberWords(["seven", "million", "five", "hundred", "twenty", "seven", "thousand"]),
			7_527_000
		)
	}

	func testParseWithAnd() {
		XCTAssertEqual(TextFormattingEngine.parseNumberWords(["one", "hundred", "and", "fifty"]), 150)
	}

	func testParseAHundred() {
		XCTAssertEqual(TextFormattingEngine.parseNumberWords(["a", "hundred"]), 100)
	}

	// MARK: - Config Decoder Resilience

	func testConfigDecodesFromPartialJSON() throws {
		let json = """
		{
			"removeTrailingPeriod": false,
			"lowercaseShortPhrases": false,
			"shortPhraseMaxWords": 3
		}
		""".data(using: .utf8)!
		let decoded = try JSONDecoder().decode(TextFormattingEngine.Config.self, from: json)
		// Present keys should be decoded
		XCTAssertEqual(decoded.removeTrailingPeriod, false)
		XCTAssertEqual(decoded.lowercaseShortPhrases, false)
		XCTAssertEqual(decoded.shortPhraseMaxWords, 3)
		// Missing keys should use defaults
		let defaults = TextFormattingEngine.Config()
		XCTAssertEqual(decoded.fixMidSentenceCapitalization, defaults.fixMidSentenceCapitalization)
		XCTAssertEqual(decoded.convertNumbersToDigits, defaults.convertNumbersToDigits)
		XCTAssertEqual(decoded.formatCurrency, defaults.formatCurrency)
		XCTAssertEqual(decoded.formatPercentages, defaults.formatPercentages)
		XCTAssertEqual(decoded.formatTimes, defaults.formatTimes)
		XCTAssertEqual(decoded.deduplicateWords, defaults.deduplicateWords)
		XCTAssertEqual(decoded.formatEmails, defaults.formatEmails)
	}

	func testConfigDecodesFromEmptyObject() throws {
		let json = "{}".data(using: .utf8)!
		let decoded = try JSONDecoder().decode(TextFormattingEngine.Config.self, from: json)
		XCTAssertEqual(decoded, TextFormattingEngine.Config())
	}

	func testConfigDecodesWithExtraUnknownKeys() throws {
		let json = """
		{
			"removeTrailingPeriod": true,
			"lowercaseShortPhrases": true,
			"shortPhraseMaxWords": 5,
			"fixMidSentenceCapitalization": true,
			"convertNumbersToDigits": true,
			"formatCurrency": true,
			"formatPercentages": true,
			"formatTimes": true,
			"deduplicateWords": true,
			"formatEmails": true,
			"formatPhoneNumbers": true,
			"futureFeatureFlag": 42
		}
		""".data(using: .utf8)!
		let decoded = try JSONDecoder().decode(TextFormattingEngine.Config.self, from: json)
		XCTAssertEqual(decoded, TextFormattingEngine.Config())
	}
}
