# P2-04 — безопасные структурированные логи

**Приоритет:** P2 · **Размер:** M · **Зависимости:** P1-05
**Цель:** сделать логи полезными для диагностики, не отправляя пароли,
токены, email, текст звонка или другие PII.

P1-05 владеет global crash/error reporter и его payload contract; здесь
владелец — adoption в коде, structured application logs, retention и доступ.

## Почему это долг

В Flutter и Cloud Functions смешаны `print`, `debugPrint` и произвольные
ошибки; особенно много raw prints в `minimal_daily_widget.dart` и legacy
functions. Без единого формата нельзя связать request/session/function, а
полный объект ошибки может содержать email, room ID, caption или URL.

## Минимальный план

1. Ввести тонкий facade: уровни debug/info/warn/error, event name, request
   correlation ID и allow-list полей. Использовать имеющийся logging/runtime,
   не подключать новую платформу только ради формата.
2. В backend сделать маленький safe logger для structured `console`-записей.
   Redact по ключам (`token`, `password`, `authorization`, `email`, `caption`,
   `transcript`) и ограничить длину пользовательского текста.
3. Убрать production `print` из изменяемых/high-risk путей; debug-only вывод
   оставить за флагом. Ошибка должна логироваться с stack trace, но без payload.
4. Описать retention и кто имеет доступ к логам в release runbook (P3-01).

## TDD/проверки

- Unit tests redaction: вложенные maps, списки, null, stack trace и Unicode.
- Тест, что error event содержит код/корреляцию, но не секретные значения.
- Проверить debug/release поведение на iOS и Android; не тестировать логи как
  пользовательский UI.

## Подводные камни

- Не логировать полный callable request «для удобства».
- Correlation ID не должен быть auth token или email.
- Не ломать локальную диагностику: сохранять тип и код ошибки, а payload
  заменять `[redacted]`.
- Не считать Firebase/Crashlytics автоматически безопасными без проверки
  правил доступа и retention.

## Не делать

Не внедрять новый SaaS/APM, distributed tracing или повсеместную замену всех
строк за одну итерацию. Сначала facade и критические потоки.

## Готово, когда

- новые критические логи единообразны и санитизированы;
- тесты подтверждают отсутствие PII/секретов;
- в исходниках критических путей нет неконтролируемого `print`;
- runbook описывает просмотр и удаление логов.

## Риск, abort и откат

- **Abort:** найден secret/PII в release log, missing correlation или reporter
  меняет user-visible error; прекратить rollout.
- **Откат:** отключить новый logger adapter/feature flag и вернуть предыдущий
  safe formatter; данные приложения не меняются.
- **Необратимость:** опубликованные логи могут быть скопированы — удаление и
  retention запускаются сразу при PII incident.
