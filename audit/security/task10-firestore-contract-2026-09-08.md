# Task 10 — Firestore/Storage contract evidence

Дата: 08.09.2026. Ветка: `codex/smalltalk-v2-remediation`.

## Результат

- Firestore и Storage имеют один канонический emulator gate.
- Восемь dedicated rules suites: 129/129 сценариев прошли.
- `backend_checks_runner.js` больше не содержит второй набор из 65 устаревших
  rules-ожиданий; оставлены только уникальные integration/load-проверки.
- Все восемь integration/load-групп прошли: concurrent end, unlock trigger,
  create-session matrix, level filter, teacher verification trigger,
  match-profile trigger, 20 параллельных create-session запросов и lifecycle.
- Тесты backend query/index contracts прошли 100/100; `supported_locations.test.js`
  прошёл 2/2; Flutter-контракты location catalog и indexes прошли 6/6.
- Текущие event queries используют точную пару `countryCode + cityKey`; каталог
  проверяет ровно New York/US, Bali/ID, Dubai/AE и Phuket/TH. Индексы `events`
  и `events_public` содержат `status/countryCode/cityKey/startsAt`.

## Изменения harness

- В canonical gate добавлен отдельный Storage Rules suite: owner read/write,
  cross-user deny, guest deny и deny путей вне user namespace.
- Integration fixtures используют текущую paid subscription, активный
  `searchRequests/{uid}`, приватные callable tokens и актуальный
  `participantIds` после резервирования пары.
- Удалены проверки отключённой `MATCH_REPEAT_PREVENTION_ENABLED=false` и
  прежнего teacher-only boost. Их актуальное поведение уже закреплено unit
  tests и не должно блокировать release противоположными ожиданиями.
- Concurrent end теперь проверяет текущую модель: один teacher earning, ноль
  legacy `call_charge`, неизменный `balanceST`, один terminal result и unlock.

## Команды

```text
npm run firestore:rules:test
npm --prefix firebase/custom_cloud_functions run lint -- --no-cache
firebase emulators:exec --config firebase/firebase.json --only firestore,functions "node audit/scripts/backend_checks_runner.js"
node --test firebase/custom_cloud_functions/match_candidate_pool.test.js firebase/custom_cloud_functions/passive_search_policy.test.js firebase/custom_cloud_functions/deployment_readiness.test.js
node --test firebase/custom_cloud_functions/supported_locations.test.js
flutter test test/backend/firestore_indexes_contract_test.dart test/services/supported_location_catalog_test.dart
```

Все перечисленные проверки завершились успешно. Предупреждения emulator о
`PERMISSION_DENIED` относятся к ожидаемым запрещающим сценариям. Отсутствующие
локально production secrets не изменяют результат проверок: Daily/APNs вызовы
в integration harness безопасно переходят в предусмотренный fallback.
