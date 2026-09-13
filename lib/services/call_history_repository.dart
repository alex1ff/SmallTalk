import 'package:cloud_functions/cloud_functions.dart';

import '/backend/backend.dart';
import '/shared_pages/call_history/call_history_utils.dart';

typedef CallHistoryCallableInvoker = Future<Object?> Function(
  String functionName,
  Map<String, dynamic> payload,
);

const getCallHistoryFunctionName = 'getCallHistory';
const getCallHistoryFunctionRegion = 'europe-west1';
const callHistoryDefaultLimit = 100;
const callHistoryMaxLimit = 200;

class CallHistoryRepository {
  const CallHistoryRepository._();

  static Future<List<VideoSessionsRecord>> loadCallHistorySessions({
    required String userId,
    int limit = callHistoryDefaultLimit,
    CallHistoryCallableInvoker? invoker,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return const <VideoSessionsRecord>[];
    }

    final normalizedLimit = normalizeCallHistoryLimit(limit);
    final responseData = await _callCallHistoryFunction(
      getCallHistoryFunctionName,
      <String, dynamic>{'limit': normalizedLimit},
      invoker: invoker,
    );
    final paths = parseCallHistoryPathsResponse(responseData);
    final sessions = await Future.wait(
      paths.map(
          (path) => VideoSessionsRecord.getDocumentOnce(_sessionRef(path))),
    );
    return mergeCallHistorySessionsForUser([sessions], normalizedUserId);
  }
}

int normalizeCallHistoryLimit(int limit) {
  if (limit < 1 || limit > callHistoryMaxLimit) {
    throw ArgumentError.value(
      limit,
      'limit',
      'Expected call history limit from 1 to $callHistoryMaxLimit.',
    );
  }
  return limit;
}

List<String> parseCallHistoryPathsResponse(Object? responseData) {
  final data = _responseMap(responseData);
  return _requiredList(data, 'paths')
      .map(_requiredSessionPath)
      .toList(growable: false);
}

Future<Object?> _callCallHistoryFunction(
  String functionName,
  Map<String, dynamic> payload, {
  CallHistoryCallableInvoker? invoker,
}) async {
  if (invoker != null) {
    return invoker(functionName, payload);
  }
  final response = await FirebaseFunctions.instanceFor(
    region: getCallHistoryFunctionRegion,
  ).httpsCallable(functionName).call(payload);
  return response.data;
}

DocumentReference _sessionRef(String path) {
  return FirebaseFirestore.instance.doc(path);
}

Map<String, dynamic> _responseMap(Object? data) {
  if (data is! Map) {
    throw const FormatException('Expected call history response map.');
  }
  final result = <String, dynamic>{};
  for (final entry in data.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const FormatException(
        'Expected call history response map with string keys.',
      );
    }
    result[key] = entry.value;
  }
  return result;
}

List<Object?> _requiredList(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is List) {
    return value.cast<Object?>();
  }
  throw FormatException('Expected list field "$field".');
}

String _requiredSessionPath(Object? value) {
  if (value is! String) {
    throw const FormatException('Expected call history session path string.');
  }
  final path = value.trim();
  final match = RegExp(r'^videoSessions/[^/]+$').firstMatch(path);
  if (match == null) {
    throw FormatException('Invalid call history session path "$path".');
  }
  return path;
}
