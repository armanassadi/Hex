import ComposableArchitecture
import HexCore
import Inject
import SwiftUI

struct WordRemappingsView: View {
	@ObserveInjection var inject
	@Bindable var store: StoreOf<SettingsFeature>
	@FocusState private var isScratchpadFocused: Bool
	@State private var activeSection: ModificationSection = .vocabulary

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				VStack(alignment: .leading, spacing: 6) {
					Text("Transcript Modifications")
						.font(.title2.bold())
					Text("Add vocabulary words and remove filler from every transcript.")
						.font(.callout)
						.foregroundStyle(.secondary)
				}

				GroupBox {
					VStack(alignment: .leading, spacing: 10) {
						HStack(spacing: 12) {
							VStack(alignment: .leading, spacing: 4) {
								Text("Scratchpad")
									.font(.caption.weight(.semibold))
									.foregroundStyle(.secondary)
								TextField("Say something…", text: $store.remappingScratchpadText)
									.textFieldStyle(.roundedBorder)
									.focused($isScratchpadFocused)
									.onChange(of: isScratchpadFocused) { _, newValue in
										store.send(.setRemappingScratchpadFocused(newValue))
									}
							}

							VStack(alignment: .leading, spacing: 4) {
								Text("Preview")
									.font(.caption.weight(.semibold))
									.foregroundStyle(.secondary)
								Text(previewText.isEmpty ? "—" : previewText)
									.font(.body)
									.frame(maxWidth: .infinity, alignment: .leading)
									.padding(.horizontal, 8)
									.padding(.vertical, 6)
									.background(
										RoundedRectangle(cornerRadius: 6)
											.fill(Color(nsColor: .controlBackgroundColor))
									)
							}
						}
					}
					.padding(.vertical, 6)
				}

				Picker("Modification Type", selection: $activeSection) {
					ForEach(ModificationSection.allCases) { section in
						Text(section.title).tag(section)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()

				switch activeSection {
				case .vocabulary:
					vocabularySection
				case .removals:
					removalsSection
				case .formatting:
					formattingSection
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding()
		}
		.onDisappear {
			store.send(.setRemappingScratchpadFocused(false))
		}
		.enableInjection()
	}

	private var vocabularySection: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 10) {
				vocabularyColumnHeaders

				LazyVStack(alignment: .leading, spacing: 6) {
					ForEach(Array(store.hexSettings.customVocabulary.enumerated()), id: \.offset) { index, _ in
						VocabularyRow(
							word: $store.hexSettings.customVocabulary[index],
							onDelete: { store.send(.removeVocabularyWord(index)) }
						)
					}
				}

				HStack {
					Button {
						store.send(.addVocabularyWord)
					} label: {
						Label("Add Word", systemImage: "plus")
					}
					Spacer()
				}
			}
			.padding(.vertical, 4)
		} label: {
			VStack(alignment: .leading, spacing: 4) {
				Text("Vocabulary")
					.font(.headline)
				Text("Add names, companies, acronyms, and jargon to correct casing in transcripts.")
					.settingsCaption()
			}
		}
	}

	private var removalsSection: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 10) {
				Toggle("Enable Word Removals", isOn: $store.hexSettings.wordRemovalsEnabled)
					.toggleStyle(.checkbox)

				removalsColumnHeaders

				LazyVStack(alignment: .leading, spacing: 6) {
					ForEach(store.hexSettings.wordRemovals) { removal in
						if let removalBinding = removalBinding(for: removal.id) {
							RemovalRow(removal: removalBinding) {
								store.send(.removeWordRemoval(removal.id))
							}
						}
					}
				}

				HStack {
					Button {
						store.send(.addWordRemoval)
					} label: {
						Label("Add Removal", systemImage: "plus")
					}
					Spacer()
				}
			}
			.padding(.vertical, 4)
		} label: {
			VStack(alignment: .leading, spacing: 4) {
				Text("Word Removals")
					.font(.headline)
				Text("Remove filler words using case-insensitive regex patterns.")
					.settingsCaption()
			}
		}
	}

	private var formattingSection: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 10) {
				Toggle("Enable Smart Formatting", isOn: $store.hexSettings.smartFormattingEnabled)
					.toggleStyle(.checkbox)

				Toggle(
					"Remove trailing period on short phrases",
					isOn: $store.hexSettings.smartFormattingConfig.removeTrailingPeriod
				)
				.toggleStyle(.checkbox)
				.disabled(!store.hexSettings.smartFormattingEnabled)

				Toggle(
					"Lowercase short phrases",
					isOn: $store.hexSettings.smartFormattingConfig.lowercaseShortPhrases
				)
				.toggleStyle(.checkbox)
				.disabled(!store.hexSettings.smartFormattingEnabled)

				HStack {
					Text("Short phrase threshold:")
					Picker(
						"",
						selection: $store.hexSettings.smartFormattingConfig.shortPhraseMaxWords
					) {
						ForEach(2...10, id: \.self) { count in
							Text("\(count) words").tag(count)
						}
					}
					.labelsHidden()
					.frame(width: 120)
					.disabled(!store.hexSettings.smartFormattingEnabled)
				}
			}
			.padding(.vertical, 4)
		} label: {
			VStack(alignment: .leading, spacing: 4) {
				Text("Smart Formatting")
					.font(.headline)
				Text("Automatically clean up short phrases — strip trailing periods, lowercase casual replies.")
					.settingsCaption()
			}
		}
	}

	private var vocabularyColumnHeaders: some View {
		HStack(spacing: 8) {
			Text("Word")
				.frame(maxWidth: .infinity, alignment: .leading)
			Spacer().frame(width: Layout.deleteColumnWidth)
		}
		.font(.caption)
		.foregroundStyle(.secondary)
		.padding(.horizontal, Layout.rowHorizontalPadding)
	}

	private var removalsColumnHeaders: some View {
		HStack(spacing: 8) {
			Text("On")
				.frame(width: Layout.toggleColumnWidth, alignment: .leading)
			Text("Pattern")
				.frame(maxWidth: .infinity, alignment: .leading)
			Spacer().frame(width: Layout.deleteColumnWidth)
		}
		.font(.caption)
		.foregroundStyle(.secondary)
		.padding(.horizontal, Layout.rowHorizontalPadding)
	}

	private func removalBinding(for id: UUID) -> Binding<WordRemoval>? {
		guard let index = store.hexSettings.wordRemovals.firstIndex(where: { $0.id == id }) else {
			return nil
		}
		return $store.hexSettings.wordRemovals[index]
	}

	private var previewText: String {
		var output = store.remappingScratchpadText
		if store.hexSettings.smartFormattingEnabled {
			output = TextFormattingEngine.apply(
				output,
				config: store.hexSettings.smartFormattingConfig,
				vocabulary: store.hexSettings.customVocabulary
			)
		}
		if store.hexSettings.wordRemovalsEnabled {
			output = WordRemovalApplier.apply(output, removals: store.hexSettings.wordRemovals)
		}
		output = VocabularyApplier.apply(output, vocabulary: store.hexSettings.customVocabulary)
		output = WordRemappingApplier.apply(output, remappings: store.hexSettings.wordRemappings)
		return output
	}
}

private struct VocabularyRow: View {
	@Binding var word: String
	var onDelete: () -> Void

	var body: some View {
		HStack(spacing: 8) {
			TextField("Word or phrase", text: $word)
				.textFieldStyle(.roundedBorder)

			Button(role: .destructive, action: onDelete) {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
			.frame(width: Layout.deleteColumnWidth)
		}
		.padding(.horizontal, Layout.rowHorizontalPadding)
		.padding(.vertical, Layout.rowVerticalPadding)
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: Layout.rowCornerRadius)
				.fill(Color(nsColor: .controlBackgroundColor))
		)
	}
}

private struct RemovalRow: View {
	@Binding var removal: WordRemoval
	var onDelete: () -> Void

	var body: some View {
		HStack(spacing: 8) {
			Toggle("", isOn: $removal.isEnabled)
				.labelsHidden()
				.toggleStyle(.checkbox)
				.frame(width: Layout.toggleColumnWidth, alignment: .leading)

			TextField("Regex Pattern", text: $removal.pattern)
				.textFieldStyle(.roundedBorder)

			Button(role: .destructive, action: onDelete) {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
			.frame(width: Layout.deleteColumnWidth)
		}
		.padding(.horizontal, Layout.rowHorizontalPadding)
		.padding(.vertical, Layout.rowVerticalPadding)
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: Layout.rowCornerRadius)
				.fill(Color(nsColor: .controlBackgroundColor))
		)
	}
}

private enum ModificationSection: String, CaseIterable, Identifiable {
	case vocabulary
	case removals
	case formatting

	var id: String { rawValue }

	var title: String {
		switch self {
		case .vocabulary:
			return "Vocabulary"
		case .removals:
			return "Word Removals"
		case .formatting:
			return "Formatting"
		}
	}
}

private enum Layout {
	static let toggleColumnWidth: CGFloat = 24
	static let deleteColumnWidth: CGFloat = 24
	static let arrowColumnWidth: CGFloat = 16
	static let rowHorizontalPadding: CGFloat = 10
	static let rowVerticalPadding: CGFloat = 6
	static let rowCornerRadius: CGFloat = 8
}
