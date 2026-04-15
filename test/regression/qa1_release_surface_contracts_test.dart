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
      expect(source, contains('resolveFriendsForUser(currentUserDocument)'));
      expect(source, contains('formatSessionStartedAtForCard'));
      expect(source, contains('Empty. You do not have calls or messages yet'));
    });

    test('chat thread fails closed for locked or non-participant conversations',
        () {
      final source =
          _source('lib/shared_pages/chat_thread/chat_thread_widget.dart');

      expect(source,
          contains('!conversation.participantIds.contains(currentUserUid)'));
      expect(source, contains('!conversation.isUnlocked'));
      expect(source, contains('This chat is not available yet.'));
      expect(
          source, contains('MessagesRecord.createDoc(conversation.reference)'));
    });

    test('email verification remains a soft profile surface', () {
      final source = _source('lib/shared_pages/profile/profile_widget.dart');

      expect(
          source, contains('FirebaseAuth.instance.currentUser?.emailVerified'));
      expect(source, contains('authManager.sendEmailVerification()'));
      expect(source, contains('_refreshEmailVerificationStatus'));
      expect(source,
          contains('This does not limit calls, chats, or profile access.'));
    });

    test('teacher finance surfaces remain gated by approved teacher access',
        () {
      final profile = _source('lib/shared_pages/profile/profile_widget.dart');
      final payCopy =
          _source('lib/teachers_pages/pay_copy/pay_copy_widget.dart');
      final userMatchProfile = _source('lib/services/user_match_profile.dart');

      expect(
        userMatchProfile,
        contains(
            'user?.role == UserRole.native_speaker && isUserApprovedTeacher(user)'),
      );
      expect(
          profile, contains('canAccessTeacherSurfaces(currentUserDocument)'));
      expect(profile, contains('context.pushNamed(PayCopyWidget.routeName)'));
      expect(profile, contains('context.pushNamed(PayWidget.routeName)'));
      expect(
          payCopy, contains('!canAccessTeacherSurfaces(currentUserDocument)'));
      expect(payCopy, contains('type: TypeTransactions.withdrawal'));
    });
  });
}
