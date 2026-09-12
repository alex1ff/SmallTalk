# P1-02 — Call/trial lifecycle contract design

## Цель

Зафиксировать существующую серверную state machine звонка и trial-доступа,
проверить критические переходы на реальных Firestore-транзакциях и не вводить
новый workflow framework. Быстрые deterministic-тесты обязательны в каждом
PR; реальные emulator-тесты выполняются в manual extended CI.

## Границы

- Канонические статусы `videoSessions`: `searching`,
  `pending_confirmation`, `connecting`, `active`, `cancelled`, `expired`,
  `ended`.
- `technical_failure` — причина завершения/reconciliation, а не отдельный
  статус `videoSessions`.
- `connected` используется как текущий callable response/legacy participant
  marker, но не является status документа `videoSessions` и не добавляется в
  каноническую session state machine.
- Серверные timestamps, Daily webhook evidence и Firestore transaction state
  имеют приоритет над локальным временем и состоянием Flutter.
- Production-код меняется только если characterization/emulator-тест
  воспроизводит конкретный дефект.

## Каноническая матрица session-переходов

| Из | В | Владелец/actor | Trusted evidence | Lease/heartbeat | Idempotency | Trial effect |
|---|---|---|---|---|---|---|
| отсутствует | `pending_confirmation` | основной pair-lock matcher | transaction snapshot + request ID | `responseExpiresAt`, `matchLock.expiresAt` | session ID + pair attempt ID | reservation обоих участников атомарна с созданием session |
| отсутствует | `searching` | legacy create path | server timestamp + request ID | `responseExpiresAt` | один session/request ID | нет до pair-lock |
| `searching` | `pending_confirmation` | legacy matcher | pair lock + server timestamp | `responseExpiresAt`, `matchLock.expiresAt` | pair attempt ID | reservation создаётся в transaction owner |
| `searching` | `connecting` | legacy `acceptCall` | assigned responder + accept lock | `acceptingAt`, `acceptAttemptId`, затем `joinDeadlineAt` | session + accept attempt | reservation остаётся `inProgress` |
| `searching` | `cancelled` | user/stop/cancel owner | transaction snapshot | `responseExpiresAt`/active lock | повтор terminal no-op | technical reconciliation |
| `searching` | `expired` | scheduler | server expiry | `responseExpiresAt` | повтор terminal no-op | technical reconciliation |
| `pending_confirmation` | `pending_confirmation` | `declineCall`/retry matcher | новый responder + pair snapshot | новый `responseExpiresAt`, `matchLock.expiresAt` | новый pair attempt ID | reservation не дублируется |
| `pending_confirmation` | `connecting` | `acceptCall` | v2: оба participant state accepted; legacy: assigned responder + accept lock | `acceptingAt`, `acceptAttemptId`, затем `joinDeadlineAt` | session/pair attempt/accept attempt | reservation остаётся `inProgress` |
| `pending_confirmation` | `cancelled` | user/no-responder owner | transaction snapshot | `responseExpiresAt`, `matchLock.expiresAt` | повтор terminal no-op | technical reconciliation |
| `pending_confirmation` | `expired` | scheduler | server expiry | `responseExpiresAt`, finalization guard | повтор terminal no-op | technical reconciliation |
| `connecting` | `active` | Daily webhook или `markSessionConnected` | server-verified presence обоих участников | `joinDeadlineAt`, `expiresAt`, Daily last-seen evidence | первый `sessionMetadata.callConnectedAt` | `bothJoinedAt` фиксируется для обоих trial независимо от победившего owner |
| `connecting` | `cancelled` | user owner до connection evidence | transaction snapshot | `joinDeadlineAt` | повтор terminal no-op | technical reconciliation |
| `connecting` | `expired` | scheduler/credential expiry | server expiry, нет connection evidence | `joinDeadlineAt`/`expiresAt` | повтор terminal no-op | technical reconciliation |
| `connecting` | `ended` | `endSession`/scheduler | уже есть `sessionMetadata.callConnectedAt` или эквивалентный server evidence | `expiresAt` | terminal transaction | qualification считается по server duration/evidence |
| `active` | `ended` | `endSession`/scheduler | `sessionMetadata.callConnectedAt`/Daily evidence + server duration | `expiresAt`/Daily heartbeat | terminal transaction | qualified call consumes trial один раз |

Любой terminal status (`cancelled`, `expired`, `ended`) не может перейти в
другой status. Идемпотентность семантическая: повтор не меняет первый
connection marker, terminal status, trial consumption и бизнес-счётчики.
Диагностические Daily heartbeat/evidence writes допустимы. Если Daily event ID
уже обработан, тест отдельно фиксирует фактическое поведение dedup/no-op.

### User-visible result/error для каждого перехода

UI локализует текст по server status/reason; backend не хранит готовую строку.

| Из | В | UI result/error |
|---|---|---|
| `ABSENT` | `pending_confirmation` | «Собеседник найден, ожидаем подтверждение»; access/pair-lock reason открывает paywall или retry |
| `ABSENT` | `searching` | «Ищем собеседника»; call timer скрыт |
| `searching` | `pending_confirmation` | «Собеседник найден, ожидаем подтверждение» |
| `searching` | `connecting` | «Подключаемся»; timer ещё не started |
| `searching` | `cancelled` | «Поиск остановлен» без технической ошибки |
| `searching` | `expired` | «Не удалось соединиться. Попробуйте снова» |
| `pending_confirmation` | `pending_confirmation` | «Ищем следующего собеседника» без сброса общего поиска |
| `pending_confirmation` | `connecting` | «Подключаемся»; timer ждёт trusted connection marker |
| `pending_confirmation` | `cancelled` | user cancel: «Звонок отменён»; no responder: «Собеседник не ответил» |
| `pending_confirmation` | `expired` | «Время ответа истекло. Попробуйте снова» |
| `connecting` | `active` | call UI + timer от `sessionMetadata.callConnectedAt` |
| `connecting` | `cancelled` | «Подключение отменено»; trial не consumed |
| `connecting` | `expired` | «Не удалось подключиться. Попробуйте снова» |
| `connecting` | `ended` | экран завершённого звонка; qualification по server evidence |
| `active` | `ended` | экран завершённого звонка и call summary |

### Owners, deadlines и callable contract

Таблица ниже характеризует **текущие** responses/errors. Идемпотентность
означает отсутствие повторного бизнес-эффекта, а не обязательный успешный
response: например, повторный `cancelCall` для terminal session сейчас
возвращает `invalid-argument`, но не должен делать writes. Намеренные Red/Green
изменения перечислены отдельно после таблицы.

| Owner | Владеет | Deadline/lease | Повторный response/error, который фиксируют characterization tests |
|---|---|---|---|
| `startSearch` | публичный вход в search lifecycle | request ID + search expiry/heartbeat | `{searchRequestId: userId, requestId, status: active/matching/matched, sessionId, pairAttemptId, expiresAt, errorCode, reused}`; access reasons и `search_already_active` приходят в `HttpsError.details` |
| `createVideoSession` | legacy/direct публичный вход | request ID + response lease | `{status: searching/calling, sessionId, message, matchedTutors}` либо `no_tutors_available`; errors `unauthenticated`, `not-found`, `permission-denied`, `invalid-argument` и access `details.reason` фиксируются отдельно |
| pair-lock/create owner | создание session и trial reservation | `responseExpiresAt`, `matchLock.expiresAt` | текущий `{locked, reason, sessionId, pairAttemptId}`; partial-write failure является Red-дефектом ниже |
| `respondToMatch` | v2 participant response/finalization stage | `responseExpiresAt`, `matchLock.expiresAt`, finalization expiry | reasons `pair_attempt_mismatch`, `late_terminal_search_stopped`, `session_not_pending`, `response_window_closed`, `student_stage_not_ready`, `claim_requires_fresh_foreground`, `timeout_not_reached`, `lifecycle_escalation_pending`, `student_delivery_failed`, `finalization_in_progress` |
| `acceptCall` | accept lock и `connecting` | `acceptingAt`, `acceptAttemptId`, `joinDeadlineAt`, `expiresAt` | успешный callable response `{status: connected, ...}` (`connected` не session status), existing accepted result либо `failed-precondition`/`invalid-argument`/`permission-denied` |
| `declineCall` | следующий responder или terminal cancel | новая response lease | повтор не отменяет новый pair attempt; terminal reason сохраняется |
| `cancelCall` | user terminal cancel | session transaction snapshot | terminal repeat: `invalid-argument`, без повторного reconciliation |
| `stopSearch` | search/session cancellation intent | request/session IDs и active lock | reasons `not_found`, `request_id_required`, `session_not_found`, `already_inactive`, `session_already_inactive`, `session_not_searching`, `session_mismatch`, `request_mismatch`, `manual`, `cancellation_intent_recorded` |
| `dailyWebhook` | signed Daily join evidence и `active` | webhook replay window, `joinDeadlineAt`, Daily last-seen | `405 Method Not Allowed`, `500 Server not configured`/internal, `401 Unauthorized`, `400 Malformed event`, `200 Ignored` (unsupported/non-unique), `200 OK`; внутренние `daily_signal_recorded*`/`daily_connected_marked` — decision diagnostics |
| `markSessionConnected` | callable presence verification и `active` | `joinDeadlineAt`, verified Daily presence | errors `unauthenticated`, `invalid-argument`, `permission-denied`, `failed-precondition`; responses `signal_recorded`, `marked`, `already_marked` (`updated` true/false), `daily_presence_not_verified`, плюс `dailyPresenceVerificationStatus: presence_unavailable` |
| `endSession` | user/scheduler terminal transition | `expiresAt`, server connection evidence | `already_ended`, `already_cancelled`, `already_expired`, `ignored_expired_end`; бизнес-эффекты один раз |
| `processExpiredNotifications` | response timeout/no responder | notification expiry + current pair attempt | stale attempt не завершает новую пару; terminal reasons включают `match_timeout`, `direct_call_timeout`, `student_pair_response_timeout`, `no_available_responder_after_timeout` |
| `cleanupExpiredSessions` | backstop для response/join/session expiry | `responseExpiresAt`, `joinDeadlineAt`, `expiresAt` | respects `finalization_guard_active`/`notification_worker_owns_timeout`; terminal cleanup идемпотентен |
| route-failure owner | push/delivery failure | текущий pair attempt и route result | `route_failed`/`student_delivery_failed` приводит к reconciliation только текущей попытки |

### Намеренные Red/Green исправления

1. Pair-lock обязан быть атомарным для двух trial-участников. Red fixture:
   requester `eligible`; responder проходит access precheck, но имеет
   просроченный `inProgress` lease и отклоняется именно внутри
   `reserveTrialCallInTransaction`. После минимального исправления не должно
   быть ни session, ни requester reservation; responder остаётся только в
   точно разрешённом исходном/rollback state. Обычный precheck-denial не
   считается достаточным тестом.
2. Daily webhook и `markSessionConnected` должны использовать один минимальный
   shared transaction helper для записи `bothJoinedAt` всем matching trial
   docs при первом trusted connection marker. Это не новый state-machine
   dispatcher: helper владеет только одинаковыми trial evidence writes.

## Матрица trial-переходов

| Из | Событие | В | Инвариант |
|---|---|---|---|
| `eligible` | атомарная reservation | `inProgress` | один `trialCallId`, `attemptCount + 1` один раз |
| `inProgress` | оба подключились и call завершён пользователем | `consumed` | consumption ровно один раз |
| `inProgress` | duration >= 120 секунд | `consumed` | qualification использует server duration |
| `inProgress` | technical failure до qualification | `eligible` | bounded retry + cooldown, без consumption |
| `inProgress` | lease истёк | `eligible` или `expired` | bounded technical retry, fail closed после лимита |
| `inProgress` | no responder/cancel/expire до connection | `eligible`/`expired` по policy | terminal owner обязан вызвать reconciliation |
| `consumed`/`expired` | повтор callable/webhook | без изменения | нет повторного consumption/счётчиков; diagnostic writes допустимы |

## Реализация контрактов

### Быстрый PR gate

Новый pure contract suite хранит одну машиночитаемую **test-only
characterization table** рядом с тестами. Production owner-функции остаются
источником поведения; общий runtime dispatcher/guard не добавляется. Suite
проверяет:

1. `to` использует только значения `VIDEO_SESSION_STATUS`; в `from` разрешён
   единственный test sentinel `ABSENT` для creation transition;
2. allowed/denied session transitions и terminal immutability;
3. наблюдаемые результаты существующих owner helpers соответствуют таблице;
4. trial reservation/reconciliation остаются idempotent;
5. Flutter timer/label contracts используют server `status`,
   `sessionMetadata.callConnectedAt`, `expiresAt` и документированные legacy
   fallbacks, не создавая независимую client state machine.

Тесты входят в `backend:ci`; Flutter contract/widget тесты входят в обычный
`flutter test` через существующий local release gate.

### Extended emulator gate

Отдельный test-файл запускается только при наличии
`FIRESTORE_EMULATOR_HOST`. Он использует реальные `runTransaction` и один
изолированный namespace на test run. Обязательные сценарии:

1. два конкурентных reserve на один trial doc — ровно один успех;
2. pair-lock с двумя trial-участниками: requester `eligible`; responder
   проходит access precheck, но после уже подготовленной requester reservation
   отказывает **внутри** `reserveTrialCallInTransaction` из-за просроченного
   `inProgress` lease. Session и requester reservation отсутствуют; responder
   остаётся в точно разрешённом rollback state;
3. technical failure до qualification — `eligible`, consumption отсутствует;
4. connected/qualified call — `consumed` ровно один раз;
5. no responder, cancel и expiry вызывают terminal reconciliation;
6. повтор reconciliation/webhook сохраняет первый connection marker, terminal
   state, trial consumption и бизнес-счётчики; разрешённые diagnostic writes
   проверяются отдельно;
7. оба trial-участника обрабатываются независимо в одной session transaction;
8. Обе production entry paths — transaction owner Daily webhook и transaction
   owner `markSessionConnected` — обязаны вызывать shared trial evidence helper;
   отдельные tests не позволяют проверить только helper и забыть wiring.
   Emulator suite принудительно выполняет Daily-wins и mark-wins ordering,
   получает один `sessionMetadata.callConnectedAt`, затем запускает реальный
   short-call end/reconcile owner и подтверждает `bothJoinedAt` и consumption
   обоих trial ровно один раз.

Cleanup выполняется в `after`/`finally`. Тест не обращается к production
Firebase и fail closed, если emulator-переменная задана некорректно.

## Flutter contract

- До server connection evidence UI показывает connecting state, а не `0:00`
  как подтверждённый звонок.
- После `active` таймер вычисляется из server
  `sessionMetadata.callConnectedAt` и server-backed session policy
  (`expiresAt`/effective limit); разрешены только явно проверенные legacy
  fallbacks.
- Terminal status останавливает таймер и не может быть локально возвращён в
  active.
- Проверка делается существующими widget/source contract tests; production UI
  меняется только при воспроизводимом несоответствии.

## Failure handling

- Неизвестный status и запрещённый переход проваливают test-only contract;
  новый runtime validator не вводится без воспроизведённого production-дефекта.
- Отсутствующий trusted timestamp не считается доказательством connection или
  qualification.
- Потеря сети клиента — только сигнал для terminal owner. `technical_failure`
  устанавливается по server timestamps, Daily evidence и deadlines; один
  client signal не доказывает ни failure, ни completed call.
- В P1-02 technical retry гарантируется для failure **до** trusted connection
  evidence. После `sessionMetadata.callConnectedAt` текущие Daily events и
  client `peer_left` не дают доверенной причины разрыва; такой short call
  следует существующей consumption policy. Post-connect technical retry не
  добавляется без отдельного provider-backed evidence/product anti-abuse
  решения.
- Emulator test failure блокирует extended job; обычный PR остаётся быстрым и
  блокируется pure contract regression.

## Проверка готовности

- `npm --prefix firebase/custom_cloud_functions run lint`.
- Новый быстрый lifecycle suite явно включён в `backend:ci`.
- Все существующие call/trial backend tests.
- `npm run backend:ci`.
- Релевантные Flutter timer/widget tests, `flutter analyze` и `flutter test`.
- Lifecycle emulator check явно вызывается внутри существующего
  `emulators:exec` runner, входит в его `allPass` и не может быть silently
  skipped при `workflow_dispatch`.
- Обычный PR job не запускает emulator; extended job остаётся только manual
  `workflow_dispatch`. Отсутствие фактического запуска lifecycle emulator
  scenarios в extended job считается failure.
- `git diff --check`.

После зелёной валидации изменения проходят отдельный `loop-code-review`.
