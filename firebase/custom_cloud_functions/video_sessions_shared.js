function normalizeString(value) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim();
}

function normalizeCode(value) {
  return normalizeString(value).toLowerCase();
}

function readStoredMatchProfile(userData = {}) {
  const matchProfile = userData.matchProfile;
  if (matchProfile && typeof matchProfile === "object") {
    return matchProfile;
  }
  return {};
}

const UNIVERSAL_SESSION_POLICY = Object.freeze({
  baseLimitSeconds: 5 * 60,
  warningLeadSeconds: 60,
  maxExtensionCount: 1,
  extensionSeconds: 5 * 60,
  extensionRequests: {},
  extensionApproved: false,
  effectiveLimitSeconds: 5 * 60,
});
const LEGACY_ACTIVE_SESSION_MAX_DURATION_MS = 60 * 60 * 1000;
const VIDEO_SESSION_STATUS = Object.freeze({
  SEARCHING: "searching",
  PENDING_CONFIRMATION: "pending_confirmation",
  CONNECTING: "connecting",
  ACTIVE: "active",
  CANCELLED: "cancelled",
  EXPIRED: "expired",
  ENDED: "ended",
});
const VIDEO_SESSION_CREDENTIAL_STATUSES = Object.freeze([
  VIDEO_SESSION_STATUS.CONNECTING,
  VIDEO_SESSION_STATUS.ACTIVE,
  "connected",
]);
const VIDEO_SESSION_TERMINAL_STATUSES = Object.freeze([
  VIDEO_SESSION_STATUS.CANCELLED,
  VIDEO_SESSION_STATUS.EXPIRED,
  VIDEO_SESSION_STATUS.ENDED,
]);

function readPositiveInteger(value, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) {
    return fallback;
  }
  return Math.floor(number);
}

function readNonNegativeInteger(value, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0) {
    return fallback;
  }
  return Math.floor(number);
}

function readExtensionRequests(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return {...value};
}

function buildUniversalSessionPolicy(policy = {}) {
  const baseLimitSeconds = readPositiveInteger(
    policy.baseLimitSeconds,
    UNIVERSAL_SESSION_POLICY.baseLimitSeconds,
  );
  const warningLeadSeconds = Math.min(
    readPositiveInteger(
      policy.warningLeadSeconds,
      UNIVERSAL_SESSION_POLICY.warningLeadSeconds,
    ),
    baseLimitSeconds,
  );
  const maxExtensionCount = readNonNegativeInteger(
    policy.maxExtensionCount,
    UNIVERSAL_SESSION_POLICY.maxExtensionCount,
  );
  const extensionSeconds = readPositiveInteger(
    policy.extensionSeconds,
    UNIVERSAL_SESSION_POLICY.extensionSeconds,
  );
  const effectiveLimitSeconds = Math.max(
    baseLimitSeconds,
    readPositiveInteger(
      policy.effectiveLimitSeconds,
      UNIVERSAL_SESSION_POLICY.effectiveLimitSeconds,
    ),
  );

  return {
    baseLimitSeconds,
    warningLeadSeconds,
    maxExtensionCount,
    extensionSeconds,
    extensionRequests: readExtensionRequests(policy.extensionRequests),
    extensionApproved: policy.extensionApproved === true,
    effectiveLimitSeconds,
  };
}

function getSessionPolicyEffectiveLimitSeconds(policy = {}) {
  return buildUniversalSessionPolicy(policy).effectiveLimitSeconds;
}

function getSessionPolicyExpiresAt(policy = {}, nowMillis = Date.now()) {
  const safeNowMillis = Number.isFinite(Number(nowMillis))
    ? Number(nowMillis)
    : Date.now();
  return new Date(
    safeNowMillis + getSessionPolicyEffectiveLimitSeconds(policy) * 1000,
  );
}

function readPolicyBackedSessionPolicy(sessionData = {}) {
  const policy = sessionData.sessionPolicy;
  if (!policy || typeof policy !== "object" || Array.isArray(policy)) {
    return null;
  }
  return buildUniversalSessionPolicy(policy);
}

function buildInitialSessionPolicyState(nowMillis = Date.now()) {
  const sessionPolicy = buildUniversalSessionPolicy();
  return {
    sessionPolicy,
    expiresAt: getSessionPolicyExpiresAt(sessionPolicy, nowMillis),
    maxDurationMs:
      getSessionPolicyEffectiveLimitSeconds(sessionPolicy) * 1000,
  };
}

function buildAcceptedSessionPolicyState(
  sessionData = {},
  nowMillis = Date.now(),
) {
  const sessionPolicy = readPolicyBackedSessionPolicy(sessionData);
  if (!sessionPolicy) {
    const safeNowMillis = Number.isFinite(Number(nowMillis))
      ? Number(nowMillis)
      : Date.now();
    return {
      sessionPolicy: null,
      expiresAt: new Date(
        safeNowMillis + LEGACY_ACTIVE_SESSION_MAX_DURATION_MS,
      ),
      maxDurationMs: LEGACY_ACTIVE_SESSION_MAX_DURATION_MS,
    };
  }

  return {
    sessionPolicy,
    expiresAt: getSessionPolicyExpiresAt(sessionPolicy, nowMillis),
    maxDurationMs:
      getSessionPolicyEffectiveLimitSeconds(sessionPolicy) * 1000,
  };
}

function readStoredCodeList(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((entry) => readLanguageCode(entry))
    .filter(Boolean);
}

function normalizeRole(rawRole) {
  const normalized = normalizeCode(rawRole)
    .replace(/\./g, "_")
    .replace(/[\s-]+/g, "_");

  if (normalized === "teacher" || normalized === "tutor") {
    return "native_speaker";
  }

  return normalized;
}

function isSupportedSessionRole(rawRole) {
  const normalized = normalizeRole(rawRole);
  return normalized === "student" || normalized === "native_speaker";
}

function extractBlockedIds(blockedUsers = []) {
  if (!Array.isArray(blockedUsers)) {
    return [];
  }

  return blockedUsers
    .map((ref) => {
      if (ref && typeof ref === "object" && typeof ref.id === "string") {
        return ref.id.trim();
      }
      if (typeof ref === "string") {
        const value = ref.trim();
        const parts = value.split("/").filter(Boolean);
        return parts.length > 0 ? parts[parts.length - 1] : "";
      }
      return "";
    })
    .filter(Boolean);
}

function readLanguageCode(value) {
  if (!value) {
    return "";
  }

  if (typeof value === "string") {
    return normalizeCode(value);
  }

  if (typeof value === "object") {
    return normalizeCode(value.code || value.value || value.languageCode);
  }

  return "";
}

function readCountryCode(value) {
  if (!value) {
    return "";
  }

  if (typeof value === "string") {
    return normalizeString(value);
  }

  if (typeof value === "object") {
    return normalizeString(value.code || value.value || "");
  }

  return "";
}

function readLevelValue(value) {
  if (!value) {
    return "";
  }

  if (typeof value === "string") {
    return normalizeString(value);
  }

  if (typeof value === "object") {
    return normalizeString(value.name || value.value || "");
  }

  return "";
}

function readRatingAverage(rating) {
  if (typeof rating === "number" && Number.isFinite(rating)) {
    return rating;
  }

  if (rating && typeof rating === "object") {
    const average = Number(rating.average);
    return Number.isFinite(average) ? average : 0;
  }

  return 0;
}

function readRatingCount(rating) {
  if (rating && typeof rating === "object") {
    const totalReviews = Number(rating.totalReviews);
    return Number.isFinite(totalReviews) ? totalReviews : 0;
  }

  return 0;
}

function readMatchCountry(userData = {}) {
  const legacyCountry = readCountryCode(userData.Country_NS);
  if (legacyCountry) {
    return legacyCountry;
  }

  return readCountryCode(readStoredMatchProfile(userData).country);
}

function readMatchLevelValue(userData = {}) {
  const legacyLevel = readLevelValue(userData.level);
  if (legacyLevel) {
    return legacyLevel;
  }

  return readLevelValue(readStoredMatchProfile(userData).level);
}

function readMatchRatingAverage(userData = {}) {
  if (Object.prototype.hasOwnProperty.call(userData, "rating")) {
    return readRatingAverage(userData.rating);
  }

  return readRatingAverage(readStoredMatchProfile(userData).ratingAverage);
}

function readMatchRatingCount(userData = {}) {
  if (Object.prototype.hasOwnProperty.call(userData, "rating")) {
    return readRatingCount(userData.rating);
  }

  return readRatingCount(readStoredMatchProfile(userData).ratingCount);
}

function readMatchPriorityScore(userData = {}) {
  return getLegacyPriorityScore(userData);
}

function getRawLegacyPriorityScore(userData = {}) {
  const queuePriority = Number(userData.queuePriority);
  if (Number.isFinite(queuePriority)) {
    return queuePriority;
  }

  const priorityScore = Number(userData.priorityScore);
  if (Number.isFinite(priorityScore)) {
    return priorityScore;
  }

  return 0;
}

function getLegacyPriorityScore(userData = {}) {
  const hasRawPriorityScore =
    userData.queuePriority != null || userData.priorityScore != null;
  if (hasRawPriorityScore) {
    return getRawLegacyPriorityScore(userData);
  }

  const storedPriorityScore = Number(
    readStoredMatchProfile(userData).legacyPriorityScore,
  );
  if (Number.isFinite(storedPriorityScore)) {
    return storedPriorityScore;
  }

  return 0;
}

function readTeacherAccreditationStatusValue(value) {
  if (value == null) {
    return "";
  }

  if (value === true) {
    return "approved";
  }
  if (value === false) {
    return "pending";
  }

  const rawValue =
    typeof value === "object" ?
      value.name || value.value || value.status || "" :
      value;
  const normalized = normalizeString(String(rawValue))
    .split(".")
    .pop()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");

  switch (normalized) {
    case "approved":
    case "approve":
    case "accepted":
    case "verified":
    case "true":
      return "approved";
    case "rejected":
    case "reject":
    case "declined":
    case "denied":
      return "rejected";
    case "pending":
    case "review":
    case "in_review":
    case "under_review":
    case "false":
      return "pending";
    default:
      return "";
  }
}

function readExplicitTeacherAccreditationStatus(userData = {}) {
  return (
    readTeacherAccreditationStatusValue(userData.teacherAccreditationStatus) ||
    readTeacherAccreditationStatusValue(userData.teacherVerificationStatus) ||
    readTeacherAccreditationStatusValue(userData.verificationStatus)
  );
}

function readTeacherAccreditationStatus(userData = {}) {
  const explicitStatus = readExplicitTeacherAccreditationStatus(userData);
  if (explicitStatus) {
    return explicitStatus;
  }

  if (userData.verif_NS === true) {
    return "approved";
  }

  const storedMatchProfile = readStoredMatchProfile(userData);
  const storedStatus = readTeacherAccreditationStatusValue(
    storedMatchProfile.teacherAccreditationStatus,
  );
  if (storedStatus) {
    return storedStatus;
  }
  if (storedMatchProfile.approvedTeacher === true) {
    return "approved";
  }

  return "";
}

function isApprovedTeacherFromLegacy(userData = {}) {
  return readTeacherAccreditationStatus(userData) === "approved";
}

function isApprovedTeacher(userData = {}) {
  return readTeacherAccreditationStatus(userData) === "approved";
}

function buildSessionUserInfo(userData = {}, fallbackName = "User") {
  return {
    name: normalizeString(userData.display_name) || fallbackName,
    photo: normalizeString(userData.photo_url) || null,
  };
}

function resolveLegacyConversationLanguages(userData = {}) {
  return Array.from(
    new Set(
      [
        readLanguageCode(userData.learningLanguage),
        readLanguageCode(userData.language_instruction_NS),
      ].filter(Boolean),
    ),
  );
}

function resolveRoleConversationLanguages(userData = {}) {
  const role = normalizeRole(userData.role);
  const languageCode = role === "native_speaker" ?
    readLanguageCode(userData.language_instruction_NS) :
    readLanguageCode(userData.learningLanguage);

  return languageCode ? [languageCode] : [];
}

function resolveConversationLanguages(userData = {}) {
  const storedMatchProfile = readStoredMatchProfile(userData);
  const roleConversationLanguages = resolveRoleConversationLanguages(userData);
  return Array.from(
    new Set(
      [
        ...roleConversationLanguages,
        ...readStoredCodeList(storedMatchProfile.supportedLanguages),
        readLanguageCode(storedMatchProfile.activeLanguage),
      ].filter(Boolean),
    ),
  );
}

function hasLegacyMatchProfileSource(userData = {}) {
  return (
    resolveLegacyConversationLanguages(userData).length > 0 ||
    !!readCountryCode(userData.Country_NS) ||
    !!readLevelValue(userData.level) ||
    Object.prototype.hasOwnProperty.call(userData, "rating") ||
    userData.verif_NS === true ||
    userData.teacherAccreditationStatus != null ||
    userData.teacherVerificationStatus != null ||
    userData.verificationStatus != null ||
    userData.queuePriority != null ||
    userData.priorityScore != null
  );
}

function resolveActiveConversationLanguage(userData = {}, explicitLanguage) {
  const requestedLanguage = readLanguageCode(explicitLanguage);
  const storedMatchProfile = readStoredMatchProfile(userData);
  const storedActiveLanguage = readLanguageCode(storedMatchProfile.activeLanguage);
  const roleSupportedLanguages = resolveRoleConversationLanguages(userData);
  const supportedLanguages = resolveConversationLanguages(userData);

  if (requestedLanguage) {
    if (
      roleSupportedLanguages.length > 0 &&
      !roleSupportedLanguages.includes(requestedLanguage)
    ) {
      return {
        code: roleSupportedLanguages[0],
        source: "profile_overrode_payload",
        supportedLanguages,
      };
    }

    return {
      code: requestedLanguage,
      source: supportedLanguages.includes(requestedLanguage) ?
        "payload_confirmed_by_profile" :
        "payload_fallback",
      supportedLanguages,
    };
  }

  if (roleSupportedLanguages.length > 0) {
    return {
      code: roleSupportedLanguages[0],
      source: "profile",
      supportedLanguages,
    };
  }

  if (storedActiveLanguage) {
    return {
      code: storedActiveLanguage,
      source: normalizeString(storedMatchProfile.activeLanguageSource) ||
        "match_profile",
      supportedLanguages:
        supportedLanguages.length > 0 ?
          supportedLanguages :
          [storedActiveLanguage],
    };
  }

  if (supportedLanguages.length > 0) {
    return {
      code: supportedLanguages[0],
      source: normalizeString(storedMatchProfile.activeLanguageSource) ||
        "match_profile",
      supportedLanguages,
    };
  }

  return {
    code: "",
    source: null,
    supportedLanguages,
  };
}

function supportsConversationLanguage(userData = {}, language) {
  const normalizedLanguage = readLanguageCode(language);
  if (!normalizedLanguage) {
    return false;
  }

  return resolveRoleConversationLanguages(userData).includes(normalizedLanguage);
}

function buildMatchProfile(userId, userData = {}, requestedLanguage) {
  const activeLanguage = resolveActiveConversationLanguage(
    userData,
    requestedLanguage,
  );
  const teacherAccreditationStatus = readTeacherAccreditationStatus(userData);

  return {
    userId: normalizeString(userId),
    role: normalizeRole(userData.role),
    activeLanguage: activeLanguage.code || null,
    activeLanguageSource: activeLanguage.source || null,
    supportedLanguages: activeLanguage.supportedLanguages,
    country: readMatchCountry(userData) || null,
    level: readMatchLevelValue(userData) || null,
    ratingAverage: readMatchRatingAverage(userData),
    ratingCount: readMatchRatingCount(userData),
    teacherAccreditationStatus: teacherAccreditationStatus || null,
    approvedTeacher: teacherAccreditationStatus === "approved",
    legacyPriorityScore: getLegacyPriorityScore(userData),
  };
}

function buildStoredMatchProfile(
  userId,
  userData = {},
  {preserveStoredValues = false} = {},
) {
  const storedMatchProfile = readStoredMatchProfile(userData);
  const supportedLanguages = resolveRoleConversationLanguages(userData);
  const activeLanguage = supportedLanguages.length > 0 ? supportedLanguages[0] : null;
  const explicitTeacherAccreditationStatus =
    readExplicitTeacherAccreditationStatus(userData);
  const teacherAccreditationStatus =
    explicitTeacherAccreditationStatus ||
    (userData.verif_NS === true ? "approved" : "") ||
    (preserveStoredValues ?
      readTeacherAccreditationStatusValue(
        storedMatchProfile.teacherAccreditationStatus,
      ) ||
        (storedMatchProfile.approvedTeacher === true ? "approved" : "") :
      "");
  const hasRawPriorityScore =
    userData.queuePriority != null || userData.priorityScore != null;
  return {
    version: "v1",
    role:
      normalizeRole(userData.role) ||
      (preserveStoredValues ? normalizeRole(storedMatchProfile.role) : "") ||
      null,
    activeLanguage:
      activeLanguage ||
      (preserveStoredValues ?
        readLanguageCode(storedMatchProfile.activeLanguage) :
        "") ||
      null,
    activeLanguageSource: activeLanguage ?
      "profile" :
      (preserveStoredValues ?
        normalizeString(storedMatchProfile.activeLanguageSource) ||
          (readLanguageCode(storedMatchProfile.activeLanguage) ?
            "match_profile" :
            "") :
        "") ||
      null,
    supportedLanguages: supportedLanguages.length > 0 ?
      supportedLanguages :
      (preserveStoredValues ?
        readStoredCodeList(storedMatchProfile.supportedLanguages) :
        []),
    country:
      readCountryCode(userData.Country_NS) ||
      (preserveStoredValues ?
        readCountryCode(storedMatchProfile.country) :
        "") ||
      null,
    level:
      readLevelValue(userData.level) ||
      (preserveStoredValues ? readLevelValue(storedMatchProfile.level) : "") ||
      null,
    ratingAverage: Object.prototype.hasOwnProperty.call(userData, "rating") ?
      readRatingAverage(userData.rating) :
      (preserveStoredValues ?
        readRatingAverage(storedMatchProfile.ratingAverage) :
        0),
    ratingCount: Object.prototype.hasOwnProperty.call(userData, "rating") ?
      readRatingCount(userData.rating) :
      (preserveStoredValues ?
        readRatingCount(storedMatchProfile.ratingCount) :
        0),
    teacherAccreditationStatus: teacherAccreditationStatus || null,
    approvedTeacher: teacherAccreditationStatus ?
      teacherAccreditationStatus === "approved" :
      (preserveStoredValues && storedMatchProfile.approvedTeacher === true),
    legacyPriorityScore: hasRawPriorityScore ?
      getRawLegacyPriorityScore(userData) :
      (preserveStoredValues ?
        Number(storedMatchProfile.legacyPriorityScore) || 0 :
        0),
  };
}

function getRequesterId(sessionData = {}) {
  return normalizeString(
    normalizeString(sessionData.requesterId) ||
      normalizeString(sessionData.matchContext?.requesterId) ||
      normalizeString(sessionData.studentId),
  ) || null;
}

function getAssignedResponderId(sessionData = {}) {
  return normalizeString(
    normalizeString(sessionData.responderId) ||
      normalizeString(sessionData.matchContext?.acceptedResponderId) ||
      normalizeString(sessionData.currentResponderId) ||
      normalizeString(sessionData.matchContext?.responderId) ||
      normalizeString(sessionData.matchContext?.currentResponderId) ||
      normalizeString(sessionData.tutorId) ||
      normalizeString(sessionData.currentTutorId),
  ) || null;
}

function getSessionParticipantIds(sessionData = {}) {
  const ids = [];
  const participantIds = Array.isArray(sessionData.participantIds) ?
    sessionData.participantIds :
    [];

  participantIds.forEach((value) => {
    const normalized = normalizeString(value);
    if (normalized && !ids.includes(normalized)) {
      ids.push(normalized);
    }
  });

  if (ids.length >= 2) {
    return ids;
  }

  [getRequesterId(sessionData), getAssignedResponderId(sessionData)]
    .filter(Boolean)
    .forEach((value) => {
      const normalized = normalizeString(value);
      if (normalized && !ids.includes(normalized)) {
        ids.push(normalized);
      }
    });

  return ids;
}

function getAcceptedSessionCredentialParticipantIds(sessionData = {}) {
  const ids = [];
  const participantIds = Array.isArray(sessionData.participantIds) ?
    sessionData.participantIds :
    [];

  participantIds.forEach((value) => {
    const normalized = normalizeString(value);
    if (normalized && !ids.includes(normalized)) {
      ids.push(normalized);
    }
  });

  [
    getRequesterId(sessionData),
    normalizeString(
      sessionData.tutorId || sessionData.matchContext?.acceptedResponderId,
    ),
  ]
    .filter(Boolean)
    .forEach((value) => {
      const normalized = normalizeString(value);
      if (normalized && !ids.includes(normalized)) {
        ids.push(normalized);
      }
    });

  return ids;
}

function isAcceptedSessionCredentialParticipant(sessionData = {}, userId) {
  const normalizedUserId = normalizeString(userId);
  if (!normalizedUserId) {
    return false;
  }

  return getAcceptedSessionCredentialParticipantIds(sessionData)
    .includes(normalizedUserId);
}

function isCredentialSessionStatus(status) {
  return VIDEO_SESSION_CREDENTIAL_STATUSES.includes(normalizeCode(status));
}

function isVideoSessionStatus(status) {
  return Object.values(VIDEO_SESSION_STATUS).includes(normalizeCode(status));
}

function readTimestampMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (value instanceof Date) {
    const millis = value.getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === "string") {
    const millis = Date.parse(value);
    return Number.isFinite(millis) ? millis : null;
  }
  return null;
}

function isCredentialSessionUnexpired(
  sessionData = {},
  nowMillis = Date.now(),
) {
  const expiresAtMillis = readTimestampMillis(sessionData.expiresAt);
  if (expiresAtMillis === null) {
    return false;
  }
  const safeNowMillis = Number.isFinite(Number(nowMillis))
    ? Number(nowMillis)
    : Date.now();
  return expiresAtMillis > safeNowMillis;
}

function isCredentialSessionJoinable(sessionData = {}, nowMillis = Date.now()) {
  if (!isCredentialSessionStatus(sessionData.status) ||
      !isCredentialSessionUnexpired(sessionData, nowMillis)) {
    return false;
  }
  if (normalizeCode(sessionData.status) !== VIDEO_SESSION_STATUS.CONNECTING) {
    return true;
  }

  const joinDeadlineMillis = readTimestampMillis(sessionData.joinDeadlineAt);
  if (joinDeadlineMillis === null) {
    return false;
  }
  const safeNowMillis = Number.isFinite(Number(nowMillis))
    ? Number(nowMillis)
    : Date.now();
  return joinDeadlineMillis > safeNowMillis;
}

function getCredentialDeadlineMillis(sessionData = {}) {
  const expiresAtMillis = readTimestampMillis(sessionData.expiresAt);
  if (expiresAtMillis === null) {
    return null;
  }
  if (normalizeCode(sessionData.status) !== VIDEO_SESSION_STATUS.CONNECTING) {
    return expiresAtMillis;
  }
  const joinDeadlineMillis = readTimestampMillis(sessionData.joinDeadlineAt);
  if (joinDeadlineMillis === null) {
    return null;
  }
  return Math.min(expiresAtMillis, joinDeadlineMillis);
}

function getCredentialTtlSeconds(
  sessionData = {},
  maxSeconds = 60 * 60,
  nowMillis = Date.now(),
) {
  const credentialDeadlineMillis = getCredentialDeadlineMillis(sessionData);
  if (credentialDeadlineMillis === null) {
    return 0;
  }
  const safeNowMillis = Number.isFinite(Number(nowMillis))
    ? Number(nowMillis)
    : Date.now();
  const remainingSeconds = Math.floor(
    (credentialDeadlineMillis - safeNowMillis) / 1000,
  );
  if (remainingSeconds < 1) {
    return 0;
  }
  return Math.min(
    readPositiveInteger(maxSeconds, 60 * 60),
    remainingSeconds,
  );
}

function getSessionExpiryTtlSeconds(
  sessionData = {},
  maxSeconds = 60 * 60,
  nowMillis = Date.now(),
) {
  const expiresAtMillis = readTimestampMillis(sessionData.expiresAt);
  if (expiresAtMillis === null) {
    return 0;
  }
  const safeNowMillis = Number.isFinite(Number(nowMillis))
    ? Number(nowMillis)
    : Date.now();
  const remainingSeconds = Math.floor((expiresAtMillis - safeNowMillis) / 1000);
  if (remainingSeconds < 1) {
    return 0;
  }
  return Math.min(
    readPositiveInteger(maxSeconds, 60 * 60),
    remainingSeconds,
  );
}

function isSessionParticipant(sessionData = {}, userId) {
  const normalizedUserId = normalizeString(userId);
  if (!normalizedUserId) {
    return false;
  }

  return getSessionParticipantIds(sessionData).includes(normalizedUserId);
}

function isRequesterForSession(sessionData = {}, userId) {
  const requesterId = getRequesterId(sessionData);
  return requesterId !== null && requesterId === normalizeString(userId);
}

module.exports = {
  buildAcceptedSessionPolicyState,
  buildInitialSessionPolicyState,
  buildMatchProfile,
  buildStoredMatchProfile,
  buildSessionUserInfo,
  buildUniversalSessionPolicy,
  extractBlockedIds,
  getAssignedResponderId,
  getAcceptedSessionCredentialParticipantIds,
  getCredentialDeadlineMillis,
  getCredentialTtlSeconds,
  getSessionExpiryTtlSeconds,
  getLegacyPriorityScore,
  hasLegacyMatchProfileSource,
  getRequesterId,
  getSessionPolicyEffectiveLimitSeconds,
  getSessionPolicyExpiresAt,
  getSessionParticipantIds,
  isApprovedTeacher,
  isAcceptedSessionCredentialParticipant,
  isCredentialSessionJoinable,
  isCredentialSessionStatus,
  isCredentialSessionUnexpired,
  isRequesterForSession,
  isSessionParticipant,
  isSupportedSessionRole,
  isVideoSessionStatus,
  normalizeRole,
  readCountryCode,
  readLanguageCode,
  readMatchCountry,
  readMatchLevelValue,
  readMatchPriorityScore,
  readMatchRatingAverage,
  readMatchRatingCount,
  readTeacherAccreditationStatus,
  readTeacherAccreditationStatusValue,
  readLevelValue,
  readRatingAverage,
  readRatingCount,
  resolveActiveConversationLanguage,
  resolveConversationLanguages,
  resolveRoleConversationLanguages,
  supportsConversationLanguage,
  VIDEO_SESSION_CREDENTIAL_STATUSES,
  VIDEO_SESSION_STATUS,
  VIDEO_SESSION_TERMINAL_STATUSES,
};
