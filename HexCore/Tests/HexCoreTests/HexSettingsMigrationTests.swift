import XCTest
@testable import HexCore

final class HexSettingsMigrationTests: XCTestCase {
	func testV1FixtureMigratesToCurrentDefaults() throws {
		let data = try loadFixture(named: "v1")
		let decoded = try JSONDecoder().decode(HexSettings.self, from: data)

		XCTAssertEqual(decoded.recordingAudioBehavior, .pauseMedia, "Legacy pauseMediaOnRecord bool should map to pauseMedia behavior")
		XCTAssertEqual(decoded.soundEffectsEnabled, false)
		XCTAssertEqual(decoded.soundEffectsVolume, HexSettings.baseSoundEffectsVolume)
		XCTAssertEqual(decoded.openOnLogin, true)
		XCTAssertEqual(decoded.showDockIcon, false)
		XCTAssertEqual(decoded.selectedModel, "whisper-large-v3")
		XCTAssertEqual(decoded.useClipboardPaste, false)
		XCTAssertEqual(decoded.preventSystemSleep, true)
		XCTAssertEqual(decoded.minimumKeyTime, 0.25)
		XCTAssertEqual(decoded.copyToClipboard, true)
		XCTAssertEqual(decoded.recordingMode, .doubleTapLock, "Legacy useDoubleTapOnly=true should map to doubleTapLock")
		XCTAssertEqual(decoded.outputLanguage, "en")
		XCTAssertEqual(decoded.selectedMicrophoneID, "builtin:mic")
		XCTAssertEqual(decoded.saveTranscriptionHistory, false)
		XCTAssertEqual(decoded.maxHistoryEntries, 10)
		XCTAssertEqual(decoded.hasCompletedModelBootstrap, true)
		XCTAssertEqual(decoded.hasCompletedStorageMigration, true)
		XCTAssertEqual(decoded.wordRemovalsEnabled, true, "Default for wordRemovalsEnabled should be true")
		XCTAssertEqual(decoded.customVocabulary, [], "Legacy fixture should default to empty vocabulary")
		XCTAssertEqual(decoded.smartFormattingEnabled, true, "Smart formatting should default to enabled")
		XCTAssertEqual(decoded.smartFormattingConfig, TextFormattingEngine.Config(), "Smart formatting config should use defaults")
	}

	func testEncodeDecodeRoundTripPreservesDefaults() throws {
		let settings = HexSettings()
		let data = try JSONEncoder().encode(settings)
		let decoded = try JSONDecoder().decode(HexSettings.self, from: data)
		XCTAssertEqual(decoded, settings)
	}

	func testSettingsDecodeSucceedsWithPartialSmartFormattingConfig() throws {
		let json = """
		{
			"soundEffectsEnabled": false,
			"soundEffectsVolume": 0.05,
			"hotkey": {"modifiers": {"modifiers": [{"kind": "option", "side": "either"}]}},
			"openOnLogin": true,
			"showDockIcon": false,
			"selectedModel": "parakeet-tdt-0.6b-v2-coreml",
			"useClipboardPaste": true,
			"preventSystemSleep": true,
			"recordingAudioBehavior": "mute",
			"minimumKeyTime": 0.3,
			"copyToClipboard": false,
			"recordingMode": "toggle",
			"saveTranscriptionHistory": true,
			"hasCompletedModelBootstrap": true,
			"hasCompletedStorageMigration": true,
			"wordRemovalsEnabled": true,
			"wordRemovals": [],
			"wordRemappings": [],
			"customVocabulary": ["Kubernetes", "API"],
			"smartFormattingEnabled": true,
			"smartFormattingConfig": {
				"removeTrailingPeriod": false,
				"lowercaseShortPhrases": true,
				"shortPhraseMaxWords": 8
			}
		}
		""".data(using: .utf8)!
		let decoded = try JSONDecoder().decode(HexSettings.self, from: json)

		// Non-Config settings must survive
		XCTAssertEqual(decoded.soundEffectsEnabled, false)
		XCTAssertEqual(decoded.soundEffectsVolume, 0.05)
		XCTAssertEqual(decoded.selectedModel, "parakeet-tdt-0.6b-v2-coreml")
		XCTAssertEqual(decoded.customVocabulary, ["Kubernetes", "API"])
		XCTAssertEqual(decoded.minimumKeyTime, 0.3)
		XCTAssertEqual(decoded.openOnLogin, true)
		XCTAssertEqual(decoded.hasCompletedModelBootstrap, true)
		XCTAssertEqual(decoded.recordingAudioBehavior, .mute)

		// Config fields that were present should be decoded
		XCTAssertEqual(decoded.smartFormattingConfig.removeTrailingPeriod, false)
		XCTAssertEqual(decoded.smartFormattingConfig.lowercaseShortPhrases, true)
		XCTAssertEqual(decoded.smartFormattingConfig.shortPhraseMaxWords, 8)

		// Config fields that were missing should use defaults
		let defaults = TextFormattingEngine.Config()
		XCTAssertEqual(decoded.smartFormattingConfig.fixMidSentenceCapitalization, defaults.fixMidSentenceCapitalization)
		XCTAssertEqual(decoded.smartFormattingConfig.formatEmails, defaults.formatEmails)
		XCTAssertEqual(decoded.smartFormattingConfig.deduplicateWords, defaults.deduplicateWords)
	}

	func testSettingsDecodePreservesAllFieldsWhenConfigIsEmpty() throws {
		let json = """
		{
			"soundEffectsEnabled": false,
			"selectedModel": "whisper-large-v3",
			"customVocabulary": ["Docker"],
			"smartFormattingConfig": {}
		}
		""".data(using: .utf8)!
		let decoded = try JSONDecoder().decode(HexSettings.self, from: json)

		XCTAssertEqual(decoded.soundEffectsEnabled, false)
		XCTAssertEqual(decoded.selectedModel, "whisper-large-v3")
		XCTAssertEqual(decoded.customVocabulary, ["Docker"])
		XCTAssertEqual(decoded.smartFormattingConfig, TextFormattingEngine.Config(),
			"Empty config object should produce all defaults, not crash")
	}

	private func loadFixture(named name: String) throws -> Data {
		guard let url = Bundle.module.url(
			forResource: name,
			withExtension: "json",
			subdirectory: "Fixtures/HexSettings"
		) else {
			XCTFail("Missing fixture \(name).json")
			throw NSError(domain: "Fixture", code: 0)
		}
		return try Data(contentsOf: url)
	}
}
