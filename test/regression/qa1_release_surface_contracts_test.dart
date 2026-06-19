import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  group('QA.1 release surface contracts', () {
    test('chat hub keeps unlocked conversations, friends, and empty state', () {
      final source =
          _source('lib/students_pages/favorite/favorite_widget.dart');

      expect(source, contains('conversation.isUnlocked'));
      expect(source, contains('openChatThread('));
      expect(
        _source('lib/shared_pages/chat_thread/open_chat_thread.dart'),
        contains('Navigator.of(context, rootNavigator: true).push'),
      );
      expect(source, contains("FieldPath(['participantMap', currentUid])"));
      expect(source, contains('resolveFriendsForUser(userDocument)'));
      expect(source, contains('kConversationMessageTypeCallEvent'));
      expect(source, contains('conversationPartnerIsFriend'));
      expect(
        source,
        contains('UserPublicProfilesRecord.maybeGetDocumentOnce'),
      );
      expect(
        source,
        contains('FutureBuilder<UserPublicProfilesRecord?>'),
      );
      expect(source, contains('_userProfileCacheByUid'));
      expect(source, contains('initialData: _cachedUserProfile(partnerRef)'));
      expect(source, contains('_friendsCacheByUid'));
      expect(source, isNot(contains('final partnerIdentityLoading')));
      expect(source, isNot(contains('_buildChatPartnerNamePlaceholder')));
      expect(source, isNot(contains('SpinKitCircle')));
      expect(source, contains("ruText: 'Собеседник'"));
      expect(source, isNot(contains("ruText: 'Пользователь'")));
      expect(source,
          isNot(contains('initialData: const _ConversationsLoadState()')));
      expect(source, contains('_conversationStateCacheByUid'));
      expect(source, contains('_cachedConversationsStateForUser(currentUid)'));
      expect(source, isNot(contains('_buildMessagesLoadingList')));
      expect(source, isNot(contains('_conversationLoadingCard')));
      expect(source, contains('_conversationsStreamUid'));
      expect(source,
          contains('loadedConversations.sort(compareConversationsForInbox)'));
      expect(source, contains('ListView.builder'));
      expect(source, isNot(contains('SingleChildScrollView(')));
      expect(source, contains('You do not have messages yet.'));
      expect(source, contains('You do not have chats with friends yet.'));
      expect(source, isNot(contains('UsersRecord.getDocumentOnce(ref)')));
      expect(source, isNot(contains('fetchRecentHubCallSessions')));
      expect(source, isNot(contains("ruText: 'Звонки'")));
    });

    test(
        'firestore rules allow only participant-scoped conversation inbox queries',
        () {
      final rules = _source('firebase/firestore.rules');

      expect(
        rules,
        contains('data.participantMap[request.auth.uid] == true;'),
      );
      expect(
        rules,
        contains(
            'allow list: if isConversationParticipantByMap(resource.data);'),
      );
      expect(
        _source(
            'firebase/custom_cloud_functions/conversation_message_summaries.js'),
        contains('buildParticipantMapRepair'),
      );
      expect(
        rules,
        contains('allow get: if isConversationParticipant(resource.data);'),
      );
      expect(rules, isNot(contains('!conversationExists(pairId)')));
      expect(rules, contains("request.resource.data.type == 'text'"));
    });

    test('chat thread fails closed for locked or non-participant conversations',
        () {
      final source =
          _source('lib/shared_pages/chat_thread/chat_thread_widget.dart');
      final callEventCard = _source('lib/components/chat_call_event_card.dart');

      expect(source,
          contains('!conversation.participantIds.contains(currentUserUid)'));
      expect(source, contains('!conversation.isUnlocked'));
      expect(source, contains('This chat is not available yet.'));
      expect(
          source, contains('MessagesRecord.createDoc(conversation.reference)'));
      expect(source, contains('messageIsCallEvent(message)'));
      expect(source, contains('buildAddFriendUpdateData'));
      expect(source, contains('buildRemoveFriendUpdateData'));
      expect(source, contains('CallDetailsWidget(videoDocRef: sessionRef)'));
      expect(source, contains('Navigator.of(context, rootNavigator: true)'));
      expect(
        _source('lib/shared_pages/chat_thread/open_chat_thread.dart'),
        contains('initialConversation: initialConversation'),
      );
      expect(source, isNot(contains('!partnerSnapshot.hasData')));
      expect(source, contains('CachedNetworkImage('));
      expect(source, contains('memCacheWidth:'));
      expect(source, contains('reverse: true'));
      expect(source, contains("descending: true"));
      expect(source, contains('limit: _messageLimit'));
      expect(source, contains('_messagePageSize'));
      expect(
          source,
          contains(
              'conversationIsUnreadForUser(conversation, currentUserUid)'));
      expect(source, contains('_scheduleMarkConversationRead(conversation)'));
      expect(source, isNot(contains('jumpTo(position.maxScrollExtent)')));
      expect(source, isNot(contains('..sort(compareMessagesForThread)')));
      expect(source, contains('height: 44.0'));
      expect(source, contains('height: 35.0'));
      expect(source, contains('ExcludeSemantics('));
      expect(
        _source('lib/shared_pages/call_details/call_details_widget.dart'),
        contains('!sessionDoc.exists || sessionDoc.data() == null'),
      );
      expect(callEventCard, contains('Icons.phone_rounded'));
    });

    test('minimal call surface persists own in-call chat after session end',
        () {
      final source =
          _source('lib/custom_code/widgets/minimal_daily_widget.dart');
      final functionIndex = _source('firebase/custom_cloud_functions/index.js');
      final persistFunction =
          _source('firebase/custom_cloud_functions/persist_call_chat.js');

      expect(source, contains("httpsCallable('persistCallChat')"));
      expect(source, contains('_ownSentChatMessages.add(message)'));
      expect(source, contains('_endSessionAndPersistCallChat'));
      expect(source, contains('ValueListenableBuilder<int>'));
      expect(source, contains("ValueKey(showRemoteVideo"));
      expect(functionIndex, contains('exports.persistCallChat'));
      expect(persistFunction, contains('inCallSessionRef'));
      expect(persistFunction, contains('incall'));
      expect(persistFunction, contains('call_event_persisted'));
    });

    test('email verification remains a soft profile surface', () {
      final source = _source('lib/shared_pages/profile/profile_widget.dart');
      final registration =
          _source('lib/authorization/registration/registration_widget.dart');
      final emailFunction =
          _source('firebase/custom_cloud_functions/email_verification.js');
      final emailService =
          _source('lib/services/email_verification_service.dart');

      expect(
          source, contains('FirebaseAuth.instance.currentUser?.emailVerified'));
      expect(source, contains('sendCustomEmailVerification('));
      expect(source, contains('_refreshEmailVerificationStatus'));
      expect(source, contains('Timer.periodic('));
      expect(source, contains('_emailVerificationPollTimer'));
      expect(source, contains('_profileHeaderCard(context)'));
      expect(source, isNot(contains('Refresh status')));
      expect(
          registration, contains('unawaited(_sendInitialEmailVerification())'));
      expect(emailFunction, contains('generateEmailVerificationLink'));
      expect(emailFunction, contains('https://api.resend.com/emails'));
      expect(emailService, contains('sendEmailVerification()'));
      expect(emailService, contains("providerMessageId: 'firebase_default'"));
    });

    test('teacher finance surfaces remain gated by approved teacher access',
        () {
      final profile = _source('lib/shared_pages/profile/profile_widget.dart');
      final payCopy =
          _source('lib/teachers_pages/pay_copy/pay_copy_widget.dart');
      final myRewNS =
          _source('lib/teachers_pages/my_rew_n_s/my_rew_n_s_widget.dart');
      final userMatchProfile = _source('lib/services/user_match_profile.dart');

      expect(
        userMatchProfile,
        contains(
            'user?.role == UserRole.native_speaker && isUserApprovedTeacher(user)'),
      );
      expect(
        profile,
        contains('if (loggedIn && currentUserDocument == null)'),
      );
      expect(profile, contains('if (canAccessTeacherSurfaces('));
      expect(profile, contains('context.pushNamed(PayCopyWidget.routeName)'));
      expect(profile, contains('context.pushNamed(PayWidget.routeName)'));
      expect(payCopy, contains('return AuthUserStreamWidget('));
      expect(
        payCopy,
        contains('if (loggedIn && currentUserDocument == null)'),
      );
      expect(
          payCopy, contains('!canAccessTeacherSurfaces(currentUserDocument)'));
      expect(payCopy, contains("httpsCallable('requestWithdrawal')"));
      expect(myRewNS, contains('return AuthUserStreamWidget('));
      expect(
        myRewNS,
        contains('if (loggedIn && currentUserDocument == null)'),
      );
      expect(
        myRewNS,
        contains('_model.reviewsFuture ??= queryReviewsRecordOnce('),
      );
    });

    test('pending native-speaker shell keeps dashboard card and online guard',
        () {
      final dashboard =
          _source('lib/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart');
      final availabilitySwitch =
          _source('lib/components/teacher_availability_switch_control.dart');
      final userMatchProfile = _source('lib/services/user_match_profile.dart');
      final loadingRoute = _source(
        'lib/authorization/loading/loading_route_logic.dart',
      );
      final tabShell =
          _source('lib/shared_pages/tab_shell/tab_shell_page.dart');
      final acceptCall =
          _source('firebase/custom_cloud_functions/accept_call.js');

      expect(userMatchProfile, contains('canUseNativeSpeakerShell'));
      expect(
        tabShell,
        contains('loggedIn && currentUserDocument == null'),
      );
      expect(
        tabShell,
        contains(
            '!isAwaitingUserDocument && _pathsWithNavBar.contains(currentPath)'),
      );
      expect(
        dashboard,
        contains("'/components/teacher_availability_switch_control.dart'"),
      );
      expect(
        dashboard,
        contains("'/components/pending_teacher_review_card.dart'"),
      );
      expect(
        dashboard,
        contains("'/components/pending_teacher_review_bottom_sheet.dart'"),
      );
      expect(
        dashboard,
        contains('AvailabilitySwitchControl('),
      );
      expect(
        dashboard,
        contains('_reloadAvailabilityGuardUser()'),
      );
      expect(
        dashboard,
        contains('_effectiveAvailabilityEnabled'),
      );
      expect(
        dashboard,
        contains('_effectiveSwitchValue'),
      );
      expect(
        dashboard,
        contains('() => _model.switchValue = false'),
      );
      expect(dashboard, contains('PendingTeacherReviewCard'));
      expect(dashboard, contains('PendingTeacherReviewBottomSheet'));
      expect(availabilitySwitch, contains('IgnorePointer('));
      expect(availabilitySwitch, contains('HitTestBehavior.opaque'));
      expect(dashboard, contains('_handlePendingAvailabilitySwitchTap'));
      expect(
        dashboard,
        contains('if (canAccessTeacherSurfaces(currentUserDocument))'),
      );
      expect(
        dashboard,
        contains('if (!_canUseTeacherShell)'),
      );
      expect(
        dashboard,
        contains('if (loggedIn && currentUserDocument == null)'),
      );
      expect(dashboard, contains('return AuthUserStreamWidget('));
      expect(
        dashboard,
        contains(
            'context.goNamed(\n        StudentsDashboardWidget.routeName,'),
      );
      expect(loadingRoute, contains('canUseNativeSpeakerShell = false'));
      expect(
        loadingRoute,
        contains('LoadingRouteDestination.dashboardNativeSpeaker'),
      );
      expect(
        acceptCall,
        contains(
            'tutorRole === "native_speaker" && !isApprovedTeacher(tutorData)'),
      );
      expect(acceptCall, contains('Teacher verification is pending'));
    });

    test('profile uses teacher-track action helper for reapply flow', () {
      final profile = _source('lib/shared_pages/profile/profile_widget.dart');
      final userMatchProfile = _source('lib/services/user_match_profile.dart');
      final celebration = _source(
        'lib/components/celebration_n_s_widget.dart',
      );

      expect(
        userMatchProfile,
        contains('TeacherTrackProfileAction.reapply'),
      );
      expect(
        userMatchProfile,
        contains('bool canRestoreNativeSpeakerTrack('),
      );
      expect(profile, contains('return AuthUserStreamWidget('));
      expect(profile, contains('resolveTeacherTrackProfileAction('));
      expect(profile, contains('teacherVerificationRequestRefForUser('));
      expect(profile, contains('canRestoreNativeSpeakerTrack('));
      expect(
        profile,
        contains('shouldMirrorPendingTeacherStatusOnRestore('),
      );
      expect(profile, contains('ensureCanonicalCurrentUserDocument('));
      expect(profile, contains('DashboardNSWidget.routeName'));
      expect(profile, contains('availabilityToday:'));
      expect(
        profile,
        contains('role: UserRole.native_speaker'),
      );
      expect(
        profile,
        contains("studentTrackUpdate['availabilityToday']"),
      );
      expect(profile, contains('FieldValue.delete()'));
      expect(profile, isNot(contains('isInCall: false')));
      expect(profile, contains('Подать заявку снова'));
      expect(celebration, contains('ваша заявка отправлена'));
      expect(celebration, contains('Что дальше:'));
      expect(
        celebration,
        contains('Мы сообщим, когда проверка завершится'),
      );
    });

    test('native speaker celebration next steps stay compact', () {
      final celebration = _source(
        'lib/components/celebration_n_s_widget.dart',
      );

      expect(
        RegExp('После одобрения вы сможете').allMatches(celebration).length,
        1,
      );
      expect(celebration, contains('Expanded('));
      expect(celebration, contains('child: Text('));
    });

    test('celebration confetti does not intercept bottom sheet actions', () {
      final studentCelebration = _source(
        'lib/components/celebration_s_t_widget.dart',
      );
      final teacherCelebration = _source(
        'lib/components/celebration_n_s_widget.dart',
      );

      expect(studentCelebration, contains('IgnorePointer('));
      expect(teacherCelebration, contains('IgnorePointer('));
      expect(studentCelebration, contains('Confetti_Animation.json'));
      expect(teacherCelebration, contains('Confetti_Animation.json'));
    });

    test('tab shell and nav bar keep profile as a shared tab', () {
      final tabShell =
          _source('lib/shared_pages/tab_shell/tab_shell_page.dart');
      final navBar = _source('lib/components/nav_bar_widget.dart');

      expect(tabShell, contains('DashboardNSWidget.routePath,'));
      expect(tabShell, contains('StudentsDashboardWidget.routePath,'));
      expect(tabShell, contains('WordsWidget.routePath,'));
      expect(tabShell, contains('FavoriteWidget.routePath,'));
      expect(tabShell, contains('ProfileWidget.routePath,'));
      expect(tabShell,
          contains('List<String> get _pathsWithNavBar => _tabPathsOrdered;'));
      expect(navBar, contains("ruText: 'Профиль'"));
      expect(navBar, contains("enText: 'Profile'"));
      expect(navBar,
          contains('context.goNamed(\n          ProfileWidget.routeName,'));
      expect(navBar, contains('FFIcons.kuser03'));
      expect(navBar, contains("icon: 'person.fill'"));
    });

    test('dashboard headers no longer expose a duplicate profile button', () {
      final studentDashboard = _source(
          'lib/students_pages/students_dashboard/students_dashboard_widget.dart');
      final teacherDashboard =
          _source('lib/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart');

      expect(studentDashboard,
          isNot(contains('context.pushNamed(ProfileWidget.routeName)')));
      expect(teacherDashboard,
          isNot(contains('context.pushNamed(ProfileWidget.routeName)')));
      expect(studentDashboard, isNot(contains('FFIcons.kuser03')));
      expect(teacherDashboard, isNot(contains('FFIcons.kuser03')));
    });

    test(
        'student dashboard hides passive availability switch for all-to-all calls',
        () {
      final studentDashboard = _source(
          'lib/students_pages/students_dashboard/students_dashboard_widget.dart');
      final waitingPage = _source(
          'lib/students_pages/waiting_for_teacher_page/waiting_for_teacher_page_widget.dart');

      expect(studentDashboard, isNot(contains('AddInterWidget()')));
      expect(
          studentDashboard,
          isNot(contains(
              "import '/components/student_availability_switch_control.dart';")));
      expect(
          File('lib/components/student_availability_switch_control.dart')
              .existsSync(),
          isFalse);
      expect(studentDashboard,
          isNot(contains('StudentAvailabilitySwitchControl(')));
      expect(studentDashboard, isNot(contains('_buildAvailabilitySwitch')));
      expect(studentDashboard,
          isNot(contains('_handleAvailabilitySwitchChanged')));
      expect(studentDashboard, isNot(contains('AvailabilityScheduleCard(')));
      expect(studentDashboard, isNot(contains('_buildAvailabilitySection')));
      expect(studentDashboard,
          isNot(contains('_buildAnimatedAvailabilitySection')));
      expect(studentDashboard, isNot(contains('availabilityToday:')));
      expect(studentDashboard, contains('_studentUserUpdate'));
      expect(studentDashboard,
          contains("'availabilityToday': FieldValue.delete()"));
      expect(
          studentDashboard, isNot(contains('createAvailabilityTodayStruct')));
      expect(studentDashboard, isNot(contains('getIntervalsFirestoreData')));
      expect(studentDashboard, isNot(contains('updateIntervalsStruct')));
      expect(studentDashboard, isNot(contains('isInCall: false')));
      expect(studentDashboard, isNot(contains('FieldValue.arrayRemove')));
      expect(studentDashboard,
          isNot(contains('hasPendingTeacherVerification(latestUser)')));
      expect(waitingPage, contains('свободных собеседников'));
      expect(waitingPage, isNot(contains('свободных преподавателей')));
    });
  });
}
