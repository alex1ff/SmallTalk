# UX/UI Loading Optimization Tasks

Цель: убрать скачки контента, мигание пустых состояний, лишние скелетоны и задержки после действий на экранах с данными.

## UX Phase 0: Audit And Rules

- [x] Пройти основные экраны и зафиксировать места, где контент пропадает при обновлении.
- [x] Составить список экранов с full-screen loader после первого успешного рендера.
- [x] Зафиксировать единые состояния загрузки: `initialLoading`, `refreshing`, `hasData`, `empty`, `errorWithData`, `errorWithoutData`.
- [x] Запретить показ empty state до завершения первой реальной загрузки данных.
- [x] Запретить замену уже показанного контента на большой loader при refresh.
- [x] Зафиксировать правило: error state не стирает старые данные, если они уже были показаны.
- [x] Проверить стабильные размеры карточек, строк, аватаров, бейджей, кнопок и нижних панелей.

### Audit 2026-07-07: Content Drop Points

Scope: первый проход покрывает основные bottom-tab экраны, ключевые detail/list экраны из этих табов, звонок, post-call summary, платежи, события, словарь и вторичные списки профиля. Вне первого прохода остаются auth/onboarding, статичные legal/info страницы и чистые формы без удаленной загрузки данных.

Included route matrix:

- Student tabs: `StudentsDashboardWidget`, `WordsWidget`, `FavoriteWidget`, `ProfileWidget`, `EventListWidget`.
- Teacher tabs: `DashboardNSWidget`, `FavoriteWidget`, `ProfileWidget`, `EventListWidget`.
- Events routes: list, detail, edit when loading existing data, group chat, event history.
- Chat routes: conversations list, private chat thread, event group chat.
- Dictionary routes: words list, word detail, flashcard review.
- Call routes: waiting/search call, active video call, call details, call summary/review.
- Profile secondary routes: call history, event history, blacklist, student reviews, teacher reviews, native speaker profile.
- Payment routes: student paywall, teacher payout/cards/transactions.

Excluded route matrix:

- Auth and onboarding routes: excluded because they are not post-login data-list UX surfaces.
- Static/legal/info pages: excluded because they do not load changing user data.
- Pure create/edit forms without remote preload, including `ProfileEditWidget` and `EventCreateWidget`: excluded because there is no existing content list/detail to preserve during refresh.

Trigger types: `cold start`, `refresh/reconnect`, `filter change`, `retry`, `return to screen`, `async section update`.

- `Чаты`, список всех чатов: `lib/students_pages/favorite/favorite_widget.dart -> _buildMessagesTabContent -> conversationsLoading && inboxItems.isEmpty`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`. Экран возвращает пустой `SizedBox`, при ошибке без элементов заменяет список inline notice.
- `Чаты`, event-чаты во вкладке всех чатов: `lib/students_pages/favorite/favorite_widget.dart -> build/_buildMessagesTabContent -> eventChatsState == null / eventChats = [] / inboxItems.isEmpty`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`. Event-чаты читаются отдельным stream-ом, но нет отдельного `eventChatsLoading`: пока event stream еще без данных, `eventChats` подставляется пустым списком, поэтому empty state может появиться раньше времени.
- `Чаты`, вкладка друзей: `lib/students_pages/favorite/favorite_widget.dart -> _buildFriendsTabContent -> conversationsLoading || friendsLoading`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`. Возвращается пустой `SizedBox`, из-за чего список друзей/чатов визуально пропадает во время ожидания.
- Личные чаты: `lib/shared_pages/chat_thread/chat_thread_widget.dart -> build -> snapshot.connectionState == waiting / messagesSnapshot.hasError / !messagesSnapshot.hasData`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`. Conversation stream показывает full loading state. Messages stream не имеет `previousData/cache`: `!messagesSnapshot.hasData` заменяет список сообщений `SpinKitCircle`, `messagesSnapshot.hasError` стирает список full error state.
- Чат события: `lib/shared_pages/events/event_group_chat_widget.dart -> _buildChatContent/_buildMessagesContent -> waiting/hasError/empty`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`. Access stream и messages stream имеют отдельные center loaders; ошибка messages stream заменяет весь список сообщением об ошибке; пустой список сразу заменяет контент empty state.
- Список событий: `lib/shared_pages/events/event_list_widget.dart -> build -> isLoadingEvents / eventCardsFuture not done / hasError / empty`.
  Trigger: `cold start`, `filter change`, `retry`, `return to screen`. Внутренний cache карточек не решает refresh для пользователя: при смене города/даты/уровней старый список все равно заменяется loading shell, error state или empty state.
- Страница события: `lib/shared_pages/events/event_detail_route_widget.dart -> build -> snapshot.connectionState == waiting / snapshot.hasError / event == null`.
  Trigger: `cold start`, `refresh/reconnect`, `retry`, `return to screen`. Event stream заменяет весь экран loading/error/missing state. Nested streams для текущего участника, активных участников и public profiles временно дают пустые данные, поэтому CTA, участники и доступ к чату могут мигать из-за разных сроков обновления.
- Редактирование события: `lib/shared_pages/events/event_edit_widget.dart -> build -> snapshot.connectionState != done / snapshot.hasError / result == null`.
  Trigger: `cold start`, `retry`, `return to screen`. Форма редактирования заменяется loading/error/forbidden state, поэтому уже ожидаемая пользователем форма не имеет previous-data состояния.
- Главная студента: `lib/students_pages/students_dashboard/students_dashboard_widget.dart -> build -> currentUserUid.isEmpty || currentUserDocument == null`.
  Trigger: `cold start`, `refresh/reconnect`. Возвращается `_buildLoadingState`; внутри dashboard stats stream `!snapshot.hasData` показывает `SpinKitCircle`, `snapshot.hasError` дает `SizedBox.shrink`.
- Главная преподавателя: `lib/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart -> build -> loggedIn && currentUserDocument == null / !_canUseTeacherShell`.
  Trigger: `cold start`, `refresh/reconnect`. Показывается fullscreen `CircularProgressIndicator` или пустой `SizedBox`, из-за чего главный экран может полностью пропадать на ожидании профиля/редиректа.
- Мои события: `lib/shared_pages/events/event_history_widget.dart -> _buildBody -> FutureBuilder waiting/hasError/items.isEmpty`.
  Trigger: `cold start`, `retry`, `return to screen`. Body заменяется `AppLoadingIndicator`, error state или empty state; список полностью пропадает при retry/возврате.
- Мои отзывы студента: `lib/students_pages/my_rew/my_rew_widget.dart -> build -> !snapshot.hasData / filtered rew.isEmpty`.
  Trigger: `cold start`, `filter change`, `return to screen`. До данных возвращается отдельный `Scaffold` со `SpinKitCircle`, а после фильтрации пустой список заменяется `EmptyWidget`.
- Мои отзывы преподавателя: `lib/teachers_pages/my_rew_n_s/my_rew_n_s_widget.dart -> build -> loggedIn && currentUserDocument == null / !canAccessTeacherSurfaces / !snapshot.hasData / empty`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`. До профиля возвращается fullscreen `CircularProgressIndicator`, при недоступной teacher-surface ветке экран заменяется сообщением/редиректом, до отзывов возвращается fullscreen `SpinKitCircle`, затем строится список или empty state.
- Словарь: `lib/students_pages/words/words_widget.dart -> build -> words == null / words.isEmpty`.
  Trigger: `cold start`, `refresh/reconnect`. Words stream уже использует `initialData` из cache, но если `words == null`, возвращается пустой `SizedBox`; empty state заменяет список.
- Карточки повторения: `lib/students_pages/flashcard/flashcard_widget.dart -> build -> snapshot.hasError / !snapshot.hasData / entries.isEmpty`.
  Trigger: `cold start`, `retry`, `return to screen`. Экран заменяется error state, `SpinKitCircle` или empty state; текущая review-сессия не имеет previous-data оболочки при перезагрузке.
- Детальная слова: `lib/students_pages/words/word_detail_widget.dart -> build -> word == null`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`. Несмотря на `initialWord`, при отсутствии данных экран заменяется `AppLoadingIndicator`.
- Профиль, прогресс: `lib/shared_pages/profile/profile_widget.dart -> _progressSection -> wordsSnapshot.data?.length ?? 0 / statsSnapshot.data ?? []`.
  Trigger: `cold start`, `refresh/reconnect`, `async section update`. Word/stat streams считают отсутствующие данные как `0` и пустой список, а не как loading/refresh state; статистика может сначала показывать нули, потом реальные значения.
- Профиль, основной экран: `lib/shared_pages/profile/profile_widget.dart -> _redesignedBuild -> loggedIn && currentUserDocument == null`.
  Trigger: `cold start`, `refresh/reconnect`. Основной таб `Профиль` заменяется fullscreen `CircularProgressIndicator.adaptive`, пока профиль пользователя еще не пришел.
- История звонков: `lib/shared_pages/my_calls/my_calls_widget.dart -> build -> currentUserDocument == null / !snapshot.hasData / snapshot.hasError / sessions.isEmpty`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`. Список заменяется loading, error или empty state.
- Ожидание/поиск звонка: `lib/students_pages/waiting_for_teacher_page/waiting_for_teacher_page_widget.dart -> build/_buildStatusBody -> sessionId == null && !_createFailed / isLoading || status == null`.
  Trigger: `cold start`, `refresh/reconnect`, `async section update`. Экран поиска/дозвона показывает loading status body до получения sessionId и может менять основной статусный блок при ошибке создания или обновлении статуса сессии.
- Детали звонка: `lib/shared_pages/call_details/call_details_widget.dart -> build/_buildCaptionLogsSection/_buildReviewSection/_buildStoredReview -> videoDocRef == null / snapshot.hasError / !snapshot.hasData / missing session / !participant.isParticipant / waiting/hasError/empty`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`, `async section update`. Основной session stream заменяет body на loading/unavailable state; caption logs stream и review-секция имеют отдельные loading/error/empty ветки, поэтому уже открытая деталка может менять блоки субтитров и review state независимо от основного контента.
- Активный звонок: `lib/shared_pages/video_call_page/video_call_page_widget.dart -> build -> videoCallPageVideoSessionsRecord == null && !hasInitialJoinCredentials`.
  Trigger: `cold start`, `refresh/reconnect`. Session stream показывает loading/media permission state; внутри страницы есть отдельные async-состояния readiness/permission.
- Итог звонка и отзыв после звонка: `lib/shared_pages/call_summary/call_summary_widget.dart -> build/_buildReviewSection/_buildStoredReview -> profile future waiting / pair review future waiting / review stream waiting`.
  Trigger: `cold start`, `return to screen`, `async section update`. Profile future на ожидании возвращает пустой body, а review submission может прыгать между loading, формой и сохраненным отзывом.
- Черный список: `lib/shared_pages/black_list/black_list_widget.dart -> build/AuthUserStreamWidget/ListView itemBuilder/FutureBuilder -> currentUserDocument?.blockedUsers ?? [] / snapshot.connectionState == waiting`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`, `async section update`. Пока user document не пришел, список считается пустым и может показать empty state раньше реальной загрузки; каждый пользователь внутри списка грузится отдельно, на ожидании конкретной строки показывается `SpinKitCircle` вместо стабильной строки.
- Профиль собеседника: `lib/students_pages/native_speaker_page/native_speaker_page_widget.dart -> build / stats FutureBuilder / _buildReviewsSection -> profile waiting / stats !hasData / reviews !hasData`.
  Trigger: `cold start`, `refresh/reconnect`, `async section update`. Основной public profile stream заменяет весь экран loader-ом; stats/reviews внутри страницы показывают отдельные `SpinKitCircle`.
- Оплата студента: `lib/students_pages/pay/pay_widget.dart -> _loadPackages/_priceFor/build -> _isLoadingPackages`.
  Trigger: `cold start`, `retry`, `async section update`. Цены показывают `Загрузка...`, CTA получает `isLoading`, покупка блокируется; тарифы и нижняя purchase-панель скачут между loading/недоступно/ценой.
- Выплаты преподавателя: `lib/teachers_pages/pay_copy/pay_copy_widget.dart -> build -> loggedIn && currentUserDocument == null / !canAccessTeacherSurfaces / cards StreamBuilder !snapshot.hasData`.
  Trigger: `cold start`, `refresh/reconnect`, `return to screen`, `async section update`. До профиля возвращается fullscreen `CircularProgressIndicator`, при недоступной teacher-surface ветке экран заменяется сообщением/редиректом; cards stream использует отдельный loading spinner, поэтому секция карт скачет независимо от остального экрана.
- Операции выплат преподавателя: `lib/teachers_pages/pay_copy/pay_copy_widget.dart -> build -> transactions StreamBuilder -> !snapshot.hasData / transactions.isEmpty`.
  Trigger: `cold start`, `refresh/reconnect`, `async section update`. Transactions stream использует отдельный loading spinner, а empty state заменяет список операций.

### Audit 2026-07-07: Full-Screen Loaders After First Render

Критерий: fullscreen/page-level loader - это состояние, где `Scaffold`, body экрана или почти весь основной экран заменяется большим loader/state scaffold. Повторный вход на экран или новый mount после уже успешного показа считается повторным рендером. Локальные spinner-ы внутри строки, карточки или отдельного блока в этот список не входят.

Экраны с fullscreen/page-level loader, который может повториться после первого успешного показа данных:

- `Страница события`: `lib/shared_pages/events/event_detail_route_widget.dart -> build -> snapshot.connectionState == waiting`. При stream reconnect, retry или повторном входе весь detail заменяется `_EventDetailRouteStateScaffold` с loader-ом.
- `Редактирование события`: `lib/shared_pages/events/event_edit_widget.dart -> build -> snapshot.connectionState != done`. При повторном входе или retry форма заменяется `_EventEditStateScaffold` с loader-ом.
- `Мои события`: `lib/shared_pages/events/event_history_widget.dart -> _buildBody -> snapshot.connectionState != done`. При retry или возвращении на экран body заменяется `AppLoadingIndicator`.
- `Личный чат`: `lib/shared_pages/chat_thread/chat_thread_widget.dart -> build -> conversation snapshot waiting / messages !hasData`. При reconnect или повторном входе экран чата либо список сообщений заменяется большим loader-ом.
- `Чат события`: `lib/shared_pages/events/event_group_chat_widget.dart -> _buildChatContent/_buildMessagesContent -> access waiting / messages waiting`. При reconnect или возврате основной чат-контент заменяется center loader-ом.
- `Профиль`: `lib/shared_pages/profile/profile_widget.dart -> _redesignedBuild -> loggedIn && currentUserDocument == null`. При auth/user stream reconnect основной экран профиля заменяется fullscreen `CircularProgressIndicator.adaptive`.
- `Главная студента`: `lib/students_pages/students_dashboard/students_dashboard_widget.dart -> build -> currentUserUid.isEmpty || currentUserDocument == null`. При auth/user stream reconnect весь dashboard заменяется `_buildLoadingState`.
- `Главная преподавателя`: `lib/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart -> build -> loggedIn && currentUserDocument == null`. При auth/user stream reconnect весь dashboard заменяется fullscreen `CircularProgressIndicator.adaptive`.
- `История звонков`: `lib/shared_pages/my_calls/my_calls_widget.dart -> build -> currentUserDocument == null / !snapshot.hasData`. При reconnect или повторном входе список заменяется `_buildLoadingState`.
- `Ожидание/поиск звонка`: `lib/students_pages/waiting_for_teacher_page/waiting_for_teacher_page_widget.dart -> build/_buildStatusBody -> sessionId == null && !_createFailed / isLoading || status == null`. При старте, reconnect или новом mount весь body заменяется статусным loading screen.
- `Детали звонка`: `lib/shared_pages/call_details/call_details_widget.dart -> build -> !snapshot.hasData`. При session stream reconnect body заменяется `_buildLoadingState`; при error/missing/forbidden body заменяется unavailable state.
- `Активный звонок`: `lib/shared_pages/video_call_page/video_call_page_widget.dart -> build -> session record null / media permission future waiting`. При session reconnect или permission check весь call screen заменяется `_buildMediaPermissionState`.
- `Профиль собеседника`: `lib/students_pages/native_speaker_page/native_speaker_page_widget.dart -> build -> profile stream waiting`. При reconnect или возврате весь public profile заменяется fullscreen `SpinKitCircle`.
- `Мои отзывы студента`: `lib/students_pages/my_rew/my_rew_widget.dart -> build -> !snapshot.hasData`. При повторном входе экран заменяется отдельным `Scaffold` со fullscreen `SpinKitCircle`.
- `Мои отзывы преподавателя`: `lib/teachers_pages/my_rew_n_s/my_rew_n_s_widget.dart -> build -> loggedIn && currentUserDocument == null / !snapshot.hasData`. При user stream reconnect или повторном входе экран заменяется fullscreen loader-ом.
- `Выплаты преподавателя`: `lib/teachers_pages/pay_copy/pay_copy_widget.dart -> build -> loggedIn && currentUserDocument == null`. При user stream reconnect экран выплат заменяется fullscreen `CircularProgressIndicator.adaptive`.
- `Детальная слова`: `lib/students_pages/words/word_detail_widget.dart -> build -> word == null`. При отсутствии stream/cache данных body заменяется `AppLoadingIndicator`.
- `Повторение слов`: `lib/students_pages/flashcard/flashcard_widget.dart -> build -> !snapshot.hasData`. При повторном входе review screen заменяется center `SpinKitCircle`.

Экраны с большими content-area loader-ами, но не fullscreen:

- `Список событий`: `lib/shared_pages/events/event_list_widget.dart -> build -> isLoadingEvents / eventCardsFuture not done`. Меняется список/контентная область под фильтрами, а не весь экран.
- `Список чатов`: `lib/students_pages/favorite/favorite_widget.dart -> _buildMessagesTabContent/_buildFriendsTabContent -> conversationsLoading || friendsLoading`. Сейчас вместо большого loader-а часто возвращается пустой `SizedBox`, но UX-проблема та же: уже видимый список может исчезнуть.
- `Черный список`: `lib/shared_pages/black_list/black_list_widget.dart -> itemBuilder FutureBuilder waiting`. Loader находится в строках списка; отдельный риск - преждевременный empty state до прихода `currentUserDocument`.
- `Профиль`, прогресс/статистика: `lib/shared_pages/profile/profile_widget.dart -> _progressSection -> words/stats stream`. Это секционные изменения: нули и пустые значения показываются вместо stable previous data.
- `Итог звонка`: `lib/shared_pages/call_summary/call_summary_widget.dart -> build -> profile future waiting`. На ожидании возвращается пустой body без loader-а; review-секция грузится отдельно.
- `Оплата студента`: `lib/students_pages/pay/pay_widget.dart -> _isLoadingPackages`. Loader выражен через тексты цен, disabled CTA и нижнюю панель, а не через fullscreen state.
- `Карты/операции выплат преподавателя`: `lib/teachers_pages/pay_copy/pay_copy_widget.dart -> cards/transactions StreamBuilder !snapshot.hasData`. После основного route loader-а секции карт и операций грузятся отдельно и могут менять высоту.

### Rule 2026-07-07: Unified Loading States

Каждый экран со списком, карточками, detail-записью, чатом или вторичными async-блоками должен приводить загрузку данных к единой модели состояния. Итоговое loading/data-состояние всегда одно из шести: `initialLoading`, `refreshing`, `hasData`, `empty`, `errorWithData`, `errorWithoutData`. Доменные состояния после успешной загрузки, например `notFound`, `deleted`, `accessDenied`, `cancelled` или `expired`, отображаются отдельно и не считаются `empty`.

Состояние считается относительно `activeDataKey`: route + текущий пользователь + id записи + активные фильтры. Для событий это `city + dateFilter + levelFilters`, для чата - conversation/eventChat id, для detail - document id. Для вторичных async-блоков используется section key: `parentDataKey + sectionName + params`, например `profile:currentUser:stats`, `eventDetail:eventId:participants`, `eventCard:eventId:publicProfiles`, `teacherPayouts:cards`.

Если на экране уже показаны данные, отдельно хранится `displayedDataKey`. При смене фильтра или нового запроса `activeDataKey` может отличаться от `displayedDataKey`; тогда старые совместимые данные остаются как stale content до успешного результата нового ключа, а при ошибке нового ключа остаются как `errorWithData`.

| State | Когда применяется | Что показываем |
| --- | --- | --- |
| `initialLoading` | По этому `dataKey` еще не было ни одного успешного результата, запрос/stream уже стартовал | Стабильный shell экрана и компактная загрузка в content area. Не показывать empty/error, не очищать уже известный shell, не менять размеры основных блоков |
| `refreshing` | Для `activeDataKey` уже есть `lastSuccessfulResult`, либо есть совместимый `displayedDataKey`, и идет повторная загрузка, reconnect, retry, pull-to-refresh, смена stream snapshot или догрузка профилей | Оставить данные на экране. Разрешен маленький refresh indicator, inline shimmer фиксированного размера или disabled state конкретной кнопки |
| `hasData` | Последняя успешная загрузка вернула непустые данные или detail-документ доступен | Показывать данные. Последующие async-блоки не должны сбрасывать родительский экран в loader |
| `empty` | Загрузка для текущего `dataKey` успешно завершилась и данных реально нет | Показывать общий empty state приложения. Empty запрещен при `initialLoading`, `refreshing` и до завершения первой успешной загрузки |
| `errorWithData` | Новая загрузка упала, но есть `lastSuccessfulResult` для `activeDataKey` или совместимый stale `displayedDataKey` | Оставить данные на экране. Ошибку показать компактно: banner, snackbar, inline retry-row или маленький retry-блок без очистки контента |
| `errorWithoutData` | Первая загрузка для `dataKey` упала и показывать нечего | Показать компактный error state с retry. Не подменять ошибку empty state и не показывать бесконечный loader |

Приоритет отображения:

1. Есть данные и идет новая загрузка того же или совместимого ключа -> `refreshing`.
2. Есть `lastSuccessfulResult`, previous loaded state или compatible `displayedDataKey`, и новая загрузка упала -> `errorWithData`, даже если previous state был confirmed `empty` или domain loaded-state.
3. Есть данные и нет активной загрузки/ошибки -> `hasData`.
4. Нет previous loaded state + request in flight -> `initialLoading`.
5. Нет previous loaded state + error -> `errorWithoutData`.
6. Нет previous loaded state + успешный результат пустой -> `empty`.

Общие правила реализации:

- Не присваивать `[]`, `null` или empty view как визуальное состояние до окончания первой реальной загрузки.
- Хранить `lastSuccessfulResult` на время жизни экрана минимум в `State/Model`, для tab/list экранов - в in-memory cache на время сессии. `lastSuccessfulResult` может быть data, confirmed empty или domain loaded-state.
- Stream reconnect с уже показанными данными всегда трактуется как `refreshing`, а не как `initialLoading`.
- Смена фильтра создает новый `activeDataKey`; если старый `displayedDataKey` совместим, старый список остается как stale content в состоянии `refreshing` до результата нового ключа. Empty для нового ключа показывается только после успешного ответа.
- Совместимые ключи - это один и тот же экран, тот же пользователь, тот же тип данных и одинаковая визуальная структура. Для list/grid экранов разные фильтры, город, дата или pagination считаются совместимыми. Для detail/chat экранов другой document id, другой conversation id, другой event id, другой пользователь или logout не считаются совместимыми.
- Ошибка не очищает данные. Очистка допустима только при явном действии пользователя: удаление, выход из чата/события, logout, смена аккаунта.
- Optimistic действия (`send`, `join`, `leave`, `delete`) не переводят весь экран в loading; они получают отдельное локальное состояние конкретной строки, сообщения или кнопки. Если список был `empty`, optimistic item временно переводит effective data в `hasData`; при rollback возвращается к `empty` только если нет previous/server data.
- Вложенные async-данные, например аватары участников, public profiles, статистика, review-блоки, не имеют права менять состояние родительского экрана с `hasData` на loader/empty.
- Вложенный async-блок ведет собственное section-level состояние по section key и не подставляет `0`, `[]`, пустую строку или empty state до первого успешного результата этой секции.

Этот раздел фиксирует общую модель; отдельные Phase 0 пункты закрываются отдельными правилами и дальше внедряются в экраны.

### Rule 2026-07-07: No Empty Before First Successful Load

Empty state разрешен только после успешного ответа/stream snapshot для текущего `activeDataKey`, когда источник данных явно вернул пустой результат. До этого момента экран находится в `initialLoading`, `refreshing` или `errorWithoutData/errorWithData`, но не в `empty`.

Успешная загрузка - это completed future, первый реальный emitted stream snapshot/data для текущего ключа, либо сохраненный completed cache-result для того же `activeDataKey`/`sectionKey`. Для Firestore/Flutter stream успех не требует `ConnectionState.done`; нужен первый реальный snapshot, относящийся к текущему ключу. `initialData`, provider default, cache miss, placeholder, `?? []`, пустой локальный state и fallback-значения не считаются успешной загрузкой. `initialData` допустим как успешный результат только если это типизированный completed cache-result с marker, а не голый `List`/model. Cache-empty можно считать empty только при явном marker/metadata, что пустой cache-result сохранен после успешной загрузки: key, completed flag и время/версия результата. Пустой Firestore `QuerySnapshot.docs` из local cache не считается подтвержденным empty, если нет server-confirmed snapshot или cache-empty marker.

Запрещено:

- Показывать empty из-за `snapshot.data == null`, `!snapshot.hasData`, `connectionState == waiting`, `streamState == null`, отсутствующего provider/cache state или еще не пришедшего `currentUserDocument`.
- Подставлять `[]` как готовый результат до завершения stream/future и на основе этого показывать empty.
- Показывать empty при ошибке загрузки. Ошибка без данных - `errorWithoutData`; ошибка с previous/stale data - `errorWithData`.
- Показывать empty для нового фильтра, города, даты, уровня или первой страницы base query до успешного ответа именно для нового `activeDataKey`.
- Показывать empty родительского экрана из-за вложенного async-блока: аватары, public profiles, stats, reviews, participants, cards/transactions, unread badges.
- Показывать empty для агрегированного списка, пока хотя бы один обязательный источник текущего `activeDataKey` еще `initialLoading`, `refreshing` или `errorWithoutData`. Для `conversations + eventChats` empty допустим только после успешного ответа обоих источников и пустого объединенного результата.

Разрешено:

- Показывать empty после успешного server/cache результата, где список реально пуст и подтвержден для всех обязательных источников.
- Показывать empty для section-level блока только после успешного результата section key, например `eventDetail:eventId:participants` или `profile:currentUser:reviews`.
- Возвращать empty после optimistic rollback, если нет previous/server data и последняя успешная загрузка действительно была пустой.

Правила для спорных случаев:

- Auth/current user document не пришел - это `initialLoading` или `refreshing`, не empty.
- Event chats/conversations stream еще не отдал snapshot - список чатов не пустой, он не загружен.
- `currentUserDocument?.blockedUsers ?? []` не считается успешным пустым результатом, пока user document не загружен.
- Search/filter result с новым `activeDataKey` и старым `displayedDataKey` остается stale content + `refreshing`; empty показывается только после успешного пустого результата нового ключа.
- Pagination использует два уровня ключей: `activeDataKey/baseQueryKey` для фильтров и `pageRequestKey` для cursor/страницы. Пустая следующая страница не переводит весь список в `empty`: это `hasData` + `noMoreItems`. Empty допустим только если успешная первая страница/current base query вернула 0 элементов.
- Для агрегированных списков обязательный источник - тот, который может добавить элементы и влияет на пустоту списка; optional enrichment source, например public profile/avatar/unread metadata, не блокирует empty. Если хотя бы один обязательный источник вернул данные, parent остается `hasData`, `refreshing` или `errorWithData` в зависимости от остальных источников. Если данных нет и хотя бы один обязательный источник еще грузится - `initialLoading` или stale `refreshing`. Если данных нет и обязательный источник упал - `errorWithoutData`, либо `errorWithData` при наличии stale data.
- Для parent `activeDataKey` и каждого `sectionKey` правило применяется отдельно; section-level empty никогда не меняет parent state на `empty`.
- Detail-документ с успешной загрузкой `doc.exists == false` не является early empty и не является list-empty. Это доменный `missing/notFound/unavailable` UI state вне loading/data-state модели только после server-confirmed результата или typed cache marker. Cached/missing doc без marker/server confirmation не показывает `notFound`.
- Nested counters и stats не показывают `0`, если это только отсутствие данных до первой успешной загрузки; используется stable placeholder или прежнее значение.

### Rule 2026-07-07: No Full-Screen Loader After Content

Если экран уже один раз показал `lastSuccessfulResult` для `activeDataKey` или compatible `displayedDataKey`, последующие refresh/reconnect/retry/filter-change не заменяют основной контент на fullscreen/page-level loader. `lastSuccessfulResult` включает confirmed `hasData`, confirmed `empty`, `errorWithData` со stale data и доменный loaded-state. Такой переход всегда отображается как `refreshing`, `errorWithData` или stale content, пока не придет новый confirmed result.

Запрещено после первого успешного показа:

- Возвращать loading `Scaffold`, fullscreen spinner, `_buildLoadingState`, `_EventDetailRouteStateScaffold` или большой center loader вместо уже показанного экрана.
- Заменять список сообщений/чатов/событий/слов/истории на `SpinKitCircle`, `CircularProgressIndicator`, пустой `SizedBox`, skeleton screen или full error только потому, что stream снова `waiting` или future перезапустился.
- Рендерить waiting-ветку restarted `FutureBuilder` после уже показанного контента; нужно показывать `lastSuccessfulResult` + `refreshing`.
- Сбрасывать detail-экран в loader при reconnect document stream, если есть `lastSuccessfulResult` или compatible stale detail.
- Сбрасывать user-gated экран в loader при повторном приходе `currentUserDocument == null`, если текущий пользователь не поменялся и есть последнее подтвержденное состояние экрана. Это относится к dashboard, profile, history, reviews, payouts, calls и другим экранам, завязанным на current user.
- Сбрасывать parent экран из-за вложенных async-блоков: public profiles, avatars, stats, reviews, cards, participants, unread counters.
- Показывать full error state при refresh/reconnect после уже показанного контента. Здесь запрещен только full-screen/full-content error replacement; общее правило ошибок фиксируется отдельным Phase 0 пунктом.

Разрешено вместо большого loader:

- Маленький refresh indicator в header, над списком, в pull-to-refresh зоне или рядом с действием.
- Inline placeholder фиксированного размера внутри новой строки/карточки, если этой строки раньше не было.
- Disabled/loading state конкретной кнопки или optimistic row/message state.
- Тонкий progress indicator для pagination внизу списка.
- Сохранение старого списка/detail как stale content с визуально стабильной геометрией.

Полный loader допустим только:

- При `initialLoading`, когда для `activeDataKey` нет `lastSuccessfulResult`, compatible `displayedDataKey`, completed cache-result или domain loaded-state.
- После logout, смены аккаунта, смены пользователя в route, явного выхода из чата/события или навигации на принципиально другой document id/conversation id/event id без compatible stale data.
- После confirmed `deleted`, `notFound`, `accessDenied`, `cancelled` или `expired` показывается соответствующий domain loaded-state, а не full loader.
- Для отдельного section key допустим только фиксированный section-level placeholder/spinner, если секция раньше не имела successful result и этот loader не выглядит как page/content-area loader и не меняет размеры parent-контента.

Правила для ключевых экранов:

- `Чаты`: список чатов остается на экране при reconnect; event-chats stream не очищает conversations list.
- `Страница чата`: уже показанные сообщения остаются; новые/старые сообщения догружаются inline.
- `События`: при смене фильтра старые карточки остаются stale content до нового результата; empty/error нового фильтра не стирает старый список до confirmed result/errorWithData.
- `Страница события`: detail, CTA, участники и organizer block не уходят в route-level loader при reconnect; вложенные профили участников обновляются inline.
- `Словарь`: список слов не заменяется empty/loader при reconnect; панель повторения сохраняет высоту.
- `Профиль`: основной профиль не исчезает при догрузке stats/subscription/email; блоки используют stable placeholders или previous values.
- `Звонки`: детали/summary не сбрасываются в full loader при reconnect session/review/caption streams, если базовая session уже была показана.

### Rule 2026-07-07: Error Keeps Previous Content

Ошибка загрузки не очищает уже показанный контент. Если для `activeDataKey` есть `lastSuccessfulResult` или compatible `displayedDataKey`, экран переходит в `errorWithData`: прежний loaded UI остается, ошибка отображается компактно и не меняет геометрию основного контента. Если `lastSuccessfulResult` был confirmed empty или domain loaded-state, этот empty/domain UI тоже остается и получает compact error slot; он не превращается в новый empty/error/fullscreen state.

`errorWithoutData` допустим только когда нет `lastSuccessfulResult`, нет compatible stale content, нет completed cache-result и первая реальная загрузка для текущего ключа завершилась ошибкой.

Запрещено при `errorWithData`:

- Заменять список/detail/chat/profile на fullscreen error state, пустой экран, empty state, loader или `SizedBox.shrink`.
- Очищать сообщения, события, слова, историю, participants, cards/transactions, reviews или stats из-за ошибки refresh/reconnect.
- Сбрасывать CTA, счетчики, unread badges, optimistic rows/messages или bottom action bar в начальное состояние из-за ошибки вложенного async-блока.
- Показывать generic "не удалось загрузить" как единственный контент, если пользователь уже видел данные.

Разрешено при `errorWithData`:

- Compact banner/snackbar/toast с текстом ошибки и retry.
- Inline retry-row фиксированной высоты в секции, где произошла ошибка.
- Маленький warning icon/status рядом с заголовком, фильтром или timestamp.
- Сохранить stale data с признаком, что обновление не удалось.

Правила для mixed states:

- Parent экран остается `hasData` или `errorWithData`, если ошибся вложенный optional source: avatar/public profile/unread/stat/review/card enrichment.
- Section key может быть `errorWithoutData`, только если сама секция не имела previous result; parent при этом не становится full error.
- Если section key уже имел previous result, ошибка секции становится section-level `errorWithData`: прежнее значение секции остается на месте, рядом показывается compact retry/status.
- Если один обязательный источник агрегированного списка упал, но другой уже дал элементы, parent остается `errorWithData` с объединенным доступным контентом.
- Если один обязательный источник агрегированного списка упал, остальные успешно вернули пусто, и previous/stale data нет, parent становится `errorWithoutData`, а не `empty`.
- Если все обязательные источники упали и нет previous/stale data, parent становится `errorWithoutData`.
- Если новый фильтр упал, но есть compatible `displayedDataKey`, показывается stale список + компактная ошибка нового фильтра.

Retry behavior:

- Retry из `errorWithData` переводит экран в `refreshing`, сохраняя данные.
- Retry из `errorWithoutData` может показывать compact/page-level loading, потому что данных еще нет.
- Повторная ошибка не должна дублировать banners бесконечно; обновляется один стабильный error slot.

### Rule 2026-07-07: Stable Layout Dimensions

Все экраны с данными должны иметь стабильную геометрию после первого рендера shell. Загрузка, refresh, ошибка, optimistic update, догрузка public profiles/avatars/unread/stats/reviews не должны менять высоту строк, карточек, нижних панелей и основных блоков.

Общие правила:

- Каждый повторяемый item задает стабильный layout contract: avatar slot, title/subtitle area, meta area, action area, divider inset, min/max height.
- Loader/placeholder/error для элемента занимает тот же slot, что и готовое значение.
- Длинный текст обрезается/переносится внутри заранее выделенной области и не раздвигает кнопки, badges, avatars или bottom bars.
- Догрузка изображения, инициалов, иконки, unread count или participant profile не меняет размер контейнера.
- Empty/error/loading state внутри списка не должен менять высоту header/filter/bottom bar.
- Safe area и keyboard inset не создают "дырки". Внутренняя высота bottom action/input bar фиксирована отдельно от `SafeArea.bottom`; keyboard двигает панель через `viewInsets.bottom`, без double padding и без изменения высоты самой панели.

Размерные контракты по компонентам:

- `Avatar`: фиксированный диаметр для контекста; фото, инициалы, иконка-заглушка и loading placeholder используют один и тот же circle size. Fallback text не влияет на размер.
- `Participant avatar stack`: фиксированный диаметр, overlap, max visible count и `+N` slot. Для известных participant refs показывается previous known visible set или стабильный fallback avatar/initial slot; загрузка public profile не добавляет и не удаляет slot. Нельзя показывать blank slot без содержимого.
- `Chat row`: фиксированная высота строки, avatar slot, time/unread slot и divider inset. Unread badge имеет fixed min size и не двигает время/текст при переходе `0 -> 1 -> 99+`.
- `Chat message bubble`: bubble, timestamp/status, retry action и sending/sent/failed indicator имеют стабильные slots. Optimistic send меняет status slot, но не пересобирает и не сдвигает соседние сообщения.
- `Event card`: стабильная структура header/body/meta/participants/actions. Join/leave/loading/error меняют состояние кнопки и счетчика, но не высоту карточки.
- `Dictionary row`: строка имеет min/max height, divider вместо отдельных карточек, max lines/ellipsis для original и translation. Длинный текст остается внутри выделенных областей и не раздувает строку без заданного лимита.
- `Buttons`: action buttons имеют фиксированную высоту, стабильный horizontal padding и отдельные slots для icon/spinner/text. Loading/disabled/sending state не меняет размер кнопки и не заменяет текст на spinner с другой шириной.
- `Badges/chips`: active/inactive state меняет цвет, но не размер. Chips имеют stable min height/width, icon/count/text slots и не reflow из-за async label/count.
- `Bottom bars`: navigation bar, event action bar, chat input bar и repeat panel имеют фиксированную внутреннюю высоту плюс safe area. Состояния loading/sending/disabled не меняют высоту.
- `Chat composer`: fixed min height, bounded max height; multiline text scrolls inside field after maxLines. Send button keeps fixed slot; attachment/retry/status icons do not alter bar height.
- `Payments`: package/tariff cards, price text, purchase CTA/bottom bar, cards rows and transactions rows reserve stable slots for loading/error/price/status.
- `Secondary list rows`: reviews, call history, blacklist/friends, event history and payout operations use fixed avatar/meta/action/divider slots.
- `Public profile/detail sections`: native speaker profile, event edit preload shell, review sections and call detail sections reserve stable section heights or min/max constraints while secondary data loads.

Ключевые проверки:

- `Чаты`: строки чатов, unread badge, avatar, divider и swipe/delete action остаются стабильными при новых сообщениях и удалении.
- `Страница чата`: message bubbles, input bar и send button не прыгают при отправке, ошибке, клавиатуре и safe area.
- `События`: карточки не меняют высоту при догрузке участников, join/leave, ошибке профиля участника или смене фильтра.
- `Страница события`: блоки organizer, date/time/place, participants grid и sticky bottom bar сохраняют размеры при reconnect.
- `Словарь`: строки слов разделены divider, repeat panel не обрезает счетчик на больших числах.
- `Профиль`: avatar, email card, progress cards и tariff blocks не меняют размер при догрузке stats/subscription.
- `Платежи`: package/tariff cards, price slot, purchase bottom bar, payout cards and transactions rows не меняют размер при загрузке цен, карт и операций.
- `Вторичные списки`: reviews, call history, event history, blacklist/friends and native speaker profile sections keep row/card geometry during loading/error/empty transitions.
- `Формы с preload`: edit-preload form shell keeps field/dropdown/button dimensions while existing data loads.
- `Звонки`: waiting/call/detail/summary actions и review блоки не меняют основной layout при async state.

## UX Phase 1: Shared Loading Patterns

- [x] Сделать общий helper/model для экранов со списками и состояниями загрузки.
- [x] Добавить общий паттерн `previousData + refreshing indicator`.
- [x] Унифицировать empty state через общий компонент приложения.
- [x] Унифицировать error state для списков: ошибка поверх старых данных или компактный retry-блок.
- [x] Убрать лишние skeleton-экраны там, где уже есть cached/previous data.
- [x] Добавить локальный in-memory cache для данных, которые нужны только на время сессии.

## UX Phase 2: Chats List

- [x] Сохранить последний загруженный список чатов в памяти на время сессии.
- [x] При входе во вкладку `Чаты` сразу показывать cached list, если он есть.
- [x] Не показывать empty state, пока не завершилась первая загрузка чатов.
- [x] При обновлении чатов оставлять текущий список на экране.
- [x] Event-чаты должны появляться в списке без необходимости сначала открывать чат события.
- [x] Удаление чата сделать optimistic: строка исчезает сразу, при ошибке возвращается.
- [x] Убрать full-screen error, если список чатов уже был загружен.
- [x] Зафиксировать высоту строки чата.
- [x] Зафиксировать размеры аватара, времени, unread badge и divider.
- [x] Проверить unread badge: цифра должна появляться без скачка строки.

## UX Phase 3: Chat Detail

- [x] При открытии чата показывать последние cached сообщения, если они есть.
- [x] Не заменять список сообщений большим loader при reconnect/refresh.
- [x] Отправленное сообщение добавлять в список мгновенно.
- [x] Добавить локальный статус сообщения: `sending`, `sent`, `failed`.
- [x] При ошибке отправки оставлять сообщение в чате со статусом ошибки и возможностью повторить.
- [ ] Не пересобирать весь список сообщений после отправки одного сообщения.
- [ ] Зафиксировать высоту input-bar и send button.
- [ ] Убрать скачок нижней панели при открытии клавиатуры и safe area.
- [ ] Убрать лишние проверки доступа из UI-цепочки отправки, если пользователь уже находится в доступном чате.

## UX Phase 4: Events List

- [ ] Сохранить последний список событий по ключу `city + dateFilter + levelFilters`.
- [ ] При смене фильтра оставлять старый список до прихода нового результата.
- [ ] Показывать компактный refresh indicator вместо очистки списка.
- [ ] Empty state показывать только после завершения загрузки нового фильтра.
- [ ] Зафиксировать высоту и структуру карточки события.
- [ ] Не менять размеры карточки при догрузке участников и аватаров.
- [ ] Подтягивать public profiles участников заранее для видимых карточек.
- [ ] Не показывать blank-заглушки участников: для известных participant refs использовать стабильный fallback avatar/initial slot до загрузки профиля.
- [ ] Join/leave на карточке делать optimistic: кнопка, счетчик мест и участники меняются сразу.
- [ ] При ошибке join/leave откатывать optimistic-состояние и показывать короткую ошибку.

## UX Phase 5: Event Detail

- [ ] Кэшировать последний detail snapshot события на время сессии.
- [ ] При обновлении event snapshot не заменять весь экран loader-ом.
- [ ] Join/leave на странице события делать optimistic.
- [ ] Сразу менять CTA, счетчик мест и список участников после join/leave.
- [ ] Подтягивать public profiles участников параллельно с participant snapshot.
- [ ] Не показывать blank-заглушку участника: если профиль уже был известен, сохранять его; если известен только ref, показывать стабильный fallback avatar/initial slot.
- [ ] Зафиксировать размеры блоков организатора, даты/времени/места и участников.
- [ ] Sticky bottom action bar не должен прыгать при обновлении данных.
- [ ] Ошибка обновления detail не должна стирать уже показанное событие.

## UX Phase 6: Dictionary

- [ ] Убрать отдельные bordered cards у слов, заменить на строки списка с divider.
- [ ] Зафиксировать высоту строки слова.
- [ ] Разнести оригинал и перевод так, чтобы длинный текст не слипался.
- [ ] Нижнюю панель повторения сделать стабильной по высоте.
- [ ] Сократить текст счетчика повторения, чтобы он не обрезался на больших числах.
- [ ] Проверить состояния пусто/загрузка/ошибка без скачков.

## UX Phase 7: Profile And Secondary Lists

- [ ] Профиль сначала показывает данные из `currentUserDocument`, вторичные данные догружаются отдельно.
- [ ] Блоки профиля не должны менять размер при догрузке статистики, подписки и почты.
- [ ] Аватар профиля не должен прыгать между placeholder и реальным состоянием.
- [ ] Проверить списки истории, моих событий, черного списка и друзей на мигание empty/error.
- [ ] Для каждого вторичного списка применить правило `previousData + refreshing indicator`.

## UX Phase 8: Verification

- [ ] Добавить widget/golden проверки стабильных размеров через `getSize`/позиции для ключевых компонентов.
- [ ] Добавить widget/golden проверку chat row: unread `0/1/99+`, avatar/time/divider не меняют позиции.
- [ ] Добавить widget/golden проверку chat message bubble: `sending/sent/failed/retry`, timestamp/status/retry slots не меняют размер bubble и позиции соседних сообщений.
- [ ] Добавить widget/golden проверку event card: loading/loaded/error participant profiles, join/leave и filter refresh не меняют высоту карточки.
- [ ] Добавить widget/golden проверку dictionary row: длинный original/translation не слипается и не выходит за min/max height.
- [ ] Добавить widget/golden проверку repeat panel: большие counts не обрезают CTA и не меняют высоту панели.
- [ ] Добавить widget/golden проверку profile blocks: avatar/email/progress/tariff cards сохраняют размеры при loading/error.
- [ ] Добавить widget/golden проверку bottom bars: chat composer/event action/repeat panel не получают double safe-area padding и не меняют внутреннюю высоту при keyboard inset.
- [ ] Добавить widget/golden проверку payments: price/package/tariff/purchase bar/cards/transactions rows сохраняют slots при loading/error.
- [ ] Добавить widget-тесты на отсутствие empty state во время первой загрузки.
- [ ] Добавить widget-тест: пустой Firestore cache snapshot без server confirmation/marker не показывает empty.
- [ ] Добавить widget-тест: `conversations + eventChats`, где один stream pending, не показывает empty.
- [ ] Добавить widget-тест: смена фильтра оставляет stale data до результата нового `activeDataKey`.
- [ ] Добавить widget-тест: пустая вторая страница pagination показывает `noMoreItems`, а не empty всего списка.
- [ ] Добавить widget-тест: cached missing detail без marker/server confirmation не показывает `notFound`.
- [ ] Добавить widget-тесты на сохранение previous data при refresh.
- [ ] Добавить widget-тесты на optimistic send message.
- [ ] Добавить widget-тесты на optimistic join/leave event.
- [ ] Добавить widget-тест: optimistic rollback возвращает empty только если последняя успешная server/cache загрузка была пустой.
- [ ] Проверить вручную вкладки `Чаты`, `События`, `Словарь`, `Профиль`.
- [ ] Проверить повторный заход на экран после навигации назад/вперед.
- [ ] Запустить `flutter analyze`.
- [ ] Запустить релевантные `flutter test`.
