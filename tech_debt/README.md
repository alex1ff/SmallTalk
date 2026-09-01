# Tech debt backlog

Аудит выполнен 30.08.2026 на commit `2fab093` в репозитории SmallTalk/Expatlio.
Документы ниже — не план переписывания проекта, а минимальный backlog для
снижения риска и стоимости следующих изменений.

## Как читать приоритеты

- **P0** — релизный контроль и источник истины. Пока задача не закрыта,
  изменения могут незаметно не проверяться или попадать не в тот runtime.
- **P1** — высокий риск регрессии, безопасности или потери времени команды.
- **P2** — заметная стоимость поддержки, но без немедленной угрозы релизу.
- **P3** — полезная гигиена после основных рисков.

Размеры: **S** — до 1 дня, **M** — 1–3 дня, **L** — до недели,
**XL** — несколько итераций с миграцией/ручным QA.

## Приоритетный список

1. [P0-01-ci-release-gate.md](P0-01-ci-release-gate.md) — автоматический
   релизный gate в GitHub.
2. [P0-02-single-firebase-backend-source.md](P0-02-single-firebase-backend-source.md)
   — убрать двусмысленность двух Firebase codebase.
3. [P1-01-js-lint-and-static-analysis.md](P1-01-js-lint-and-static-analysis.md)
   — вернуть рабочий ESLint и усилить статический контроль.
4. [P1-02-call-lifecycle-contract-test-matrix.md](P1-02-call-lifecycle-contract-test-matrix.md)
   — единая матрица контрактов call/trial lifecycle.
5. [P1-03-start-search-service-decomposition.md](P1-03-start-search-service-decomposition.md)
   — безопасно разделить `start_search.js`.
6. [P1-04-daily-call-widget-decomposition.md](P1-04-daily-call-widget-decomposition.md)
   — разделить `MinimalDailyWidget` по ответственностям.
7. [P1-05-observability-and-error-boundary.md](P1-05-observability-and-error-boundary.md)
   — единое наблюдение за падениями и non-fatal ошибками.
8. [P1-06-dependency-upgrade-and-security.md](P1-06-dependency-upgrade-and-security.md)
   — управляемое обновление Flutter/Node зависимостей и audit debt.
9. [P1-07-firestore-rules-maintenance.md](P1-07-firestore-rules-maintenance.md)
   — снизить риск изменения 1610-строчных правил.
10. [P1-08-voip-service-decomposition.md](P1-08-voip-service-decomposition.md)
    — декомпозиция критического VoIP lifecycle.
11. [P1-09-legacy-fallback-retirement.md](P1-09-legacy-fallback-retirement.md)
    — инвентаризация и поэтапное удаление старых схем/fallback.
12. [P1-10-runtime-performance-budgets.md](P1-10-runtime-performance-budgets.md)
    — измеримый budget для startup, UI и звонка.
13. [P2-01-integration-e2e-critical-flows.md](P2-01-integration-e2e-critical-flows.md)
    — реальные smoke-flow поверх unit/contract тестов.
14. [P2-02-route-consolidation-and-typed-args.md](P2-02-route-consolidation-and-typed-args.md)
    — единый routing и типизированные аргументы.
15. [P2-03-typed-data-contracts.md](P2-03-typed-data-contracts.md) — убрать
    необязательный `Map<String, dynamic>` из бизнес-потоков.
16. [P2-04-logging-and-pii.md](P2-04-logging-and-pii.md) — политика логов и
    защита PII/секретов.
17. [P2-05-localization-design-accessibility.md](P2-05-localization-design-accessibility.md)
    — системно закрыть hardcoded UI, a11y и design tokens.
18. [P2-06-generated-code-boundary.md](P2-06-generated-code-boundary.md) —
    безопасная граница бывшего FlutterFlow-кода.
19. [P2-07-ui-god-components.md](P2-07-ui-god-components.md) — остальные
    крупные UI-монолиты: events, dashboard, profile, favorite, native speaker.
20. [P2-08-test-coverage-and-flake-budget.md](P2-08-test-coverage-and-flake-budget.md)
    — риск-ориентированное покрытие и контроль flaky tests.
21. [P2-09-dart-analyzer-baseline.md](P2-09-dart-analyzer-baseline.md) —
    усиление analyzer без массового rewrite.
22. [P3-01-release-docs-and-versioning.md](P3-01-release-docs-and-versioning.md)
    — версия приложения, operational docs и актуальные метрики.
23. [P3-02-dead-code-assets-docs-inventory.md](P3-02-dead-code-assets-docs-inventory.md)
    — инвентаризация рудиментов, assets и устаревших документов.

## Исходные факты аудита (не текущий статус реализации)

Ниже сохранён baseline аудита. Прогресс конкретных задач указан в их файлах;
P1-03 и P1-04 пока выполнены лишь частично.

- В репозитории нет файлов `.github/workflows/*`; единственный release gate —
  локальный [`scripts/local_ci.sh`](../scripts/local_ci.sh).
- [`firebase/firebase.json`](../firebase/firebase.json) подключает одновременно
  `firebase/functions` и `firebase/custom_cloud_functions`. В первом
  [`index.js`](../firebase/functions/index.js) оставлен фактически пустой
  `onUserDeleted`.
- `firebase/custom_cloud_functions/npm run lint` сейчас не запускается:
  ESLint не находит конфигурацию.
- `firebase/firestore.rules` содержит около 1610 строк и 166 функций.
- Наиболее крупные зоны: `event_list_widget.dart` (~6524 строк),
  `minimal_daily_widget.dart` (~6116), `students_dashboard_widget.dart`
  (~4621), `start_search.js` (~3985), `match_pair_lock.js` (~2001).
- `flutter pub outdated` показывает 88 ограничений старше resolvable-версий и
  11 lock-версий, закреплённых ниже доступного обновления.
- `npm audit --omit=dev` показывает 9 moderate advisory в custom functions и
  7 в legacy functions; high/critical нет.
- В Flutter-коде есть 44 `ignore`/`ignore_for_file` и много `print()`;
  прямые Firebase-вызовы встречаются в страницах, а не только в services.
- Есть только один файл в `integration_test/`; он проверяет в основном routing,
  а не полноценный auth → purchase → call → end → review flow.
- Критические монолиты не ограничиваются Daily: `voip_service.dart` (~3483
  строк), `event_list_widget.dart` (~6524), dashboard (~4621), profile (~4435),
  favorite (~3464) и event create (~3184).
- В legacy fallbacks поддерживаются старые поля VoIP token, profile,
  videoSession, caption и onboarding; для них нет общего usage/retirement
  реестра.
- В корне лежат несколько параллельных task/PRD/TODO документов; assets — 71
  файл без обязательного ownership/usage inventory.

## Что не следует делать

- Не переписывать FlutterFlow-экспорт целиком и не добавлять новый state
  management framework только ради стиля.
- Не менять Firestore schema, subscription IDs, callable names или route paths
  без отдельной миграции и обратной совместимости.
- Не обновлять все пакеты одной командой без промежуточных commits и
  platform QA.
- Не считать зелёный `flutter analyze` доказательством runtime-корректности
  Daily, RevenueCat, App Check или StoreKit.

## Сложные задачи второго этапа

Их не нужно брать одновременно с быстрыми улучшениями:

1. P0-02 — консолидация двух Firebase codebase и возможная миграция trigger.
2. P1-03 — декомпозиция matchmaking без изменения race/lease semantics.
3. P1-04 — выделение Daily/Deepgram lifecycle из stateful widget.
4. P1-06 — major-upgrade RevenueCat/Firebase/Daily с iOS/Android sandbox QA.
5. P1-07 — реорганизация Firestore rules без ослабления deny-by-default.
6. P2-02 — постепенный отказ от смешанного GoRouter/Navigator.
7. P2-06 — окончательное отделение generated-style файлов от hand-maintained
   domain code.
8. P1-08/P1-09 — VoIP extraction и retirement legacy fallback нельзя смешивать
   с одним большим PR: сначала characterization и usage inventory.
9. P2-07 — UI god-components брать по одному экрану, начиная с hotspot с
   ближайшим продуктовым изменением.
10. P1-10 — performance fixes не начинать по ощущениям: сначала обновить
    device baseline и только затем выбирать hotspot.

## Рабочий TDD-порядок

Для каждой задачи: сначала characterization/contract test на текущий публичный
результат, затем минимальный production diff, затем тест на ошибку/гонку,
после чего `flutter analyze`, профильные Flutter tests, `npm run backend:ci` и
правила Firestore в emulator. Изменение считается завершённым только когда
поведение, данные и error shape явно зафиксированы тестами.

## Review log

- Независимый проход 1: **7.5/10**. Найдены расхождения README/CI, отсутствие
  performance debt, недостаточная конкретика coverage/rollback и пропущенные
  god-components.
- Независимый проход 2: **8.5/10**. Проверены исправленный индекс, ссылки,
  performance/native-speaker/VoIP/legacy разделы и risk sections; оставшиеся
  пять точечных замечаний (CI staging, emulator split, pinned Node coverage,
  реальные Dart rule names, ownership logging) внесены после прохода.
- Полный третий проход намеренно не запускался: ограничение задачи — максимум
  два прохода. После последней правки выполнены структурные проверки всех
  Markdown-файлов, ссылок, индекса и whitespace.
