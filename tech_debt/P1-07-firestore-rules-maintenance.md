# P1-07 — Поддерживаемость и регрессии Firestore Rules

**Размер:** L · **Владелец:** backend/security · **Стадия:** второй этап ·
**Зависимости:** P0-01, P0-02.

**Статус:** локальный maintenance/security-срез выполнен; поэтапное ужесточение
старых owner-only схем вынесено в отдельную hardening-работу.

## Историческое доказательство долга

До выполнения среза [`firebase/firestore.rules`](../firebase/firestore.rules)
содержал около 1610 строк, по первоначальному инвентарю — 166 functions/match
declarations, и одновременно описывал users, calls, captions, events, chat,
moderation, transactions, trial и teacher verification. Внутри находились
неиспользуемая функция `nestedFieldEquals` и unused parameter warning. Один
файл трудно ревьюить: изменение общего helper может открыть доступ в другом
коллекционном разделе. Текущий файл после cleanup содержит 120 функций;
`nestedFieldEquals` удалён.

## Цель

Сохранить deny-by-default и сделать ownership/field validation обозримыми.

## Минимальный scope

1. Составить таблицу коллекций: client read/create/update/delete, server-only
   writes, owner/participant/admin conditions, sensitive fields.
2. Удалить только доказанно неиспользуемые helpers после rules test.
3. Перегруппировать файл крупными секциями и добавить короткие комментарии
   invariants; не внедрять собственный DSL.
4. Для каждой чувствительной области иметь allow/deny emulator tests:
   subscription/trial, events/public projection, videoSessions, captions,
   transactions, teacher verification, chat/reports.
5. Добавить contract test, который обнаруживает случайное открытие catch-all
   admin fallback и несоответствие indexes/rules query shape.

## TDD-порядок

- Сначала snapshot/manifest текущих разрешений.
- Перед удалением helper запускаются все rules tests.
- Каждый refactor rules — маленький diff + emulator suite.
- Проверить query-level behavior: list должен иметь обязательный status/index
  predicate, не только одиночный `get`.

## Не входит

- Ослабление правил ради удобства Flutter-кода.
- Хранение ролей/entitlement в client-writable fields.
- Переезд на новую БД или custom rules generator.

## Подводные камни

- Firestore rules не являются обычным JavaScript и не поддерживают привычную
  модульность.
- `get()` в rules имеет лимиты и влияет на стоимость/latency.
- Collection/list semantics отличаются от document get; тестировать оба.

## Готово, когда

- Нет warning от rules compiler без documented reason.
- Каждая sensitive collection имеет deny tests.
- Manifest разрешений обновлён и ревьюится вместе с правилами.
- Rules deploy проходит до функций и не требует ручного hotfix.

## Риск, abort и откат

- **Abort:** любой новый allow, enumeration path или missing deny test; deploy
  не продолжать.
- **Откат:** redeploy предыдущую проверенную rules версию/index manifest;
  schema/data changes не смешивать.
- **Необратимость:** доступ можно закрыть обратно, но уже прочитанные данные
  нельзя вернуть — security review обязателен до deploy.

## Выполнено 2026-08-31

- Добавлен эффективный manifest доступа:
  [`docs/runbooks/firestore-access-control.md`](../docs/runbooks/firestore-access-control.md).
  Он учитывает рекурсивный custom-claim admin fallback и отдельно объясняет,
  что Admin SDK обходит rules.
- Удалён доказанно неиспользуемый `nestedFieldEquals` и неиспользуемый параметр
  `ownUserAvailabilityTodayUpdateIsValid`, без перестановки доменных блоков.
- Эмулятор подтвердил три обхода через `MapDiff.changedKeys()`: добавление чужой
  отметки прочтения, удаление authority-поля conversation и удаление поля
  promo-кода. Валидаторы переведены на `affectedKeys()`, добавлены deny-тесты.
- Удалён legacy client-side update `promoCodes.usageCount`: Flutter-клиент не
  использовал его, canonical `redeemPromoCode` выполняет транзакцию через
  Admin SDK. Прямой replay счётчика теперь запрещён emulator-тестом.
- Добавлен самостоятельный rules gate `npm run firestore:rules:test`; он
  запускает семь dedicated suites. Основной CI теперь выполняет этот gate.
- Index contract расширен на фактический клиентский источник `events_public`.
- Security assessment сохранён в
  [`audit/firestore_security_assessment.json`](../audit/firestore_security_assessment.json).

Проверки локального среза:

- pre-change dedicated emulator suites: 116/116;
- red security reproductions: три ожидаемых падения;
- post-change dedicated emulator suites: 126/126, включая дополнительные
  manifest assertions;
- `npm --prefix firebase/custom_cloud_functions run lint` — pass;
- `flutter test test/backend/firestore_indexes_contract_test.dart` — 1/1;
- `flutter analyze --no-pub` — без замечаний;
- `git diff --check` — чисто.

Manual `backend:checks` содержит старый встроенный rules harness с
противоречащими актуальным dedicated suites ожиданиями. Он не является
каноническим rules gate; перенос его уникальных integration/load checks и
удаление дублированной rules-части — отдельный follow-up, чтобы не смешивать
maintenance правил с большим переписыванием runner.
