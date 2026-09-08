# P1-10 — измеримый performance budget для startup и звонка

**Приоритет:** P1 · **Размер:** M/L · **Зависимости:** P0-01, P2-01, P2-08
**Цель:** превратить известные performance-сигналы в воспроизводимые пороги,
а не начинать оптимизацию по ощущениям.

## Доказательство долга

`audit/baseline_metrics.json` фиксирует TTFF около 10.9 s и peak memory около
201 MB на Android emulator; frame/raster metrics и 15-min memory growth не
измерены, а redundant streams отмечены статически. В `audit/optimization_backlog.md`
уже перечислены startup delay, nested scrollables/shrinkWrap, auth listener
lifecycle и runtime KPI, но нет обязательного device matrix или CI artifact.

## Минимальный план

1. Обновить baseline на текущем commit: cold/warm startup, first interactive,
   frame >16.7/33 ms, build/raster percentile, peak memory/growth, network
   reads/writes и call join/reconnect/drop rate.
2. Матрица: iOS physical (минимум один поддерживаемый mid-tier), Android
   physical и emulator; debug не считать performance measurement, использовать
   profile/release и одинаковые сценарии.
3. Согласовать пороги до правок: например TTFF не ухудшать, frame jank и
   memory не хуже baseline; абсолютные продуктовые цели зафиксировать после
   первого reliable baseline.
4. Приоритизировать измеренные hotspots: startup readiness/listener leaks,
   nested scrollables, redundant Firestore streams, heavy language payload,
   font/assets. Один hotspot — один PR с before/after artifact.

## TDD/проверки

- Performance smoke выполняет одинаковый script/flow, сохраняет JSON/trace.
- Regression test на auth listener dispose и stream deduplication.
- Если metric unavailable (например gfxinfo для Flutter surface), явно
  отметить blocked, не подменять нулём.

## Подводные камни

- Не оптимизировать memory/TTFF ценой корректности offline/auth/call state.
- Emulator цифры не выдавать за production; сравнивать только одинаковый
  device/build/scenario.
- Firestore cost считать по фактическим reads/writes, а не по числу widgets.

## Риск, abort и откат

- **Abort:** crash-free, call join/reconnect или correctness regression; либо
  ухудшение любого согласованного budget более чем на 10%.
- **Откат:** вернуть предыдущий tagged build/PR и старый query/listener path;
  данные не мигрировать в рамках performance PR.
- **Необратимость:** отсутствует, пока не меняется схема/кэш-данные; такой diff
  выносится в отдельную задачу.

## Не делать

Не строить continuous profiling platform и не переписывать списки/slivers до
reliable baseline. Порог 90% кадров или фиксированные MB не придумывать без
измерения.

## Готово, когда

- baseline актуален и воспроизводим на device matrix;
- budget/blocked metrics опубликованы как артефакт;
- выбранные hotspot fixes имеют before/after и не ухудшают call/auth;
- performance smoke включён в release checklist.

## Прогресс 2026-08-31

- Challenge сузил первый срез до tooling-контракта без runtime-инструментации:
  [performance_budget.js](../audit/performance_budget.js) валидирует
  версионированный snapshot и сравнивает только совместимые device/build/
  scenario/method fingerprints.
- Шаблон
  [performance_baseline.template.json](../audit/performance_baseline.template.json)
  не содержит придуманных измерений: недоступные метрики имеют `not_collected`
  и обязательную причину; регрессия считается только при явно заданном
  `maxRegressionPercent`.
- CLI потребитель:
  `node audit/scripts/validate_performance_budget.js <snapshot> [candidate]`.
  Он возвращает `incompatible`, `blocked`, `unbudgeted`, `pass` или
  `regression`, не превращая отсутствие измерения в ноль или pass.
- Добавлены unit-тесты для schema, fingerprints, units/status, NaN/Infinity,
  lower/higher-is-better, baseline zero и blocked metrics, включая CLI exit
  contracts. Runtime/physical-device profiling и hotspots остаются открытыми.

Локальный signal: `npm --prefix firebase/custom_cloud_functions run
test:performance-budget` — green; `flutter analyze --no-pub` обязателен после
изменений runtime-кода и здесь не требуется, потому что этот срез tooling-only.

## Локальный baseline 07.09.2026

- В `audit/performance_baselines/` сохранены десять cold profile-web samples,
  raw diagnostics, build hashes и точная процедура повторения.
- Валидатор различает `browser`, `emulator` и `physical`; браузерный замер не
  маркируется как мобильный эмулятор.
- Порог 10% берётся только из baseline и действует для стабильных web-profile
  transfer/resource/bundle signals. Candidate не может ослабить порог или
  пропустить budgeted metric; network/auth/cache входят в compatibility.
- Межпакетный headless timing нестабилен и оставлен без ложного gate. Warm
  reload, mobile frame/memory/call и авторизованные backend-сценарии не
  подменены ненадёжными данными: они перенесены в финальную device-задачу 02.
- Кодовая часть закрыта 08.09.2026: полный launcher и архивное восстановление
  baseline зелёные; независимый review-loop принят, реализация и тесты 10/10.
