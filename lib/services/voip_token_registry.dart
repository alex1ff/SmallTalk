typedef VoipTokenRegistrationInvoker = Future<void> Function(
  Map<String, dynamic> payload,
);
typedef VoipPushKitTokenReader = Future<dynamic> Function();

/// Keeps token transport and platform policy out of the VoIP lifecycle facade.
class VoipTokenRegistry {
  const VoipTokenRegistry({
    required this.currentUserId,
    required this.invokeRegistration,
    required this.readPushKitToken,
    required this.clientPlatform,
    required this.matchProtocolVersion,
    required this.log,
  });

  final String? Function() currentUserId;
  final VoipTokenRegistrationInvoker invokeRegistration;
  final VoipPushKitTokenReader readPushKitToken;
  final String Function() clientPlatform;
  final int Function() matchProtocolVersion;
  final void Function(String message) log;

  Future<void> saveFcmToken(String token) async {
    await _saveToken(tokenType: 'fcm', token: token);
  }

  Future<void> savePushKitToken(String token) async {
    await _saveToken(tokenType: 'pushkit', token: token);
  }

  Future<void> removeRegisteredToken(String tokenType) async {
    if (currentUserId() == null) return;
    try {
      await invokeRegistration(<String, dynamic>{
        'removeTokenType': tokenType,
        'platform': clientPlatform(),
        'matchProtocolVersion': matchProtocolVersion(),
      });
    } catch (error) {
      log('VoIP token removal failed: $error');
    }
  }

  Future<void> clearRegisteredTokens() async {
    if (currentUserId() == null) return;
    try {
      await invokeRegistration(<String, dynamic>{
        'clearAll': true,
        'matchProtocolVersion': matchProtocolVersion(),
      });
    } catch (error) {
      log('VoIP token clear failed: $error');
    }
  }

  Future<void> syncPushKitToken() async {
    if (clientPlatform() != 'ios') return;
    try {
      final token = await readPushKitToken();
      if (token is! String) return;
      if (token.trim().isEmpty) {
        await removeRegisteredToken('pushkit');
      } else {
        await savePushKitToken(token);
      }
    } catch (error) {
      log('PushKit token read failed: $error');
    }
  }

  Future<void> _saveToken({
    required String tokenType,
    required String token,
  }) async {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty || currentUserId() == null) return;
    try {
      await invokeRegistration(<String, dynamic>{
        'tokenType': tokenType,
        'token': trimmedToken,
        'platform': clientPlatform(),
        'matchProtocolVersion': matchProtocolVersion(),
      });
    } catch (error) {
      log('VoIP $tokenType token save failed: $error');
    }
  }
}
