# P1-08 — декомпозиция `VoIPService`

**Приоритет:** P1 · **Размер:** L/XL · **Зависимости:** P1-02, P1-05
**Цель:** изолировать CallKit/FCM/navigation lifecycle без изменения поведения
входящего звонка.

P1-02 владеет server session state; здесь scope только native notification,
CallKit/FCM bridge и navigation handoff.

## Почему это долг

`lib/services/voip_service.dart` содержит около 3483 строк и совмещает
регистрацию push/VoIP token, CallKit events, foreground/background handling,
accept/decline, восстановление сессии, навигацию, retry и legacy fallback.
В файле около 90 блоков lifecycle/error/navigation-состояния. Ошибка ordering
может открыть две страницы звонка, принять уже завершённую сессию или потерять
входящий вызов.

`VOIP_SETUP.md` и `VOIP_TODO.md` при этом всё ещё утверждают, что отправка
VoIP push, accept и навигация не реализованы, хотя актуальный backend уже
экспортирует соответствующие пути. Это отдельный operational risk: ручной QA
может повторять закрытые пункты или пропустить terminated-state gaps.

## Минимальный план

1. Зафиксировать таблицу событий: notification → CallKit → accept/decline →
   session validation → navigation → cleanup.
2. Выделить без DI-framework: token registry, CallKit adapter, session resolver
   и navigation coordinator. `VoIPService` остаётся facade.
3. Все clock, platform events и navigation callbacks передавать параметрами в
   тестируемые policy/helpers; сохранить plugin API в одном adapter.
4. Удалять legacy path только через P1-09, а не одновременно с extraction.
5. После characterization обновить `VOIP_SETUP.md`/`VOIP_TODO.md` ссылкой на
   этот backlog и явно отметить, что остаётся только для iOS/Android device
   QA: PushKit/CallKit terminated-state, background, token rotation.

## TDD/проверки

- Characterization: duplicate accept, stale notification, app killed,
  background/foreground race, decline после server end, missing token.
- Fake CallKit/event stream/clock; unit tests не вызывают нативный plugin.
- Integration smoke на реальном iOS и Android: accept/decline/back/relaunch.

## Подводные камни

- CallKit completion callback должен завершаться ровно один раз.
- Навигация возможна только после проверки server-owned session state.
- Token/room URL нельзя логировать; late callback после dispose игнорировать.
- Не исправлять race дополнительным `Future.delayed` без теста ordering.

## Риск, abort и откат

- **Abort:** duplicate CallKit UI, missed terminated-state call, accept после
  server end или ухудшение notification delivery; не продолжать extraction.
- **Откат:** вернуть предыдущий facade/adapter commit и старые plugin bindings;
  серверные session/notification данные не мигрировать.
- **Необратимость:** отсутствует для кода; platform entitlements изменять
  отдельным явно проверенным commit.

## Не делать

Не заменять CallKit/FCM plugin, не переписывать matchmaking и не вводить новый
global state manager.

## Готово, когда

- facade читабелен как последовательность событий;
- adapters/policies покрыты race/idempotency tests;
- public API и server payload не изменились;
- device smoke подтверждает killed/background/foreground paths.

## Прогресс 2026-08-31

- После независимого challenge выбран узкий первый срез: pending early CallKit
  action queue. Plugin subscription, async handlers и navigation оставлены в
  `VoIPService`.
- В [`voip_pending_callkit_action_queue.dart`](../lib/services/voip_pending_callkit_action_queue.dart)
  вынесены FIFO, identity/dedupe, приоритет, TTL, bound и user-target policy.
  Replacement сохраняет позицию; равный приоритет обновляет payload/time/user.
- Добавлены прямые тесты TTL boundary, priority/equal replacement, eviction,
  auth switch и accept payload expiry. Существующие facade-тесты продолжают
  проверять serialized extra и повторную expiry-проверку после долгого awaited
  permission gate внутри последовательного dispatch.
- `VOIP_SETUP.md` и `VOIP_TODO.md` обновлены до фактического состояния и больше
  не требуют повторно реализовать backend push/accept/navigation.
- Token registration/cleanup вынесен в
  [`voip_token_registry.dart`](../lib/services/voip_token_registry.dart): adapter
  ограничивает callable boundary, platform policy и best-effort error handling;
  Firebase/Auth lifecycle orchestration осталось в фасаде.

Локальные сигналы: token registry 8/8 и focused VoIP suite 105/105,
`flutter analyze --no-pub` без
ошибок, `git diff --check` чисто. P1-08 остаётся **частично выполненной**:
token registry, session resolver/navigation coordinator и физический iOS/
Android smoke ещё открыты.
