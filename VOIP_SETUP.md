
# VoIP Setup Documentation

## ✅ Что уже настроено

### 1. Flutter Dependencies
- `flutter_callkit_incoming: ^3.0.0` - CallKit (iOS) + ConnectionService (Android)
- `firebase_messaging: ^15.2.7` - Push notifications

### 2. VoIP Service (`lib/services/voip_service.dart`)
- Инициализация FCM токенов
- Обработка CallKit/ConnectionService событий
- Показ входящих звонков
- Обработка Accept/Decline/End/Timeout

### 3. Integration в `main.dart`
- Background message handler
- VoIP service initialization
- Обработка входящих звонков в фоне

### 4. iOS Configuration (`ios/Runner/Info.plist`)
- `UIBackgroundModes`: voip, remote-notification, processing, audio
- Camera и Microphone permissions

### 5. Android Configuration (`android/app/src/main/AndroidManifest.xml`)
- VoIP permissions (WAKE_LOCK, FOREGROUND_SERVICE, etc.)
- Full-screen intent для звонков поверх экрана блокировки

---

## 🚧 Что осталось сделать

### 1. Обновить Cloud Functions для отправки VoIP Push

В файле `acceptCall` функции добавить отправку VoIP push студенту:
```javascript
// После создания Daily room
await sendVoipPushToStudent(sessionData.studentId, {
  sessionId: sessionId,
  callerName: tutorData.display_name,
  callerId: tutorId,
  callerPhoto: tutorData.photo_url,
  roomUrl: dailyRoom.url,
  meetingToken: dailyRoom.token,
});
```

### 2. Настроить VoIP Certificate (iOS)

1. Apple Developer → Certificates, Identifiers & Profiles
2. Создать VoIP Services Certificate
3. Экспортировать `.p12`
4. Загрузить в Firebase Cloud Messaging

### 3. Интегрировать навигацию на VideoCallPage

В `voip_service.dart` функции `_handleCallAccept()` добавить:
- Вызов Cloud Function `acceptCall`
- Навигация на `VideoCallPage` с параметрами

### 4. Тестирование

- [ ] Тест на iOS реальном устройстве
- [ ] Тест на Android реальном устройстве
- [ ] CallKit экран показывается
- [ ] Accept работает
- [ ] Decline работает
- [ ] Timeout обрабатывается

---

## 🔄 Workflow с GitHub

### При изменениях из FlutterFlow:
```bash
git checkout develop
git pull origin flutterflow
git merge flutterflow
# Разрешить конфликты если есть
git push origin develop
```

### VoIP код остается в ветке `develop` и НЕ перезаписывается FlutterFlow!

---

## 📱 Deploy в TestFlight

1. Merge `develop` → `main`
2. FlutterFlow → Deploy from GitHub (branch: main)
3. Automatic upload to TestFlight

---

## 🔍 Troubleshooting

### iOS: CallKit не показывается
- Проверьте VoIP Certificate в Firebase
- Проверьте FCM token сохранен в Firestore
- Проверьте `apns-push-type: voip` в push payload

### Android: Уведомления не приходят
- Проверьте POST_NOTIFICATIONS permission
- Android 13+ требует runtime permission
- Проверьте FCM token актуален

### Background handler не срабатывает
- iOS: Проверьте `@pragma('vm:entry-point')`
- Android: Проверьте `FOREGROUND_SERVICE` permission
- Проверьте что handler зарегистрирован ДО `initFirebase()`

---

## 📚 Полезные ссылки

- [flutter_callkit_incoming docs](https://pub.dev/packages/flutter_callkit_incoming)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Apple CallKit](https://developer.apple.com/documentation/callkit)
- [Android ConnectionService](https://developer.android.com/reference/android/telecom/ConnectionService)

