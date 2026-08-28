import 'package:cloud_functions/cloud_functions.dart';

typedef PasswordResetInvoker = Future<Object?> Function(
  Map<String, dynamic> payload,
);

class PasswordResetRequestResult {
  const PasswordResetRequestResult({required this.accepted});

  final bool accepted;
}

PasswordResetRequestResult parsePasswordResetRequestResult(Object? data) {
  final response = data is Map
      ? data.map((key, value) => MapEntry(key.toString(), value))
      : const <String, dynamic>{};
  return PasswordResetRequestResult(accepted: response['accepted'] == true);
}

Future<PasswordResetRequestResult> requestPasswordReset({
  required String email,
  String locale = 'ru',
  PasswordResetInvoker? invoker,
}) async {
  final payload = <String, dynamic>{
    'email': email.trim(),
    'locale': locale,
  };
  final responseData = await (invoker ??
      (payload) async {
        final response = await FirebaseFunctions.instance
            .httpsCallable(
              'requestPasswordReset',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 20),
              ),
            )
            .call(payload);
        return response.data;
      })(payload);

  final result = parsePasswordResetRequestResult(responseData);
  if (!result.accepted) {
    throw StateError('Password reset request was not accepted.');
  }
  return result;
}
