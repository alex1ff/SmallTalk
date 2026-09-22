# P1-02 — Единая матрица call/trial lifecycle

**Размер:** L · **Владелец:** call backend + Flutter QA · **Зависимости:**
P0-01; частично параллельно с P1-03/P1-04.

## Доказательство долга

В проекте много полезных unit/contract tests, но call flow распределён между
`start_search.js`, `match_pair_lock.js`, `create_video_session.js`,
`accept_call.js`, `respond_to_match.js`, `decline_call.js`, `cancel_call.js`,
`stop_search.js`, `end_session.js`, Daily callbacks и Flutter listeners.
Ошибки “соединился и отвалился”, 0:00 → 5:00, повтор trial и no-responder
легко расходятся между входами. Сейчас нет одной таблицы состояний и теста,
который проходит весь серверный сценарий от reservation до final reconciliation.

## Цель

Зафиксировать state machine и матрицу invariants без введения нового workflow
framework.

Эта задача владеет контрактом и тестовой матрицей. P1-03/P1-04/P1-08 могут
выносить код только после фиксации этих переходов и не должны создавать свои
конкурирующие state machines.

## Минимальный scope

1. Составить таблицу: `searching`, `pending_confirmation`, `connecting`,
   `active`, `ended`, `canceled`, `expired`, `technical_failure` и допустимые
   переходы.
2. Для каждого перехода указать actor, trusted timestamp, lease/heartbeat,
   idempotency key, entitlement/trial effect и user-visible error.
3. Добавить pure decision tests для allowed/denied transitions.
4. Добавить emulator transaction tests минимум для:
   - один trial reservation при двойном tap;
   - технический обрыв до qualification не consumes trial;
   - реальный connected call consumes ровно один trial;
   - no responder/cancel/expire reconcile reservation;
   - повтор webhook/callable не удваивает writes.
5. Сверить Flutter labels/timers с backend state, не подменяя server truth
   локальным таймером.

## TDD-порядок

1. Сначала characterization существующих callable responses/error details.
2. Red: тест на каждую дыру из таблицы.
3. Green: минимальная правка owner-функции.
4. Refactor: вынести только повторяющиеся pure policies в существующий
   `trial_access.js`/`video_sessions_shared.js`.
5. Regression: emulator suite + targeted Flutter widgets.

## Не входит

- Новый event bus/CQRS/actor model.
- Переписывание Daily SDK.
- Изменение длительности trial (30 минут окна, qualification policy) без
  отдельного product decision.

## Подводные камни

- Клиентская потеря сети не является доказательством завершения звонка.
- Timestamp должен быть backend/server snapshot, не значение устройства.
- В тесте нужно различать reservation, accepted, connected и qualified.
- Проверять оба участника: student и native speaker/teacher имеют разные
  права и trial effects.

## Готово, когда

- Есть одна state-transition таблица рядом с тестами.
- Каждый terminal path имеет ровно одну reconciliation policy.
- Повтор любого callable/webhook idempotent.
- Тесты ловят trial replay и false consumption.

## Риск, abort и откат

- **Abort:** тест обнаружил duplicate charge/session, новый transition расходится
  с server truth или выросла flakiness; остановить policy refactor.
- **Откат:** revert pure policy/owner-function commit; сохранённые production
  данные не откатывать автоматически.
- **Необратимость:** отсутствует до отдельной миграции trial/payment data.
