import Foundation

/// Applies vocabulary corrections to transcribed text.
///
/// Each vocabulary word is matched case-insensitively at word boundaries and
/// replaced with the user's preferred casing. For example, adding "Kubernetes"
/// to the vocabulary will correct "kubernetes" or "KUBERNETES" in the
/// transcript to "Kubernetes".
public enum VocabularyApplier {
	public static func apply(_ text: String, vocabulary: [String]) -> String {
		guard !vocabulary.isEmpty else { return text }
		var output = text
		for word in vocabulary {
			let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { continue }
			let escaped = NSRegularExpression.escapedPattern(for: trimmed)
			let pattern = "(?<!\\w)\(escaped)(?!\\w)"
			// Replace with the exact casing the user provided
			let replacement = trimmed.replacingOccurrences(of: "\\", with: "\\\\")
			output = output.replacingOccurrences(
				of: pattern,
				with: replacement,
				options: [.regularExpression, .caseInsensitive]
			)
		}
		return output
	}
}
