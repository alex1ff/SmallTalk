# VoIP: текущее устройство и проверка

Актуальный backlog и границы рефакторинга:
[`tech_debt/P1-08-voip-service-decomposition.md`](tech_debt/P1-08-voip-service-decomposition.md).
Приложение больше не поддерживается через FlutterFlow; обычные файлы Flutter
являются редактируемым production-кодом.

## Что реализовано

- FCM и PushKit token registration выполняется через callable
  `registerVoipToken`; приватные токены не пишутся клиентом напрямую.
- Backend уже отправляет входящие уведомления и ведёт server-owned lifecycle
  сессии. `acceptCall`, `declineCall`, `endSession` и восстановление активной
  сессии реализованы.
- `VoIPService` обрабатывает CallKit/ConnectionService Accept, Decline, End и
  Timeout, проверяет payload/session identity и передаёт подтверждённый звонок
  в `VideoCallPage`.
- Ранние CallKit-события переживают cold start через bounded queue с TTL,
  приоритетом, dedupe и привязкой к текущему Firebase Auth пользователю.
- iOS background modes и Android full-screen/foreground permissions находятся
  в platform-конфигурации репозитория.

## Локальная проверка

```bash
flutter test \
  test/services/voip_service_accept_helpers_test.dart \
  test/services/voip_service_decline_helpers_test.dart \
  test/services/voip_service_timeout_helpers_test.dart \
  test/services/voip_pending_callkit_action_queue_test.dart \
  test/services/voip_token_registry_test.dart
flutter analyze
```

Unit/widget tests не заменяют native delivery smoke: они не вызывают APNs,
PushKit, CallKit или Android ConnectionService.

## Обязательный device smoke перед релизом

Проверить на физическом iPhone и Android-устройстве с production-like build:

- foreground, background и terminated/killed state;
- входящий экран на lock screen;
- Accept открывает ровно одну страницу правильной сессии;
- Decline и Timeout закрывают только соответствующий системный звонок;
- повторный/устаревший push не открывает звонок;
- logout/login другим пользователем не воспроизводит старое действие;
- token rotation и переустановка обновляют регистрацию;
- отсутствие camera/microphone permission корректно отменяет accept;
- relaunch после принятия восстанавливает активную сессию без duplicate accept.

Результат smoke фиксировать: платформа/OS, build, начальное состояние,
sessionId (без room URL/token), ожидаемый и фактический результат.

## Troubleshooting

- iOS: проверить Push Notifications/VoIP entitlements, APNs environment,
  `apns-push-type: voip`, актуальность PushKit token и device console.
- Android: проверить `POST_NOTIFICATIONS`, full-screen intent, foreground
  service permissions и battery restrictions.
- Не логировать PushKit/FCM token, Daily room URL или meeting token.
- Не добавлять `Future.delayed` для исправления race без воспроизводящего теста.
- Call action handling должен становиться ready только после Firebase Auth и
  инициализации обязательного CallKit pipeline.

Полезные источники: [flutter_callkit_incoming](https://pub.dev/packages/flutter_callkit_incoming),
[Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging),
[Apple CallKit](https://developer.apple.com/documentation/callkit),
[Android ConnectionService](https://developer.android.com/reference/android/telecom/ConnectionService).
