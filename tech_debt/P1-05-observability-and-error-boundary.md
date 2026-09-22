# P1-05 — Наблюдаемость и глобальная обработка ошибок

**Статус:** локальная реализация завершена · **Дата:** 31.08.2026

**Размер:** M · **Владелец:** platform/reliability · **Зависимости:** P0-01.

## Доказательство долга

Поиск production Dart-кода не показывает единой обвязки
`runZonedGuarded`, `FlutterError.onError`, `PlatformDispatcher.instance.onError`
или Crashlytics/Sentry. Ошибки Daily/Deepgram/Firestore обрабатываются локально
в больших widgets. В результате crash и non-fatal failure могут быть видны
только пользователю или в разрозненных `print`.

## Цель

Получать actionable сигнал: release, platform, session ID (не токен), feature,
ошибка и stack trace — при этом не раскрывать PII.

Эта задача владеет global error boundary, reporter integration и redaction
contract. Переход production `print` на facade и retention/adoption policy
описаны отдельно в P2-04.

## Минимальный scope

1. Один global error boundary в `main.dart`/app bootstrap.
2. Один существующий provider (Firebase Crashlytics или выбранный эквивалент),
   без параллельного добавления нескольких систем.
3. `recordError` для uncaught framework/async errors и non-fatal call,
   translation, AI, purchase и auth failures.
4. Санитизация metadata: environment, build, feature, session hash; запрет
   room URL, tokens, raw captions, email и full user profile.
5. Reporter metadata contract для client/server correlation; backend structured
   logger, его adoption и retention принадлежат P2-04.
6. Runbook: где искать crash, как связать client session с server logs и когда
   считать ошибку release blocker.

## TDD/порядок работ

- Тесты на mapping/sanitization payload.
- Тест, что global handlers не падают при ошибке reporting SDK.
- Тесты на user-facing fallback для offline/provider errors.
- Manual smoke в debug/release mode и проверка dashboard event.

## Не входит

- Новая аналитическая платформа.
- Сбор полного network trace.
- Автоматическое логирование всего `catch` блока.

## Подводные камни

- Reporting не должен блокировать UI и завершение звонка.
- Debug logs и production logs должны иметь разные уровни.
- Не считать “error swallowed” graceful degradation без метрики.

## Готово, когда

- Uncaught Flutter/async/backend ошибки появляются в одном месте.
- Все sensitive fields проверены тестом/санитизатором.
- Для ключевых feature есть error rate и owner.
- User sees localized fallback, а не raw exception.

## Реализовано

- Добавлен типизированный `ErrorReporter` с allow-list кодов, фиксированным
  `error_type`, безопасным synthetic exception и SHA-256 хешем session ID.
- Добавлена bounded in-memory очередь (20 записей), последовательный flush,
  timeout и изоляция ошибок sink; Web/тесты используют no-op adapter.
- Установлены и скомпонованы `FlutterError.onError` и
  `PlatformDispatcher.instance.onError`, включая background FCM isolate.
- Crashlytics подключён как единственный mobile sink; добавлены пять
  согласованных non-fatal границ (VoIP, auth refresh, purchase, translation,
  AI feedback) без изменения пользовательских fallback/return shapes.
- Добавлены unit/boundary tests и ручной iOS Xcode phase для `upload-symbols`.

Проверено локально: `flutter analyze --no-pub`, целевые error-reporting тесты,
полный Flutter suite (`2331` тест), `pod install
--project-directory=ios --deployment` после обновления Podfile.lock и повторный
deployment-check после добавления Xcode phase.

## Открытый внешний release gate

- Android debug build на этой машине не запускается: Android SDK отсутствует.
- Нужен физический iOS/Android smoke: тестовый crash и non-fatal, перезапуск
  приложения для отправки очереди и проверка символизации в Crashlytics.
- CocoaPods предупредил о существующих кастомных base configurations и
  `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES`; это pre-existing Xcode setup, не
  изменяемый автоматически в рамках этой задачи. Перед release проверить
  archive на CI/рабочем Mac.

## Риск, abort и откат

- **Abort:** reporting SDK блокирует UI, раскрывает PII или сам вызывает crash;
  отключить только новый reporter adapter.
- **Откат:** revert integration/config commit, оставив user-facing handlers и
  локальный safe logger.
- **Необратимость:** отсутствует; cloud logs очищаются по retention policy.
