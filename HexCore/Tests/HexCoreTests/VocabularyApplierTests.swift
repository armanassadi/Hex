import XCTest
@testable import HexCore

final class VocabularyApplierTests: XCTestCase {

	func testEmptyVocabularyReturnsOriginal() {
		let result = VocabularyApplier.apply("hello world", vocabulary: [])
		XCTAssertEqual(result, "hello world")
	}

	func testCorrectsCasingToMatchVocabulary() {
		let result = VocabularyApplier.apply(
			"i was talking about kubernetes and docker",
			vocabulary: ["Kubernetes", "Docker"]
		)
		XCTAssertEqual(result, "i was talking about Kubernetes and Docker")
	}

	func testAllCapsGetsCorrected() {
		let result = VocabularyApplier.apply(
			"KUBERNETES is great",
			vocabulary: ["Kubernetes"]
		)
		XCTAssertEqual(result, "Kubernetes is great")
	}

	func testDoesNotMatchInsideWords() {
		let result = VocabularyApplier.apply(
			"something is fun",
			vocabulary: ["some"]
		)
		// "some" should not match inside "something"
		XCTAssertEqual(result, "something is fun")
	}

	func testMatchesWholeWordBoundaries() {
		let result = VocabularyApplier.apply(
			"arman said hello",
			vocabulary: ["Arman"]
		)
		XCTAssertEqual(result, "Arman said hello")
	}

	func testMultipleOccurrences() {
		let result = VocabularyApplier.apply(
			"arman asked arman about arman",
			vocabulary: ["Arman"]
		)
		XCTAssertEqual(result, "Arman asked Arman about Arman")
	}

	func testMultiWordPhrase() {
		let result = VocabularyApplier.apply(
			"we use visual studio code for development",
			vocabulary: ["Visual Studio Code"]
		)
		XCTAssertEqual(result, "we use Visual Studio Code for development")
	}

	func testAlreadyCorrectCasingUnchanged() {
		let result = VocabularyApplier.apply(
			"Kubernetes is great",
			vocabulary: ["Kubernetes"]
		)
		XCTAssertEqual(result, "Kubernetes is great")
	}

	func testWhitespaceOnlyWordIsSkipped() {
		let result = VocabularyApplier.apply(
			"hello world",
			vocabulary: ["  ", ""]
		)
		XCTAssertEqual(result, "hello world")
	}

	func testAcronymCorrection() {
		let result = VocabularyApplier.apply(
			"the api uses graphql over https",
			vocabulary: ["API", "GraphQL", "HTTPS"]
		)
		XCTAssertEqual(result, "the API uses GraphQL over HTTPS")
	}

	func testPunctuationAdjacentWord() {
		let result = VocabularyApplier.apply(
			"have you tried kubernetes?",
			vocabulary: ["Kubernetes"]
		)
		XCTAssertEqual(result, "have you tried Kubernetes?")
	}

	func testWordAtStartOfString() {
		let result = VocabularyApplier.apply(
			"kubernetes is a container orchestrator",
			vocabulary: ["Kubernetes"]
		)
		XCTAssertEqual(result, "Kubernetes is a container orchestrator")
	}

	func testWordAtEndOfString() {
		let result = VocabularyApplier.apply(
			"we migrated to kubernetes",
			vocabulary: ["Kubernetes"]
		)
		XCTAssertEqual(result, "we migrated to Kubernetes")
	}

	func testSpecialRegexCharactersInWord() {
		let result = VocabularyApplier.apply(
			"use c++ for performance",
			vocabulary: ["C++"]
		)
		XCTAssertEqual(result, "use C++ for performance")
	}

	func testVocabularyWithSettingsRoundTrip() throws {
		let settings = HexSettings(customVocabulary: ["Kubernetes", "GraphQL", "Arman"])
		let data = try JSONEncoder().encode(settings)
		let decoded = try JSONDecoder().decode(HexSettings.self, from: data)
		XCTAssertEqual(decoded.customVocabulary, ["Kubernetes", "GraphQL", "Arman"])
	}
}
