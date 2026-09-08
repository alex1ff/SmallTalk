# Performance baseline · 07.09.2026

Текущий локальный baseline относится только к profile-сборке Flutter Web в
Headless Chrome на указанной Mac. Он не доказывает скорость iOS/Android.

## Воспроизведение

```sh
./audit/scripts/run_web_performance_baseline.sh
```

Launcher закрепляет и проверяет CLI 0.1.19, строит profile web, хэширует всё
содержимое `build/web`, runtime-source, collector и exact collector evidence,
поднимает loopback server и
передаёт collector одноразовый ID manifest. Старый raw JSON нельзя привязать к
другой сборке. Генератор переносит десять samples в candidate и проверяет
environment/scenario/method. На другой машине или после обновления браузера
нужен отдельный baseline с новой metadata, а не обход проверки.

Проверить, что закоммиченный baseline точно восстанавливается из неизменяемых
collector evidence и build manifest:

```sh
node audit/scripts/create_web_performance_snapshot.js --verify-archived \
  audit/performance_baselines/web-profile-2026-09-07.json \
  audit/performance_baselines/web-profile-2026-09-07.manifest.json \
  audit/performance_baselines/web-profile-2026-09-07.collector.json \
  output/playwright/reconstructed-baseline.json
```

Режим `--verify-archived` завершается успешно только при точном совпадении
всех evidence-derived metadata и samples, а не при простом попадании в 10%-й
regression budget.

Валидировать snapshot:

```sh
node audit/scripts/validate_performance_budget.js \
  audit/performance_baselines/web-profile-2026-09-07.json
```

Сравнить новую совместимую выборку с baseline:

```sh
node audit/scripts/validate_performance_budget.js \
  audit/performance_baselines/web-profile-2026-09-07.json \
  path/to/candidate.json
```

## Результат

- cold Flutter surface ready: среднее 1185.5 ms, медиана 1232.5 ms;
- cold first actionable semantic control: среднее 1638.1 ms, медиана 1583.5 ms;
- локальная передача без сжатия: среднее 22.52 MiB;
- `main.dart.js` profile-сборки: 19.39 MiB;
- used JS heap в точке готовности: среднее 90.06 MiB, только browser signal.

Порог берётся только из baseline: candidate не может повысить или удалить его.
Защитный порог 10% установлен для стабильных сигналов одинаковой среды:
локальной передачи, числа ресурсов и размера `main.dart.js`. Межпакетный разброс
timing оказался слишком большим, поэтому startup time и JS heap измерены, но
пока не блокируют выпуск. Это честнее ложных падений gate.

## Приоритет после baseline

1. Задача 04: разобрать cold-start путь до Flutter surface/первого действия.
2. Задача 13: проверить вклад загружаемого web bundle и assets; не переносить
   выводы о web bundle на размер/скорость iOS без отдельного измерения.
3. Задачи 05–07 менять только по воспроизводимым запросам/listeners/stage
   timestamps. Их runtime-цифры на устройствах остаются в финальной задаче 02.

Полный worktree при сборке был dirty только из-за CI/docs/tooling-файлов;
runtime inputs (`lib`, `web`, `assets`, `pubspec*`) совпадали с commit
`5d785a8d`. Warm reload оставлен только в raw evidence: кэш чередовал полный
transfer и нулевую передачу, а `performance.memory` накапливал данные процесса.
Выдавать warm или нестабильный headless timing за надёжный бюджет нельзя.
