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
        return ref.trim();
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
        readLanguageCode(userData.native_language_NS),
      ].filter(Boolean),
    ),
  );
}

function resolveConversationLanguages(userData = {}) {
  const storedMatchProfile = readStoredMatchProfile(userData);
  return Array.from(
    new Set(
      [
        ...resolveLegacyConversationLanguages(userData),
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
  const legacySupportedLanguages = resolveLegacyConversationLanguages(userData);
  const supportedLanguages = resolveConversationLanguages(userData);

  if (requestedLanguage) {
    return {
      code: requestedLanguage,
      source: supportedLanguages.includes(requestedLanguage) ?
        "payload_confirmed_by_profile" :
        "payload_fallback",
      supportedLanguages,
    };
  }

  if (legacySupportedLanguages.length > 0) {
    return {
      code: legacySupportedLanguages[0],
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

  return resolveConversationLanguages(userData).includes(normalizedLanguage);
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
  const supportedLanguages = resolveLegacyConversationLanguages(userData);
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
    sessionData.studentId ||
      sessionData.matchContext?.requesterId ||
      sessionData.requesterId,
  ) || null;
}

function getAssignedResponderId(sessionData = {}) {
  return normalizeString(
    sessionData.tutorId ||
      sessionData.currentTutorId ||
      sessionData.matchContext?.acceptedResponderId,
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

  [getRequesterId(sessionData), sessionData.tutorId, sessionData.currentTutorId]
    .filter(Boolean)
    .forEach((value) => {
      const normalized = normalizeString(value);
      if (normalized && !ids.includes(normalized)) {
        ids.push(normalized);
      }
    });

  return ids;
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
  buildMatchProfile,
  buildStoredMatchProfile,
  buildSessionUserInfo,
  extractBlockedIds,
  getAssignedResponderId,
  getLegacyPriorityScore,
  hasLegacyMatchProfileSource,
  getRequesterId,
  getSessionParticipantIds,
  isApprovedTeacher,
  isRequesterForSession,
  isSessionParticipant,
  isSupportedSessionRole,
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
  supportsConversationLanguage,
};
