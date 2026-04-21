import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  group('QA.1 release surface contracts', () {
    test(
        'chat hub keeps unlocked conversations, friends, calls, and empty state',
        () {
      final source =
          _source('lib/students_pages/favorite/favorite_widget.dart');

      expect(source, contains('conversation.isUnlocked'));
      expect(
          source,
          contains(
              'ChatThreadWidget(conversationRef: conversation.reference)'));
      expect(source,
          contains("query.where('participantIds', arrayContains: currentUid)"));
      expect(source, contains('resolveFriendsForUser(currentUserDocument)'));
      expect(source, contains('kConversationMessageTypeCallEvent'));
      expect(source, contains('formatSessionStartedAtForCard'));
      expect(source, contains('initialData: const _ConversationsLoadState()'));
      expect(source, contains('You do not have messages yet.'));
      expect(source, contains('You do not have friends yet.'));
    });

    test(
        'firestore rules allow only participant-scoped conversation inbox queries',
        () {
      final rules = _source('firebase/firestore.rules');

      expect(
        rules,
        contains('allow list: if isConversationParticipant(resource.data);'),
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
      final callEventCard =
          _source('lib/shared_pages/chat_thread/chat_call_event_card.dart');

      expect(source,
          contains('!conversation.participantIds.contains(currentUserUid)'));
      expect(source, contains('!conversation.isUnlocked'));
      expect(source, contains('This chat is not available yet.'));
      expect(
          source, contains('MessagesRecord.createDoc(conversation.reference)'));
      expect(source, contains('messageIsCallEvent(message)'));
      expect(source, contains("CallDetailsWidget.routeName"));
      expect(callEventCard, contains('Icons.videocam_rounded'));
    });

    test('email verification remains a soft profile surface', () {
      final source = _source('lib/shared_pages/profile/profile_widget.dart');
      final registration =
          _source('lib/authorization/registration/registration_widget.dart');
      final emailFunction =
          _source('firebase/custom_cloud_functions/email_verification.js');

      expect(
          source, contains('FirebaseAuth.instance.currentUser?.emailVerified'));
      expect(source, contains('sendCustomEmailVerification('));
      expect(source, contains('_refreshEmailVerificationStatus'));
      expect(source,
          contains('This does not limit calls, chats, or profile access.'));
      expect(
          registration, contains('unawaited(_sendInitialEmailVerification())'));
      expect(emailFunction, contains('generateEmailVerificationLink'));
      expect(emailFunction, contains('https://api.resend.com/emails'));
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
      expect(payCopy, contains('type: TypeTransactions.withdrawal'));
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
      expect(dashboard, contains('IgnorePointer('));
      expect(dashboard, contains('HitTestBehavior.opaque'));
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
        'lib/authorization/components/celebration_n_s/celebration_n_s_widget.dart',
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
      expect(profile, contains('isInCall: false'));
      expect(profile, contains('Подать заявку снова'));
      expect(celebration, contains('ваша заявка отправлена'));
      expect(celebration, contains('Что дальше:'));
      expect(
        celebration,
        contains('Мы сообщим, когда проверка завершится'),
      );
    });

    test('tab shell and nav bar keep profile as a shared tab', () {
      final tabShell =
          _source('lib/shared_pages/tab_shell/tab_shell_page.dart');
      final navBar = _source('lib/shared_pages/nav_bar/nav_bar_widget.dart');

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
  });
}
