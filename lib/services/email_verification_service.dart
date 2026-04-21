import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomEmailVerificationResult {
  const CustomEmailVerificationResult({
    required this.sent,
    required this.alreadyVerified,
    this.providerMessageId,
  });

  final bool sent;
  final bool alreadyVerified;
  final String? providerMessageId;
}

typedef CustomEmailVerificationInvoker = Future<Object?> Function(
  Map<String, dynamic> payload,
);

typedef FirebaseEmailVerificationFallback = Future<void> Function();

CustomEmailVerificationResult parseCustomEmailVerificationResult(Object? data) {
  final response = data is Map
      ? data.map(
          (key, value) => MapEntry(key.toString(), value),
        )
      : const <String, dynamic>{};

  return CustomEmailVerificationResult(
    sent: response['sent'] == true,
    alreadyVerified: response['alreadyVerified'] == true,
    providerMessageId: response['providerMessageId']?.toString(),
  );
}

Future<CustomEmailVerificationResult> sendCustomEmailVerification({
  String locale = 'ru',
  CustomEmailVerificationInvoker? invoker,
  FirebaseEmailVerificationFallback? firebaseEmailFallback,
  bool fallbackToFirebaseDefault = true,
}) async {
  final payload = <String, dynamic>{
    'locale': locale,
  };

  try {
    final responseData = await (invoker ??
        (payload) async {
          final response = await FirebaseFunctions.instance
              .httpsCallable('sendCustomEmailVerification')
              .call(payload);
          return response.data;
        })(payload);

    return parseCustomEmailVerificationResult(responseData);
  } catch (_) {
    if (!fallbackToFirebaseDefault) {
      rethrow;
    }

    await (firebaseEmailFallback ?? _sendFirebaseDefaultEmailVerification)();
    return const CustomEmailVerificationResult(
      sent: true,
      alreadyVerified: false,
      providerMessageId: 'firebase_default',
    );
  }
}

Future<void> _sendFirebaseDefaultEmailVerification() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw FirebaseAuthException(
      code: 'no-current-user',
      message: 'No signed-in user is available for email verification.',
    );
  }

  await user.sendEmailVerification();
}
