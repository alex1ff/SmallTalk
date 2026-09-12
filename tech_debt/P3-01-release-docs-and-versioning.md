# P3-01 — воспроизводимый release runbook и версия

**Приоритет:** P3 · **Размер:** S/M · **Зависимости:** P0-01, P0-02, P1-06
**Цель:** чтобы сборка из GitHub/FlutterFlow-пайплайна и Firebase deploy были
повторяемыми, а команда понимала, что именно попало в релиз.

## Почему это долг

Версия в `pubspec.yaml` и фактические release-процедуры расходятся по
контекстам. README содержит устаревающие числа тестов, а локальный gate,
Firebase environments, App Check, RevenueCat products, backfill и rollback не
собраны в одном коротком runbook. Это создаёт ручные ошибки при TestFlight,
песочнице StoreKit и production deploy.

P0-01 владеет тем, что запускается автоматически и блокирует PR; этот документ
владеет человеческим release checklist и operational context, но не добавляет
второй CI gate.

## Минимальный план

1. Описать version/build-number policy, branch/tag convention и обязательные
   checks перед TestFlight/Play Internal Testing.
2. Составить environment matrix: bundle IDs, Firebase project, Functions
   region, RevenueCat app/entitlement/offering, App Check, test accounts и
   sandbox reset. Секреты — только ссылки на secret store, не значения.
3. Зафиксировать команды local gate, backend deploy, rules/index deploy,
   event projection backfill и проверку READY; добавить безопасный rollback и
   post-deploy smoke.
4. Обновлять метрики README командами, а не ручными оценками; если проверка не
   запускалась, писать это явно.

## Проверки

- Пройти runbook на чистом checkout с тестовым проектом.
- Проверить, что каждая команда имеет ожидаемый результат и не требует
  интерактивного локального состояния.
- Release checklist должен включать migration/backfill и проверку функций,
  которые не задеплоились.

## Подводные камни

- Не коммитить App Store/RevenueCat/Firebase secrets и private keys.
- Не описывать production rollback как `git reset --hard`; использовать
  конкретный tag/предыдущий артефакт и обратимые миграции.
- Не считать «Ready to Submit» в RevenueCat доказательством доступности товара
  в StoreKit sandbox.

## Не делать

Не переписывать документацию продукта и не строить отдельную release platform;
достаточно актуального Markdown рядом с существующими скриптами.

## Готово, когда

- новый разработчик может повторить тестовый deploy по документу;
- версия, артефакт и commit однозначно связаны;
- environment/secrets checklist закрыт до публикации;
- README больше не содержит неподтверждённых чисел.
