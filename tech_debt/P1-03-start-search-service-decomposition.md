# P1-03 — Декомпозиция `start_search.js`

**Размер:** XL · **Владелец:** matchmaking · **Стадия:** второй этап ·
**Зависимости:** P1-02.

## Прогресс — выполнено, 31.08.2026

- Вынесены `start_search_request_policy.js`, `start_search_entry_policy.js`,
  `start_search_responder_policy.js` и `start_search_push_transport.js`.
  Сохранены существующие exports и callable contracts.
- Stateful responsibilities разделены без нового framework:
  `start_search_notification_store.js` владеет Firestore notification writes и
  повторными проверками; `start_search_delivery.js` — push/foreground routing;
  `start_search_recovery.js` — release/retry transactions;
  `start_search_matcher.js` — candidate/lock orchestration и восстановление.
- Рекурсивная группа `tryCreate → reconcileReleased → resumeRestored →
  tryCreate` оставлена в одном matcher module, поэтому циклических imports нет.
  `start_search.js` — façade на 475 строк: callable transaction, error mapping,
  registration/secrets и прежний `__private__` compatibility surface.
- Тела перенесённых функций механически сохранены. Единственное поведенческое
  исправление — доказанный context binding pre-push hook из раздела ниже.
- Добавлены characterization tests на stale guards и cooldown/re-read при
  восстановлении поиска. Runtime consumers продолжают импортировать прежний
  façade; прямой переход на новые private modules им не требуется.
- Полный search emulator после декомпозиции: 106/106 без skips; lifecycle
  emulator: 9/9; consumer/policy набор: 178/178 при одном ожидаемом skip без
  emulator. Backend CI, ESLint, `flutter analyze --no-pub` и diff-check прошли.
- Native APNs/FCM delivery и production deploy не выполнялись: они относятся к
  release/E2E validation, а не к завершённой behavior-preserving декомпозиции.

### Восстановление regression suite — 31.08.2026

- Положительные сценарии используют платную подписку, отдельный отрицательный
  сценарий подтверждает: gift-only доступ не создаёт поиск/trial и не меняет
  user document. Trial и `subscription: null` overrides сохранены.
- Каждый процесс проверяет поиск в отдельном demo namespace. Очистка ожидается
  между тестами и при завершении, разрешена только через loopback emulator.
  Внутри сценариев concurrency сохранён. Production Firebase не затрагивается.
- Location filters проверяются как explicit input, не копия профиля;
  ranking fixtures соответствуют minimum-level и no-filter FIFO контрактам,
  уже покрытым отдельными policy tests. Production ranking не менялся.
- Найден старый дефект default pre-push hook: вызов без `db` отменял найденную
  пару в background-сценариях. Context binding исправлен в legacy call site;
  zero-argument notification hook, optional skip, повторная проверка состояния
  и v2 wait logic сохранены. Подробности и rollback:
  [design](../docs/superpowers/specs/2026-08-31-search-emulator-and-pre-push-context-design.md).
- До исправления wiring: 100/104 теста, 4 background failures. После: два полных
  прогона 104/104 без skips; call lifecycle emulator 9/9. Backend CI, ESLint,
  `flutter analyze --no-pub` и diff-check прошли.
- Этот этап был prerequisite; его green baseline использован для завершённой
  декомпозиции выше.

## Доказательство долга

[`firebase/custom_cloud_functions/start_search.js`](../firebase/custom_cloud_functions/start_search.js)
содержит около 3985 строк и одновременно принимает callable input, читает
пользователя, проверяет entitlement/permissions, резервирует trial, выбирает
кандидата, отправляет APNs/CallKit, восстанавливает поиск, ждёт foreground
responder, очищает ошибки и форматирует callable response. Это god-handler с
hidden dependencies на `match_pair_lock`, `match_candidate_pool`, APNs,
Firestore и timers.

## Цель

Оставить `startSearch` тонким transport adapter, а бизнес-решения сделать
тестируемыми без вызова Cloud Function.

## Минимальный scope

Разделить только на существующие понятные роли:

1. input/identity validation;
2. `startSearchAccessPolicy` (subscription/trial/active call);
3. match orchestration (`match_candidate_pool` + `match_pair_lock`);
4. delivery adapter (APNs/foreground retry);
5. recovery/cleanup policy;
6. response/error mapper.

Каждый helper принимает `db`, clock, id generator и delivery callbacks через
параметры там, где это нужно. Не вводить DI framework.

## TDD-порядок

- Зафиксировать текущие callable payload/error detail tests.
- Сначала вынести pure policy functions без изменения вызовов.
- Затем добавить fake clock/id/delivery и тесты retry/lease/cooldown.
- Перенести orchestration блоками, после каждого блока запускать полный
  `start_search.test.js` и call lifecycle suite.
- Только в конце сократить HTTP/callable handler.

## Не входит

- Новая matchmaking algorithm.
- Изменение matching filters или fairness.
- Параллелизация транзакций ради скорости.

## Подводные камни

- Нельзя менять порядок Firestore reads/writes и lease expiry.
- APNs retry должен оставаться idempotent и не создавать дубликаты CallKit.
- Recovery после технической ошибки должен сохранить trial cooldown.
- Не переносить Firestore access в UI или низкоуровневый helper без policy.

## Готово, когда

- Handler меньше примерно 300–500 строк и читабелен как сценарий.
- Все callable response/error shapes неизменны.
- Все time/random/external dependencies injectable в tests.
- Existing tests проходят без увеличения flaky timing.

## Риск, abort и откат

- **Abort:** ухудшились match rate, lease ordering, APNs delivery или trial
  reconciliation; extraction остановить на последнем зелёном seam.
- **Откат:** вернуть предыдущий handler commit и старые helper bindings;
  открытые leases/session docs чинить отдельным recovery path.
- **Необратимость:** отсутствует, пока не меняются Firestore schema и writes.
