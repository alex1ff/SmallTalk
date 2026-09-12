# P1-01 — Рабочий ESLint и единый статический контроль

**Размер:** S/M · **Владелец:** backend · **Зависимости:** P0-01 для CI.

## Доказательство долга

`npm run lint` в `firebase/custom_cloud_functions` завершается ошибкой
`ESLint couldn't find a configuration file`. В `firebase/functions` лежит
старый ESLint 6.x без общей конфигурации. Release gate проверяет `node --check`
и тесты, но не стиль, unreachable code, accidental globals, unsafe promises и
неиспользуемые импорты.

## Цель

Сделать lint воспроизводимым для обоих backend codebase и включить его в CI,
не превращая первый проход в многомесячную косметическую чистку.

Эта задача владеет только JavaScript ESLint/config/scripts. Dart analyzer
allowlist и suppression budget ведутся отдельно в P2-09.

## Минимальный scope

1. Создать корневую ESLint-конфигурацию для CommonJS Node 22 с правилами,
   совместимыми с текущим стилем (`eslint-config-google` допустим только как
   база, а не как причина массового rewrite).
2. Исключить `node_modules`, lockfiles, snapshots и emulator artifacts.
3. Сначала включить `--max-warnings=0` на изменяемые production files и
   контрактные tests; legacy-исключения перечислить явно с issue ID.
4. Включить `no-floating-promises`-эквивалент для используемого JS стиля,
   no-duplicate-case, no-unreachable и безопасные правила для secrets/logs.
5. Добавить `npm run lint:changed`/полный lint без дублирования конфигураций.
6. После добавления рабочей конфигурации включить оба lint вызова в
   `scripts/local_ci.sh`; до этого временный отдельный CI step не должен
   создавать ложное ощущение полного baseline.

## TDD/порядок работ

- Contract test проверяет наличие config, ignore и scripts.
- Запустить lint, классифицировать violations: исправление, локальное
  исключение с объяснением или отдельная задача.
- Не менять поведение production функций ради форматирования.
- Проверить, что намеренный lint violation блокирует job.

## Не входит

- Полный переход на TypeScript.
- Массовое форматирование всех 86 production JS файлов.
- Изменение `firebase-functions` API.

## Подводные камни

- Тестовые fake-объекты и Firebase `admin` могут потребовать точечных
  `/* eslint-disable-next-line */`, но не глобального отключения.
- Не включать правило, которое запрещает существующий безопасный Firebase
  callback pattern без characterization tests.
- Одинаковые правила не означают одинаковую бизнес-логику codebase.

## Готово, когда

- `npm run lint` проходит в каждом codebase.
- CI запускает lint до deploy.
- Каждое исключение имеет короткое объяснение и владельца.
- Lint не меняет runtime output и не требует отключения тестов.

## Риск, abort и откат

- **Abort:** lint блокирует более 20% production files без владельца или
  меняет runtime semantics; сначала сузить rule scope.
- **Откат:** revert config/script commit, сохранив отдельные безопасные fixes.
- **Необратимость:** отсутствует; lint-only изменения не трогают данные.
