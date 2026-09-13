# In-call chat and word sheets

## Goal

Make the call overlays feel native and compact, remove duplicated word content, and ensure words saved from quick translation contain the same useful dictionary data as words saved from captions.

## Scope

This change covers:

- the chat composer shown during a call;
- the quick-translation bottom sheet;
- the word bottom sheet opened from live captions and legacy word cards;
- enrichment and presentation of words saved from quick translation;
- the full-page word details layout.

Call media, captions, translation quotas, and dictionary review scheduling stay unchanged.

## Interaction design

### Call chat

The composer remains part of the dark chat panel. It must not render a separate white slab behind the input. The text field and send button keep their current affordances and contrast.

### Quick translation

The keyboard action is Done. Pressing it closes the complete translation sheet, not only the keyboard. The explicit Translate button remains the only action that starts translation.

Done first removes focus and then pops only the quick-translation modal route. It never triggers translation, saves a draft, or pops the call route. While a translate or save request is running, closing the sheet is allowed; late results must not update disposed state.

### Entry points

- Tapping a live caption opens the shared draggable word sheet over the call. It receives the caption word, source language, sentence, and transient conversation context.
- Legacy `WordCardWidget` entry points also open the shared draggable word sheet with a saved `UserWordsRecord`.
- Tapping a row on the Dictionary page continues to open `WordDetailWidget` as a full page. It does not open or nest another modal.
- Quick Translation stays in its own compact sheet. Save enriches the stored word in the background and does not navigate to a word sheet or full page.

### Word sheet

Caption and saved-word entry points use the same draggable sheet shell:

- one drag handle;
- no centered word title;
- no expand/collapse button;
- the source word and dictionary toggle share the first content row;
- a slow downward drag collapses an expanded sheet;
- another downward drag from the collapsed extent closes it;
- a fast downward fling closes it immediately;
- upward drag expands it;
- content scroll and sheet drag share one scroll controller, so pulling down at the top moves the sheet instead of scrolling empty space.

The modal uses one `DraggableScrollableSheet` and gives its controller to the only scrolling child. Its extents are relative to the available height after safe-area and keyboard insets:

- minimum/close extent: `0.18`;
- collapsed snap extent and initial extent: `0.46`;
- expanded snap extent: `0.90`.

A slow release snaps to the nearest collapsed or expanded extent. Reaching the minimum from the collapsed state closes the modal. A downward release with a velocity of at least `900 logical pixels/second` closes it from any extent. A small drag below that threshold never dismisses directly from the expanded state. These decisions live in the shared shell rather than in word-content widgets.

The keyboard is dismissed before a drag changes the sheet extent. The handle and dictionary toggle have semantic labels, a minimum 44-by-44 logical-pixel touch target, and remain usable at the platform's largest supported text scale. Content is not clipped at large text sizes; it scrolls inside the same controller.

## Word content hierarchy

The same normalized presentation model is used in the sheet and on the Word page:

1. Source word, transcription, and dictionary toggle.
2. Primary translation, shown once as plain text.
3. Additional translations in a separate compact chip row, followed by meanings and synonyms. None may repeat the primary translation or each other.
4. Conversation context when available.
5. Example sentences with translations.

The direct Quick Translation result is always the primary translation. Otherwise the first non-empty translation on the primary entry is primary. Remaining translations keep API order. Meanings and synonyms keep their first-seen order across entries. Empty sections are omitted. Labels are shown only when their section has content.

All visible word-like strings use the same duplicate key: Unicode-trimmed, surrounding punctuation removed, internal whitespace collapsed, and compared case-insensitively. A value already used as source, primary translation, additional translation, meaning, or synonym is not shown again in a lower-priority section. Example sentences are deduplicated by normalized language plus normalized source text; when duplicates exist, the item containing a non-empty translated sentence wins.

The live caption sentence is persisted through the existing `Sentence` field when the user saves from the caption sheet. The wider `contextText` remains transient call UI and is intentionally not added to the saved-word schema. Quick Translation has no conversation sentence; its full Word page therefore shows dictionary examples only.

## Saving from quick translation

The existing callable remains the authority that creates the deterministic word and review documents. It returns `wordPath` and `alreadyExisted`. After it succeeds, the client starts `WordLookupService.fetchRemote(...)`, a new lookup path that uses the source and target languages from the translation result and deliberately bypasses both the saved-word early return and the in-memory cache.

Entries and examples remain independent remote requests. `fetchRemote` returns `WordRemoteLookupResult(entries, examples, failures)`, where `failures` identifies `entries`, `examples`, or both. A successful half is returned and merged even when the other half fails. The caller logs every reported failure; an all-failed result is still non-fatal to the completed save.

`QuickTranslationWordEnricher.enrich(wordReference, directTranslation, remoteResult)` owns the Firestore merge. It runs a transaction, re-reads the document, and writes only the `entry` and `Sentence` arrays. This prevents two overlapping saves or an open caption sheet from replacing each other's content. `alreadyExisted` changes no merge rule: existing rich content is retained and missing remote content is added.

The merge rules are:

- entry zero remains the primary entry; its source text is the direct source text and its first translation is the direct translation;
- the first remote entry with the same normalized source text is merged into entry zero even when the callable-created entry has no part of speech; this fills its missing transcription and part of speech while keeping the direct translation first;
- after that primary special case, other remote entries are matched by normalized source text plus normalized part of speech; a match fills missing transcription and part of speech, then unions source synonyms and translations;
- translation items match by normalized translation text plus normalized part of speech; a match retains existing scalar fields and fills missing `gen`, `fr`, and `asp`, then unions its synonyms and meanings;
- unmatched remote entries and translations are appended in API order;
- synonyms and meanings are unioned by the common duplicate key; examples are unioned by normalized language and source sentence, preferring the version with translations;
- keep existing metadata and review records;
- never create a second word document.

The sheet reports Saved as soon as the authoritative save succeeds. Enrichment is best-effort: a lookup failure must not undo the save or show a false failure.

For retry, `SavedWordLookupMetadata.fromRecord` reads the callable's raw top-level `source`, `sourceLanguage`, and `targetLanguage` values from `UserWordsRecord.snapshotData`; generated schema getters are not required. When a Quick Translation word is opened in `WordDetailWidget` or the legacy saved-word sheet and it has no transcription or no examples, that opener calls `fetchRemote` once per mounted view and passes the result to the same enricher. It builds the language configuration from those stored codes. Legacy records without both language codes skip automatic enrichment instead of guessing a language. A Firestore stream update then refreshes the full page; the modal updates its local presentation model after the merge completes.

## Component boundaries

- `InCallTranslationSheet`: translation input, Done dismissal, save orchestration, and one call to the enricher after the authoritative save.
- `DraggableWordSheet`: owns the controller, extents, snap/close behavior, drag handle, keyboard dismissal, and modal-only dismissal callback. Its content builder must use the supplied `ScrollController`.
- `WordSheetContent`: receives `WordDetailContent`, optional transient context, save state, and an async `onToggleSaved` callback. It has no Firestore or lookup calls.
- `WordLookupService.resolve(...)`: existing saved-first lookup used for ordinary word display.
- `WordLookupService.fetchRemote(...)`: remote-only entries/examples lookup that returns successful partial data plus explicit per-source failures and does not read saved words.
- `SavedWordLookupMetadata`: reads Quick Translation provenance and source/target language codes from a record's raw snapshot data and decides whether automatic retry is eligible.
- `QuickTranslationWordEnricher`: transaction-safe merge into the `wordPath` returned by the callable.
- `WordDetailContent`: normalized, duplicate-free presentation model used by both `WordSheetContent` and `WordDetailBody`.
- Call chat composer: transparent/dark panel styling only.

## Error handling

- The inline dictionary control has four states: unsaved, saving/removing spinner, saved, and retryable error. It is disabled only while its own request is pending.
- A failed save leaves the sheet open and the control unsaved with the existing retry message. A failed delete leaves it saved. A retry repeats only the failed operation.
- Removing a word from the live or legacy sheet updates the control in place. Removing from the full Word page closes that page after deletion because its backing document no longer exists.
- Enrichment errors are logged as non-fatal and leave the minimal saved word usable.
- Missing dictionary data renders the direct translation without placeholders or duplicated chips.
- Drag dismissal uses the modal route and cannot affect the call route beneath it.
- Async work checks `mounted` and the active translation generation before changing UI.

## Validation

- Run `flutter analyze`.
- Run existing translation, word lookup/content, and call overlay tests.
- Add focused tests only for duplicate filtering and the transaction merge because those rules carry data-loss and concurrency risk. Do not add screenshot-mirroring tests for styling changes.
- Manually verify these acceptance scenarios on an iPhone-sized viewport:
  1. Opening in-call chat shows the dark panel and composer without a white slab beneath it.
  2. Pressing the keyboard Done button in Quick Translation closes the whole modal and does not translate.
  3. A caption word sheet shows the source once, has no expand button, and places the save star inline with the source row.
  4. From expanded state, a slow downward drag collapses; a second drag closes; a fast downward fling closes directly; long content still scrolls upward normally.
  5. Saving a Quick Translation creates one word document, reports Saved immediately, then adds available transcription, alternate translations, meanings, synonyms, and examples without replacing the direct primary translation.
  6. Opening words saved from Quick Translation and captions on the full Word page shows one primary translation, deduplicated secondary content, and examples when available.
