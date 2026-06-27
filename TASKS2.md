# Этапы работ: новая логика поиска и звонка

## Этап 1. Подготовка и разбор текущей логики

Цель этапа: зафиксировать точки изменения в текущем коде и не сломать существующие звонки.

- [x] Найти все места, где студентский интерфейс использует `availabilityToday`.
- [x] Найти все backend-проверки, где студенты участвуют в подборе через `availabilityToday` или `isAvailable`.
- [x] Проверить текущий сценарий создания звонка: `createVideoSession`, `acceptCall`, `declineCall`, `processExpiredNotifications`.
- [x] Проверить текущую VoIP-логику: входящий звонок, accept, decline, timeout, навигация.
- [x] Зафиксировать текущие статусы `videoSessions` и поля, которые уже используются в приложении.
- [x] Определить, какие существующие поля можно переиспользовать, а какие нужно добавить для новой очереди поиска.

Результат аудита student UI availability:

- `lib/students_pages/students_dashboard/students_dashboard_widget.dart`: импортирует `student_availability_switch_control.dart`, читает `currentUserDocument?.availabilityToday.enabled`, читает `availabilityToday.intervals`, пишет `availabilityToday` при переключении доступности и удалении интервала.
- `lib/students_pages/students_dashboard/students_dashboard_widget.dart`: вызывает `AddInterWidget` через `_openAddInterBottomSheet()`, использует `StudentAvailabilitySwitchControl`, строит `_buildAvailabilitySection()`. Активная точка рендера: `_buildReferenceSearchHero()` -> `_buildAnimatedAvailabilitySection()` -> `_buildAvailabilitySection()`. Дополнительная legacy-точка напрямую вызывает `_buildAvailabilitySection()`, но находится под `_showLegacyDashboard => false` и сейчас неактивна.
- `lib/students_pages/students_dashboard/students_dashboard_model.dart`: хранит `switchValue` для student availability switch.
- `lib/students_pages/students_dashboard/students_dashboard_widget.dart`: `_buildTimezoneMetadataUpdate()` используется не только availability switch, но и `_syncTimezoneMetadata()` при загрузке страницы; при удалении student availability нельзя удалять timezone sync целиком.
- `lib/components/student_availability_switch_control.dart`: отдельный переключатель студентской доступности.
- `lib/components/teacher_availability_switch_control.dart`: teacher-only аналог переключателя, который должен остаться для teacher dashboard; удалять можно только student switch, если после удаления student call-site на него нет ссылок.
- `lib/components/add_inter_widget.dart`: общий bottom sheet интервалов, который становится частью student UI при вызове из student dashboard и пишет `availabilityToday.enabled = true` с интервалами. Этот же компонент используется `lib/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart`, поэтому удалять или ломать компонент нельзя; в следующих задачах нужно убрать только student call-site.
- `lib/components/availability_schedule_card.dart`: общий виджет расписания с текстом "Доступен сегодня"; используется student dashboard и `lib/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart`, поэтому удалять его нельзя без проверки teacher flow.
- `lib/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart`: teacher owner для `availabilityToday`, `AddInterWidget`, `AvailabilityScheduleCard` и teacher switch; при удалении student availability этот flow должен остаться рабочим.
- `test/students_pages/dashboard_component_contract_test.dart` и `test/regression/qa1_release_surface_contracts_test.dart`: тесты закрепляют текущий student availability UI и потребуют обновления при удалении функционала.
- Teacher-only тесты и контракты с текстом "Доступен сегодня", включая `test/teachers_pages/dashboard_ns_pending_widgets_test.dart`, не относятся к student UI, но защищают shared teacher flow и должны остаться актуальными после удаления student availability.
- `lib/shared_pages/profile/profile_widget.dart`: shared/student-accessible профиль, но найденные записи `availabilityToday` относятся к переходу/восстановлению teacher/native-speaker track, а не к обычному student availability UI.
- `lib/authorization/shared/social_auth_entry_logic.dart`: `hasAvailabilityToday()` используется как teacher-role signal. Это не student UI, но важно не сломать auth/teacher inference при будущей чистке данных.

Результат аудита backend availability checks:

- Базовая availability-логика: `firebase/custom_cloud_functions/availability.js`: `evaluateTutorAvailabilityWindow()` является общей role-agnostic проверкой доступности. Она сначала читает `availabilityToday.enabled`, затем fallback на `isAvailable`, а если оба поля отсутствуют, считает пользователя доступным. Если `availabilityToday.enabled = false` или fallback `isAvailable = false`, пользователь сразу считается недоступным. Пустые интервалы или интервалы без timezone дают доступность только если пользователь не выключен через `availabilityToday.enabled` / `isAvailable`.
- `firebase/custom_cloud_functions/video_sessions_shared.js`: `isSupportedSessionRole()` разрешает роли `student` и `native_speaker`. Поэтому переменные `tutorId`, `tutorData`, `availableTutors` в backend не означают только учителя.
- Первичный filtered-подбор: `firebase/custom_cloud_functions/create_video_session.js` собирает кандидатов из `learningLanguage.code` и `language_instruction_NS.code`, затем для каждого supported-role кандидата проверяет `availableAfter`, `evaluateTutorAvailabilityWindow()` и `isInCall`. Из-за этого студент-кандидат сейчас может попасть или не попасть в подбор через `availabilityToday` / `isAvailable`.
- Первичный filtered-подбор: `firebase/custom_cloud_functions/create_video_session.js` сохраняет итоговый список `availableTutors`, `tutorDetails` и `matchContext.candidateRoleCounts`; эти структуры уже учитывают student-candidates. При внедрении очереди студентов эти места нужно перевести на новый источник активного поиска, а teacher-candidates оставить на расписании доступности.
- Direct creation path: `firebase/custom_cloud_functions/create_video_session.js` в ветке `directTutorId` / `directUserId` использует те же проверки `availableAfter`, `evaluateTutorAvailabilityWindow()` и `isInCall` после `isSupportedSessionRole()`. Сейчас direct target технически может быть студентом, если передан его id.
- Teacher direct-call status: `firebase/custom_cloud_functions/direct_call_status.js` проверяет `availableAfter`, `evaluateTutorAvailabilityWindow()` и `isInCall`, но перед этим жестко требует requester `student` и target `native_speaker`. Это статус прямого звонка student -> teacher, не общий student-student подбор.
- Lifecycle accept: `firebase/custom_cloud_functions/accept_call.js` повторно проверяет `evaluateTutorAvailabilityWindow()` и `isInCall` для responder перед подтверждением звонка. Это проверка уже выбранного responder; при student-student сценарии ее нельзя оставлять завязанной на legacy student availability.
- Lifecycle decline/expiration: `firebase/custom_cloud_functions/decline_call.js` и `firebase/custom_cloud_functions/process_expired_notifications.js` не вызывают availability-check и не пересобирают пул по `availabilityToday` / `isAvailable`; они выбирают следующего responder из уже сохраненного `availableTutors`.
- Lifecycle cleanup: `firebase/custom_cloud_functions/end_session.js` и `firebase/custom_cloud_functions/cleanup_expired_sessions.js` могут сбрасывать `isAvailable` / `availableAfter`, но это очистка состояния после звонка, не backend-подбор и не availability-check кандидатов.
- `audit/scripts/backend_checks_runner.js`: проверки all-to-all matrix и teacher boost явно создают student-candidate с `availabilityToday.enabled = true`. All-to-all matrix ожидает student-candidate в `availableTutors` и `candidateRoleCounts.student`; teacher boost ожидает student peer в `availableTutors`.
- `firebase/custom_cloud_functions/create_video_session_matrix.test.js`: закрепляет, что роль `student` поддерживается в all-to-all matrix, а teacher-priority сортировка смешивает teachers и students.
- `firebase/custom_cloud_functions/availability.test.js`: закрепляет приоритет `availabilityToday.enabled` над `isAvailable` и fallback на `isAvailable` для legacy profiles.
- `firebase/custom_cloud_functions/direct_call_status.test.js`: закрепляет teacher direct-call status, включая случай, где `availabilityToday.enabled = false` делает target unavailable.
- `firebase/custom_cloud_functions/callable_entitlements.test.js`: закрепляет доступ к callable-функциям и отсутствие live availability fields в response; это contract-тест вокруг прямого звонка, а не проверка student matching.
- `firebase/custom_cloud_functions/user_document_rules.test.js`: защищает live lifecycle fields `isAvailable` / `availableAfter`; `availabilityToday` сейчас не входит в `privateUserLifecycleFields`.
- `firebase/custom_cloud_functions/public_user_profiles.test.js` и `test/regression/voip_call_surface_contracts_test.dart`: закрепляют, что `availabilityToday` и live availability fields не уходят в публичные профили и лишние клиентские поверхности. Менять эти контракты нужно только с учетом teacher flow.

Результат аудита текущего сценария создания звонка:

- `firebase/custom_cloud_functions/create_video_session.js`: `createVideoSession` проверяет requester, доступ студента к звонкам, язык, фильтры и кандидатов, затем создает `videoSessions/{sessionId}` со статусом `searching`, `studentId = requesterId`, `participantIds = [requesterId]`, `availableTutors`, `triedTutors = []`, `studentInfo`, `matchContext`, `expiresAt`, `sessionPolicy` и precreated Daily room, если Daily room создалась.
- `firebase/custom_cloud_functions/create_video_session.js`: после создания session document функция `sendNotificationToNextTutor()` в транзакции выбирает первого кандидата из `availableTutors`, которого нет в `triedTutors`, создает `notifications/{sessionId_recipientId}` с `type = incoming_call`, `status = sent`, `expiresAt = now + 45s`, пишет `currentTutorId = nextTutor`, затем после fresh validation отправляет VoIP/push.
- `firebase/custom_cloud_functions/call_notifications.js`: единый contract входящего звонка использует `recipientId`, `sessionId`, `type = incoming_call`, `status = sent`, `title`, `message`, `createdAt`, `expiresAt`, `studentInfo`; push payload содержит `sessionId`, `studentName`, `studentId`, `studentPhoto`, `language`.
- `firebase/custom_cloud_functions/accept_call.js`: `acceptCall` принимает только назначенного responder: session должна быть `searching`, `currentTutorId` должен совпадать с caller uid, session `expiresAt` не должен быть в прошлом. Для защиты от двойного accept используется lock `acceptingTutorId` / `acceptingAt` на 30 секунд.
- `firebase/custom_cloud_functions/accept_call.js`: после lock функция перечитывает responder/requester, проверяет supported role, teacher approval для `native_speaker`, `evaluateTutorAvailabilityWindow()` и `isInCall`, затем использует precreated Daily room или создает новую комнату и meeting token.
- `firebase/custom_cloud_functions/accept_call.js`: финальная транзакция переводит session в `active`, пишет `tutorId = responderId`, `acceptedAt`, `dailyRoomUrl`, `dailyRoomName`, `expiresAt`, `tutorInfo`, `participantIds = [requesterId, responderId].sort()`, удаляет `currentTutorId`, сбрасывает `studentNavigationTriggered` / `tutorNavigationTriggered` в `false`, пишет `matchContext.acceptedResponderId`, `acceptedResponderRole`, `acceptedResponderInfo`.
- `firebase/custom_cloud_functions/accept_call.js`: при accept server-side выставляет `isInCall = true` и `currentSessionId = sessionId` только responder-документу. Requester в этой функции server-side не лочится через `isInCall/currentSessionId`.
- `firebase/custom_cloud_functions/accept_call.js`: после успешной транзакции отправляет VoIP/push requester-стороне, переводит notification назначенного responder в `accepted`, остальные активные notifications по session переводит в `cancelled`, ответ функции возвращает `status = connected`, `sessionId`, Daily room data, meeting token и `studentInfo`.
- `firebase/custom_cloud_functions/decline_call.js`: `declineCall` доступен supported-role responder и работает только если session `searching` и `currentTutorId` совпадает с caller uid. В транзакции добавляет responder в `triedTutors`, выбирает следующего кандидата из уже сохраненного `availableTutors`, пишет новый `currentTutorId` или статус `no_tutors_available`.
- `firebase/custom_cloud_functions/decline_call.js`: если следующий кандидат найден, в той же транзакции создает новое incoming_call notification и после транзакции отправляет VoIP/push следующему responder. Если кандидатов больше нет, удаляет Daily room и оставляет session в `no_tutors_available`. Старое notification текущего responder после транзакции переводится в `declined`.
- `firebase/custom_cloud_functions/process_expired_notifications.js`: scheduled-функция выбирает `notifications` с `type = incoming_call`, `status = sent`, `expiresAt <= now`. В транзакции переводит notification в `expired`, проверяет session `searching`; stale notification отклоняется только если одновременно есть `currentTutorId`, есть `recipientId`, и они различаются. Если `currentTutorId` отсутствует, timed-out responder берется из `recipientId` notification. Далее responder добавляется в `triedTutors`, выбирается следующий из сохраненного `availableTutors` или ставится session `no_tutors_available`.
- `firebase/custom_cloud_functions/process_expired_notifications.js`: если следующий responder найден, создается новое incoming_call notification, `currentTutorId` переключается на него, затем после fresh validation отправляется VoIP/push. Если следующего нет, Daily room удаляется через `deleteDailyRoomForSession()`.
- Текущий flow не использует `tutorStatuses`. Source of truth для подбора и handoff: `status`, `currentTutorId`, `availableTutors`, `triedTutors`, `notifications.status`, `notifications.expiresAt`, `acceptingTutorId`, `acceptingAt`.
- Persisted statuses в текущем create/accept/decline/expiration flow: `searching`, `active`, `no_tutors_available`; соседние lifecycle-функции пишут `cancelled` и `ended`. `connecting` поддерживается клиентом и cleanup/end paths, но текущий `acceptCall` переводит session сразу из `searching` в `active`. Клиент местами tolerates `connected`; `expired` сейчас используется как notification status и end reason, не как основной `videoSessions.status` в этом flow.
- Legacy naming: `studentId` означает requester, `currentTutorId` / `tutorId` означает responder. Firestore rules дают доступ session participant через `participantIds`, `studentId`, `tutorId`, `currentTutorId`.
- Основные race-защиты: notification создается в той же транзакции, где назначается `currentTutorId`; `createVideoSession` и `processExpiredNotifications` отправляют push только после fresh validation; `acceptCall` повторно проверяет session перед финальным update; `processExpiredNotifications` отклоняет stale notification при конфликте `currentTutorId` и `recipientId`.
- Основные слабые места для новой очереди: следующий responder берется из старого `availableTutors` без повторной availability/queue re-check; `declineCall` отправляет push следующему responder без отдельного fresh reread перед push; requester не получает server-side `isInCall/currentSessionId` в `acceptCall`; `processExpiredNotifications` не учитывает `acceptingTutorId/acceptingAt` во время accept-lock окна; direct `createVideoSession` технически может принять student target, тогда как `getDirectCallStatus` рассчитан на student -> teacher.
- Контрактные и source-contract тесты, которые закрепляют части текущего flow: `firebase/custom_cloud_functions/call_notification_recovery.test.js`, `firebase/custom_cloud_functions/daily_room_lifecycle_contracts.test.js`, `firebase/custom_cloud_functions/session_policy_live_surfaces.test.js`, `firebase/custom_cloud_functions/credential_issuance_contracts.test.js`, `firebase/custom_cloud_functions/create_video_session_matrix.test.js`, `firebase/custom_cloud_functions/direct_call_status.test.js`, `firebase/custom_cloud_functions/callable_entitlements.test.js`, `test/regression/voip_call_surface_contracts_test.dart`, `audit/scripts/backend_checks_runner.js`. Они не полностью покрывают accept lock, decline handoff validation, все `triedTutors` transitions и expiration races.

Результат аудита текущей VoIP-логики:

- `lib/services/voip_service.dart`: `VoIPService` инициализируется после авторизации, регистрирует FCM/PushKit токены через callable `registerVoipToken`, слушает foreground FCM, CallKit events и Firestore `notifications` текущего пользователя.
- `lib/main.dart`: background FCM handler обрабатывает payload `type = incoming_call` и вызывает `showIncomingCall`; инициализация и остановка VoIP привязаны к auth state. При `resumed` приложение обновляет auth/presence, но не делает отдельный VoIP recovery.
- `ios/Runner/AppDelegate.swift`: closed-state iOS обрабатывается через PushKit. Payload приводит `sessionId` к детерминированному `callKitId`, показывает native CallKit UI и завершает PushKit completion с fallback-таймером. Дальнейшие accept/decline события обрабатываются Dart-слоем через `FlutterCallkitIncoming.onEvent` после старта приложения и auth-init.
- `android/app/src/main/AndroidManifest.xml` и `android/app/src/main/kotlin/com/example/my_project/MainActivity.kt`: на Android нет отдельной native `ConnectionService` или кастомной обработки accept/recovery из `MainActivity`; background/closed-state сценарий опирается на FCM background handler, `flutter_callkit_incoming` и последующую Dart-обработку.
- `showIncomingCall`: показывает системный входящий звонок на 45 секунд, сохраняет соответствие `sessionId -> callKitId`, передает в `extra` `sessionId`, `callKitId`, `callerId`, room data и token data, если они есть в payload.
- Stale/duplicate защита CallKit: accept допускает deterministic cold-start event без заранее известного in-memory session state, затем применяет dedupe/stale-check по `callKitId`; decline, timeout и end строже отсекают устаревшие, protected и неизвестные session events.
- Firestore fallback входящего звонка: query читает `notifications` только по `recipientId = currentUser`; `type = incoming_call`, `status = sent`, неистекший `expiresAt` и наличие `sessionId` проверяются локально. Затем listener валидирует, что `videoSessions/{sessionId}` находится в `searching` и `currentTutorId = currentUser`.
- Backend payload для responder стороны из `create_video_session.js`, `decline_call.js` и `process_expired_notifications.js` содержит `type`, `sessionId`, `callerName`, `callerId`, `callerPhoto`, `language` без room data. Backend payload для requester стороны из `accept_call.js` содержит `roomUrl`, `roomName` и поле `meetingToken`, но сейчас отправляет `meetingToken = ""`; fresh token добирается через `getSessionTokens`. Background FCM handler в `lib/main.dart` прокидывает в `extraData` `roomUrl` и `meetingToken`, но не `roomName`.
- `accept` на клиенте определяет роль по payload: если есть `roomUrl` или `meetingToken`, пользователь считается requester side, клиент не вызывает `acceptCall`, сохраняет room data, открывает `/videoCallPage` и fire-and-forget пишет `studentNavigationTriggered = true`.
- `accept` responder side выполняет stale/duplicate guards, проверяет camera/mic permissions, вызывает callable `acceptCall`, ждет ответ `status = connected`, сохраняет room data, открывает `/videoCallPage` и fire-and-forget пишет `tutorNavigationTriggered = true`.
- Если camera/mic permission отклонен на CallKit accept, клиент завершает текущий системный звонок и чистит локальное состояние, но не вызывает `declineCall` или `endSession`; backend завершает попытку через notification timeout и scheduled cleanup.
- `decline` выполняет stale/protected/unknown guards, очищает локальное состояние CallKit и вызывает callable `declineCall({ sessionId })`.
- `timeout` выполняет stale/protected/unknown guards и очищает только локальное состояние CallKit. Backend timeout обрабатывается отдельно scheduled-функцией `processExpiredNotifications`.
- `actionCallEnded` вызывает `endSession` только если есть локально известный room url или fallback-проверка подтверждает, что текущий пользователь совпадает с `studentId` или `tutorId` активной/connecting/connected session. `participantIds` в этой fallback-проверке не используется.
- Навигация из VoIP идет прямым переходом на `/videoCallPage` с `videoDocRef`, `roomUrl`, `roomName`, `meetingToken`. Если navigator context еще не готов, session кладется в `_pendingSessionId` и повторяется до 10 раз с задержкой 100 мс.
- Дополнительное восстановление навигации есть в `lib/custom_code/actions/check_active_session_and_navigate.dart`: action ищет session по `studentNavigationTriggered` или `tutorNavigationTriggered`, сбрасывает флаг и открывает `VideoCallPage`.
- `lib/custom_code/actions/start_student_session_listener.dart` содержит legacy action для прослушивания конкретной session и навигации студента при `active`/`connected`, `studentNavigationTriggered` или наличии room data; прямых call-site в `lib/` для него не найдено.
- Экран ожидания `lib/students_pages/waiting_for_teacher_page/waiting_for_teacher_page_widget.dart` слушает session и открывает звонок только когда есть `dailyRoomUrl` и session уже `active`/`connected` или выставлен `studentNavigationTriggered`; перед навигацией получает fresh token через `getSessionTokens`.
- `lib/shared_pages/video_call_page/video_call_page_widget.dart` использует переданные room/token без немедленного повторного получения, если они есть; иначе получает credentials через `getSessionTokens`. Это важно для token strategy: requester push сейчас приходит с `meetingToken = ""`, а рабочий token получается через `getSessionTokens`. При terminal session status страница завершает системный CallKit UI и ведет пользователя на summary.
- VoIP tokens хранятся в приватной коллекции через `firebase/custom_cloud_functions/voip_tokens.js`; если push/VoIP token отсутствует, backend не доставит системный входящий звонок, а Firestore listener сработает только при открытом приложении.
- Legacy naming в VoIP flow: `studentId` означает requester, `currentTutorId` / `tutorId` означает responder. Для новой очереди эти названия нужно заменить или закрыть нейтральными полями `requesterId`, `responderId`, `currentResponderId`, не ломая существующие rules и клиентские fallback-и.
- Проблемные места для новой очереди: роль accept-ветки сейчас выводится из наличия room data, а не из явного сценария; payload не содержит `scenario`, `requesterId`, `responderId`, `requesterRole`, `responderRole`, `navRole`, `acceptMode`, `callKitId`, `notificationId` / `searchRequestId`, `expiresAt`, `tokenStrategy`; client timeout и backend expiration живут отдельно; requester не лочится server-side через `isInCall/currentSessionId` при accept; `studentNavigationTriggered` и `tutorNavigationTriggered` завязаны на старые роли.
- Контрактные тесты, которые закрепляют VoIP-поведение: `test/regression/voip_call_surface_contracts_test.dart`, `firebase/custom_cloud_functions/call_notification_recovery.test.js`, `firebase/custom_cloud_functions/voip_token_privacy_contracts.test.js`, `firebase/custom_cloud_functions/callable_entitlements.test.js`, `firebase/custom_cloud_functions/credential_issuance_contracts.test.js`, `firebase/custom_cloud_functions/mark_session_connected.test.js`, `firebase/custom_cloud_functions/session_policy_live_surfaces.test.js`, `firebase/custom_cloud_functions/daily_room_lifecycle_contracts.test.js`, `firebase/custom_cloud_functions/create_video_session_matrix.test.js`, `firebase/custom_cloud_functions/direct_call_status.test.js`.

Результат аудита текущих статусов и полей `videoSessions`:

- Persisted `videoSessions.status`, которые сейчас пишутся основным backend lifecycle: `searching`, `active`, `no_tutors_available`, `cancelled`, `ended`.
- `searching`: создается в `createVideoSession`; означает созданную session с requester в `participantIds`, пулом `availableTutors`, списком `triedTutors` и текущим назначенным responder в `currentTutorId`.
- `active`: пишется в `acceptCall` после подтверждения responder; это persisted статус активной/joinable session. `acceptCall` при этом возвращает клиенту response `status = connected`, но не пишет `videoSessions.status = connected`.
- `no_tutors_available`: persisted write появляется только когда session уже создана и handoff больше не находит кандидатов. В ранних ветках `createVideoSession`, где кандидатов нет до создания session document, это callable response без persisted `videoSessions` doc.
- `cancelled`: пишется `cancelCall` для отмены requester-side session в статусах `searching` или `connecting`; также используется для notification cancellation и conversation outcome, но notification status не является `videoSessions.status`.
- `ended`: пишется `endSession` и `cleanupExpiredSessions`; используется как основной terminal status состоявшегося или истекшего активного звонка.
- `connecting`: перечислен в `VideoSessionsRecord`, поддержан клиентом, `endSession`, `cleanupExpiredSessions`, `getSessionTokens`, `markSessionConnected`, `requestSessionExtension` и session limit UI, но текущий `acceptCall` переводит session сразу из `searching` в `active`.
- `connected`: не должен считаться persisted статусом текущего backend. Клиент местами tolerates `connected` для старых поверхностей и callable response, но credential/joinability helpers принимают только `active` и `connecting`.
- `expired`: сейчас используется как `notifications.status`, `endReason` и metadata cleanup signal; основной backend flow не пишет `videoSessions.status = expired`.
- Соседние статусы нельзя смешивать с `videoSessions.status`: `notifications.status` использует `sent`, `accepted`, `declined`, `cancelled`, `expired`; callable responses используют отдельные статусы, включая `connected`, `declined`, `ok`, `already_ended`, `ignored_expired_end`, `signal_recorded`, `already_marked`, `marked`, `daily_presence_not_verified`, `pending_partner`, `approved`, `already_requested`, `already_extended`.
- Typed Dart schema `lib/backend/schema/video_sessions_record.dart` читает поля: `language`, `createdAt`, `startedAt`, `endedAt`, `duration`, `status`, `tutorId`, `studentId`, `participantIds`, `dailyRoomUrl`, `meetingToken`, `dailyRoomName`, `expiresAt`, `currentTutorId`, `triedTutors`, `availableTutors`, `studentInfo`, `acceptedAt`, `tutorInfo`, `version`, `platform`, `earnings`, `studentHasReviewed`, `tutorHasReviewed`, `studentReviewRef`, `tutorReviewRef`.
- Backend create/search поля: `studentId`, `participantIds`, `language`, `status`, `createdAt`, `expiresAt`, `sessionPolicy`, `studentPreferences.country`, `triedTutors`, `availableTutors`, `studentInfo`, `matchContext`, `studentHasReviewed`, `tutorHasReviewed`, `dailyRoomUrl`, `dailyRoomName`, `sessionMetadata.roomCreatedAt`, `sessionMetadata.dailyRoomConfigVersion`, `tutorInfo` для direct target.
- `matchContext` уже используется как место для нейтральной информации: `requesterId`, `requesterRole`, `requestedLanguage`, `requestedLanguageSource`, `directCandidateId`, `requesterProfile`, `filters`, `ranking`, `candidatePoolSize`, `candidateIds`, `candidateRoleCounts`, `acceptedResponderId`, `acceptedResponderRole`, `acceptedResponderInfo`, `teacherEarningUserId`, payout flags и completed pair history refs.
- Accept/lifecycle поля: `currentTutorId`, `acceptingTutorId`, `acceptingAt`, `tutorId`, `acceptedAt`, `dailyRoomUrl`, `dailyRoomName`, `expiresAt`, `tutorInfo`, `participantIds`, `sessionPolicy`, `studentNavigationTriggered`, `tutorNavigationTriggered`, `navigationTimestamp`, `navigationCompletedAt`.
- Cancel/end поля: `endedAt`, `cancelledAt`, `cancelledBy`, `cancelReason`, `duration`, `durationMinutes`, `freeMinuteApplied`, `chargedParticipantIds`, `subscriptionCoveredParticipantIds`, `sessionMetadata.endReason`, `sessionMetadata.endedAtTimestamp`, `sessionMetadata.finalDuration`.
- Credential/joinability contract: `getSessionTokens`, `getDeepgramToken`, `markSessionConnected` и `daily_webhook` требуют `status` `active` или `connecting`, неистекший `expiresAt` и accepted participant model через `participantIds`, `studentId`, `tutorId` или `matchContext.acceptedResponderId`; `currentTutorId` не считается принятым responder для выдачи credentials. `daily_webhook` проверяет expiry относительно Daily event time (`joined_at` / `event_ts`). `requestSessionExtension` тоже требует `active` или `connecting` и неистекший `expiresAt`, но participant check идет через `isSessionParticipant()` / `getSessionParticipantIds()`, где fallback включает `currentTutorId`.
- Daily/connection proof поля: `startedAt`, `sessionMetadata.callConnectedAt`, legacy fallback `sessionMetadata.callConnectedAtTimestamp`, `sessionMetadata.callConnectedAtSource`, `sessionMetadata.callConnectedBy`, `sessionMetadata.callConnectedSignalParticipantIds`, `sessionMetadata.connectedParticipantSignals`, `sessionMetadata.connectedParticipantSignalsComplete`, `sessionMetadata.dailyPresenceVerifiedAt`, `sessionMetadata.dailyPresenceConnectedParticipantIds`, `sessionMetadata.dailyPresenceRoomName`, `sessionMetadata.dailyWebhookParticipantSignals`, `sessionMetadata.dailyWebhookLastEventId`, `sessionMetadata.dailyWebhookLastEventType`, `sessionMetadata.dailyWebhookLastEventAt`, `sessionMetadata.dailyWebhookRoomName`, `sessionMetadata.dailyWebhookConnectedAt`, `sessionMetadata.dailyWebhookConnectedParticipantIds`, `sessionMetadata.dailyWebhookConnectedEventIds`.
- Daily room cleanup поля в `sessionMetadata`: `dailyRoomDeleteSource`, `dailyRoomDeleteRoomName`, `dailyRoomDeleteAttemptedAt`, `dailyRoomDeletedAt`, `dailyRoomDeleteFailedAt`, `dailyRoomDeleteError`, `dailyRoomDeleteSkippedAt`.
- Review fields: `studentHasReviewed`, `tutorHasReviewed`, `studentReviewRef`, `tutorReviewRef` пишутся backend `submitReview`, client helper `syncSessionReviewState` и backfill script. `REVIEWABLE_SESSION_STATUSES` применяется к fallback-поиску recent mutual session и включает `connected`, `connecting`, `active`, `ended`, `cancelled`, `completed`; прямой `submitReview` по `sessionId` / `sessionPath` опирается на participant validation, а не на этот список статусов.
- Caption logs находятся под `videoSessions/{sessionId}/captionLogs/{logId}` и зависят от session membership через `participantIds`, `studentId`, `tutorId`, `currentTutorId`.
- Security rules: client не может создавать или удалять `videoSessions`; read разрешен session participant через `participantIds`, `studentId`, `tutorId`, `currentTutorId`; update разрешен admin или client-only navigation update строго по `studentNavigationTriggered`, `tutorNavigationTriggered`, `navigationTimestamp`, `navigationCompletedAt`. `studentNavigationTriggered` может менять только requester через `studentId`; `tutorNavigationTriggered` может менять responder через `tutorId` / `currentTutorId` или non-requester participant через `participantIds`.
- Flutter navigation consumers: `VoIPService`, `checkActiveSessionAndNavigate`, `start_student_session_listener` и waiting page читают `status`, `studentId`, `tutorId`, `currentTutorId`, `dailyRoomUrl`, `dailyRoomName`, `studentNavigationTriggered`, `tutorNavigationTriggered`. `start_student_session_listener` также читает legacy `studentMeetingToken`; backend writer для этого поля в текущем flow не найден.
- `VideoCallPage` читает `dailyRoomUrl`, `dailyRoomName`, `language`, `status`, `expiresAt`, `studentId`, `sessionPolicy`, `sessionMetadata.callConnectedAt`, `startedAt`, `duration`; при `ended` или `cancelled` завершает системный звонок и открывает summary.
- `MinimalDailyWidget` и session limit UI используют `status`, `expiresAt`, `sessionPolicy`; countdown и auto-end включаются только для `active` и `connecting`.
- `MyCalls` читает историю через `participantIds arrayContains` и фильтрует `status == ended`; legacy helper `fetchRecentHubCallSessions` отдельно ищет через `studentId`, `tutorId`, `currentTutorId` и тоже фильтрует `status == ended`.
- История звонков и детали звонка используют `studentId`, `tutorId`, `currentTutorId`, `participantIds`, `studentInfo`, `tutorInfo`, `matchContext.acceptedResponderInfo`, `startedAt`, `createdAt`, `endedAt`, `duration`, `sessionMetadata.callConnectedAt`. Review flags и review refs читаются схемой и синхронизируются helper/backend, но call details UI строит состояние отзыва через pair review flow.
- Backend shared helpers уже частично поддерживают нейтральную модель: `getRequesterId()` читает `studentId`, `matchContext.requesterId`, `requesterId`; `getAssignedResponderId()` читает `tutorId`, `currentTutorId`, `matchContext.acceptedResponderId`; `getSessionParticipantIds()` сначала читает `participantIds`, затем fallback на requester/responder.
- Chat unlock и repeat prevention используют `getUnlockParticipants()` из `chats_shared`: сейчас source of truth для пары там legacy-only `studentId + tutorId/currentTutorId`; `participantIds` и нейтральные поля не являются источником пары для unlock/repeat history.
- Важные ограничения для новой очереди: при создании `participantIds` сейчас содержит только requester; responder добавляется после accept, поэтому `array-contains` не найдет назначенного responder в `searching` session. `startedAt` сам по себе не считается доказательством состоявшегося звонка; для completed/unlock/repeat history нужен `sessionMetadata.callConnectedAt` или legacy `sessionMetadata.callConnectedAtTimestamp`.
- Контрактные тесты для этих статусов и полей: `test/regression/voip_call_surface_contracts_test.dart`, `test/custom_code/widgets/session_limit_ui_test.dart`, `firebase/custom_cloud_functions/video_sessions_shared.test.js`, `firebase/custom_cloud_functions/mark_session_connected.test.js`, `firebase/custom_cloud_functions/daily_webhook.test.js`, `firebase/custom_cloud_functions/credential_issuance_contracts.test.js`, `firebase/custom_cloud_functions/request_session_extension.test.js`, `firebase/custom_cloud_functions/cleanup_expired_sessions.test.js`, `firebase/custom_cloud_functions/conversation_call_events.test.js`, `firebase/custom_cloud_functions/submit_review.test.js`, `firebase/custom_cloud_functions/create_video_session_matrix.test.js`.

Результат решения по переиспользуемым и новым полям для очереди:

- Новую очередь поиска нужно хранить отдельно от `videoSessions`, в коллекции `searchRequests/{uid}`. `videoSessions.status = searching` остается статусом созданной session, а не статусом активной очереди.
- В `users` можно переиспользовать: `role`, `learningLanguage`, `language_instruction_NS`, `matchProfile.supportedLanguages`, `matchProfile.activeLanguage`, `level`, `matchProfile.level`, `Country_NS`, `matchProfile.country`, `profileCity`, `blockedUsers`, `isInCall`, `currentSessionId`, `subscription`, `giftMinutes`, teacher approval fields `teacherAccreditationStatus`, `verif_NS`, `matchProfile.approvedTeacher`.
- Для проверки доступа к звонкам нужно переиспользовать `users/{uid}/usage/current`: `dayKey`, `dayDurationSeconds`, `weekKey`, `weekDurationSeconds`, `lastUpdatedAt`, а также существующие helpers `readUsage()` и `checkUsageLimits()`.
- `availabilityToday` можно переиспользовать только для учителей вместе с `availableAfter` и legacy fallback `isAvailable`. Для студентов `availabilityToday` и `isAvailable` не используются как признак доступности для новой очереди.
- `userPrivateTokens/{uid}` и helper `getUserVoipTokens()` нужно переиспользовать для проверки, может ли учитель, direct-call target или фоновый пользователь получить системный входящий звонок. Legacy fallback чтения токенов в helper нужно сохранить на время миграции.
- `lastSeenAt` нельзя использовать как heartbeat поиска: presence обновляется с другой частотой и не заменяет server-side `heartbeatAt` для таймаутов 30/90 секунд.
- `queuePriority` нельзя использовать как время ожидания новой очереди: сортировка ожидания должна идти от `searchRequests.createdAt` / `heartbeatAt` и стабильного tie-breaker.
- В `videoSessions` можно переиспользовать: `status`, `language`, `createdAt`, `expiresAt`, `participantIds`, `dailyRoomUrl`, `dailyRoomName`, `sessionPolicy`, `sessionMetadata`, `acceptedAt`, `startedAt`, `endedAt`, `duration`, review flags и review refs.
- `matchContext` нужно переиспользовать как snapshot для аудита, фильтров, ranking и accepted responder info. `matchContext` не должен быть live-state очереди.
- Legacy-поля `studentId`, `currentTutorId`, `tutorId`, `studentInfo`, `tutorInfo`, `studentNavigationTriggered`, `tutorNavigationTriggered` нужно временно продолжать писать для совместимости с текущими rules, историей, VoIP fallback и навигацией.
- Legacy-поля `studentId`, `currentTutorId`, `tutorId` нельзя использовать как основной контракт новой очереди: для student-student сценария нужны нейтральные поля requester/responder.
- `availableTutors` и `triedTutors` нельзя использовать как основной источник кандидатов новой очереди: это snapshot старого подбора без повторной проверки queue, availability и свежих токенов. Для новой очереди кандидатный пул должен пересобираться или валидироваться заново на каждой попытке.
- `studentNavigationTriggered` и `tutorNavigationTriggered` нельзя расширять как долгосрочный нейтральный контракт. Для новой модели нужно добавить навигационное состояние по userId.
- `notifications` можно переиспользовать как Firestore fallback входящего звонка: `type = incoming_call`, `status`, `recipientId`, `sessionId`, `createdAt`, `expiresAt`, `acceptedAt`. Payload нужно сделать нейтральным; `studentInfo`, `studentId`, `studentName` не должны быть основными именами для caller/peer.
- Для `searchRequests/{uid}` нужно добавить поля: `userId`, `userRef`, `role`, `status`, `language`, `filters.preferredLevel`, `filters.levelRank`, `filters.countryCode`, `filters.cityKey`, `createdAt`, `updatedAt`, `heartbeatAt`, `expiresAt`, `backgroundExpiresAt`, `appState`, `appStateUpdatedAt`.
- Для `searchRequests/{uid}` нужно добавить lifecycle/lock поля: `currentSessionId`, `matchedUserId`, `matchedRole`, `pairAttemptId`, `excludedCandidateIds`, `attemptExcludedCandidateIds`, `lockOwner`, `lockExpiresAt`, `version`, `stopReason`, `stoppedAt`, `lastError`.
- Статусы `searchRequests.status`: `active`, `matching`, `matched`, `stopped`, `expired`, `cancelled`, `error`. Эти статусы не показываются пользователю напрямую и маппятся в продуктовые состояния UI.
- Для `videoSessions` нужно добавить нейтральные поля: `scenario`, `requesterId`, `requesterRole`, `currentResponderId`, `currentResponderRole`, `responderId`, `responderRole`, `participantRoles`, `participantInfos`, `searchRequestIds`, `pairAttemptId`.
- Для lifecycle session нужно добавить: `responseExpiresAt`, `joinDeadlineAt`, `confirmedParticipantIds`, `declinedBy`, `noAnswerUserId`, `joinedParticipantIds`, `participantJoinState`.
- Статусы `videoSessions.status` для новой логики: `searching` пишет matcher после атомарного lock пары и создания session; `pending_confirmation` пишет backend после отправки входящего звонка/notification; `connecting` пишет backend после accept и выдачи room credentials; `active` пишет backend после подтвержденного входа участников в комнату; `cancelled` пишет backend при decline, stop, logout или media denied до активного звонка; `expired` пишет cleanup при response/join/search timeout; `ended` пишет backend после завершения активного звонка. Клиент не пишет lifecycle-статусы напрямую.
- Таймауты новой логики: heartbeat активного поиска обновляется каждые 30 секунд, заявка считается stale после 90 секунд без heartbeat, `searchRequests.expiresAt` ставится на 10 минут активного поиска, `backgroundExpiresAt` ставится на 10 минут после ухода приложения в background, `responseExpiresAt` ставится на 45 секунд для ответа на входящий звонок, `joinDeadlineAt` ставится на 60 секунд после accept для входа в комнату.
- Для navigation recovery нужно добавить `navigationByUserId.{uid}` с состоянием перехода конкретного участника. Legacy flags `studentNavigationTriggered` / `tutorNavigationTriggered` остаются только как временная совместимость.
- Для VoIP/notification/push payload нужно добавить единый контракт: `payloadVersion`, `scenario`, `notificationId`, `callKitId`, `sessionId`, `searchRequestId`, `pairAttemptId`, `requesterId`, `responderId`, `requesterRole`, `responderRole`, `navRole`, `acceptMode`, `tokenStrategy`, `callerInfo`, `peerInfo`, `expiresAt`, `roomUrl`, `roomName`.
- FCM `data` payload должен быть string-only: даты передаются ISO string или millis string, `callerInfo` и `peerInfo` сериализуются как JSON string, `roomName` передается обязательно при наличии комнаты. Legacy ключи `studentId`, `studentName`, `callerId`, `callerName` временно сохраняются до миграции старых клиентов.
- Один и тот же payload contract должен использоваться в foreground FCM, background FCM, iOS PushKit, Android и Firestore notification fallback. `roomName` не должен теряться в background handler.
- Direct-call конкретному учителю остается отдельным сценарием `direct_student_teacher` и не создает активную заявку в общей очереди.
- `createVideoSession` остается API только для direct-call сценария `direct_student_teacher`; direct-call на student target должен возвращать reject/error. Общая очередь не вызывает `createVideoSession` напрямую и работает через новые callable/scheduled endpoints.
- API новой очереди: `startSearch` создает или возвращает текущий активный `searchRequests/{uid}`; `stopSearch` останавливает поиск и очищает locks; `heartbeatSearch` обновляет `heartbeatAt`, `appState`, `backgroundExpiresAt`; matcher создает pair attempt и session; cleanup закрывает stale/expired requests и sessions. Все endpoints возвращают `status`, `searchRequestId`, `sessionId`, `pairAttemptId`, `expiresAt`, `errorCode` при ошибке. Повторный вызов с тем же активным состоянием должен быть идемпотентным.
- При создании пары нужно атомарно лочить обоих участников через search request lock и user call lock, чтобы один пользователь не попал в две пары.
- `startSearch` должен быть идемпотентным: у одного студента может быть только один активный `searchRequests/{uid}`.
- `stopSearch`, logout, истекший доступ, активный звонок и media denied после match должны атомарно убирать заявку из очереди.
- Подбор идет из общего пула без приоритета роли: сначала фильтруются доступные кандидаты по языку, доступу, blocklist, `isInCall`, teacher approval/availability/tokens, затем ранжирование идет по exact level, adjacent level, country/city match, waiting time, stable tie-breaker по requestId/userId.
- `excludedCandidateIds` хранит кандидатов, исключенных до завершения текущего search lifecycle и сбрасывается при новом `startSearch` после `stopSearch`/expiry. `attemptExcludedCandidateIds` хранит исключения только внутри текущего `pairAttemptId` и сбрасывается при новой pair attempt. Teacher decline/timeout добавляет учителя в exclusions и возвращает студента в поиск; student-student decline/timeout удаляет неответившего студента из очереди, а второго возвращает в active search с новым `pairAttemptId`.
- Decline/timeout учителя исключает только этого учителя из текущей попытки и не завершает поиск студента. Decline/timeout студента в student-student сценарии удаляет неответившего студента из очереди и возвращает второго в активный поиск.
- Accept после timeout, cleanup или смены `pairAttemptId` должен быть stale-safe и не должен открывать устаревшую session.
- Neutral lifecycle migration должна затронуть `cancelCall`, `endSession`, `getSessionTokens`, `getDeepgramToken`, `markSessionConnected`, `daily_webhook`, `requestSessionExtension`, `VoIPService` fallback/recovery и typed records. Эти поверхности должны читать нейтральные поля и сохранять legacy mirror-поля до завершения миграции.
- Typed records/structs нужно обновить: добавить `SearchRequestsRecord`, нейтральные поля в `VideoSessionsRecord` и `NotificationsRecord`, response structs для `startSearch`, `stopSearch`, `heartbeatSearch`, accept/tokens/navigation recovery. Legacy mirror-поля остаются только как временная совместимость.
- Firestore rules нужно расширить под `searchRequests`, `currentResponderId`, нейтральные participant поля и `navigationByUserId`; текущие rules знают только `participantIds`, `studentId`, `tutorId`, `currentTutorId` и старые navigation flags.
- Rules для `searchRequests/{uid}`: пользователь может делать `get` только своего документа, `list` запрещен клиентам, candidate listing доступен только backend/admin, создание/изменение/удаление выполняется через callable backend. Поля lock/match/result (`lockOwner`, `lockExpiresAt`, `matchedUserId`, `matchedRole`, `pairAttemptId`, `currentSessionId`, `excludedCandidateIds`, `attemptExcludedCandidateIds`, `stopReason`, `lastError`) являются server-owned.
- Rules для `navigationByUserId`: participant может обновлять только собственную navigation-запись и только разрешенные поля состояния навигации; server-owned поля session lifecycle, participants, locks и room credentials клиентом не меняются.
- Для `searchRequests` нужны индексы под подбор и cleanup: `status + language`, `status + language + createdAt`, `status + language + filters.levelRank + createdAt`, `status + language + filters.countryCode + filters.cityKey + filters.levelRank + createdAt`, `status + appState + backgroundExpiresAt`, `status + heartbeatAt`, `status + expiresAt`, `status + lockExpiresAt`, `expiresAt`, а также индексы под city/country filters при их включении.
- Контрактные тесты для этого решения: `startSearch`, `stopSearch`, `heartbeatSearch`, cleanup 90 секунд, 10 минут foreground/background expiry, 45 секунд response timeout, 60 секунд join timeout, ranking без role priority, exact/adjacent level matching, country/city matching, blocklists, repeat prevention, `isInCall`, teacher approval, teacher token for queue and direct-call, direct `createVideoSession` reject student target, double-match races, stale accept, accept during accept-lock, payload parity, FCM string serialization, `searchRequests` indexes/rules, neutral `videoSessions` rules, neutral cancel/end/credentials/join rules, `create_video_session_matrix.test.js`, `direct_call_status.test.js`, `call_notification_recovery.test.js`, `voip_call_surface_contracts_test.dart`, `user_document_rules.test.js`, `public_user_profiles.test.js`, `dashboard_component_contract_test.dart`.

Критерий завершения: понятно, какие файлы и функции будут изменяться на backend и frontend.

## Этап 2. Удаление пассивной доступности у студентов

Цель этапа: студент больше не должен быть доступен для звонка без активного поиска.

- [x] Убрать из студенческого дашборда переключатель "Доступен сегодня".
- [x] Убрать из студенческого интерфейса расписание доступности.
- [x] Убрать возможность менять `availabilityToday` из студентского интерфейса.
- [x] Оставить `availabilityToday` только для учителей.
- [x] Обновить проверки и компоненты, которые ожидают наличие student availability UI.
- [x] Проверить, что учительский интерфейс доступности не изменился.

Критерий завершения: студент не видит и не меняет доступность, учительская доступность работает как раньше.

## Этап 3. Клиентская логика кнопки "Начать поиск"

Цель этапа: студент может запускать и останавливать активный поиск.

- [x] Добавить кнопку "Начать поиск" в студенческий интерфейс.
- [x] Добавить состояние "Остановить поиск" после запуска поиска.
- [x] Добавить экран или блок "Ищем собеседника".
- [x] Добавить состояние "Соединяем".
- [x] Добавить состояние "Пока никого не нашли" после 10 минут без пары.
- [x] Добавить обработку ошибок поиска.
- [x] Добавить проверку доступа перед стартом поиска: авторизация, подписка, лимиты, активный звонок, камера и микрофон.
- [x] При ручной остановке поиска вызывать backend-остановку активной заявки.

Критерий завершения: студент управляет поиском через одну основную кнопку и видит корректное состояние поиска.

## Этап 4. Backend: очередь активного поиска

Цель этапа: создать серверную очередь активных студентов.

- [x] Создать структуру активной заявки поиска.
- [x] Реализовать backend-функцию `startSearch`.
- [x] Реализовать backend-функцию `stopSearch`.
- [x] Реализовать backend-функцию `heartbeatSearch`.
- [x] Сохранять в заявке пользователя, язык, фильтры, статус, `createdAt`, `heartbeatAt`, `expiresAt`, состояние приложения.
- [x] Обновлять heartbeat каждые 30 секунд с клиента.
- [x] Удалять или помечать неактивной заявку при отсутствии heartbeat 90 секунд.
- [x] Останавливать поиск через 10 минут без найденной пары.
- [x] Останавливать поиск в фоне через 10 минут.
- [x] Гарантировать, что у одного студента может быть только одна активная заявка.

Критерий завершения: backend надежно создает, продлевает, останавливает и очищает заявки поиска.

## Этап 5. Backend: единый пул кандидатов

Цель этапа: подбирать кандидатов из студентов и учителей без приоритета роли.

- [x] Собрать единый пул кандидатов: активные студенты из очереди и доступные учителя.
- [x] Для студентов проверять активную заявку поиска.
- [x] Для учителей проверять расписание доступности.
- [x] Исключать учителей без активного VoIP/push токена.
- [x] Проверять язык звонка.
- [x] Проверять уровень языка: сначала точное совпадение, затем ближайший уровень на один шаг выше или ниже.
- [x] Проверять страну или город, если фильтр выбран.
- [x] Проверять блокировки в обе стороны.
- [x] Проверять `isInCall`.
- [x] Проверять право пользователя участвовать в звонке.
- [x] Проверять защиту от повторного подбора.
- [x] Отсортировать кандидатов по качеству совпадения фильтров и времени ожидания.
- [x] Исключить приоритет роли кандидата из алгоритма.

Критерий завершения: лучший кандидат выбирается по фильтрам и доступности, а не по роли.

## Этап 6. Backend: создание пары и статусы сессии

Цель этапа: безопасно создавать пару и не допускать двойных звонков.

- [x] Реализовать атомарную блокировку двух участников при создании пары.
- [x] Создавать `videoSession` для student-student.
- [x] Создавать или переиспользовать `videoSession` для student-teacher.
- [x] Поддержать статусы `searching`, `pending_confirmation`, `connecting`, `active`, `cancelled`, `expired`, `ended`.
- [x] Переводить заявки поиска в состояние найденной пары.
- [x] Помечать участников как находящихся в звонке после подтверждения.
- [x] Снимать участников с активного поиска после начала звонка.
- [x] Возвращать второго участника в поиск, если пара сорвалась до начала звонка.
- [x] Защитить сценарии от гонок при одновременном поиске нескольких пользователей.

Критерий завершения: один пользователь не может попасть в два звонка, статусы управляются backend.

## Этап 7. Student-to-student сценарий

Цель этапа: соединять двух активных студентов.

- [x] При найденной паре student-student создать общую сессию.
- [x] Если оба студента в открытом приложении, автоматически открыть страницу звонка у обоих.
- [x] Если один студент в фоне, отправить ему системный входящий звонок.
- [x] Обработать accept входящего звонка.
- [x] Обработать decline входящего звонка.
- [x] Обработать timeout 45 секунд без ответа.
- [x] При отказе или timeout удалить неответившего студента из очереди.
- [x] Вернуть второго студента в активный поиск.

Критерий завершения: два студента соединяются автоматически или корректно расходятся при отказе/таймауте.

## Этап 8. Student-to-teacher сценарий

Цель этапа: соединять студента с доступным учителем из общего пула.

- [x] При выборе учителя отправлять ему системный входящий звонок.
- [x] Оставлять студента на экране ожидания соединения.
- [x] При accept учителя переводить обоих участников на страницу звонка.
- [x] При decline учителя исключать его из текущей попытки.
- [x] При timeout 45 секунд исключать учителя из текущей попытки.
- [x] После отказа или timeout продолжать подбор по общему пулу.
- [x] Не давать роли следующего кандидата отдельный приоритет.

Критерий завершения: учитель подключается через входящий звонок, отказ не завершает весь поиск студента.

## Этап 9. Direct-call конкретному учителю

Цель этапа: сохранить прямой звонок учителю отдельно от общей очереди.

- [x] Оставить прямой звонок из профиля учителя отдельным сценарием.
- [x] Не добавлять direct-call в общую очередь поиска.
- [x] Проверять доступность учителя по расписанию.
- [x] Проверять активный VoIP/push токен учителя.
- [x] Проверять блокировки, `isInCall` и базовые права доступа.
- [x] При accept открывать страницу звонка у студента и учителя.
- [x] При decline или timeout завершать direct-call без автоперехода в общий поиск.

Критерий завершения: прямой звонок работает отдельно и не влияет на очередь поиска.

## Этап 10. VoIP, фон и закрытое приложение

Цель этапа: корректно обработать звонки вне открытого приложения.

- [x] Проверить отправку VoIP/CallKit/ConnectionService для учителей.
- [x] Добавить отправку VoIP/CallKit/ConnectionService для фонового студента.
- [x] Передавать в payload `sessionId`, имя собеседника, `scenario`, `requesterId`, `responderId`, `requesterRole`, `responderRole`, `navRole`, `acceptMode`, `callKitId`, `notificationId` или `searchRequestId`, `expiresAt`, `roomUrl`, `roomName` и `tokenStrategy`.
- [x] Синхронизировать payload parity между foreground FCM, background FCM, iOS PushKit и Android: backend `roomName` не должен теряться в background handler.
- [x] Обработать accept из foreground.
- [x] Обработать accept из background.
- [x] Обработать accept из закрытого приложения.
- [x] Обработать accept/decline, если CallKit event пришел до готовности auth, router или `VoIPService.initialize()`.
- [x] Обработать decline.
- [x] Обработать timeout 45 секунд.
- [x] Проверить, что после accept приложение открывает страницу звонка.
- [x] Проверить, что после decline/timeout backend отменяет пару или продолжает подбор.
- [x] Добавить тесты на closed-state/auth/router recovery для accept и decline.

Критерий завершения: входящий звонок работает в foreground, background, locked screen и closed-state сценариях.

## Этап 11. Вход в комнату звонка и таймаут 60 секунд

Цель этапа: отменять пару, если один участник подтвердил звонок, но не вошел в комнату.

- [x] Фиксировать факт входа каждого участника в комнату звонка.
- [x] Запускать таймаут 60 секунд после подтверждения пары.
- [x] Если оба вошли в комнату за 60 секунд, переводить сессию в `active`.
- [x] Если один участник не вошел, отменять пару.
- [x] Возвращать ожидавшего участника в активный поиск.
- [x] Снимать `isInCall` с участников при отмене до старта звонка.

Критерий завершения: зависшие соединения не оставляют пользователя в подвешенном состоянии.

## Этап 12. Восстановление состояния

Цель этапа: приложение корректно восстанавливает экран после перезапуска.

- [x] При старте приложения проверять активный поиск пользователя.
- [x] При активном поиске открывать состояние поиска.
- [x] При `pending_confirmation` или `connecting` открывать экран соединения.
- [x] При `active` открывать страницу звонка.
- [x] Восстанавливать звонок по `participantIds` и нейтральным полям `requesterId` / `responderId` / `currentResponderId`, а не только по legacy `studentId` / `tutorId` и `studentNavigationTriggered` / `tutorNavigationTriggered`.
- [x] При истекшем поиске показывать обычное состояние без активного поиска.
- [x] При завершенном или отмененном звонке не возвращать пользователя в очередь автоматически.

Критерий завершения: после перезапуска пользователь видит актуальное состояние, а не устаревший экран.

## Этап 13. Завершение звонка и очистка состояний

Цель этапа: после звонка все временные состояния должны быть очищены.

- [x] При завершении звонка удалять обеих участников из активного поиска.
- [x] Снимать `isInCall` с обоих участников.
- [x] Переводить сессию в `ended`.
- [x] Открывать стандартный экран завершения или оценки звонка.
- [x] Не запускать повторный поиск автоматически.
- [x] Проверить cleanup для отмененных и истекших сессий.

Критерий завершения: после звонка пользователь не остается в очереди и не считается занятым.

## Этап 14. Тесты backend

Цель этапа: покрыть критичные правила подбора и таймаутов.

- [x] Тест `startSearch`: создается одна активная заявка.
- [x] Тест `stopSearch`: заявка останавливается.
- [x] Тест `heartbeatSearch`: heartbeat продлевает активность.
- [x] Тест 90 секунд без heartbeat: заявка истекает.
- [x] Тест 10 минут без пары: поиск останавливается.
- [x] Тест единого пула: студент и учитель сравниваются без приоритета роли.
- [x] Тест уровня: точный уровень выбирается раньше ближайшего.
- [x] Тест уровня: ближайший уровень допускается только на один шаг.
- [x] Тест блоклистов в обе стороны.
- [x] Тест исключения учителя без VoIP/push токена.
- [x] Тест student-student пары.
- [x] Тест student-teacher пары.
- [x] Тест decline и timeout с возвратом второго участника в поиск.
- [x] Тест защиты от двойной сессии для одного пользователя.

Критерий завершения: критичная backend-логика проверена автоматическими тестами.

## Этап 15. Тесты Flutter

Цель этапа: проверить UI и клиентские состояния.

- [x] Тест отсутствия student availability UI.
- [x] Тест отображения кнопки "Начать поиск".
- [x] Тест перехода кнопки в "Остановить поиск".
- [x] Тест состояния "Ищем собеседника".
- [x] Тест состояния "Соединяем".
- [x] Тест состояния "Пока никого не нашли".
- [x] Тест ошибки доступа: нет подписки или лимита.
- [x] Тест ошибки доступа: нет камеры или микрофона.
- [x] Тест восстановления активного поиска после перезапуска.
- [x] Тест восстановления активного звонка после перезапуска.

Критерий завершения: основные UI-состояния покрыты тестами.

## Этап 16. Ручная проверка сценариев

Цель этапа: проверить сценарии, которые сложно полностью покрыть автотестами.

- [x] Student-student: оба приложения открыты.
- [x] Student-student: один студент в фоне.
- [x] Student-student: один студент отклоняет звонок.
- [x] Student-student: один студент не отвечает 45 секунд.
- [x] Student-teacher: учитель принимает звонок.
- [x] Student-teacher: учитель отклоняет звонок.
- [ ] Student-teacher: учитель не отвечает 45 секунд.
- [ ] Direct-call учителю: accept.
- [ ] Direct-call учителю: decline.
- [ ] Direct-call учителю: timeout.
- [ ] Закрытое приложение: входящий звонок до истечения 90 секунд.
- [ ] Закрытое приложение: заявка удаляется после 90 секунд без heartbeat.
- [ ] Таймаут входа в комнату 60 секунд.
- [ ] Завершение звонка и очистка очереди.

Критерий завершения: все основные пользовательские сценарии проверены вручную.

## Этап 17. Финальная валидация

Цель этапа: убедиться, что изменения готовы к передаче.

- [ ] Запустить `flutter analyze`.
- [ ] Запустить релевантные Flutter-тесты.
- [ ] Запустить релевантные backend-тесты.
- [ ] Проверить, что в студенческом интерфейсе нет `availabilityToday`.
- [ ] Проверить, что учительская доступность не сломана.
- [ ] Проверить, что старые звонки и история звонков открываются корректно.
- [ ] Проверить, что ошибки не оставляют пользователя в активном поиске.
- [ ] Проверить логи backend на сценариях accept, decline, timeout и cleanup.

Критерий завершения: проверки пройдены, критичных ошибок в звонках и очереди нет.
