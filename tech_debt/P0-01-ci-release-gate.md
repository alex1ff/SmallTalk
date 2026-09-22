# P0-01 — Автоматический CI и release gate

**Размер:** M · **Владелец:** repository/release · **Стадия:** быстрый
приоритет · **Зависимости:** нет.

## Почему это техдолг

В репозитории нет `.github/workflows`. Проверки существуют только в
[`scripts/local_ci.sh`](../scripts/local_ci.sh): они требуют локально
установленные Flutter, Node, Java и Firebase CLI. README описывает gate, но
push/PR не запускает его автоматически. Это создаёт bus factor на одном
компьютере и позволяет собрать незапроверенный commit.

## Цель

Добавить один воспроизводимый GitHub Actions workflow для pull request и
основной ветки, не дублируя бизнес-логику shell-скрипта. Локальный скрипт и CI
должны использовать один и тот же набор проверок.

Эта задача владеет только executable gate и required status. Release runbook,
версия, environment matrix и ручные deploy steps принадлежат P3-01.

## Минимальный scope

1. Workflow на Ubuntu с зафиксированными Flutter 3.35.3/Dart 3.9.2, Node 22,
   Java 21 и Firebase CLI версии, совместимой с lockfile.
2. Кэш pub/npm с ключами от `pubspec.lock` и обоих package-lock.
3. Базовый PR gate запускает существующий `./scripts/local_ci.sh` без
   расхождения с локальной машиной. После P1-01 этот же script включает JS
   lint; до её закрытия lint должен быть отдельным явно обязательным шагом.
   Расширенный Firestore emulator/rules harness (`npm run backend:checks`) и
   device/sandbox проверки идут отдельным nightly/manual job: они
   диагностические и не маскируются под быстрый gate.
4. Required status check для PR; deploy не должен происходить из CI без
   отдельного ручного approval.
5. Отдельный nightly или manual workflow для тяжёлого полного emulator
   harness, если обычный PR job слишком длинный.

## TDD/порядок работ

- Сначала добавить contract-test, который проверяет, что workflow содержит
  release gate и запускает `scripts/local_ci.sh` либо эквивалентные команды,
  а отдельный job запускает `npm run backend:checks`.
- Запустить тот же набор локально и зафиксировать baseline.
- Добавить workflow с `timeout-minutes`, артефактами логов и явным fail при
  любом ненулевом коде.
- Проверить PR с намеренной ошибкой в Dart и backend, затем вернуть baseline.

## Не входит

- Автоматический production deploy, секреты Firebase, App Store signing.
- Переписывание local CI в новый build system.
- Полный visual/golden suite на каждый PR.

## Подводные камни

- Flutter tests могут потребовать больше памяти/времени; нельзя заменять их
  только smoke-тестом.
- Emulator должен использовать demo project и не иметь доступа к production.
- Секрет-readiness проверять только в отдельном job; не выводить значения.
- Не привязывать workflow к локальным путям macOS.

## Критерии готовности

- PR без workflow-файла или с failing analyze/tests/backend gate не может merge.
- `scripts/local_ci.sh` и базовый CI дают одинаковый результат на одном
  commit; nightly расширяет, но не подменяет этот baseline.
- Артефакты сохраняются при падении.
- Нет production credentials в workflow и логах.
- README содержит ссылку на workflow и ожидаемый runtime.

## Риск и откат

Риск — flaky emulator/долгий job. Required check не отключать: при проблеме
сначала чинить job или временно вынести flaky расширенный harness в nightly,
сохранив базовый gate обязательным. Откат — revert workflow commit; код
приложения не затрагивается.
