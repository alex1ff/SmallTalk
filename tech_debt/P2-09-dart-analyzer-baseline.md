# P2-09 — усиление Dart analyzer без массового rewrite

**Приоритет:** P2 · **Размер:** M · **Зависимости:** P0-01, P2-06
**Цель:** ловить типовые ошибки раньше, постепенно уменьшая suppressions.

P1-01 владеет JS lint. Здесь scope только Dart analyzer/linter baseline и
правила для Flutter lifecycle/async; не дублировать backend config.

## Почему это долг

`analysis_options.yaml` включает лишь небольшой correctness baseline. В коде
около 44 `ignore`/`ignore_for_file`; часть оправдана generated records, но в
`minimal_daily_widget.dart` глобально подавлены unused imports, а в profile
есть unused element. Слабый baseline допускает новые async/context, dispose и
типовые ошибки без сигнала.

## Минимальный план

1. Инвентаризировать каждое suppression: generated, test fake, temporary или
   production smell. У временного — issue/owner/date; generated сгруппировать.
   Начальный allowlist пересоздать на commit `2fab093` в формате
   `file + rule + tool + owner + expiry`; не использовать устаревший
   `audit/baseline_metrics.json` как текущую метрику.
2. Подключить актуальный `flutter_lints` baseline и включать правила пакетами:
   correctness/async/lifecycle сначала, style позже.
3. На legacy warnings создать baseline allow-list; новые warning запрещать в
   CI. Уменьшать allow-list только при касании feature.
4. Приоритетные реальные правила: `use_build_context_synchronously`,
   `cancel_subscriptions`, `discarded_futures`, `unawaited_futures`,
   `close_sinks` и `avoid_dynamic_calls` там, где они доступны в pinned
   analyzer/flutter_lints; каждое включение проверить отдельным analyze run.
5. В CI сравнивать allowlist с baseline: новая строка или рост warning/error
   блокирует PR, пока не добавлены причина и срок.

## TDD/проверки

- Contract test/CI diff не даёт добавить новый global `ignore` без причины.
- Намеренное async-context/discarded future нарушение должно падать в analyze.
- После каждого набора правил запускать полный `flutter analyze` и tests; lint
  fixes не смешивать с behavior changes.

## Подводные камни

- Некоторые FlutterFlow records законно используют verbose getters; не
  исправлять generated schema ради стиля.
- Autofix может изменить null/async semantics; каждый production diff ревьюить.
- Не отключать правило глобально из-за одного fake в тесте.

## Риск, abort и откат

- **Abort:** analyzer fix меняет null/async behavior, либо baseline растёт без
  owner; остановиться и вернуть только спорный rule set.
- **Откат:** revert конфигурационного commit/allowlist, production code не
  откатывать вместе с ним.
- **Необратимость:** отсутствует; suppression removal делается маленькими PR.

## Не делать

Не включать сотню style rules за раз, не форматировать весь репозиторий и не
считать отсутствие warnings достаточным runtime QA.

## Готово, когда

- новые suppressions требуют объяснения;
- CI запрещает рост analyzer baseline;
- critical async/lifecycle rules включены;
- временные suppressions имеют owner и сокращаются при feature work.
