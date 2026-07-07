# UX/UI Loading Optimization Tasks

Цель: убрать скачки контента, мигание пустых состояний, лишние скелетоны и задержки после действий на экранах с данными.

## UX Phase 0: Audit And Rules

- [x] Пройти основные экраны и зафиксировать места, где контент пропадает при обновлении.
- [ ] Составить список экранов с full-screen loader после первого успешного рендера.
- [ ] Зафиксировать единые состояния загрузки: `initialLoading`, `refreshing`, `hasData`, `empty`, `errorWithData`, `errorWithoutData`.
- [ ] Запретить показ empty state до завершения первой реальной загрузки данных.
- [ ] Запретить замену уже показанного контента на большой loader при refresh.
- [ ] Зафиксировать правило: error state не стирает старые данные, если они уже были показаны.
- [ ] Проверить стабильные размеры карточек, строк, аватаров, бейджей, кнопок и нижних панелей.

### Audit 2026-07-07: Content Drop Points

Scope: первый проход покрывает основные bottom-tab экраны, ключевые detail/list экраны из этих табов, звонок, post-call summary, платежи, события, словарь и вторичные списки профиля. Вне первого прохода остаются auth/onboarding, статичные legal/info страницы и чистые формы без удаленной загрузки данных.

Included route matrix:

- Student tabs: `StudentsDashboardWidget`, `WordsWidget`, `FavoriteWidget`, `ProfileWidget`, `EventListWidget`.
- Teacher tabs: `DashboardNSWidget`, `FavoriteWidget`, `ProfileWidget`, `EventListWidget`.
- Events routes: list, detail, create/edit when loading existing data, group chat, event history.
- Chat routes: conversations list, private chat thread, event group chat.
- Dictionary routes: words list, word detail, flashcard review.
- Call routes: waiting/search call, active video call, call details, call summary/review.
- Profile secondary routes: call history, event history, blacklist, student reviews, teacher reviews, native speaker profile.
- Payment routes: student paywall, teacher payout/cards/transactions.

Excluded route matrix:

- Auth and onboarding routes: excluded because they are not post-login data-list UX surfaces.
- Static/legal/info pages: excluded because they do not load changing user data.
- Pure edit/create forms without remote preload, including `ProfileEditWidget`: excluded because there is no existing content list/detail to preserve during refresh.

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
- Мои отзывы преподавателя: `lib/teachers_pages/my_rew_n_s/my_rew_n_s_widget.dart -> build -> !snapshot.hasData / empty`.
  Trigger: `cold start`, `return to screen`. До данных возвращается fullscreen `SpinKitCircle`, затем строится список или empty state.
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
- Детали звонка: `lib/shared_pages/call_details/call_details_widget.dart -> _buildCaptionLogsSection/_buildReviewSection/_buildStoredReview -> waiting/hasError/empty`.
  Trigger: `cold start`, `refresh/reconnect`, `async section update`. Caption logs stream и review-секция имеют отдельные loading/error/empty ветки, поэтому уже открытая деталка может менять блоки субтитров и review state независимо от основного контента.
- Активный звонок: `lib/shared_pages/video_call_page/video_call_page_widget.dart -> build -> videoCallPageVideoSessionsRecord == null && !hasInitialJoinCredentials`.
  Trigger: `cold start`, `refresh/reconnect`. Session stream показывает loading/media permission state; внутри страницы есть отдельные async-состояния readiness/permission.
- Итог звонка и отзыв после звонка: `lib/shared_pages/call_summary/call_summary_widget.dart -> build/_buildReviewSection/_buildStoredReview -> profile future waiting / pair review future waiting / review stream waiting`.
  Trigger: `cold start`, `return to screen`, `async section update`. Post-call summary и review submission могут прыгать между loading, формой и сохраненным отзывом.
- Черный список: `lib/shared_pages/black_list/black_list_widget.dart -> build -> ListView itemBuilder/FutureBuilder -> snapshot.connectionState == waiting`.
  Trigger: `cold start`, `return to screen`, `async section update`. Каждый пользователь внутри списка грузится отдельно; на ожидании конкретной строки показывается `SpinKitCircle` вместо стабильной строки.
- Профиль собеседника: `lib/students_pages/native_speaker_page/native_speaker_page_widget.dart -> build / stats FutureBuilder / _buildReviewsSection -> profile waiting / stats !hasData / reviews !hasData`.
  Trigger: `cold start`, `refresh/reconnect`, `async section update`. Основной public profile stream заменяет весь экран loader-ом; stats/reviews внутри страницы показывают отдельные `SpinKitCircle`.
- Оплата студента: `lib/students_pages/pay/pay_widget.dart -> _loadPackages/_priceFor/build -> _isLoadingPackages`.
  Trigger: `cold start`, `retry`, `async section update`. Цены показывают `Загрузка...`, CTA получает `isLoading`, покупка блокируется; тарифы и нижняя purchase-панель скачут между loading/недоступно/ценой.
- Карты выплат преподавателя: `lib/teachers_pages/pay_copy/pay_copy_widget.dart -> build -> cards StreamBuilder -> !snapshot.hasData`.
  Trigger: `cold start`, `refresh/reconnect`, `async section update`. Cards stream использует отдельный loading spinner, поэтому секция карт скачет независимо от остального экрана.
- Операции выплат преподавателя: `lib/teachers_pages/pay_copy/pay_copy_widget.dart -> build -> transactions StreamBuilder -> !snapshot.hasData / transactions.isEmpty`.
  Trigger: `cold start`, `refresh/reconnect`, `async section update`. Transactions stream использует отдельный loading spinner, а empty state заменяет список операций.

## UX Phase 1: Shared Loading Patterns

- [ ] Сделать общий helper/model для экранов со списками и состояниями загрузки.
- [ ] Добавить общий паттерн `previousData + refreshing indicator`.
- [ ] Унифицировать empty state через общий компонент приложения.
- [ ] Унифицировать error state для списков: ошибка поверх старых данных или компактный retry-блок.
- [ ] Убрать лишние skeleton-экраны там, где уже есть cached/previous data.
- [ ] Добавить локальный in-memory cache для данных, которые нужны только на время сессии.

## UX Phase 2: Chats List

- [ ] Сохранить последний загруженный список чатов в памяти на время сессии.
- [ ] При входе во вкладку `Чаты` сразу показывать cached list, если он есть.
- [ ] Не показывать empty state, пока не завершилась первая загрузка чатов.
- [ ] При обновлении чатов оставлять текущий список на экране.
- [ ] Event-чаты должны появляться в списке без необходимости сначала открывать чат события.
- [ ] Удаление чата сделать optimistic: строка исчезает сразу, при ошибке возвращается.
- [ ] Убрать full-screen error, если список чатов уже был загружен.
- [ ] Зафиксировать высоту строки чата.
- [ ] Зафиксировать размеры аватара, времени, unread badge и divider.
- [ ] Проверить unread badge: цифра должна появляться без скачка строки.

## UX Phase 3: Chat Detail

- [ ] При открытии чата показывать последние cached сообщения, если они есть.
- [ ] Не заменять список сообщений большим loader при reconnect/refresh.
- [ ] Отправленное сообщение добавлять в список мгновенно.
- [ ] Добавить локальный статус сообщения: `sending`, `sent`, `failed`.
- [ ] При ошибке отправки оставлять сообщение в чате со статусом ошибки и возможностью повторить.
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
- [ ] Не показывать пустые заглушки участников, если профиль еще грузится.
- [ ] Join/leave на карточке делать optimistic: кнопка, счетчик мест и участники меняются сразу.
- [ ] При ошибке join/leave откатывать optimistic-состояние и показывать короткую ошибку.

## UX Phase 5: Event Detail

- [ ] Кэшировать последний detail snapshot события на время сессии.
- [ ] При обновлении event snapshot не заменять весь экран loader-ом.
- [ ] Join/leave на странице события делать optimistic.
- [ ] Сразу менять CTA, счетчик мест и список участников после join/leave.
- [ ] Подтягивать public profiles участников параллельно с participant snapshot.
- [ ] Не показывать пустую заглушку участника, если уже был известен его профиль.
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

- [ ] Добавить widget-тесты на отсутствие empty state во время первой загрузки.
- [ ] Добавить widget-тесты на сохранение previous data при refresh.
- [ ] Добавить widget-тесты на optimistic send message.
- [ ] Добавить widget-тесты на optimistic join/leave event.
- [ ] Проверить вручную вкладки `Чаты`, `События`, `Словарь`, `Профиль`.
- [ ] Проверить повторный заход на экран после навигации назад/вперед.
- [ ] Запустить `flutter analyze`.
- [ ] Запустить релевантные `flutter test`.
