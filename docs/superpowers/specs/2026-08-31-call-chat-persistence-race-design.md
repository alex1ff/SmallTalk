# Call chat persistence: generation-safe single-flight coordinator

## Контекст

`MinimalDailyWidget._persistOwnCallChatMessages()` берёт snapshot локально
отправленных сообщений, ждёт `persistCallChat`, затем безусловно ставит
completed. Сообщение, добавленное во время await, отсутствует в старом snapshot
и больше не сохраняется. Late send/end/auto-end/persist continuations также
могут изменить state уже новой сессии. Отдельная гонка возникает, если
`endSession`/terminal/dispose начинают persist пока `sendAppMessage` ещё
выполняется: его успешное continuation может добавить сообщение уже после
чистого persist.

Backend менять не нужно: `persist_call_chat.js` строит message document ID из
`sessionId + senderId + clientId` и транзакционно пропускает существующие
сообщения. Повторная отправка полного snapshot идемпотентна.

## Цель

Не терять сообщение, добавленное во время успешного in-flight snapshot, пока
живёт тот же session generation и snapshot укладывается в существующий
backend limit (не более 100 сообщений за request). Не позволять старым
send/end/auto-end/persist continuations менять новую сессию. Сохранить прежние
payload, лимит попыток по `maxAttempts` (по умолчанию 3), backend schema, UI и
публичный widget API.

Сообщения, которые существовали только в памяти и не попали ни в один request
до аварийного уничтожения процесса/старой сессии, остаются отдельным durable
offline scope. Сообщения сверх backend limit 100 также остаются вне гарантии
до отдельной задачи по chunking/capping.

## Не входит

- Cloud Function, Firestore schema/rules или новый endpoint;
- local database/offline recovery;
- автоматический retry failed backend request или новая backoff policy;
- входящие сообщения, Daily transport или UI;
- полный `CallChatController` extraction.

## Компонент

### `CallChatPersistenceCoordinator<T>`

Один generic Dart-класс без Flutter/Firebase. `T` обязан быть immutable/value-like
на стороне caller; coordinator копирует входной `Iterable<T>` в immutable List,
но не может защитить от мутации самого объекта `T`.

Coordinator владеет:

- monotonically increasing session generation;
- current message revision и acknowledged revision;
- root Future всей текущей цепочки persist;
- отдельным batch-running состоянием;
- completed flag и attempt count;
- `maxAttempts`, по умолчанию 3.

`MAX_CALL_CHAT_MESSAGES = 100` остаётся ограничением существующей Cloud
Function. Chunking или отдельное ограничение локального списка не входят в
этот срез; гарантия tail применяется только к batch, принятому backend.

API:

- `generation` и `isCurrentGeneration(int)` — guards внешних async paths;
- `recordMessage()` — повышает revision и снимает completed;
- `reset()` — повышает generation, очищает revisions/flags/attempt count,
  отцепляет root Future старой generation, но не отменяет уже начатый backend
  request;
- `completeWithoutRequest({required expectedGeneration})` — non-async Future;
  присоединяется к current root, если он есть, иначе отмечает current revision
  acknowledged и completed;
- `persist({expectedGeneration, snapshot, persistBatch})` — non-async Future;
  `snapshot` имеет тип `Iterable<T> Function()`, а `persistBatch` —
  `FutureOr<void> Function(List<T> immutableEntries)`. Coordinator создаёт
  immutable копию списка перед callback; caller владеет immutable/value-like
  объектами `T`.

`persist` возвращает один и тот же **root Future** всем concurrent callers на
всём протяжении batch/tail chain. Это identity contract самого non-async
coordinator method. Async widget adapter возвращает derived Future и сохраняет
прежнюю error policy.

## State machine и identity

1. Stale `expectedGeneration` возвращает `Future<void>.value()` до чтения
   session/list.
2. `completed && currentRevision == acknowledgedRevision` — no-op.
3. Если root chain уже активна, caller получает тот же root Future; второй batch
   не стартует одновременно.
4. Если attempts достигли `maxAttempts`, chain завершается без нового request.
5. Для нового root coordinator создаёт `Completer<void>`, сохраняет его Future
   как `_activeRoot` до вызова callbacks и начинает первый batch синхронно.
6. Batch захватывает immutable token `(generation, revision)` и immutable list.
   `_batchRunning` относится только к текущему batch и очищается до tail.
7. Success current generation:
   - clean revision обновляет acknowledged revision и completed=true;
   - dirty revision оставляет completed=false и требует tail.
8. Если нужен tail, coordinator оставляет тот же root Future active, очищает
   `_batchRunning`, затем приватно запускает следующий batch напрямую. Tail не
   вызывает публичный `persist`, поэтому не присоединяется сам к себе.
9. Root Future завершается только после всей успешной tail chain. Concurrent
   caller во время tail получает тот же root Future.
10. Перед complete/completeError coordinator очищает `_activeRoot` только по
    identity. Completion/error listener может сразу начать новый root.
11. `reset()` отцепляет старый root. Старый batch по завершении сравнивает
    generation/root identity и не меняет state новой generation; новый root
    может идти параллельно со старым backend request на другом session ID.

## Ошибки

Coordinator передаёт sync/async error и исходный stack trace в root Future; не
создаёт второго unobserved runner Future и не делает automatic retry ошибки.
Widget adapter перехватывает backend/coordinator error в существующем catch,
пишет текущий debug log и возвращает caller-у **derived normal Future**, как до
изменения. Identity contract действует только внутри coordinator: каждый
adapter вызов наблюдает root error ровно один раз и не оставляет unhandled
error. Новый tail error проходит тот же adapter catch. Поэтому awaited widget
callers сохраняют прежнюю error policy, а direct coordinator tests могут
наблюдать исходный error.

Новые логи coordinator/observer не содержат сообщения, user ID, session ID,
credentials или error object. Существующие generic `$error`/`$e` логи widget не
расширяются и не меняются в этом срезе.

## Widget wiring

Widget хранит coordinator и прежний `_ownSentChatMessages`; старые поля
`_persistCallChatInFlight`, `_persistCallChatCompleted` и
`_persistCallChatAttemptCount` удаляются.

### Daily send

`_sendChatMessage()` захватывает coordinator generation и нормализованный
session ID до `sendAppMessage`. После await добавляет сообщение и вызывает
`recordMessage()` только при совпадении generation и session ID. `finally`
меняет `_isSendingChatMessage` только для current pair. Session switch
синхронно сбрасывает этот UI flag.

`CallChatController` сам владеет pending sends текущей generation. Persist
сначала дожидается уже начатых sends, затем снимает immutable snapshot;
успешный send во время batch повышает revision и создаёт dirty-tail pass.
Session reset инвалидирует старую generation, поэтому поздний send не меняет
новую сессию.

### Persist adapter

`_persistOwnCallChatMessages({int? expectedGeneration})`:

- отбрасывает stale expected generation до чтения `widget.sessionId`;
- при missing session вызывает `completeWithoutRequest` и не делает I/O;
- сначала ждёт текущий `sendAppMessage` той же generation и session, затем
  повторно проверяет guards перед snapshot;
- передаёт coordinator snapshot текущего списка;
- `persistBatch` замыкает нормализованный session ID, формирует прежний payload,
  вызывает прежний callable и timeout 8 секунд;
- ловит backend/coordinator errors в прежнем catch, не меняет retry policy;
- все fire-and-forget callers используют существующий безопасный wrapper, а
  coordinator root error не становится unhandled.

### End-session и auto-end

`_endSessionAndPersistCallChat()` и `_requestAutoEndAtSessionLimit()` захватывают
generation, normalized session ID и (для auto-end) target expiry до
`endSession`. После await status, marker и persist effects выполняются только
если generation, session ID и auto-end expiry (где применимо) всё ещё совпадают.
Persist получает captured generation и не перечитывает новую сессию.

### Session switch и terminal didUpdate

При raw `sessionId` change coordinator `reset()` выполняется до очистки списка,
flags и `_isSendingChatMessage`; raw comparison сохраняется как прежний,
поэтому whitespace-only change тоже считается switch. Terminal status branch
не вызывает persist для того же `didUpdateWidget`, если в нём уже был session
switch; иначе передаёт current expected generation.

## Сохранённое поведение

- `persistCallChat` payload: `sessionId`, `clientId`, `text`, `sentAtMs`;
- empty valid-session request создаёт call event;
- missing session делает local no-op completion;
- максимум `maxAttempts` batch attempts (по умолчанию 3), включая successful
  dirty tails;
- failed backend request автоматически не повторяется;
- persist callers ждут root chain; fire-and-forget participant-left,
  terminal/auto-end и dispose paths передают тот же root через adapter, но не
  блокируют остальной lifecycle;
- backend idempotency принимает повторный полный snapshot, если batch не
  превышает существующий limit 100 сообщений.

Намеренное изменение: concurrent caller теперь ждёт shared root Future вместо
немедленного return. Это не меняет данные, но не позволяет cleanup/end обогнать
уже начатое сохранение.

## Инварианты

- Только clean current snapshot выставляет completed.
- `recordMessage()` после clean success снова делает dirty state.
- Dirty success запускает tail после очистки batch-running state.
- Только completion текущего root/batch identity и generation меняет coordinator
  state после await; синхронные `recordMessage`, `reset` и
  `completeWithoutRequest` являются отдельными owner operations.
- Старые send/end/auto-end continuations не читают и не меняют новую сессию.
- Failed request не создаёт скрытый retry или unhandled tail error.
- Гарантия сохранения относится к сообщениям, появившимся во время snapshot в
  той же generation, только для backend-accepted batch (не более 100); это не
  offline durability promise.

## TDD

Direct controllable coordinator tests с `Completer`:

1. concurrent callers получают identical root Future и один batch;
2. operation входит синхронно после установки root;
3. message during first batch создаёт второй snapshot после batch clear;
4. первый Future ждёт tail completion;
5. concurrent caller during tail получает тот же root identity;
6. message after clean success разблокирует новый root;
7. reset during batch изолирует late success/error, разрешает новый root;
8. reset during tail не позволяет старому tail читать новый snapshot;
9. sync/async failure сохраняет stack, не retry-ит и не создаёт second error;
10. tail failure наблюдаем через root без unhandled error;
11. ровно `maxAttempts` attempts не создают следующий request (отдельно
    проверяется значение по умолчанию 3);
12. `completeWithoutRequest` присоединяется к active root, корректно no-op для
    stale expected generation и завершает current no-session state;
13. instances изолированы.

Отдельные direct barrier tests проверяют request во время send, send после
request, failed send без лишнего persist и reset старого lease.

Widget source-contract tests:

- coordinator import/field и отсутствие старых трёх flags;
- `recordMessage()` строго после Daily success и guards send/finally;
- pending `sendAppMessage` завершается до persist snapshot, а session switch
  сбрасывает pending barrier;
- snapshot/token capture до callable await;
- completed/tail decisions delegated through coordinator;
- tail/start expected-generation guards;
- end-session, auto-end (включая expiry) и terminal didUpdate guards;
- session reset до clear и UI flag reset;
- прежний payload/function name/timeout/attempt cap;
- fire-and-forget paths не оставляют unhandled error.

Существующие backend tests продолжают подтверждать `clientId` idempotency.
После реализации: `flutter analyze`, coordinator + VoIP/QA persistence tests,
backend `persist_call_chat.test.js`, полный `flutter test`, независимый
loop-code-review.

## Риски и откат

Риски: root/batch identity deadlock, recursive tail сверх лимита, stale
completion clearing new state, unhandled tail error, старый send/end/auto-end
на новой сессии. Unit/source tests фиксируют эти границы.

При регрессии откатывается coordinator/wiring; backend и данные не мигрируются.
Native/network smoke с реальной задержкой callable остаётся отдельной проверкой.
