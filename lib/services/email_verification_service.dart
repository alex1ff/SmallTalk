import 'package:cloud_functions/cloud_functions.dart';

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
}) async {
  final payload = <String, dynamic>{
    'locale': locale,
  };

  final responseData = await (invoker ??
      (payload) async {
        final response = await FirebaseFunctions.instance
            .httpsCallable('sendCustomEmailVerification')
            .call(payload);
        return response.data;
      })(payload);

  return parseCustomEmailVerificationResult(responseData);
}
