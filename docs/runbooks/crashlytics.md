# Crashlytics: runbook мобильных ошибок

## Где искать ошибку

1. Откройте Firebase Console → проект приложения → **Crashlytics**.
2. Ищите issue по фиксированному названию вида
   `AppReport[feature/error_code/error_type]`. Название не содержит текст
   исключения, email, токенов или URL комнаты.
3. Для каждого issue проверьте release/build, OS и stack trace. `feature`,
   `error_code` и `error_type` также передаются как per-event information;
   они не являются отдельными Crashlytics filter dimensions.
4. Если нужен session correlation, откройте конкретное событие и найдите
   `session_hash`. Сырые session ID в Crashlytics не отправляются.

## Связь с backend

Backend должен вычислять digest тем же способом: `trim` ID → UTF-8 → SHA-256
→ lowercase hexadecimal. Сверяйте только одинаковый digest и временное окно;
не записывайте рядом с ним исходный ID. Если hash отсутствует, расследуйте по
release/build, времени и типу ошибки, не расширяя клиентский payload.

## Первичная классификация

| Код | Владелец | Первое действие |
| --- | --- | --- |
| `flutter_framework_fatal`, `platform_async_fatal` | platform/reliability | проверить stack trace и последний release |
| `firebase_initialize_failed` | platform/reliability | проверить native Firebase config и доступность SDK |
| `voip_initialize_failed` | calling/VoIP | проверить CallKit/PushKit и порядок bootstrap |
| `auth_refresh_failed` | auth | проверить Firebase Auth/App Check и срок токена |
| `purchase_failed` | monetization | сверить RevenueCat/App Store/Play Store и исключения отмены |
| `translation_*` | translation | проверить callable response и provider availability |
| `ai_feedback_*` | AI feedback | проверить callable job/status и retry path |

## Release gate

Перед публикацией на физическом iOS и Android устройстве:

1. Установить release-сборку с тем же Firebase project и build number.
2. Сгенерировать тестовый non-fatal на одной из пяти feature-границ и
   проверить, что UI fallback завершился и событие появилось после
   возврата/перезапуска приложения.
3. Сгенерировать тестовый crash только в непубликуемом debug/internal build;
   убедиться, что crash виден в Crashlytics и следующий запуск приложения
   проходит.
4. Для iOS проверить dSYM-symbolication, для Android — mapping/deobfuscation.
   Без этой проверки P1-05 считается локально реализованным, но не закрытым
   release gate.

## Сбой самого reporter

Reporter работает fire-and-forget, держит максимум 20 sanitized reports и
ограничивает запись sink коротким timeout. Если Crashlytics недоступен,
пользовательский fallback и завершение звонка не должны блокироваться. При
подозрении на влияние SDK временно удалите только `CrashlyticsErrorReportSink`
и его bootstrap attach, оставив typed tests и существующие UI catches.
