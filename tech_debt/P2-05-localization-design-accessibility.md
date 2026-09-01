# P2-05 — локализация, design tokens и базовая доступность

**Приоритет:** P2 · **Размер:** M/L · **Зависимости:** P1-05, P3-01
**Цель:** убрать ошибки языка/даты и визуальную рассинхронизацию в ключевых
сценариях, не превращая задачу в полный редизайн.

## Почему это долг

В feature-коде много hardcoded строк, `Color` и `TextStyle` (порядка 596
вхождений в основных shared/students/components). Уже наблюдалась английская
локаль с русским «завтра». Часть экранов опирается на FlutterFlow-стили
напрямую, а не на единый `ExpatlioDesign`; у интерактивных элементов не везде
есть `Semantics` и проверка размера touch target.

## Минимальный план

1. Провести инвентаризацию user-visible строк в auth, paywall, profile,
   search/call, events и review. Сначала вынести ошибки, статусы и относительные
   даты, потому что они влияют на доверие и поддержку.
2. Исправить форматирование дат/«today/tomorrow» через locale-aware formatter,
   pluralization и timezone; не склеивать перевод строкой.
3. Добавить отсутствующие базовые design tokens (цвета, радиусы, spacing,
   typography) в существующую тему и мигрировать только изменяемые critical
   components.
4. Добавить Semantics labels, достаточный contrast, minimum 44×44 logical px и
   поддержку text scale для auth/paywall/call controls. Проверить keyboard/back
   для web, где это применимо.

## TDD/проверки

- Locale matrix для English/Russian: дата, plural, error/loading/empty.
- Widget tests на semantics label, enabled/disabled/loading и text scale.
- Небольшие golden tests только для критических кнопок/paywall/call status;
  не фиксировать целые экраны с системным status bar.

## Подводные камни

- Не менять продуктовые тексты и смысл без согласования; сначала исправить
  язык/формат.
- Проверить RTL/длинные строки и VoiceOver/TalkBack, а не только английский.
- Не смешивать серверные timestamps и локальное время пользователя.
- Generated localization-файлы менять через существующий pipeline, не вручную.

## Не делать

Не проводить полный visual redesign и не мигрировать весь экспорт FlutterFlow
за один PR. Tokens вводить там, где это уменьшает повторение и баги.

## Готово, когда

- критические статусы и даты не зависят от языка устройства случайным образом;
- core flows проходят locale/semantics/text-scale tests;
- новые изменяемые widgets используют tokens, а не новые hardcoded цвета;
- `flutter analyze` и визуальная проверка iOS/Android зелёные.

## Риск, abort и откат

- **Abort:** locale matrix показывает смешанный язык/неверную дату, text scale
  ломает critical CTA или contrast регрессирует; не распространять batch.
- **Откат:** вернуть изменённые resource/token/widget файлы отдельным commit;
  сохранённые пользовательские данные не затрагиваются.
- **Необратимость:** отсутствует для UI; опубликованный перевод можно исправить
  следующей локализацией.
