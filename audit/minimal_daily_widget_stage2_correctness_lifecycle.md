# MinimalDailyWidget Stage 2 Correctness And Lifecycle

- Date: `2026-03-06`
- Status: `Completed`
- Working widget changed: `No`
- Scope:
  - `lib/custom_code/widgets/minimal_daily_widget.dart`
  - `lib/shared_pages/video_call_page/video_call_page_widget.dart`
  - `lib/services/voip_service.dart`
  - `firebase/custom_cloud_functions/end_session.js`

## Commands Executed

```bash
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/daily_co_reference_flutter" "callStateUpdated joined left leaving participantLeft participantUpdated dispose leave event ordering" --tokens 3500
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/daily_co_reference_flutter" "CallState joined meaning local participant joined left leaving callStateUpdated" --tokens 2500
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/developers_deepgram" "ListenV1Finalize CloseStream KeepAlive websocket close behavior final transcript on stop" --tokens 3500
python3 ~/.agents/skills/context7/scripts/context7.py context "/websites/developers_deepgram" "streaming listen results channel alternatives is_final speech_final utterance_end message schema" --tokens 3500
nl -ba lib/custom_code/widgets/minimal_daily_widget.dart | sed -n '360,470p'
nl -ba lib/custom_code/widgets/minimal_daily_widget.dart | sed -n '600,740p'
nl -ba lib/custom_code/widgets/minimal_daily_widget.dart | sed -n '948,980p'
nl -ba lib/custom_code/widgets/minimal_daily_widget.dart | sed -n '1128,1298p'
nl -ba lib/custom_code/widgets/minimal_daily_widget.dart | sed -n '1327,1468p'
nl -ba lib/custom_code/widgets/minimal_daily_widget.dart | sed -n '1498,1590p'
nl -ba lib/custom_code/widgets/minimal_daily_widget.dart | sed -n '2260,2445p'
nl -ba lib/shared_pages/video_call_page/video_call_page_widget.dart | sed -n '232,244p'
nl -ba lib/shared_pages/video_call_page/video_call_page_widget.dart | sed -n '240,415p'
nl -ba lib/services/voip_service.dart | sed -n '930,1008p'
nl -ba firebase/custom_cloud_functions/end_session.js | sed -n '96,126p'
nl -ba /Users/patrikkardenas/.pub-cache/hosted/pub.dev/daily_flutter-0.34.0/lib/src/model/call_state.dart | sed -n '1,220p'
```

## Lifecycle Findings

### MDW-S2-01

- Severity: `P0`
- Type: `Daily-related + billing correctness`
- Classification: `definite issue`
- Trigger:
  - Local participant reaches Daily `CallState.joined` before the remote participant is actually connected.
  - Device clock is skewed relative to server time.
- Involved methods:
  - `MinimalDailyWidget._handleCallStateUpdate()`
  - `MinimalDailyWidget._markSessionStarted()`
  - Cloud Function `endSession`
- Evidence:
  - `CallState.joined` in the installed Daily package means the local client has joined the call, not that the remote participant is present:
    - `/Users/patrikkardenas/.pub-cache/hosted/pub.dev/daily_flutter-0.34.0/lib/src/model/call_state.dart:14-18`
    - `/Users/patrikkardenas/.pub-cache/hosted/pub.dev/daily_flutter-0.34.0/lib/src/model/call_state.dart:27-35`
    - Context7 `joined-meeting`: local participant joined; participant list may initially contain only local participant.
  - The widget marks the session as started immediately on `CallState.joined`:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:606-619`
  - The widget writes `sessionMetadata.callConnectedAtTimestamp` from `DateTime.now()` on the client:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:1531-1561`
  - Backend billing/duration uses `callConnectedAtTimestamp` before `startedAt`:
    - `firebase/custom_cloud_functions/end_session.js:105-113`
  - Summary fallback also derives duration from `startedAt` if backend duration is still `0`:
    - `lib/shared_pages/video_call_page/video_call_page_widget.dart:235-240`
- Root cause:
  - A client-side timestamp named like a true “call connected” marker is being written at local join time, using device clock time, and the backend trusts it as the primary billing start time.
- User-visible consequence:
  - Waiting alone in the room can be charged as active call time.
  - Clock skew on a device can inflate or reduce call duration.
  - Client-side summary can show misleading early duration.
- Conclusion source:
  - Source reading + Context7 + local package source.

### MDW-S2-02

- Severity: `P0`
- Type: `Deepgram-related + privacy/correctness`
- Classification: `definite issue`
- Trigger:
  - User taps the in-call mute button while Deepgram is enabled.
- Involved methods:
  - `MinimalDailyWidget._buildControls()`
  - `MinimalDailyWidget._updateInputSettings()`
  - `MinimalDailyWidget._startDeepgramStreaming()`
  - `MinimalDailyWidget._processFinalTranscript()`
  - `MinimalDailyWidget._sendCaptionMessage()`
- Evidence:
  - The mute button only toggles Daily microphone input:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:2149-2153`
    - `lib/custom_code/widgets/minimal_daily_widget.dart:957-976`
  - Deepgram uses a separate local `FlutterSoundRecorder` microphone capture path:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:1143-1177`
  - Final transcripts are still sent to the other participant through Daily app messages:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:1263-1295`
  - There is no code path that stops or gates Deepgram when `_state.microphoneEnabled` becomes `false`.
- Root cause:
  - “Mute” controls the Daily call transport only. The transcription recorder is an independent audio capture pipeline and remains active.
- User-visible consequence:
  - A muted user can still be transcribed locally.
  - Those transcripts can still be sent to the remote participant as captions.
  - The UI communicates a privacy guarantee that the implementation does not actually enforce.
- Conclusion source:
  - Source reading.

### MDW-S2-03

- Severity: `P1`
- Type: `Pure Flutter/Dart/widget + Deepgram lifecycle`
- Classification: `definite issue`
- Trigger:
  - Fast `inactive -> paused -> resumed` transitions.
  - App backgrounding/foregrounding during ongoing Deepgram stop/start work.
- Involved methods:
  - `MinimalDailyWidget.didChangeAppLifecycleState()`
  - `MinimalDailyWidget._handleAppBackground()`
  - `MinimalDailyWidget._handleAppForeground()`
  - `MinimalDailyWidget._updateInputSettings()`
  - `MinimalDailyWidget._stopDeepgramStreaming()`
  - `MinimalDailyWidget._startDeepgramStreamingWithResolvedCredential()`
- Evidence:
  - Background handling fires async work without waiting for it:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:1401-1407`
  - Foreground handling immediately fires more async work, also without waiting:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:1411-1420`
  - `_updateInputSettings()` is async:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:957-980`
  - `_stopDeepgramStreaming()` only flips `isStreamingToDeepgram` to `false` at the end of teardown:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:1343-1376`
- Root cause:
  - Background and foreground transitions are not serialized. A quick resume can observe stale state from an in-flight background teardown.
- User-visible consequence:
  - Camera/microphone state can end up opposite to the intended resume state.
  - Deepgram can remain stopped after resume because the foreground branch checks `_state.isStreamingToDeepgram` before the background stop finishes, then never retries.
  - Re-entry can overlap stop/start operations against half-cleaned recorder or websocket state.
- Conclusion source:
  - Source reading.

### MDW-S2-04

- Severity: `P2`
- Type: `Deepgram-related`
- Classification: `probable protocol misuse`
- Trigger:
  - Ending a call.
  - Going to background.
  - Restarting Deepgram after websocket failure.
- Involved methods:
  - `MinimalDailyWidget._stopDeepgramStreaming()`
  - `MinimalDailyWidget._restartDeepgramConnection()`
- Evidence:
  - The widget stops Deepgram by stopping recorder and then closing the websocket sink directly:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:1343-1369`
  - Current Deepgram docs explicitly distinguish:
    - `Finalize`: flush buffered audio and produce final results.
    - `CloseStream`: close the stream intentionally.
    - Context7 query: `ListenV1Finalize CloseStream KeepAlive websocket close behavior final transcript on stop`
- Root cause:
  - Teardown uses transport closure only, without sending protocol-level finalization/close messages first.
- User-visible consequence:
  - The last spoken fragment before stop/background/reconnect can be dropped or never surface as a final transcript.
  - Caption continuity becomes unreliable exactly at call-end and interruption boundaries.
- Conclusion source:
  - Source reading + Context7.
- Note:
  - This is an inference from the current code and documented protocol semantics; runtime confirmation belongs in retest.

### MDW-S2-05

- Severity: `P2`
- Type: `VoIP / system-call integration`
- Classification: `definite issue`
- Trigger:
  - Stale `_lastCallKitId`
  - Back-to-back call attempts
  - Widget disposal or summary navigation while another CallKit entry exists
- Involved methods:
  - `MinimalDailyWidget._endSystemCallUi()`
  - `MinimalDailyWidget._markSystemCallConnected()`
  - `VoIPService.endCurrentCall()`
  - `VoIPService.markCallConnected()`
- Evidence:
  - The widget has `sessionId` available, but does not pass it into VoIPService:
    - `lib/custom_code/widgets/minimal_daily_widget.dart:1518-1526`
    - `lib/custom_code/widgets/minimal_daily_widget.dart:1568-1577`
  - VoIPService supports a session-scoped call ID lookup, but falls back to `_lastCallKitId` when `sessionId` is omitted:
    - `lib/services/voip_service.dart:977-983`
    - `lib/services/voip_service.dart:989-1005`
  - If there is no resolved call ID, `endCurrentCall()` ends all calls:
    - `lib/services/voip_service.dart:1004-1005`
- Root cause:
  - Widget-level lifecycle uses global “current call” semantics even though the service has a session-aware API surface.
- User-visible consequence:
  - Wrong CallKit/ConnectionService UI can be marked connected or dismissed.
  - In edge cases, disposing one call screen can terminate another visible system call UI.
- Conclusion source:
  - Source reading.

## Pass Notes

- `participant-left` handling already contains a useful stale-update guard before cancelling the remote-left timer:
  - `lib/custom_code/widgets/minimal_daily_widget.dart:661-681`
- Deepgram message parsing aligns with current docs for `channel.alternatives`, `is_final`, and `speech_final`:
  - `lib/custom_code/widgets/minimal_daily_widget.dart:1236-1256`
  - Context7 query: `streaming listen results channel alternatives is_final speech_final utterance_end message schema`

## Stage Conclusion

- Stage result: `Fail`
- Primary blockers:
  - `MDW-S2-01` client-authored billing start timestamp
  - `MDW-S2-02` mute does not stop transcription/caption leakage
- Recommended fix order:
  1. Move call-connected authority off the client and stop using local join/device clock as billing truth.
  2. Bind Deepgram lifecycle to actual mic state so mute truly stops transcription and caption emission.
  3. Serialize app lifecycle transitions for Daily inputs and Deepgram stop/start.
  4. Send protocol-level Deepgram stop/finalize messages before websocket closure.

## Resolution Update

- Date: `2026-03-06`
- Status: `P0 fixes applied`
- Working widget changed: `Yes`

### Resolved In This Pass

- `MDW-S2-01`
  - Fixed by moving the effective call-start marker to remote participant presence, writing `sessionMetadata.callConnectedAt` with `FieldValue.serverTimestamp()`, stopping backend billing from trusting accept-time fallbacks, and updating the summary fallback to use the server-authored connected timestamp.
- `MDW-S2-02`
  - Fixed by binding Deepgram start/stop to actual microphone state plus remote participant presence, so mute now stops local transcription and prevents caption emission.
- `MDW-S2-05`
  - Fixed in the widget/integration scope by passing `sessionId` into `VoIPService.markCallConnected()` and `VoIPService.endCurrentCall()` in active call and summary-navigation paths.

### Validation After Fixes

- `node --check firebase/custom_cloud_functions/accept_call.js`
  - passed
- `node --check firebase/custom_cloud_functions/end_session.js`
  - passed
- `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`
  - `6 issues` remain, all from the FlutterFlow-generated import header
- `flutter analyze lib/shared_pages/video_call_page/video_call_page_widget.dart`
  - `No issues found!`
- `flutter analyze`
  - `No issues found!`
- `flutter test`
  - `All tests passed!`

### Remaining Stage 2 Work

- `MDW-S2-03`
  - App lifecycle stop/start is still not serialized; quick background/foreground transitions can overlap Daily input and Deepgram work.
- `MDW-S2-04`
  - Deepgram teardown still closes the transport without protocol-level `Finalize` / `CloseStream`.

## Resolution Update 2

- Date: `2026-03-06`
- Status: `Stage 2 code fixes completed`
- Working widget changed: `Yes`

### Resolved In This Pass

- `MDW-S2-03`
  - Fixed by serializing app lifecycle transitions so background/foreground input updates no longer overlap and duplicate `inactive -> paused` handling is collapsed into a single transition path.
- `MDW-S2-04`
  - Fixed by sending Deepgram protocol-level `Finalize` and `CloseStream` messages before closing the WebSocket transport.

### Validation After Final Pass

- `flutter analyze lib/custom_code/widgets/minimal_daily_widget.dart`
  - `6 issues` remain, all from the FlutterFlow-generated import header
- `flutter analyze`
  - `No issues found!`
- `flutter test`
  - `All tests passed!`

### Updated Stage Status

- Stage result: `Pass with retest required`
- Residual risk:
  - Runtime confirmation is still needed for quick background/foreground transitions and for last-utterance flush timing around hangup/background, but the previously documented correctness gaps are now closed in code.
