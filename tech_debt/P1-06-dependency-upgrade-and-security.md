# P1-06 — Управляемый upgrade зависимостей и advisory debt

**Статус:** частично; безопасный локальный срез реализован, major-миграции и platform QA открыты · **Дата:** 31.08.2026

**Размер:** L/XL · **Владелец:** platform · **Стадия:** второй этап ·
**Зависимости:** P0-01, P1-02.

## Доказательство долга

Исходный аудит на commit `2fab093` от 30.08.2026 показывал 88 constraints старше
resolvable-версий и 11 lock-версий ниже доступного обновления. Это исторический
baseline до последующих P1-05 dependency changes, а не текущий снимок. Важные pinned
пакеты: Firebase 5/3/11 series, `daily_flutter 0.34.0`,
`purchases_flutter 9.9.5`, `go_router 12.1.3`. В том же исходном аудите
`npm audit --omit=dev` показывал 9 moderate advisory в custom functions и 7
в legacy functions; high/critical не было. В `pubspec.yaml` тогда были
overrides для `http` и `uuid`.

## Цель

Уменьшить known advisory и frozen-version debt без одновременного major
upgrade всего приложения.

## Dependency manifest на 31.08.2026

Версии сняты командами `flutter pub outdated --no-dev-dependencies`,
`npm outdated --json`, `npm ls` и `npm audit --omit=dev --json`. Latest — это
ориентир для планирования, а не разрешение обновлять package автоматически.

### Flutter runtime

| Экосистема / owner | Текущая линия | Resolvable/latest | Риск и решение |
| --- | --- | --- | --- |
| FlutterFire / platform | core `3.14.0`, auth `5.6.0`, firestore `5.6.9`, functions `5.5.2`, messaging `15.2.7`, storage `12.4.7`, analytics `11.5.0`, App Check `0.3.2+7`, performance `0.10.1+7` | core `4.14.0`, auth `6.6.1`, firestore `6.9.0`, functions `6.4.0`, messaging `16.6.0`, storage `13.5.0`, analytics `12.5.0`, App Check `0.4.7`, performance `0.11.5` | Связанный major: native Firebase SDK, Gradle/Xcode, auth/App Check и emulator. Отдельный slice, не смешивать с другими majors. |
| Crashlytics / reliability | `4.3.7` | `5.3.0` | Связан с FlutterFire major и P1-05 release smoke; отложен. |
| RevenueCat / monetization | `9.9.5` | `10.10.1` | StoreKit/Play Billing и purchase/restore identity lease; только с iOS/Android sandbox. |
| Daily / calling | `0.34.0` | `0.39.0` | Join/reconnect, native background, media lifecycle; только с device call smoke. |
| CallKit / VoIP | `3.1.3` | `3.1.5` | Даже patch затрагивает локальный CocoaPods source patch exact-identity; не обновлять без повторной проверки patch и PushKit smoke. |
| Routing / navigation | `go_router 12.1.3` | resolvable `17.2.3`, latest `18.0.0` | Несколько majors и смешанный Navigator/GoRouter; принадлежит P2-02. |
| Device/files/permissions | device info `11.5.0`, file picker `10.1.9`, permission handler `11.4.0` | `13.2.0`, `12.1.2`, `13.0.1` | Native manifests/capabilities; отдельный platform slice. |
| Images/video/cache | cached image `3.4.1`, image picker `1.1.2`, video player `2.10.0` | `4.0.0`, `1.2.3`, `2.14.0` | UI/cache/native playback regression risk; не security-first. |
| Pure Dart ID/hash / platform | было `uuid 4.5.2`, `crypto 3.0.6`; теперь `4.6.0`, `3.0.7` | `4.6.0`, `3.0.7` | Адресное minor/patch обновление с characterization tests. |

Новый pre-slice снимок 31.08.2026, уже после добавления P1-05 Crashlytics,
показывал 91 ограниченное зависимостями обновление до resolvable и 12 lock-версий ниже
доступного обновления. Остальные UI/utility обновления не
маскируются общим `pub upgrade`: их нужно брать небольшими owner-scoped
наборами только при наличии ближайшей продуктовой работы.

### Firebase Functions runtime

| Package / owner | Declared / locked | Wanted/latest | Решение |
| --- | --- | --- | --- |
| `firebase-functions` / backend | `^7.3.2` / `7.3.2` | `7.3.2` | Уже latest; оставить. |
| `firebase-admin` / backend | было `^13.9.0`, locked `13.10.0` | same-major `13.10.0`, latest `14.3.0` | Declared выровнен до `^13.10.0`; major 14 — отдельная миграция. |
| `@google-cloud/translate` / translation | `^9.4.2` / `9.4.2` | latest `10.0.1` | Major и Node/client API surface; отложен. |
| `@google/genai` / AI feedback | `^2.15.0` / `2.15.0` | wanted/latest `2.19.0` | Не нужен для текущего security результата; обновлять отдельно с structured feedback tests. |
| `axios` / Daily/email/payments | `^1.6.0` / `1.19.0` | wanted/latest `1.20.0` | Широкий HTTP surface; отдельный patch после network contract tests. |
| rules/test tooling / platform | rules `5.0.0`, Firebase web SDK `12.12.0`, functions-test `3.4.1` | `5.0.2`, `12.18.0`, `3.5.0` | Dev-only bundle; отдельный reproducibility slice, не смешивать с runtime. |

## Advisory baseline и план

`npm audit --omit=dev` показывает **9 moderate, 0 high, 0 critical**. Цепочка
приходит из `firebase-admin 13.10.0`:

- `@google-cloud/firestore 7.11.6` → `google-gax 4.6.1` → `uuid 9.0.1`;
- `@google-cloud/storage 7.21.0` → `gaxios 6.7.1`, `retry-request 7.0.2`,
  `teeny-request 9.0.0`, `uuid 9.0.1`.

Автоматический `npm audit fix` предлагает небезопасные major/downgrade пути и
не используется. Официальный Admin SDK 13.10 уже убрал собственную прямую
зависимость `uuid`. Обновлённый Firestore/Storage stack в Admin 14 — кандидат
на следующий срез, но устранение всех advisory нужно подтвердить повторным
audit: один major bump сам по себе не гарантирует чистое дерево.
Источник: [официальные release notes Admin SDK](https://firebase.google.com/support/release-notes/admin/node).

Admin 14 нельзя считать обычным version bump: он удаляет legacy namespace.
В текущем backend найдено 96 CommonJS consumers `require('firebase-admin')`
(77 production, 19 tests). Отдельная migration task должна:

1. перевести imports на modular entry points небольшими группами;
2. зафиксировать Firestore/Timestamp/FieldValue/Messaging/Auth contracts;
3. прогнать backend CI, rules и functions emulator;
4. повторить audit и deploy smoke на demo project;
5. только после этого поднять production constraint до Admin 14.

## Выполненный безопасный срез

- Удалены дублирующие `dependency_overrides` для `http` и `uuid`; прямые
  constraints остаются источником solver contract.
- Lock обновлён адресно: `crypto 3.0.6 → 3.0.7`, `uuid 4.5.2 → 4.6.0`.
- Declared `firebase-admin` выровнен с уже reproducible lock:
  `^13.9.0 → ^13.10.0`; dependency graph backend не менялся.
- Не выполнялись массовый `flutter pub upgrade`, `npm update` или
  `npm audit fix`; unrelated ecosystems и native code не затронуты.

До изменения 220 characterization tests для hash/UUID, event IDs,
match coordinator и VoIP lifecycle были зелёными. Результаты после изменения
приведены ниже; финальный review loop выполняется отдельно.

## Валидация безопасного среза

- `flutter pub get --enforce-lockfile` — lock воспроизводится без overrides.
- `flutter analyze --no-pub` — без замечаний.
- Затронутые hash/UUID/event/match/VoIP tests — `220/220` до и после upgrade.
- Полный Flutter suite — `2332/2332`.
- `npm ci --ignore-scripts` и `npm ls --all` — reproducible/valid tree;
  `firebase-admin 13.10.0`, `firebase-functions 7.3.2`.
- `npm run backend:ci` — lint, syntax и все backend gate-наборы зелёные
  (включая `277`, `25`, `13` и `21` test groups).
- Финальный `npm audit --omit=dev` — **9 moderate, 0 high, 0 critical**;
  результат не ухудшился и полностью совпадает с migration plan выше.
- После адресного обновления осталось 10 lock-обновлений (было 12). Число
  constraints старше resolvable стало 92: удаление `http` override снова
  показывает реальный direct constraint debt вместо его маскировки.

Platform/device smoke намеренно не заявлен: native ecosystem packages в этом
срезе не менялись. Для отложенных Firebase/RevenueCat/Daily/CallKit majors
iOS/Android sandbox и call smoke остаются обязательным gate.

## Минимальный scope

1. Составить dependency manifest: direct/transitive, владелец, current,
   resolvable/latest, breaking risk.
2. Сначала обновить security-relevant transitive chain и убрать временные
   overrides, если compatibility позволяет.
3. Отдельные upgrade PR для Firebase, RevenueCat, Daily/CallKit и router.
4. После каждого PR: `flutter analyze`, полный Flutter suite, backend tests,
   iOS/Android sandbox purchase, Daily join/reconnect, App Check и auth flows.
5. Обновлять lockfiles только соответствующим package manager.

## TDD/порядок работ

- Перед каждым major upgrade добавить/проверить characterization tests для
  public API: purchase restore, entitlement mirror, room join, Deepgram,
  push, routing.
- Делать один ecosystem upgrade за commit.
- Сначала upgrade в demo/emulator project, затем production.
- Зафиксировать advisory baseline и уменьшение после каждого шага.

## Не входит

- Обновление пакетов “до latest” без platform QA.
- Переписывание бизнес-логики из-за новых API.
- Игнорирование advisory ради зелёного audit.

## Подводные камни

- Firebase plugin majors меняют platform code и требуют новых Xcode/Gradle.
- RevenueCat upgrade может изменить offerings/entitlement API и StoreKit
  behavior.
- `uuid`/`http` overrides могут быть нужны временно; каждое исключение должно
  иметь issue и срок удаления.

## Готово, когда

- Security audit не содержит high/critical и согласованный план moderate.
- Нет необъяснимых dependency overrides.
- Версии и lockfiles одинаково воспроизводятся в CI/local.
- Sandbox purchase и call smoke зелёные на обеих платформах.

## Риск, abort и откат

- **Abort:** analyze/test, StoreKit, Daily reconnect, App Check или auth smoke
  красный; не объединять следующий ecosystem upgrade.
- **Откат:** вернуть предыдущие `pubspec.lock`/`package-lock` и подписанный
  platform artifact; production data не мигрировать в upgrade PR.
- **Необратимость:** отсутствует для package code; StoreKit product changes
  требуют отдельного rollback plan.
