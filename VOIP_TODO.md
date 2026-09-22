# VoIP validation backlog

Production flows `acceptCall`, incoming push delivery, navigation,
decline/end/timeout and token registration уже реализованы. Этот файл содержит
только остающиеся проверки; архитектурная работа ведётся в
[`tech_debt/P1-08-voip-service-decomposition.md`](tech_debt/P1-08-voip-service-decomposition.md).

## Local automation

- [x] duplicate/stale Accept и process-level dedupe;
- [x] early action readiness, TTL, priority, bound и user targeting;
- [x] Decline/Timeout idempotency и stale CallKit identity;
- [x] cold-start accepted-call recovery и navigation retry;
- [x] denied media permissions и server-ended tombstones;
- [x] foreground/background payload identity checks.

## Physical iOS

- [ ] PushKit token registration/rotation;
- [ ] foreground/background/terminated delivery;
- [ ] CallKit lock-screen UI;
- [ ] Accept/Decline/Timeout/End exactly once;
- [ ] accept after relaunch restores one correct session;
- [ ] logout/login does not replay the previous user's action.

## Physical Android

- [ ] FCM token registration/rotation;
- [ ] foreground/background/terminated delivery;
- [ ] full-screen incoming UI and lock screen;
- [ ] Accept/Decline/Timeout/End exactly once;
- [ ] OEM battery restrictions documented for tested devices;
- [ ] logout/login does not replay the previous user's action.

## Release evidence

- [ ] Record device/OS/build and initial lifecycle state for each smoke;
- [ ] Record session ID only; never include push token, room URL or meeting token;
- [ ] Attach failure logs with secrets redacted;
- [ ] Do not mark P1-08 fully complete until both platform smoke matrices pass.
