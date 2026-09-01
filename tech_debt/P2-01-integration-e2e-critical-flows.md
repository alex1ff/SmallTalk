# P2-01 — Реальные integration/E2E smoke flows

**Размер:** L · **Владелец:** QA/product · **Зависимости:** P0-01, P1-02,
P1-05.

## Доказательство долга

В `integration_test/` один smoke-файл, в основном проверяющий routing. Основной
объём — unit/widget/contract tests; они полезны, но не доказывают, что вместе
работают Firebase Auth, App Check, RevenueCat mirror, Daily room, captions,
call timers, trial reconciliation и post-call review на устройстве.

## Цель

Иметь короткий набор недорогих реальных flows, который ловит интеграционные
ошибки до TestFlight/Play build.

## Минимальный scope

1. Emulator smoke: signed-out → register/login → profile → protected route.
2. Backend emulator: active subscription/trial → start search → session →
   terminal path → trial state.
3. Sandbox/manual matrix: RevenueCat purchase/restore, renewal/upgrade,
   RevenueCat webhook, Daily join/reconnect/end, translation/AI failure.
4. Device smoke iOS и Android для permissions, CallKit/VoIP, back navigation,
   timer and subtitle rendering.
5. Lightweight deterministic emulator smoke входит в PR; полный
   `npm run backend:checks`/device/sandbox harness запускается nightly/manual.
   Каждый flow должен иметь deterministic test account/data cleanup.

## TDD-порядок

- Сначала оформить flow table с preconditions/postconditions.
- Перенести уже существующие routing assertions в reusable harness, не
  создавать новый framework.
- Добавить по одному happy path и одному failure path на feature.
- Все flaky waits заменить polling/explicit signal; не увеличивать sleeps.

## Не входит

- Полный visual regression всех экранов.
- Нагрузочное тестирование тысяч пользователей.
- Реальные покупки в production.

## Подводные камни

- RevenueCat sandbox timing и webhook delay должны быть частью тестового
  expectation, а не причиной ручного “retry until works”.
- Нельзя хранить sandbox secrets в repo/CI logs.
- Device test с Daily требует fake room или отдельный sandbox budget.

## Готово, когда

- Critical flow list versioned и привязан к release checklist.
- PR job запускает emulator smoke; nightly/manual запускает device/sandbox.
- Отчёт различает product bug, infra outage и flaky test.

## Прогресс 2026-09-01

- Challenge сузил первый срез: routing characterization остаётся synthetic
  (подставной `BaseAuthUser`) и не называется Firebase Auth/E2E.
- Общий harness вынесен в
  [`test_support/routing_smoke_harness.dart`](../test_support/routing_smoke_harness.dart)
  и используется test- и integration-entrypoint. Он сохраняет desktop viewport
  только для widget-теста, изолирует auth/redirect/splash globals и восстанавливает
  viewport после каждого сценария.
- Flow matrix зафиксирована в
  [`audit/critical_flow_matrix.json`](../audit/critical_flow_matrix.json): три
  PR routing contracts отделены от не реализованных Firebase emulator и
  RevenueCat/Daily device flows. Contract test проверяет версии, уникальные ID,
  обязательные pre/postconditions, cleanup и уровень доказательства.
- Полный emulator/auth/Daily/RevenueCat harness не включён в PR: существующий
  smoke не поднимает реальный Firebase Auth и не доказывает vendor transport.
  Это отдельный следующий этап после изоляции demo account и cleanup audit.

Локальные сигналы: routing widget suite проходит, matrix contract запускается
через `npm --prefix firebase/custom_cloud_functions run test:critical-flow-matrix`.
Device/sandbox validation остаётся manual/nightly и не объявляется выполненной.

## Риск, abort и откат

- **Abort:** тест нестабилен два запуска подряд на одном seed/environment или
  cleanup оставляет пользовательские данные; flow не делать required.
- **Откат:** вернуть harness/fixture commit и удалить только sandbox data по
  явному test account; production data не затрагивается.
- **Необратимость:** отсутствует при изолированных emulator/sandbox accounts.
