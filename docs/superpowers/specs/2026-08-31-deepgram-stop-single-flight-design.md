# Deepgram stop: single-flight cleanup

## Контекст

`MinimalDailyWidget` вызывает `_stopDeepgramStreaming()` из независимых путей:
смены состояния Daily, microphone sync, ошибок start/audio sink, reconnect,
смены `sessionId` и общего cleanup. Несколько вызовов могут пересечься на
`await` и одновременно читать или закрывать общие recorder, WebSocket,
subscriptions и controller. Текущие локальные `try/catch` защищают отдельный
шаг от исключения, но не дают одному владельцу всего stop-прохода.

## Цель

В каждый момент выполнять максимум один полный Deepgram stop. Повторный вызов
должен получить и дождаться того же `Future`, включая тот же success/error.
После завершения следующий вызов может запустить новый stop. Сохранить порядок
и содержание существующей очистки, final caption flush и restart.

## Не входит

- общая очередь start/stop/restart операций;
- отмена уже начатого stop;
- изменение Deepgram WebSocket/recorder protocol;
- новая retry/backoff policy;
- изменение caption payload, diagnostics или UI;
- исправление session-switch orchestration за пределами stop;
- native/device smoke вместо unit tests.

## Рассмотренные варианты

1. **Небольшой single-flight coordinator — выбран.** Повторные вызовы разделяют
   один `Future`; алгоритм изолирован и проверяется без Flutter/native SDK.
2. Общая lifecycle-очередь для start/stop/restart. Закрывает больше гонок, но
   меняет гораздо больше семантики и не нужна для подтверждённого риска.
3. Немедленный return повторного stop. Проще, но вызывающий код может начать
   restart/cleanup до фактического освобождения ресурсов.

## Компоненты

### `DeepgramStopSingleFlight`

Небольшой Dart-класс без Flutter и SDK зависимостей. Он хранит только текущий
`Future<void>?` и предоставляет один метод:

- `run(Future<void> Function() operation)` — запускает operation, если активной
  нет, иначе возвращает существующий Future.

`run` — **не `async`**: он обязан вернуть сохранённый Future без обёртки и
сохранить object identity. Перед вызовом operation coordinator создаёт обычный
`Completer<void>()`, сохраняет его Future как активный и только затем синхронно
вызывает callback. Поэтому operation сохраняет текущее выполнение до первого
`await`, а даже синхронный reentrant вызов присоединяется к уже установленному
Future. Sync throw перехватывается тем же кодом, что async error.

Success завершает общий Future. Ошибка и исходный stack trace передаются всем
ожидающим. Перед `complete` или `completeError` coordinator очищает активную
ссылку, только если она всё ещё указывает на Future этого запуска. Поэтому
completion/error listener может reentrant запустить новый stop, а не получить
уже завершённый старый Future. Обычный, не sync `Completer` уведомляет listeners
асинхронно. `then/onError` внутреннего runner завершается success после переноса
результата в Completer и не создаёт второй unobserved error Future.

### Widget adapter

Widget хранит один `DeepgramStopSingleFlight`. Текущий метод разделяется на:

- не-`async` `_stopDeepgramStreaming()` с прямым
  `return coordinator.run(_performDeepgramStop)`;
- `_performDeepgramStop()` — неизменённое тело существующей stop-очистки.

Awaited callers продолжают вызывать `_stopDeepgramStreaming()` и автоматически
присоединяются к активной операции. Два fire-and-forget места — Daily
`CallState.left` и смена `sessionId` — используют общий
`_stopDeepgramStreamingUnawaited()`. Он присоединяет `catchError`, пишет только
безопасный debug context и передаёт полученный Future в `unawaited`. Это
предотвращает unhandled zone error, не меняя общий Future и ошибку для awaited
listeners. I/O и mutable SDK resources не переходят в coordinator.

## Сохранённый порядок

Внутри первого stop порядок остаётся прежним:

1. ранний no-op guard выполняет final caption/log flush и возвращается;
2. state gate фиксирует stop/finalizing и инвалидирует stream generation;
3. отменяется audio subscription;
4. останавливается и закрывается recorder;
5. отправляются `Finalize`/`CloseStream`, закрывается WebSocket;
6. завершается finalizing window;
7. отменяется message subscription;
8. закрывается audio controller;
9. завершается stop state, обновляется UI state;
10. финализируется caption, flush logs, очищается local caption.

Повторный concurrent вызов не выполняет этот список второй раз и не делает
дополнительную generation invalidation. Последовательный вызов после полного
завершения снова выполняет обычный no-op или resource stop, как раньше.

## Restart и ошибки

- Два restart-path могут дождаться одного stop. После него первый start
  синхронно выставляет `startInProgress`; второй start отбрасывается текущим
  guard, поэтому duplicate stream не создаётся.
- Ошибки отдельных cleanup steps по-прежнему локально логируются и не мешают
  последующим шагам.
- Если внешний final caption/log step пробросит ошибку, все waiters получают
  её с исходным stack trace. Coordinator очищается, и следующий stop разрешён.
- Coordinator не добавляет retry и не подавляет ошибку вызывающего кода.
- Fire-and-forget observer поглощает ошибку только в своей derived Future;
  awaited listeners общего Future по-прежнему получают исходную ошибку.
- Новые логи не содержат credential, room URL, user ID или caption text.

## Инварианты

- Одновременно выполняется не более одного stop callback.
- Все concurrent callers получают идентичный Future.
- `run` и `_stopDeepgramStreaming` не `async` и не оборачивают общий Future.
- Coordinator устанавливает активный Future до первого вызова operation.
- Operation начинает выполняться синхронно до возврата `run`.
- Активная ссылка очищается до уведомления success/error listeners.
- Success и error доступны всем waiters; после обоих состояний разрешён retry.
- No-op stop тоже single-flight, но после его завершения может выполняться снова.
- Start, stream gate и все SDK effects остаются владельцами widget.
- `finishFinalization` и `finishStop` сохраняют текущие разные моменты времени.

## TDD и проверки

До wiring добавить unit tests coordinator:

1. два concurrent run вызывают operation один раз и возвращают `identical`
   Future;
2. operation входит синхронно до возврата `run`;
3. reentrant run из operation получает уже установленный Future;
4. оба waiters завершаются после одного success;
5. completion listener reentrant запускает новую operation;
6. после success следующий обычный run запускает новую operation;
7. async error и исходный stack trace получают оба waiters;
8. error listener reentrant запускает новую operation;
9. synchronous throw обрабатывается так же и разрешает retry;
10. zone-test после microtask drain не видит второго uncaught runner error,
    когда caller обработал shared error;
11. независимые coordinator не делят состояние.

Source-contract tests widget должны фиксировать:

- один coordinator field и не-`async` wrapper с прямым
  `return ...run(_performDeepgramStop)`;
- отсутствие resource cleanup в wrapper;
- полное существующее тело и порядок внутри `_performDeepgramStop`;
- awaited callers используют wrapper, а оба fire-and-forget callers — общий
  error-observing helper;
- ранний no-op return остаётся до `requestStop`.

После правки: `flutter analyze`, direct coordinator tests, VoIP regression tests,
полный `flutter test`, затем независимый loop-code-review.

## Риск, abort и откат

Основной риск — скрытая взаимная зависимость, при которой сама stop operation
ожидает публичный `_stopDeepgramStreaming()`. В текущем теле такого вызова нет;
source-contract закрепит отсутствие рекурсии. Если появится deadlock, resource
leak, потеря final caption или restart перестанет запускаться, срез откатывается
целиком до прежнего прямого метода.

Изменение не затрагивает серверные данные и не требует миграции. Реальная
проверка background/foreground, audio sink failure и reconnect на iOS/Android
остаётся отдельным smoke после controller extraction.
