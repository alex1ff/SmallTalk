# Caption log queue: защита от поздних ответов

## Контекст

`MinimalDailyWidget` хранит pending/persisted caption logs и последовательно
записывает их batch-операциями Firestore. Пока `batch.commit()` ожидает сеть,
widget может получить новый `sessionId`, очистить очередь и добавить запись с
тем же `logId`. Сейчас поздний success старой операции удаляет запись только по
`logId`, поэтому может удалить новую запись и пометить её уже сохранённой.

## Цель

Выделить небольшую тестируемую очередь и не позволить операциям старого звонка
изменять состояние нового звонка. Сохранить Firestore schema, document IDs,
merge writes, debounce 1000 ms, threshold 8, сериализацию flush и retry после
ошибки.

## Не входит

- durable/offline storage;
- новая backoff policy;
- изменение caption payload или правил Firestore;
- перенос timers, Firebase batch adapter или widget lifecycle;
- параллельные flush-операции.

## Компоненты

### `CaptionLogQueue<T>`

Один generic-класс без Flutter/Firebase зависимостей. Владеет:

- pending map `logId → entry`;
- persisted ID set;
- generation текущей сессии;
- serial Future chain.

API минимальный:

- `enqueue(id, entry)` — заменяет pending entry, если ID ещё не подтверждён;
- `pendingCount`, `isEmpty` — для threshold/retry wiring;
- `flush(persist)` — сериализует snapshot и передаёт его callback. Callback
  возвращает `true` после commit и `false`, если session/writer недоступны;
- `reset()` — повышает generation и очищает pending/persisted;
- `clear()` при окончательном dispose не требуется: `reset()` достаточно.

`flush` возвращает один из результатов: `empty`, `persisted`, `unavailable` или
`stale`. Empty не вызывает callback. Unavailable сохраняет pending и отличается
от empty success. Ошибка актуального generation пробрасывается с исходным stack
trace в widget; ошибка устаревшего generation превращается в `stale` и не
попадает в retry-path новой сессии.

### Widget adapter

Widget сохраняет:

- проверку session/writer;
- создание Firestore batch и `SetOptions(merge: true)`;
- debounce/threshold timers;
- debug diagnostics и условие retry `!_disposed`.

`didUpdateWidget` при смене `sessionId` сначала отменяет
`_captionLogFlushTimer`, затем вызывает `queue.reset()` до работы с новой
сессией. Старый debounce/retry timer не должен запускать flush новой сессии.

## Data flow

1. Producer создаёт `_CaptionLogEntry` как сейчас.
2. Widget проверяет наличие session/writer и вызывает `queue.enqueue`.
3. Threshold или timer вызывает `queue.flush(persistCallback)`. В этот момент
   queue фиксирует generation запроса, но ещё не копирует entries.
4. После достижения головы serial chain queue сначала проверяет generation.
   Если запрос уже stale, он завершается без callback. Только актуальный запрос
   создаёт snapshot текущих entries и вызывает persist callback.
5. После success queue подтверждает только snapshot того же generation.
6. Для каждого ID acknowledgement атомарно проверяет
   `identical(currentPending[id], snapshotEntry)`. Только при успехе проверки
   запись одновременно удаляется из pending и ID добавляется в persisted.
   Для replacement не выполняется ни одно из этих действий.
7. Если generation сменился во время активного callback, success/error старой
   операции не меняет новое
   состояние и не просит retry.
8. Ошибка текущего generation сохраняет pending entries; widget ставит retry.

Старая batch-операция может корректно завершить запись в документ старой
сессии. Запрещено только её позднее влияние на память новой сессии.

## Инварианты

- В каждый момент выполняется максимум один persist callback.
- Enqueue во время flush не теряется; same-ID replacement остаётся pending и
  не становится persisted старым acknowledgement.
- Новая версия того же ID не удаляется acknowledgement старой версии.
- `reset()` не прерывает активную сеть и не обгоняет её в serial chain, но
  синхронно инвалидирует активный и уже поставленные старые flush-запросы.
  Поставленный, но ещё не начавшийся старый запрос не видит entries новой сессии.
- Только exception актуального generation пробрасывается вызывающему;
  `unavailable` и `stale` возвращаются результатом. Во всех случаях внутренняя
  serial chain восстанавливается и не блокирует следующие flush-операции.
- Missing session/writer не считается success и не подтверждает записи.
- Entry и caption PII не попадают в новые логи.

## Ошибки и retry

Persist callback возвращает `false`, когда session/writer недоступны: queue
оставляет pending и возвращает `unavailable` без retry, как текущий ранний
выход. Callback бросает исходную ошибку при фактической ошибке записи. Queue
оставляет snapshot pending и восстанавливает внутреннюю Future chain. Если
generation ещё актуален, та же ошибка с исходным stack trace доходит до widget;
widget сохраняет debug log и создаёт один debounce retry, когда очередь непуста
и widget не disposed. Если generation уже сменился, queue возвращает `stale`,
а widget не логирует ошибку как относящуюся к новой сессии и не ставит retry.

## Тесты

До изменения production-кода зафиксировать существующее поведение: FIFO,
dedup persisted IDs, replacement pending entry, success acknowledgement,
failure retention/recovery и threshold/debounce wiring.

Новые regression-тесты:

1. entry добавлен во время commit — success удаляет snapshot, но не новый ID;
2. тот же ID заменён во время commit — старая acknowledgement не удаляет его;
3. `reset()` во время success/error — старый callback не меняет новую очередь;
4. новая сессия ждёт старый in-flight callback, затем сохраняется отдельно;
5. retry разрешён только для ошибки актуального generation;
6. synchronous и asynchronous exception не отравляют serial chain;
7. widget source-contract сохраняет batch schema, merge write,
   `CaptionLogsRecord.createDoc(sessionRef, id: entry.logId)`, timer threshold,
   session reset и dispose guard.
8. empty flush не вызывает persist callback;
9. unavailable session/writer сохраняет pending и не считается empty success;
10. поставленный, но ещё не начавшийся flush инвалидируется reset и не читает
    entries новой generation;
11. replacement не удаляется и не становится persisted старым acknowledgement;
12. старый debounce/retry timer отменяется при session switch, а новая запись
    получает обычные 1000 ms;
13. current-generation error доходит до widget, stale error не создаёт retry
    новой generation.

После правки: `flutter analyze`, профильные Flutter tests, полный `flutter test`,
затем независимый loop-code-review. Native smoke остаётся отдельной проверкой.

## Откат и риск

Изменение локальное и не меняет данные на сервере. При красных тестах, потере
записи или нарушении FIFO откатывается только queue/wiring с сохранением новых
характеризационных тестов. Основной остаточный риск — отсутствие device/network
smoke с реальной задержкой Firestore.
