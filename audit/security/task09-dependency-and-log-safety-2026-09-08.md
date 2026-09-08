# Task 09: dependency и logging evidence

Дата: 08.09.2026. Ветка: `codex/smalltalk-v2-remediation`.

## Dependency audit

- Flutter runtime: снят актуальный `flutter pub outdated`; массовые major
  upgrade FlutterFire/Daily/RevenueCat/router отложены до platform/device QA,
  потому что текущий срез не подтверждает runtime security defect.
- Firebase Functions runtime (`npm 10.9.7`): `npm audit --omit=dev` показывает
  9 moderate / 9 затронутых package entries; 0 high, 0 critical. Отдельный
  исправляемый `qs` обновлён `6.15.3 → 6.16.0`, а transitive
  `@google-cloud/storage` — `7.21.0 → 7.22.0`. Весь оставшийся отчёт приходит
  через `firebase-functions 7.3.2` / `firebase-admin 13.10.0`. Audit
  `fixAvailable` предлагает breaking downgrades до `firebase-functions 4.9.0`
  и `firebase-admin 10.3.0`. Поэтому force-fix не применяется; безопасное
  обновление после выхода совместимой vendor-цепочки остаётся отдельной задачей
  с документацией, emulator и device QA.
- Root runtime: `npm audit --omit=dev` — 0 advisory.
- Локальный Firebase CLI обновлён `15.14.0 → 15.29.0`. После clean lock и
  обычного `npm audit fix --package-lock-only` удалены прежние 2 critical и
  8 high; остаются 7 moderate в dev-only transitive цепочках Firebase CLI.
  Автоматический fix предлагает downgrade до `firebase-tools 10.1.1` и не
  применяется. CLI не входит в приложение или Functions runtime.
- После clean `npm ci` фактически установлены `qs 6.16.0`,
  `@google-cloud/storage 7.22.0`, `firebase-functions 7.3.2` и
  `firebase-admin 13.10.0`; `firebase --version` подтверждает CLI 15.29.0.
- Root tooling, lockfile и CI зафиксированы на Node.js 22: transitive
  `universal-analytics 0.5.4` требует Node 22, поэтому прежний диапазон `>=20`
  больше не соответствовал воспроизводимому `npm ci`.

Принятое исключение: оставшаяся Functions-цепочка (9 moderate package entries)
и 7 CLI dev-only moderate.
Владелец — platform. Условие снятия: совместимый vendor fix для текущих
Firebase Admin/Functions либо отдельно проверенная upgrade-миграция, которая
не требует downgrade. До этого не использовать `npm audit fix --force` и не
объединять major upgrade с продуктовой правкой.

## Safe logging slice

- Добавлен backend allowlist logger: только фиксированные event/source/error
  codes, field-specific enum/number/boolean поля и хеши корреляции. Общего
  пропуска «похожих на token» строк нет.
- Default sink — официальный `firebase-functions/logger`: metadata попадает в
  queryable structured fields Cloud Logging, а не склеивается в `textPayload`.
- Полный `sessionHash` совпадает с Crashlytics contract; raw session ID не
  записывается. Другие идентификаторы используют namespaced short hashes.
- Переведены чувствительные call/Daily credential, push, auth email,
  password-reset, payment/RevenueCat, translation и AI provider failure пути.
- После review scope-аудита на тот же adapter переведены остальные deployed
  runtime-события Events, moderation, gifts, usage и withdrawals. Прямые
  `console.*` остались только в локальных административных `scripts/`, которые
  не исполняются как Cloud Functions.
- Удалены raw room URL/name, participant names, token claims, push/provider
  response IDs/body и exception messages из затронутых production logs.
- User-visible неожиданные backend ошибки больше не возвращают raw exception
  message из create/cancel/decline/end call paths.
- Доступ и retention описаны в `docs/runbooks/logging-privacy.md`. Фактическая
  Cloud Logging конфигурация требует проверки владельцем: локально `gcloud`
  недоступен, поэтому изменение IAM/retention не заявляется.

## Локальные проверки

- ESLint изменённых backend-файлов — clean.
- `safe_log.test.js` + `call_lifecycle_logs.test.js` — 9/9, включая реальный
  production-adapter, token-shaped input и отказоустойчивость logging sink.
  Они включены в canonical `backend:ci`, а не оставлены ручной проверкой.
- Профильные call/auth/RevenueCat тесты после первого среза — 126/126.
- Финальная профильная выборка call/Daily/auth/payment/AI — 208/208.
- Flutter call/auth/payment regression selection — 261/261;
  `flutter analyze` — clean.
- `npm run backend:ci` — полный canonical backend gate прошёл: syntax,
  ESLint, config guardrails, 280 event/call tests, 25 password-reset tests,
  13 backend-source tests, deployment source validation и 21 RevenueCat test.
- `git diff --check` — clean. Review-loop фиксируется после независимого pass.
- После исправлений первого review-pass повторно пройдены `backend:ci`,
  `flutter analyze` и 80 точечных dashboard/VoIP contract tests.
- После промежуточных замечаний второго pass пройдены 68 профильных
  safe-log/lifecycle/AI/Daily/RevenueCat тестов и ESLint; hostile getters и
  `Symbol` metadata не ломают application path, provider HTTP status и
  code-owned webhook reason сохраняются.
- После полного runtime-log среза пройдены: 85 sensitive payment/gift/Daily,
  194 Events/moderation, 79 cleanup/stop и 84 matchmaking теста; по одному
  emulator-only сценарию в двух последних наборах корректно пропущено.
- Финальный canonical `npm run backend:ci` и `git diff --check` прошли на
  объединённом состоянии; итоговый review verdict указан в статусе задачи.
