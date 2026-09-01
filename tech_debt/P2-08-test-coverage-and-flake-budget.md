# P2-08 — риск-ориентированное покрытие и flake budget

**Приоритет:** P2 · **Размер:** M · **Зависимости:** P0-01, P2-01
**Цель:** измерять не число тестов, а защищённость критических контрактов и
стабильность suite.

## Почему это долг

Тестов много, но в CI нет versioned coverage report/threshold, mutation или
flake ledger. README содержит ручные числа, которые расходятся с текущими
suite. Большие test-файлы (например `start_search.test.js` ~7821 строк) сами
становятся сложны для навигации; green suite не показывает непокрытые branch,
race и platform integration.

## Минимальный план

1. Получить baseline branch/line coverage отдельно для Dart services/widgets
   и backend policy командой `flutter test --coverage`. Для Node закрепить
   `c8` как devDependency и запускать, например:

   ```text
   npx c8 --reporter=json-summary --reporter=lcov --report-dir=coverage/node npm run test:events
   ```

   Сохранить `coverage/lcov.info`/JSON как CI artifact.
   Исключения (generated/platform adapters) перечислить в versioned manifest.
2. Не вводить общий 90% порог. Для изменяемого кода запрещать снижение, а для
   call/trial/payment/auth/rules требовать явную branch matrix. Baseline
   зафиксировать на commit `2fab093`; changed-code threshold — не ниже baseline
   (допуск только с explicit owner/reason в PR).
3. Разделить самые крупные test-файлы по use case/contract, переиспользуя
   fixtures; не создавать новую тестовую DSL.
4. Вести flake ledger: test, частота, owner, причина, срок. Flaky — повторный
   результат при одинаковом commit/seed/environment без изменения входа;
   максимум один автоматический retry только для диагностики. Quarantine — не
   более 14 дней, с owner и expiry, никогда для P0 flows.
5. Публиковать coverage/slowest/flaky summary как CI artifact.

## TDD/проверки

- Для каждого bugfix сначала failing regression test.
- Для refactor — characterization, затем mutation/намеренная ошибка должна
  доказать, что тест действительно ловит нарушение.
- Seed/random clock/network должны быть детерминированы.

## Подводные камни

- Высокий line coverage не доказывает race/idempotency/security.
- Generated boilerplate и недоступный platform code могут искажать метрику.
- Не принимать snapshot source-string checks за runtime contract, если можно
  вызвать pure function/emulator.

## Риск, abort и откат

- **Abort:** baseline/threshold не воспроизводится два раза или новый тест
  делает suite flaky; P0 flow попал в quarantine.
- **Откат:** вернуть предыдущий test manifest/runner commit и удалить только
  новый artifact step; production code/data не меняются.
- **Необратимость:** отсутствует; quarantine всегда имеет дату автоматического
  снятия.

## Не делать

Не гнаться за единым процентом, не переписывать все tests и не добавлять sleep
для «стабилизации».

## Готово, когда

- CI публикует воспроизводимый baseline и не допускает снижение changed code;
- P0/P1 flows связаны с конкретной матрицей тестов;
- flaky tests имеют owner/срок и не маскируются безлимитным retry;
- README получает цифры из команды/артефакта.
