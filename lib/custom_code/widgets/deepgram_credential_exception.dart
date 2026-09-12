class DeepgramCredentialException implements Exception {
  const DeepgramCredentialException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => 'DeepgramCredentialException($code): $message';
}
