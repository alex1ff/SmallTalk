import '/backend/schema/enums/enums.dart';

class PendingSocialAuthContext {
  const PendingSocialAuthContext({
    required this.providerId,
    required this.sourceScreen,
    required this.roleIntent,
    required this.createdAt,
    this.authUid,
  });

  static const maxAge = Duration(minutes: 10);

  final String providerId;
  final String sourceScreen;
  final UserRole roleIntent;
  final DateTime createdAt;
  final String? authUid;

  PendingSocialAuthContext copyWith({
    String? providerId,
    String? sourceScreen,
    UserRole? roleIntent,
    DateTime? createdAt,
    String? authUid,
    bool clearAuthUid = false,
  }) {
    return PendingSocialAuthContext(
      providerId: providerId ?? this.providerId,
      sourceScreen: sourceScreen ?? this.sourceScreen,
      roleIntent: roleIntent ?? this.roleIntent,
      createdAt: createdAt ?? this.createdAt,
      authUid: clearAuthUid ? null : authUid ?? this.authUid,
    );
  }

  bool isValidFor({
    String? currentAuthUid,
    DateTime? now,
  }) {
    if (providerId.trim().isEmpty || sourceScreen.trim().isEmpty) {
      return false;
    }

    final resolvedNow = now ?? DateTime.now();
    if (resolvedNow.difference(createdAt) > maxAge) {
      return false;
    }

    final expectedUid = authUid?.trim();
    final actualUid = currentAuthUid?.trim();
    if (expectedUid != null &&
        expectedUid.isNotEmpty &&
        actualUid != null &&
        actualUid.isNotEmpty &&
        expectedUid != actualUid) {
      return false;
    }

    return true;
  }

  Map<String, dynamic> toSerializableMap() => <String, dynamic>{
        'providerId': providerId,
        'sourceScreen': sourceScreen,
        'roleIntent': roleIntent.serialize(),
        'createdAtMillis': createdAt.millisecondsSinceEpoch,
        'authUid': authUid,
      };

  static PendingSocialAuthContext? maybeFromMap(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final providerId = value['providerId']?.toString().trim() ?? '';
    final sourceScreen = value['sourceScreen']?.toString().trim() ?? '';
    final roleIntent = deserializeEnum<UserRole>(value['roleIntent']);
    final createdAtMillis = value['createdAtMillis'];
    final authUid = value['authUid']?.toString();

    if (providerId.isEmpty ||
        sourceScreen.isEmpty ||
        roleIntent == null ||
        createdAtMillis is! int) {
      return null;
    }

    return PendingSocialAuthContext(
      providerId: providerId,
      sourceScreen: sourceScreen,
      roleIntent: roleIntent,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
      authUid: authUid,
    );
  }
}
