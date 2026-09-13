# P0-02 — Один источник Firebase backend

**Размер:** L/XL · **Владелец:** backend/release · **Стадия:** второй этап,
после инвентаризации production · **Зависимости:** P0-01 желательно.

## Почему это техдолг

[`firebase/firebase.json`](../firebase/firebase.json) подключает два codebase:
`firebase/functions` и `firebase/custom_cloud_functions`. Первый содержит
[`firebase/functions/index.js`](../firebase/functions/index.js) с пустым
`onUserDeleted`: он получает user, строит Firestore reference и не выполняет
действия. Второй содержит основной runtime, десятки callable/trigger и другую
версию `firebase-admin`. Сейчас непонятно, какой код является источником истины
для deploy, а случайный полный `firebase deploy` может затронуть legacy source.

## Цель и границы P0

На P0 достаточно получить production inventory и versioned export manifest:
команда должна точно знать, что задеплоено. Консолидация/удаление второго
codebase — отдельная P1-миграция после этого evidence. В конечном результате
оставить один явно поддерживаемый backend source и доказать, что удаление или
перенос legacy не меняет deployed function IDs, trigger, region, secrets,
Firestore schema и runtime behavior.

## Минимальный scope

1. **P0 inventory:** получить production inventory: `functions:list --json`, trigger regions,
   codebase, hashes, service account и последние логи.
2. Сопоставить exports двух codebase и проверить, нет ли исторических функций,
   которые ещё вызываются клиентом, Scheduler, RevenueCat или Firestore.
3. Для `onUserDeleted` принять решение: удалить как no-op или заменить реальным
   owner-ом в custom codebase, если он нужен для cleanup.
4. **P1 migration:** удалить второй codebase из `firebase.json` только после migration window;
   обновить scripts, docs и readiness tests.
5. Зафиксировать один deploy command с explicit `--only` и безопасным rollback.

## TDD/порядок работ

- Добавить inventory contract test: список разрешённых exports, codebase и
  trigger должен быть явным.
- Добавить tests на delete cleanup до удаления legacy.
- Сначала deploy custom source без удаления legacy.
- Проверить production logs и manual smoke.
- Удалить legacy config/source отдельным commit; проверить `functions:list` и
  повторную отправку тестового события.

## Не входит

- Массовая миграция всех функций с 1st gen на 2nd gen.
- Изменение callable names или Firebase project.
- Удаление audit snapshots.

## Подводные камни

- Firebase может удалять функцию, если export исчезнет; использовать explicit
  deploy и подтверждать diff.
- Проверить scheduled jobs/topics и Eventarc triggers, а не только callable.
- `onUserDeleted` может быть пустым сейчас, но его имя могло быть частью старого
  deploy; сначала проверить production list.
- Не смешивать миграцию codebase с major-upgrade dependencies.

## Критерии готовности

- В репозитории один documented source of truth.
- `firebase.json`, package scripts и readiness tests согласованы.
- Нет no-op exports и дублирующих function IDs.
- Production inventory после deploy совпадает с ожидаемым manifest.
- Rollback procedure проверена на staging/demo project.

## Риск и откат

Риск высокий: удаление trigger/функции и потеря cleanup. Откат — вернуть
codebase/config из отдельного commit и redeploy старого manifest; не удалять
production function вручную до подтверждения replacement.
