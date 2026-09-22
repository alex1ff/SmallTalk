# P2-03 — типизированные контракты данных на границах функций

**Приоритет:** P2 · **Размер:** L · **Зависимости:** P1-02, P2-06
**Цель:** локализовать `Map<String, dynamic>` и `dynamic`, чтобы изменения
Firestore/callable API ловились тестом и анализатором до релиза.

## Почему это долг

В Flutter-коде около 831 вхождения `Map<String, dynamic>`/`dynamic`. Страницы
делают прямые Firebase-вызовы, а разбор ответов повторяется в event,
translation, call и subscription flows. Ошибка shape сейчас часто проявится
только в runtime как `NoSuchMethodError`, `CastError` или пустой UI.

## Минимальный план

1. Начать с наиболее рискованных границ: RevenueCat entitlement/purchase,
   trial/call lifecycle, event public/private projection и translation/AI
   response. Составить таблицу поля, типа, nullable и версии.
2. Для каждой границы создать маленькие immutable request/response модели
   (обычные Dart-классы/records в существующем слое, без нового генератора).
   Один parser должен проверять обязательные поля и выдавать доменную ошибку.
3. Перенести вызов Firebase из widget только в уже существующие services или
   добавить узкий service; UI получает typed state, а не raw map.
4. Сохранить совместимость с текущими Firestore документами: неизвестные поля
   игнорировать, отсутствующие обязательные — логировать и показывать retry.

## TDD/проверки

- Сначала characterization tests на текущий успешный response.
- Parser tests: missing/null/wrong type/extra field/старый response version.
- Contract tests callable: auth/App Check ошибки, timeout, idempotent повтор.
- Golden/widget tests для loading/error/empty, чтобы shape error не стал
  «пустым экраном».

## Подводные камни

- Firestore `Timestamp`, `GeoPoint`, `DocumentReference` и `FieldValue` нельзя
  бездумно приводить к JSON.
- Не менять имена полей, subscription IDs и callable error codes без версии.
- Не делать одну огромную универсальную модель для несвязанных фич.
- Не скрывать невалидный ответ значением по умолчанию, если это маскирует
  оплату, лимит звонка или права пользователя.

## Не делать

Не переписывать все FlutterFlow records и не добавлять новый serializer/ORM
ради полного покрытия. Мигрировать контракт за контрактом, начиная с P0/P1.

## Готово, когда

- критические flows не парсят raw map в виджетах;
- каждый выбранный callable имеет типизированные request/response и тест shape;
- ошибки отображаются предсказуемо и наблюдаемы;
- `flutter analyze`, backend tests и emulator rules остаются зелёными.

## Риск, abort и откат

- **Abort:** новый parser меняет error code, entitlement/limit decision или
  silently drops required field; вернуть raw boundary до исправления fixture.
- **Откат:** revert одного DTO/parser/service commit; Firestore документы и
  callable schema не откатывать без migration.
- **Необратимость:** отсутствует для read-only parsing; writes отдельно gated.
