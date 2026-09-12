# P2-07 — декомпозиция остальных UI god-components

**Приоритет:** P2 · **Размер:** XL по частям · **Зависимости:** P2-03, P2-06
**Цель:** снизить стоимость UI-изменений через несколько локальных extraction,
а не переписывание экранов.

## Почему это долг

Кроме Daily крупными остаются `event_list_widget.dart` (~6524 строк),
`students_dashboard_widget.dart` (~4621), `profile_widget.dart` (~4435),
`favorite_widget.dart` (~3464), `native_speaker_page_widget.dart` (~3158) и
`event_create_widget.dart` (~3184).
В них смешаны fetch/cache, permission/access policy, analytics, modal flows,
локализация и layout. Один `students_dashboard_widget` содержит около 181
state/navigation/error hotspots.

## Минимальный план

1. Для каждого файла завести отдельную маленькую подзадачу и baseline:
   dependencies, side effects, state, callbacks, test coverage и rebuild hot
   spots. Hotspot — участок с сетью/слушателем/side effect или >3 связанных
   async state transitions, а не просто длинный `build`. Не брать два экрана
   одновременно.
2. Сначала вынести presentational sections с typed input/callback; затем
   loading/error/pagination controller; repository уже существующий — не
   дублировать.
3. Оставить page widget владельцем route/modal orchestration. Переносить
   business policy только в service, а не в новый child widget.
4. Целевой размер не является KPI; остановиться, когда рисковая ответственность
   отделена и тестируема.

## TDD/проверки

- Characterization widget tests на loading/error/empty/success, pagination,
  filters, modal result и dispose.
- Тест rebuild/state после refresh и смены пользователя.
- Golden только для стабильных extracted components, не для всей страницы.

## Подводные камни

- Не создавать callback-prop chain из десятков параметров; группировать только
  связанный view state.
- Не переносить Firestore listener так, чтобы изменить lifetime/subscription.
- Сохранять keys, semantics и scroll position.
- Проверять mounted/late async callback после navigation.

## Риск, abort и откат

- **Abort:** изменился порядок listener/callback, scroll position, semantics или
  сетевой read/write count; extraction вернуть до следующего seam.
- **Откат:** revert одного extraction commit, сохранив characterization tests;
  Firestore schema/data не меняются.
- **Необратимость:** отсутствует, пока не меняются persistence contracts.

## Не делать

Не вводить новый state-management framework, не менять дизайн и не выделять
компоненты только ради уменьшения line count.

## Готово, когда

- для каждого hotspot есть owner и отдельная последовательность extraction;
- network/business logic не живёт в extracted presentation;
- core states покрыты тестами;
- изменения можно ревьюить небольшими PR без cross-feature diff.
