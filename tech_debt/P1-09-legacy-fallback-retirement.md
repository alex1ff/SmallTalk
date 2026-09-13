# P1-09 — управляемое удаление legacy fallback и старых полей

**Приоритет:** P1 · **Размер:** L/XL · **Зависимости:** P0-01, P0-02, P1-02
**Цель:** перестать бессрочно поддерживать старые схемы, не отрезав реально
активных пользователей.

## Почему это долг

Legacy-ветки есть в `video_sessions_shared.js`/matchmaking (student/tutor,
country/level/priority), `voip_tokens.js` (legacy FCM/VoIP token),
`user_match_profile.dart` (country), videoSessions/captions, onboarding и
reviews. Некоторые fallbacks читают
старые поля из `users`, затем синхронизируют их в private/normalized данные.
Без явной версии и метрики невозможно понять, когда ветку безопасно удалить;
каждая новая feature обязана учитывать обе схемы.

## Минимальный план

1. Создать реестр fallback: поле/ветка, владелец, read/write path, доля активных
   документов, privacy/security риск, дата последнего использования. Минимальная
   поддерживаемая версия клиента должна быть явной (например, текущая release
   major и одно окно обновления), а не «все старые версии навсегда».
2. Добавить безопасную серверную метрику счётчика без PII и одноразовый audit
   script для production aggregate; не читать пользовательские тексты.
3. Для нужных данных выполнить idempotent серверный backfill с dry-run,
   checkpoint и лимитом batch. Вместо наивного восстановления старого snapshot
   использовать forward repair: обновлять только отсутствующие/устаревшие поля
   с `updatedAt`/generation guard, чтобы не перезаписать более новую запись.
4. Сначала прекратить legacy writes, затем выдержать окно совместимости,
   затем удалить reads/rules/indexes отдельными маленькими PR.
5. Для клиентов ниже минимальной поддерживаемой версии вернуть явное
   upgrade-required состояние, а не непредсказуемый fallback.

## TDD/проверки

- До миграции — fixtures старой/новой/частично мигрированной схемы.
- Backfill tests: повторный запуск, конфликт свежей записи, missing/null,
  checkpoint resume.
- После удаления — contract test, что legacy поле больше не читается/пишется,
  и rules deny client write.

## Подводные камни

- Нельзя удалять fallback по одному `rg`: сначала production usage и минимальная
  поддерживаемая версия приложения.
- VoIP token и entitlement — security-sensitive; миграция только на сервере.
- Не перетирать более новую normalized запись старыми данными.
- Firestore backfill имеет стоимость и quota; батчи и dry-run обязательны.

## Риск, abort и откат

- **Abort:** usage не нулевой после окна совместимости, обнаружено перезаписывание
  более новой normalized записи, либо rules/VoIP delivery ухудшились.
- **Откат:** остановить rollout и запустить идемпотентный forward repair из
  audit/checkpoint с guard; не восстанавливать целиком старый snapshot поверх
  новых данных. Legacy read временно вернуть отдельным commit.
- **Необратимость:** удаление старых полей/индексов необратимо после migration
  window; выполнять только после backup/aggregate и подтверждения owner.

## Не делать

Не делать «big bang» schema v2 и не оставлять dual-write навсегда. Каждая
legacy-ветка закрывается собственной маленькой миграцией.

## Готово, когда

- каждый fallback имеет owner, usage metric и retirement date;
- backfill идемпотентен и проверен на staging;
- security-sensitive legacy fields больше не client-readable/writable;
- compatibility tests остаются только для поддерживаемых версий.

## Прогресс 2026-08-31

- Добавлен machine-readable реестр
  [`audit/legacy_fallback_manifest.json`](../audit/legacy_fallback_manifest.json)
  для четырёх семейств fallback: VoIP tokens, raw country/level match profile,
  session participant aliases и source-present history helper.
- Для каждой записи указаны owner, поля/ветка, source symbols, классификация
  writes, privacy risk, prerequisites и две колонки evidence. Пока
  client-version/production-usage evidence отсутствуют, значения оставлены
  `null`; реестр не содержит retirement date и не разрешает удаление.
- Добавлен минимальный Node contract test, проверяющий уникальность записей,
  существование source paths, обязательные поля и запрет retirement без
  evidence. Он запускается в `scripts/local_ci.sh`.
- Challenge подтвердил, что Country_NS/level и session aliases продолжают
  использоваться активным клиентом/backend-контрактом; writes не прекращались.
  VoIP legacy writes клиента уже отсутствуют и защищены privacy-contract.

Локальный сигнал: `npm --prefix firebase/custom_cloud_functions run
test:legacy-fallback-manifest` — green. Production aggregate, минимальная
версия клиента, compatibility window, backfill и deletion остаются отдельными
операционными задачами; P1-09 частично выполнена.
