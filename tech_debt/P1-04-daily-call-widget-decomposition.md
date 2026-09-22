# P1-04 — Декомпозиция `MinimalDailyWidget`

**Размер:** XL · **Владелец:** Flutter media/call · **Стадия:** второй этап ·
**Зависимости:** P1-02, P1-05.

## Статус — локально закрыто, внешний device QA открыт, 01.09.2026

Критический ownership больше не сосредоточен в одном State-объекте:

- `DailySessionController` владеет единственным process lease, созданием,
  guarded join/configuration, событиями, активными SDK-операциями и single-flight
  cleanup. Timeout создания не притворяется отменой: поздний native client
  дожидается dispose, а неподтверждённый dispose блокирует повторный lease.
- `DeepgramTransportController` владеет permission/recorder/WebSocket/audio,
  generation, финализацией и reconnect. SDK вынесен в production adapter,
  поэтому lifecycle-races проверяются без platform channel. Final frames
  принимаются во время drain, исходящая final caption ожидается до Daily leave.
- `CallTimerController` владеет периодическим scheduler, server clock offset и
  one-shot решениями. Cleanup suspend не позволяет позднему promotion callback
  воскресить timer во время разборки media.
- `CallChatController` владеет сообщениями, unread/open/send состоянием,
  generation-safe persistence и end-session ordering; существующий coordinator
  по-прежнему даёт dirty-tail и bounded retry.
- `CallControlsBar` и `CallDurationBadge` — чистые presentational widgets с
  сохранёнными размерами, цветами, русскими semantics и widget tests.
- Старые Daily process globals, recorder/socket/subscription owners и около
  1000 строк смешанного lifecycle/UI-кода удалены из widget. Публичный
  constructor, callbacks, Daily settings, caption schema и call UX не менялись.
- Прямой focused P1-04 suite: 363 controller/policy/widget теста; отдельный
  terminal-quarantine wiring contract также зелёный. Полный
  `flutter analyze --no-pub` и `git diff --check` — без замечаний.
- Финальный независимый `loop-code-review`: actionable findings отсутствуют,
  оценка реализации 10/10, тестов 10/10. Предыдущие проходы нашли и закрыли
  recorder/Daily quarantine, безопасные diagnostics, credential fallback,
  terminal UI precedence, late-cleanup state preservation и запрет re-entry.
- На машине доступны только macOS и Chrome. Физический iOS/Android smoke
  (join, background/foreground, reconnect, final caption, leave) остаётся
  обязательным release check и не подменяется unit/widget тестами.

Ниже сохранена хронология промежуточных срезов. Формулировки «не закрыто» в
этих записях описывают состояние соответствующего среза на момент выполнения,
а не текущий итоговый статус задачи.

- Первый небольшой срез: pure rules для Daily URL/token и Deepgram credentials
  вынесены в `lib/custom_code/widgets/daily_join_credentials.dart`.
- Widget сохраняет constructor, callbacks, cache/refresh и lifecycle; его
  private wrappers передают текущие значения в helper.
- До переноса 30 characterization tests проверены на исходных методах во
  временной локальной оболочке; те же тесты теперь напрямую проверяют модуль.
  Отдельный source-contract test проверяет wiring, не подменяя runtime tests.
- Сохранены различия fallback URL/token и приоритет нового Deepgram credential
  над deprecated API key. Новых зависимостей или controllers не добавлено.
- **Задача не закрыта:** stateful Daily/Deepgram lifecycle, caption flush,
  chat, cleanup и UI всё ещё в widget. Их перенос требует отдельных срезов
  с characterization tests и device smoke; список ниже остаётся backlog.

### Второй срез: очередь lifecycle-переходов

- `DailyLifecycleTransitionQueue` владеет только последовательностью Future
  и поколением действий при background/foreground. Сетевых/SDK зависимостей нет.
- Enqueue сразу делает предыдущий token устаревшим, но не удаляет callback.
  Mounted/disposed/connected guards и повторная проверка после await остаются
  в widget. Invalidate при cleanup не отменяет уже начатое SDK-действие и не
  разрешает следующему действию обогнать его.
- Ошибка сохраняется в Future вызывающего кода; внутренняя цепочка продолжает
  обслуживать следующие действия. Существующий debug reporter передан из widget.
- 9 characterization tests прошли на исходных методах до переноса. Прямые
  тесты модуля дополнены проверкой однократного reporter для sync/async ошибок;
  source-contract tests отдельно защищают wiring и порядок cleanup/guards.
- Camera/mic state, pause/resume policy, создание/закрытие CallClient и captions
  не переносились. Это не полный `DailySessionController`; native background /
  foreground smoke на iOS/Android остаётся непроведённым.

### Третий срез: правила входящих субтитров

- `caption_message_policy.dart` принимает payload, текущий caption snapshot и
  legacy counter; возвращает отдельный counter patch и необязательное обновление.
  ParticipantId, mutable maps, timers, UI и Firestore остаются в widget.
- В одном месте собраны legacy-нумерация, отбрасывание старых revision/utterance,
  подавление повторов и запрет final → interim для того же utterance.
- Counter patch применяется **до** отказа от обновления: даже отклонённый
  numeric payload может продвинуть счётчик. При исчезновении caption счётчик
  остаётся; departure/cleanup очищают его как раньше.
- Missing/invalid любого numeric поля включает legacy numbering; запись от
  имени peer разрешена только если оба поля не разобраны и phase final.
  Точная нормализация текста и совместимость форматов сохранены.
- 46 characterization tests прошли на исходном обработчике вместе с исходным
  upsert guard до переноса; тот же набор теперь проверяет pure policy.
  Дополнительные source-contract tests проверяют только wiring/владение эффектами.
- Deepgram stream, local utterance assembly, caption persistence/flush и полный
  `CaptionController` ещё не выделены. Native caption smoke не проводился.

### Четвёртый срез: сборка локальных реплик

- `LocalCaptionAssembler` владеет ID/revision, open flag, committed/current
  текстом, startedAt и confidence. Возвращает immutable emission; часы подменяются
  в тестах без ожиданий. Использует существующую нормализацию caption policy.
- Сборка сохраняет порядок правил prefix/suffix/word overlap. Промежуточный
  результат не коммитится; final segment и speech final остаются разными флагами.
- Подготовка финального обновления **не закрывает** реплику. Widget сохраняет
  порядок UI → outgoing → log → cancel fallback → close → fade, без `finally`
  закрытия при ошибке отправки/журнала. Последний короткий interim финализируется
  до flush/clear существующим stop-потоком.
- Close сохраняет revision/time/confidence; clear сбрасывает их, но сохраняет
  utterance ID для корректного порядка у собеседника. Timers, их generation guards,
  throttle, транспорт и Firestore по-прежнему принадлежат widget.
- До переноса: 30 проверок исходной сборки и 8 проверок порядка эффектов/ошибок
  в изолированной оболочке фактических методов. Постоянные тесты проверяют
  production assembler; отдельные source-contract tests защищают wiring.
- WebSocket/recording lifecycle, caption flush/retry и native smoke ещё впереди;
  это не завершение P1-04 и не полная проверка звонка на устройстве.

### Пятый срез: очередь сохранения субтитров

- До переноса подтверждена гонка: старый Firestore commit после смены
  `sessionId` мог удалить/пометить persisted запись новой сессии с тем же ID.
  Исправление описано в
  [`caption-log-queue-design`](../docs/superpowers/specs/2026-08-30-caption-log-queue-design.md)
  и прошло независимое spec review.
- `CaptionLogQueue<T>` владеет pending/persisted, serial Future chain,
  generation сессии и внутренними версиями entries. Snapshot создаётся только
  в голове цепочки; acknowledgement удаляет только идентичную версию того же ID.
- `reset()` немедленно изолирует старые active/queued flush-запросы. Поздний
  success/error возвращает `stale` и не меняет память новой сессии; unavailable
  session/writer сохраняет pending без ложного success.
- Widget сохраняет `_CaptionLogEntry`, Firestore batch,
  `CaptionLogsRecord.createDoc(sessionRef, id: entry.logId)`, `merge: true`,
  debounce 1000 ms, threshold 8, retry timer и disposed guard. При session
  switch старый timer отменяется до `queue.reset()`.
- Unit tests с управляемыми `Completer` проверяют reset во время commit,
  same-ID replacement, queued stale flush, FIFO, unavailable, sync/async errors
  и recovery. Source-contract tests фиксируют Firebase schema/IDs и timer wiring.
- Очередь остаётся in-memory: offline durability и native/network smoke не
  добавлялись. Deepgram WebSocket/recorder lifecycle и остальной cleanup всё
  ещё принадлежат widget; P1-04 не закрыта полностью.

### Шестой срез: разбор входящих Deepgram frames

- `deepgram_message_parser.dart` теперь чисто интерпретирует JSON envelope,
  service error, `UtteranceEnd`, alternatives, final flags, transcript и
  confidence. Нормализация текста переиспользует caption policy.
- Malformed JSON и неверный raw type намеренно бросают исходное исключение во
  внешний `try/catch` widget. Успешно decoded non-map возвращает
  `invalidEnvelope` без debug exception, как раньше.
- Widget сохраняет mounted/mic/remote/finalizing guard, диагностические коды и
  тексты, `UtteranceEnd` timer, explicit finalization, cancel fallback и передачу
  transcript в assembler. Outer catch продолжает охватывать parser и все effects.
- Совместимость закреплена matrix-тестами: приоритет error key/type, точный
  регистр `UtteranceEnd`, first-alternative-only, literal boolean flags,
  `speech_finalized`, toString/whitespace и num/string/NaN/Infinity confidence.
- WebSocket open/close, recorder/audio sink, generation guards и reconnect ещё
  принадлежат widget. Native Deepgram smoke и реальная сеть не проверялись;
  это по-прежнему частичная P1-04.

### Седьмой срез: latest-wins буфер исходящих субтитров

- `OutgoingCaptionBuffer<T>` владеет только последним pending item и подписью
  последней успешно завершившейся отправки. Value/signature хранятся атомарно.
- Сохранено текущее поведение: новый enqueue заменяет старый, failed send
  считается drop без mark, duplicate подавляется только после success, clear
  сбрасывает оба состояния. При перекрывающихся sends последний завершившийся
  success по-прежнему определяет duplicate signature.
- Widget сохраняет throttle 200 ms, immediate cancel timer, независимые
  `unawaited` flush, Daily `sendAppMessage`, JSON schema, mic/remote guards и
  обработку ошибок. Async chain, retry и generation намеренно не добавлялись.
- Challenge подтвердил достижимость overlapping sends, но receiver revision
  policy защищает от отката final более старым interim. Сериализация изменила бы
  транспортную семантику и требует отдельного design gate.
- Direct tests проверяют latest-wins, atomic value/signature, mark-on-success,
  drop-on-failure, completion-order и clear; source contracts защищают transport.
- Реальный порядок Daily/native messages и device/network smoke не проверялись.

### Восьмой срез: состояние Deepgram stream

- `DeepgramStreamGate` теперь владеет поколением stream, флагами start/stop и
  отдельным состоянием финализации. WebSocket, recorder, subscriptions, timers,
  diagnostics и restart effects остаются в widget.
- Сохранены исходные переходы: каждый непустой stop инвалидирует callbacks,
  повторный sink failure подавляется, а последующий обычный stop выполняет
  вторую инвалидацию. `stopRequested` остаётся установленным до нового start.
- Финальные Deepgram frames во время `Finalize` по-прежнему обходят generation и
  `shouldRun` guard. Проверка `shouldRun` передана callback-ом и не вычисляется в
  этой ветке, поэтому последние субтитры не отбрасываются раньше времени.
- Завершение финализации остаётся после закрытия WebSocket и до отмены message
  subscription; завершение полного stop остаётся после закрытия audio controller.
  Ранний no-op stop не меняет state gate.
- 10 временных characterization checks прошли до переноса. Постоянные unit tests
  покрывают token invalidation, stale start completion, repeated stop, sink race,
  lazy finalizing bypass и изоляцию экземпляров; source contracts фиксируют
  wiring и порядок эффектов. Полный набор: 2256 тестов, `flutter analyze` чистый.
- Параллельные вызовы `_stopDeepgramStreaming()` не входили в этот pure
  extraction; подтверждённый reentrancy-риск закрыт отдельным девятым срезом.
- Реальный Deepgram/native lifecycle smoke на iOS/Android не проводился.

### Девятый срез: single-flight остановка Deepgram

- `DeepgramStopSingleFlight` даёт одному stop-проходу эксклюзивное владение
  recorder, WebSocket, subscriptions и audio controller. Concurrent callers
  получают идентичный Future и не закрывают общие ресурсы повторно.
- Coordinator устанавливает Future до синхронного входа в operation, одинаково
  передаёт sync/async error и исходный stack trace, очищает active до уведомления
  listeners и разрешает reentrant retry после success/error.
- `_stopDeepgramStreaming()` остаётся не-`async` facade; исходный teardown без
  перестановок находится в `_performDeepgramStop()`. Start/restart queue и SDK
  effects не переносились.
- Fire-and-forget stop при `CallState.left` и смене `sessionId` теперь проходит
  через общий observer: ошибка не становится unhandled zone error и не логирует
  credential, URL, user ID, caption или сам объект ошибки. Awaited callers
  продолжают получать исходную ошибку общего Future.
- 8 unit tests проверяют identity, single invocation, synchronous entry,
  operation/completion/error reentrancy, stack trace, sync throw, retry,
  отсутствие второго runner error и изоляцию экземпляров. Source contract
  защищает non-async facade, два фоновых caller и прежний teardown order.
- `flutter analyze` чистый; полный набор — 2265 тестов. Реальный stop/reconnect
  smoke с native recorder/WebSocket на iOS/Android ещё не проводился.
  Независимый loop-code-review: findings нет, итоговая оценка 10/10.

### Десятый срез: одноразовые решения лимита звонка

- `CallLimitDecisionTracker` владеет только state трёх one-shot решений:
  показанными 5/10-минутными checkpoints, warning для exact expiry и auto-end
  request для exact expiry. Расчёт времени переиспользует `session_limit_ui`.
- Timer, ValueNotifier, server clock alignment, student/countdown/status guards,
  UI overlay, Firebase callable и error effects остаются в widget.
- Сохранена семантика прыжка времени: при первом значении ≥10 минут tracker
  возвращает `[5, 10]` в настроенном порядке и помечает оба checkpoint.
  Disconnect/cleanup без `clearHistory` не разрешает повторный показ.
- Session switch сбрасывает limit markers и checkpoint history; изменение
  `sessionExpiresAt` сбрасывает только warning/auto-end. Поздняя ошибка старого
  auto-end очищает marker только при совпадающем expiry и не снимает новый.
- До wiring существующие timer/VoIP characterization tests прошли 94/94.
  10 direct tests покрывают отдельные 5/10 checkpoints, jump order/dedup, reset
  boundaries, exact-instant expiry, null/matching/stale clear, retry и изоляцию.
  Source contract сохраняет guards и порядок решения до UI/Firebase effect.
- `flutter analyze` чистый; полный набор — 2276 тестов. Вынесение самого Timer
  отклонено challenge-review как слишком связанное с mounted/disposed,
  `_activeTimers` и notifier disposal для малого behavior-preserving среза.

### Одиннадцатый срез: generation-safe сохранение чата

- Добавлен чистый `CallChatPersistenceCoordinator<T>` без Flutter/Firebase.
  Он хранит generation, revisions, acknowledged state, лимит попыток и один
  root Future всей цепочки. Snapshot копируется в immutable list, а `T` остаётся
  caller-owned immutable/value-like объектом.
- Устранена гонка: сообщение, добавленное во время успешного request, делает
  revision dirty и запускает tail после очистки batch state. Concurrent callers
  присоединяются к тому же root Future, поэтому cleanup/end не обгоняют active
  persist. Ошибка не запускает скрытый retry; лимит `maxAttempts` равен 3 по
  умолчанию.
- `MinimalDailyWidget` передаёт generation/session guards через send,
  end-session, auto-end, terminal `didUpdateWidget` и dispose. При смене raw
  `sessionId` coordinator сбрасывается до очистки локального списка; поздние
  continuations старой сессии не меняют новую.
- `CallChatController` владеет pending sends текущей generation: persist ждёт
  уже начатые `sendAppMessage` перед snapshot, а успешный send во время batch
  повышает revision и создаёт dirty-tail pass. Session reset инвалидирует
  поздние continuations старой сессии.
- Payload, `persistCallChat`, timeout 8 секунд и empty valid-session call event
  сохранены. Cloud Function не менялась; её существующий лимит 100 сообщений
  за request остаётся отдельным scope для будущего chunking/capping.
- Добавлены прямые controllable tests с `Completer`: identity root/tail,
  sync entry, dirty tail, reset во время batch/tail, stack-preserving errors,
  maxAttempts, no-request completion и instance isolation.
  ordering/reset сценария. QA source-contract дополнительно защищает wiring и
  удаление трёх прежних mutable flags.
- `flutter analyze` чистый; focused coordinator/barrier tests: 18/18, полный
  Flutter-набор — 2294/2294, backend `persist_call_chat` — 7/7.

### Двенадцатый срез: decoder входящих Daily app-message

- `decodeDailyAppMessagePayload` вынесен в маленький pure Dart helper без
  Flutter/Daily зависимостей. Он сохраняет ровно два decode-прохода, trim на
  каждом строковом слое и `Map<String, dynamic>.from` для итогового object.
- Malformed первый/второй JSON layer и map conversion по-прежнему бросают во
  внешний `try/catch` widget. Empty string, non-object JSON и triple-encoded
  object возвращают `null`, как раньше.
- Widget сохраняет mounted guard, generic debug log, case-sensitive routing
  `caption`/`chat`, `ParticipantId` и все caption/chat effects.
- 7 direct matrix tests покрывают single/double encoding, whitespace, malformed
  layers, null/list/bool/number, triple encoding и структуру результирующего
  mutable map. Source-contract фиксирует порядок mounted → try/decode → routes
  → catch и отсутствие прежнего private decoder.
- Challenge checkpoint: `PROCEED_WITH_SCOPE`; chat reducer и cleanup extraction
  отклонены для этого среза как менее ценные либо слишком широкие.
- `flutter analyze` и diff-check чистые; focused decoder/VoIP tests — 73/73,
  полный Flutter-набор — 2302/2302.

### Тринадцатый срез: правила имён и ID участников

- `call_participant_identity.dart` содержит четыре pure-функции без
  Flutter/Daily/Firebase. Wrapper-методы сохраняют lookup участников и передачу
  raw SDK/widget значений; существующие callers, payload и UI не менялись.
- Remote display name использует trimmed Daily username либо дословный fallback.
  Local name сохраняет приоритет Daily → widget username → роль; `isStudent`
  только при `true` даёт «Студент», иначе «Преподаватель».
- Legacy remote caption-log speaker key сохраняет trimmed userId → trimmed
  participant session ID → `remote_<utteranceId>`. Это не auth identity.
  Local Daily ID остаётся raw, включая whitespace-only; только null/empty
  заменяются на `local`. Непустые `null`/`0` не являются sentinel-значениями.
- До production wiring 13 matrix tests прошли на фактических исходных private
  методах, извлечённых без изменения тел во временную оболочку SDK-данных.
  После переноса тот же набор напрямую проверяет helper; временная оболочка
  удалена. Два source-contract tests отдельно защищают wiring и разные ID
  consumers: локальный caption-log writer UID не подменён Daily ID, remote
  chat/active captions по-прежнему используют raw participant ID.
- Challenge checkpoint: `PROCEED_WITH_SCOPE`. Новых controllers, зависимостей,
  модели участника или дополнительного чтения CallClient не добавлено.
- Фокусные identity/VoIP tests — 81/81; `flutter analyze` и diff-check чистые.
  Реальная передача media/субтитров на устройстве в этом pure-срезе не
  проверялась; P1-04 остаётся частично выполненной.

## Доказательство долга

[`lib/custom_code/widgets/minimal_daily_widget.dart`](../lib/custom_code/widgets/minimal_daily_widget.dart)
содержит около 6116 строк и объединяет Daily `CallClient`, lifecycle,
reconnect/token refresh, аудио/видео tracks, Deepgram websocket, captions,
caption persistence, chat, session auto-end, timers, cleanup и UI. В файле
десятки `try/catch` и `print`, ручные timers и mutable state. Любое изменение
субтитров потенциально затрагивает звонок или cleanup.

## Цель

Сохранить один публичный widget API, но разделить stateful orchestration по
жизненным циклам и сделать критические решения тестируемыми.

P1-02 владеет server call/trial state machine; здесь scope только Daily/media
client lifecycle и UI bridge, без новой billing/reconciliation policy.

## Минимальный scope

1. `DailySessionController`: create/join/leave/connection/reconnect.
2. `CaptionController`: Deepgram credential, websocket, utterance, flush,
   diagnostic state.
3. `CallTimerController`: active start, deadline, pause/resume, cleanup.
4. `CallChatController`: local queue, persist, retry.
5. Presentational widgets для local/remote video, captions, controls.
6. `MinimalDailyWidget` только связывает controllers, callbacks и layout.

Сначала выделить pure helpers и controllers внутри `custom_code` без нового
state-management package.

## TDD-порядок

- Characterization tests на timer, duplicate client guard, reconnect, end
  callback, caption diagnostics и cleanup ordering.
- Fake Daily/Deepgram clients and clock; no real network in unit tests.
- Red tests for “disconnect before connected”, “late event after dispose”,
  “stale token”, “caption flush after end”.
- Move one responsibility at a time; after each move run focused widget tests
  and `flutter analyze`.
- Real-device smoke on iOS and Android after controller extraction.

## Не входит

- Замена Daily или Deepgram.
- Новый global store.
- Изменение caption schema или call screen visual design.

## Подводные камни

- Все timers, streams, websocket и CallClient должны закрываться ровно один
  раз; late callbacks после `dispose` игнорируются.
- Нельзя логировать токены, room URL, user IDs или caption PII.
- Server session state остаётся источником истины для call duration.
- Нельзя исправлять race локальным `Future.delayed` без теста на ordering.

## Готово, когда

- Публичный constructor и callback contracts сохранены.
- Controllers имеют unit tests и injectable dependencies.
- Widget build не выполняет сеть, I/O или тяжёлую обработку.
- Cleanup deterministic в success, error, timeout и dispose paths.

## Риск, abort и откат

- **Abort:** crash, token leak, late callback после dispose, потерянный caption
  или timer drift; не продолжать перенос следующей ответственности.
- **Откат:** вернуть предыдущий widget/facade commit; сохранённые captions и
  session state не переписывать.
- **Необратимость:** отсутствует для extraction; schema migration отдельна.
