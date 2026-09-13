import '/backend/backend.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';

class SessionParticipantDisplayInfo {
  const SessionParticipantDisplayInfo({
    this.name = '',
    this.photoUrl = '',
  });

  final String name;
  final String photoUrl;
}

Map<String, dynamic> sessionMapData(dynamic rawValue) {
  if (rawValue is Map) {
    return rawValue.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
  return const <String, dynamic>{};
}

String sessionMapText(
  Map<String, dynamic> data,
  Iterable<String> keys,
) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}

SessionParticipantDisplayInfo resolveSessionRequesterDisplayInfo(
  VideoSessionsRecord session,
) {
  final requesterId = resolveSessionRequesterId(session.snapshotData);
  final participantInfo = _participantInfo(session, requesterId);
  final participantName = _displayName(participantInfo);
  final participantPhotoUrl = _photoUrl(participantInfo);
  if (participantName.isNotEmpty || participantPhotoUrl.isNotEmpty) {
    return SessionParticipantDisplayInfo(
      name: participantName,
      photoUrl: participantPhotoUrl,
    );
  }

  final requesterInfo = sessionMapData(session.snapshotData['requesterInfo']);
  final requesterInfoName = _displayName(requesterInfo);
  final requesterInfoPhotoUrl = _photoUrl(requesterInfo);
  if (requesterInfoName.isNotEmpty || requesterInfoPhotoUrl.isNotEmpty) {
    return SessionParticipantDisplayInfo(
      name: requesterInfoName,
      photoUrl: requesterInfoPhotoUrl,
    );
  }

  if (requesterId == session.studentId.trim()) {
    return SessionParticipantDisplayInfo(
      name: session.studentInfo.name.trim(),
      photoUrl: session.studentInfo.photo.trim(),
    );
  }

  return const SessionParticipantDisplayInfo();
}

SessionParticipantDisplayInfo resolveSessionResponderDisplayInfo(
  VideoSessionsRecord session,
) {
  final responderId = resolveSessionResponderId(session.snapshotData);
  final participantInfo = _participantInfo(session, responderId);
  final participantName = _displayName(participantInfo);
  final participantPhotoUrl = _photoUrl(participantInfo);
  if (participantName.isNotEmpty || participantPhotoUrl.isNotEmpty) {
    return SessionParticipantDisplayInfo(
      name: participantName,
      photoUrl: participantPhotoUrl,
    );
  }

  final acceptedResponderInfo = sessionMapData(
    _sessionMatchContext(session)['acceptedResponderInfo'],
  );
  final acceptedResponderId = sessionMapText(
    _sessionMatchContext(session),
    const ['acceptedResponderId'],
  );
  if (acceptedResponderId.isEmpty || acceptedResponderId == responderId) {
    final acceptedResponderName = _displayName(acceptedResponderInfo);
    final acceptedResponderPhotoUrl = _photoUrl(acceptedResponderInfo);
    if (acceptedResponderName.isNotEmpty ||
        acceptedResponderPhotoUrl.isNotEmpty) {
      return SessionParticipantDisplayInfo(
        name: acceptedResponderName,
        photoUrl: acceptedResponderPhotoUrl,
      );
    }
  }

  if (responderId == session.tutorId.trim() ||
      responderId == session.currentTutorId.trim()) {
    return SessionParticipantDisplayInfo(
      name: session.tutorInfo.name.trim(),
      photoUrl: session.tutorInfo.photo.trim(),
    );
  }

  return const SessionParticipantDisplayInfo();
}

SessionParticipantDisplayInfo resolveSessionParticipantDisplayInfo({
  required VideoSessionsRecord session,
  required String? userId,
}) {
  final normalizedUserId = userId?.trim() ?? '';
  if (normalizedUserId.isEmpty) {
    return const SessionParticipantDisplayInfo();
  }

  if (normalizedUserId == resolveSessionRequesterId(session.snapshotData)) {
    return resolveSessionRequesterDisplayInfo(session);
  }

  if (normalizedUserId == resolveSessionResponderId(session.snapshotData)) {
    return resolveSessionResponderDisplayInfo(session);
  }

  if (normalizedUserId == session.studentId.trim()) {
    return SessionParticipantDisplayInfo(
      name: session.studentInfo.name.trim(),
      photoUrl: session.studentInfo.photo.trim(),
    );
  }

  if (normalizedUserId == session.tutorId.trim() ||
      normalizedUserId == session.currentTutorId.trim()) {
    return SessionParticipantDisplayInfo(
      name: session.tutorInfo.name.trim(),
      photoUrl: session.tutorInfo.photo.trim(),
    );
  }

  return const SessionParticipantDisplayInfo();
}

Map<String, dynamic> _sessionMatchContext(VideoSessionsRecord session) {
  return sessionMapData(session.snapshotData['matchContext']);
}

Map<String, dynamic> _participantInfo(
  VideoSessionsRecord session,
  String? userId,
) {
  final normalizedUserId = userId?.trim() ?? '';
  if (normalizedUserId.isEmpty) {
    return const <String, dynamic>{};
  }

  final participantInfos =
      sessionMapData(session.snapshotData['participantInfos']);
  return sessionMapData(participantInfos[normalizedUserId]);
}

String _displayName(Map<String, dynamic> data) {
  return sessionMapText(data, const ['displayName', 'name']);
}

String _photoUrl(Map<String, dynamic> data) {
  return sessionMapText(data, const ['photoUrl', 'photo']);
}
