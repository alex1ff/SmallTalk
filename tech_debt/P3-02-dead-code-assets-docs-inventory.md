# P3-02 — инвентаризация рудиментов, assets и устаревших документов

**Приоритет:** P3 · **Размер:** S/M · **Зависимости:** P0-01, P2-06
**Цель:** удалить доказанно неиспользуемое и оставить один актуальный источник
операционных задач.

## Почему это долг

В корне одновременно лежат `TASKS.md`, `TASKS2.md`,
`UX_UI_LOADING_OPTIMIZATION_TASKS.md`, `VOIP_TODO.md`, старые audit plans и
несколько PRD. В assets есть 71 файл и favicon-заглушки в разных каталогах.
Без статуса/владельца непонятно, что актуально; рудиментарный код и assets
увеличивают поиск, bundle и риск случайного возврата старого решения.

## Минимальный план

1. Сгенерировать inventory: файл, импорты/asset references, build inclusion,
   runtime use, owner, last relevant commit, решение keep/archive/delete.
2. Для документов добавить header `active`, `historical` или `superseded by`;
   актуальные незакрытые задачи перенести в этот backlog, историю не терять.
3. Удалять code/assets только если статический поиск, build и smoke подтверждают
   отсутствие использования. Делать небольшими группами с bundle-size diff.
4. Проверить дубли package/dependency и пустые favicon assets; не менять бренд
   или лицензионные файлы без product approval.

## Проверки

- `flutter build`/asset bundle проходит без missing asset.
- Route/function/export manifest не теряет runtime entrypoint.
- Документные ссылки и `scripts/generate_audit_inventory.sh` обновлены.

## Подводные камни

- Asset может загружаться по строке из Firestore/remote config и не находиться
  обычным `rg`.
- Native iOS/Android ресурсы могут ссылаться вне Dart.
- Не удалять audit evidence, нужное для rollback/compliance; архивировать.

## Не делать

Не проводить массовую «чистку» без доказательства и не оптимизировать 7 MB
assets до измерения реального bundle impact.

## Готово, когда

- каждый legacy doc имеет статус и актуальную ссылку;
- кандидаты delete подтверждены build/smoke;
- bundle/repository diff измерен;
- нет двух активных backlog с противоречащими инструкциями.
