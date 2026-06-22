const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  MATCH_CANDIDATE_SOURCE,
  buildActiveStudentSearchRequestsQuery,
  buildAvailableTeachersQuery,
  buildStudentQueueCandidateFromDocs,
  buildTeacherAvailabilityCandidateFromDoc,
  collectMatchCandidatePool,
  isActiveStudentSearchRequest,
  mergeCandidatePools,
  readPreferredLevelRank,
  validateActiveStudentSearchRequest,
} = require("./match_candidate_pool");
const {
  SEARCH_REQUEST_STATUS,
} = require("./search_requests");

const fixedNowMillis = Date.UTC(2026, 0, 1, 12, 0, 0);

function timestampFromMillis(millis) {
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

function doc(id, data, exists = true) {
  return {
    id,
    exists,
    data: () => data,
  };
}

function fakeQuery(docs, {limitCount = null, startAfterId = ""} = {}) {
  return {
    where: () => fakeQuery(docs, {limitCount, startAfterId}),
    orderBy: () => fakeQuery(docs, {limitCount, startAfterId}),
    limit: (count) => fakeQuery(docs, {limitCount: count, startAfterId}),
    startAfter: (lastDoc) => fakeQuery(docs, {
      limitCount,
      startAfterId: lastDoc?.id || "",
    }),
    get: async () => {
      const startIndex = startAfterId ?
        docs.findIndex((entry) => entry.id === startAfterId) + 1 :
        0;
      const pageDocs = docs.slice(Math.max(startIndex, 0));
      return {
        docs: limitCount ? pageDocs.slice(0, limitCount) : pageDocs,
      };
    },
  };
}

function fakeDb({
  studentRequestDocs = [],
  teacherDocs = [],
  userDocsById = {},
  privateTokenDocsById = {},
}) {
  return {
    collection: (name) => {
      if (name === "searchRequests") {
        return fakeQuery(studentRequestDocs);
      }
      if (name === "users") {
        return {
          ...fakeQuery(teacherDocs),
          doc: (id) => ({
            get: async () => userDocsById[id] || doc(id, null, false),
          }),
        };
      }
      if (name === "userPrivateTokens") {
        return {
          doc: (id) => ({
            get: async () => privateTokenDocsById[id] || doc(id, null, false),
          }),
        };
      }
      throw new Error(`Unexpected collection: ${name}`);
    },
  };
}

function activeRequest(overrides = {}) {
  return {
    requestId: "request-a",
    userId: "student-a",
    userRef: {id: "student-a"},
    role: "student",
    language: "en",
    filters: {preferredLevel: "B1", levelRank: 3},
    status: SEARCH_REQUEST_STATUS.ACTIVE,
    appState: "foreground",
    createdAt: timestampFromMillis(fixedNowMillis - 120 * 1000),
    heartbeatAt: timestampFromMillis(fixedNowMillis - 30 * 1000),
    expiresAt: timestampFromMillis(fixedNowMillis + 8 * 60 * 1000),
    backgroundExpiresAt: null,
    currentSessionId: null,
    matchedUserId: null,
    matchedResponderId: null,
    matchedSessionId: null,
    matchedRole: null,
    pairAttemptId: null,
    lockOwner: null,
    ...overrides,
  };
}

function studentData(overrides = {}) {
  return {
    role: "student",
    display_name: "Student A",
    learningLanguage: {code: "en"},
    level: {value: "B1"},
    ...overrides,
  };
}

function teacherData(overrides = {}) {
  return {
    role: "native_speaker",
    display_name: "Teacher A",
    language_instruction_NS: {code: "en"},
    level: {value: "C1"},
    verif_NS: true,
    isAvailable: true,
    created_time: timestampFromMillis(fixedNowMillis - 300 * 1000),
    availableSince: timestampFromMillis(fixedNowMillis - 240 * 1000),
    ...overrides,
  };
}

function privateTokenData(overrides = {}) {
  return {
    voipToken: "teacher-fcm",
    ...overrides,
  };
}

test("active student candidates come only from fresh active search requests", () => {
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest(), fixedNowMillis),
    {valid: true, reason: "active"},
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest(), fixedNowMillis),
    true,
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      status: SEARCH_REQUEST_STATUS.MATCHING,
    }), fixedNowMillis),
    {valid: false, reason: "inactive_status"},
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      role: "native_speaker",
    }), fixedNowMillis),
    {valid: false, reason: "not_student"},
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      language: "",
    }), fixedNowMillis),
    {valid: false, reason: "missing_language"},
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      heartbeatAt: null,
    }), fixedNowMillis),
    {valid: false, reason: "missing_heartbeat"},
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      status: SEARCH_REQUEST_STATUS.MATCHING,
    }), fixedNowMillis),
    false,
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      heartbeatAt: timestampFromMillis(fixedNowMillis - 91 * 1000),
    }), fixedNowMillis),
    {valid: false, reason: "stale_heartbeat"},
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      heartbeatAt: timestampFromMillis(fixedNowMillis - 91 * 1000),
    }), fixedNowMillis),
    false,
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      heartbeatAt: timestampFromMillis(fixedNowMillis - 90 * 1000),
    }), fixedNowMillis),
    true,
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      expiresAt: timestampFromMillis(fixedNowMillis),
    }), fixedNowMillis),
    {valid: false, reason: "expired_request"},
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      expiresAt: null,
    }), fixedNowMillis),
    {valid: false, reason: "expired_request"},
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      expiresAt: timestampFromMillis(fixedNowMillis),
    }), fixedNowMillis),
    false,
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      appState: "background",
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis - 1),
    }), fixedNowMillis),
    {valid: false, reason: "background_expired"},
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      appState: "background",
      backgroundExpiresAt: null,
    }), fixedNowMillis),
    {valid: false, reason: "background_expired"},
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      appState: "background",
      backgroundExpiresAt: "not-a-date",
    }), fixedNowMillis),
    {valid: false, reason: "background_expired"},
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      appState: "background",
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis + 1),
    }), fixedNowMillis),
    true,
  );
  assert.equal(
    isActiveStudentSearchRequest(activeRequest({
      appState: "background",
      backgroundExpiresAt: timestampFromMillis(fixedNowMillis - 1),
    }), fixedNowMillis),
    false,
  );
  assert.deepEqual(
    validateActiveStudentSearchRequest(activeRequest({
      lockOwner: "matcher-a",
    }), fixedNowMillis),
    {valid: false, reason: "open_match_state"},
  );
});

[
  "activeSessionId",
  "currentSessionId",
  "matchedSessionId",
  "matchedUserId",
  "matchedResponderId",
  "matchedRole",
  "pairAttemptId",
  "lockOwner",
  "lockExpiresAt",
].forEach((fieldName) => {
  test(`student active request rejects open state field ${fieldName}`, () => {
    assert.deepEqual(
      validateActiveStudentSearchRequest(activeRequest({
        [fieldName]: fieldName === "lockExpiresAt" ?
          timestampFromMillis(fixedNowMillis + 30 * 1000) :
          "value",
      }), fixedNowMillis),
      {valid: false, reason: "open_match_state"},
    );
  });
});

test("student queue candidate carries neutral pool shape", () => {
  const candidate = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-a", activeRequest()),
    userDoc: doc("student-a", studentData()),
    language: "en",
    nowMillis: fixedNowMillis,
  });

  assert.equal(candidate.userId, "student-a");
  assert.equal(candidate.role, "student");
  assert.equal(
    candidate.source,
    MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE,
  );
  assert.equal(candidate.searchRequestId, "request-a");
  assert.equal(candidate.searchRequestDocId, "student-a");
  assert.equal(candidate.language, "en");
  assert.equal(candidate.availability.reason, "active_search_request");
  assert.equal(candidate.availability.searchRequestValidationReason, "active");
  assert.equal(candidate.profile.role, "student");
});

test("candidate level filter accepts exact and adjacent levels", () => {
  const buildCandidate = (userId, level, preferredLevelRank) =>
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc(userId, activeRequest({
        requestId: `request-${userId}`,
        userId,
        userRef: {id: userId},
        filters: {},
      })),
      userDoc: doc(userId, studentData({level})),
      language: "en",
      nowMillis: fixedNowMillis,
      preferredLevelRank,
    });

  const exact = buildCandidate("student-exact", {value: "B1"}, 3);
  const lowerAdjacent = buildCandidate("student-lower", {value: "A2"}, 3);
  const upperAdjacent = buildCandidate("student-upper", {value: "B2"}, 3);

  assert.equal(exact.matchQuality.levelTier, "exact");
  assert.equal(exact.matchQuality.levelDistance, 0);
  assert.equal(lowerAdjacent.matchQuality.levelTier, "adjacent");
  assert.equal(upperAdjacent.matchQuality.levelTier, "adjacent");
  assert.equal(buildCandidate("student-low", {value: "A1"}, 3), null);
  assert.equal(buildCandidate("student-high", {value: "C1"}, 3), null);
  assert.equal(buildCandidate("student-missing", null, 3), null);

  assert.equal(
    buildCandidate("student-c2-exact", {value: "C2"}, 6).userId,
    "student-c2-exact",
  );
  assert.equal(
    buildCandidate("student-c2-adjacent", {value: "C1"}, 6).userId,
    "student-c2-adjacent",
  );
  assert.equal(buildCandidate("student-c2-far", {value: "B2"}, 6), null);
});

test("candidate level filter normalizes legacy level shapes", () => {
  const legacyName = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-basic", activeRequest({
      requestId: "request-student-basic",
      userId: "student-basic",
      userRef: {id: "student-basic"},
      filters: {},
    })),
    userDoc: doc("student-basic", studentData({level: "Basic"})),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLevelRank: 2,
  });
  const profileCode = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-c1", activeRequest({
      requestId: "request-student-c1",
      userId: "student-c1",
      userRef: {id: "student-c1"},
      filters: {},
    })),
    userDoc: doc("student-c1", studentData({
      level: null,
      matchProfile: {level: {code: "C1"}},
    })),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLevelRank: 5,
  });

  assert.equal(legacyName.matchQuality.candidateLevel, "A2");
  assert.equal(legacyName.matchQuality.levelTier, "exact");
  assert.equal(profileCode.matchQuality.candidateLevel, "C1");
  assert.equal(profileCode.matchQuality.levelTier, "exact");
  assert.equal(readPreferredLevelRank({preferredLevel: "Basic"}), 2);
  assert.equal(readPreferredLevelRank({levelRank: "4"}), 4);
});

test("student queue candidate honors candidate preferred level filter", () => {
  const rejectedByCandidateFilter = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-strict", activeRequest({
      requestId: "request-student-strict",
      userId: "student-strict",
      userRef: {id: "student-strict"},
      filters: {preferredLevel: "B1", levelRank: 3},
    })),
    userDoc: doc("student-strict", studentData({level: {value: "B1"}})),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLevelRank: 3,
    requesterLevelRank: 5,
  });
  const acceptedByCandidateFilter = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-flexible", activeRequest({
      requestId: "request-student-flexible",
      userId: "student-flexible",
      userRef: {id: "student-flexible"},
      filters: {preferredLevel: "B2", levelRank: 4},
    })),
    userDoc: doc("student-flexible", studentData({level: {value: "B1"}})),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLevelRank: 3,
    requesterLevelRank: 5,
  });

  assert.equal(rejectedByCandidateFilter, null);
  assert.equal(acceptedByCandidateFilter.userId, "student-flexible");
  assert.equal(
    acceptedByCandidateFilter.matchQuality.requesterLevelTier,
    "adjacent",
  );
});

test("candidate location filter accepts country from profile fields", () => {
  const countryMatch = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-us", activeRequest({
      requestId: "request-student-us",
      userId: "student-us",
      userRef: {id: "student-us"},
      filters: {},
    })),
    userDoc: doc("student-us", studentData({
      Country_NS: {code: "us"},
      profileCity: {key: "new_york"},
    })),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLocation: {
      countryCode: "US",
      cityKey: "",
      invalidCityFilter: false,
    },
  });
  const countryFromMatchProfile = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-profile-country", activeRequest({
      requestId: "request-student-profile-country",
      userId: "student-profile-country",
      userRef: {id: "student-profile-country"},
      filters: {},
    })),
    userDoc: doc("student-profile-country", studentData({
      Country_NS: null,
      matchProfile: {country: {value: "US"}},
    })),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLocation: {
      countryCode: "US",
      cityKey: "",
      invalidCityFilter: false,
    },
  });
  const countryMismatch = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-ca", activeRequest({
      requestId: "request-student-ca",
      userId: "student-ca",
      userRef: {id: "student-ca"},
      filters: {},
    })),
    userDoc: doc("student-ca", studentData({Country_NS: {code: "CA"}})),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLocation: {
      countryCode: "US",
      cityKey: "",
      invalidCityFilter: false,
    },
  });

  assert.equal(countryMatch.userId, "student-us");
  assert.equal(countryMatch.matchQuality.locationTier, "country_exact");
  assert.equal(countryMatch.matchQuality.locationDistance, 1);
  assert.equal(countryFromMatchProfile.userId, "student-profile-country");
  assert.equal(countryMismatch, null);
});

test("candidate location falls back after empty legacy country field", () => {
  const candidate = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-profile-country", activeRequest({
      requestId: "request-student-profile-country",
      userId: "student-profile-country",
      userRef: {id: "student-profile-country"},
      filters: {},
    })),
    userDoc: doc("student-profile-country", studentData({
      Country_NS: {},
      matchProfile: {country: {code: "US"}},
    })),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLocation: {
      countryCode: "US",
      cityKey: "",
      invalidCityFilter: false,
    },
  });

  assert.equal(candidate.userId, "student-profile-country");
  assert.equal(candidate.matchQuality.candidateCountryCode, "US");
});

test("candidate location filter requires selected city and country pair", () => {
  const selectedLocation = {
    countryCode: "US",
    cityKey: "new_york",
    invalidCityFilter: false,
  };
  const cityMatch = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-ny", activeRequest({
      requestId: "request-student-ny",
      userId: "student-ny",
      userRef: {id: "student-ny"},
      filters: {},
    })),
    userDoc: doc("student-ny", studentData({
      Country_NS: {code: "US"},
      profileCity: {key: " New_York "},
    })),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLocation: selectedLocation,
  });
  const sameCityKeyWrongCountry = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-ny-ca", activeRequest({
      requestId: "request-student-ny-ca",
      userId: "student-ny-ca",
      userRef: {id: "student-ny-ca"},
      filters: {},
    })),
    userDoc: doc("student-ny-ca", studentData({
      Country_NS: {code: "US"},
      profileCity: {countryCode: "CA", cityKey: "new_york"},
    })),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLocation: selectedLocation,
  });
  const missingCity = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-us", activeRequest({
      requestId: "request-student-us",
      userId: "student-us",
      userRef: {id: "student-us"},
      filters: {},
    })),
    userDoc: doc("student-us", studentData({Country_NS: {code: "US"}})),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLocation: selectedLocation,
  });

  assert.equal(cityMatch.userId, "student-ny");
  assert.equal(cityMatch.matchQuality.locationTier, "city_exact");
  assert.equal(cityMatch.matchQuality.locationDistance, 0);
  assert.equal(sameCityKeyWrongCountry, null);
  assert.equal(missingCity, null);
});

test("candidate location keeps profileCity source atomic", () => {
  const selectedLocation = {
    countryCode: "US",
    cityKey: "new_york",
    invalidCityFilter: false,
  };
  const profileCityWins = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-profile-city", activeRequest({
      requestId: "request-student-profile-city",
      userId: "student-profile-city",
      userRef: {id: "student-profile-city"},
      filters: {},
    })),
    userDoc: doc("student-profile-city", studentData({
      Country_NS: {code: "US"},
      profileCity: {cityKey: "new_york"},
      matchProfile: {
        city: {countryCode: "CA", cityKey: "new_york"},
      },
    })),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLocation: selectedLocation,
  });

  assert.equal(profileCityWins.userId, "student-profile-city");
  assert.equal(profileCityWins.matchQuality.candidateCityCountryCode, "US");
});

test("student queue candidate honors candidate preferred location filter", () => {
  const rejectedByCandidateFilter = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-country-strict", activeRequest({
      requestId: "request-student-country-strict",
      userId: "student-country-strict",
      userRef: {id: "student-country-strict"},
      filters: {countryCode: "CA"},
    })),
    userDoc: doc("student-country-strict", studentData({
      Country_NS: {code: "US"},
    })),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLocation: {
      countryCode: "US",
      cityKey: "",
      invalidCityFilter: false,
    },
    requesterLocation: {
      countryCode: "US",
      cityKey: "new_york",
      cityCountryCode: "US",
    },
  });
  const acceptedByCandidateFilter = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-city-flexible", activeRequest({
      requestId: "request-student-city-flexible",
      userId: "student-city-flexible",
      userRef: {id: "student-city-flexible"},
      filters: {countryCode: "US", cityKey: "new_york"},
    })),
    userDoc: doc("student-city-flexible", studentData({
      Country_NS: {code: "US"},
      profileCity: {countryCode: "US", cityKey: "new_york"},
    })),
    language: "en",
    nowMillis: fixedNowMillis,
    preferredLocation: {
      countryCode: "US",
      cityKey: "",
      invalidCityFilter: false,
    },
    requesterLocation: {
      countryCode: "US",
      cityKey: "new_york",
      cityCountryCode: "US",
    },
  });

  assert.equal(rejectedByCandidateFilter, null);
  assert.equal(acceptedByCandidateFilter.userId, "student-city-flexible");
  assert.equal(
    acceptedByCandidateFilter.matchQuality.requesterLocationTier,
    "city_exact",
  );
});

test("student queue candidate rejects requester and candidate blocklists", () => {
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-blocked", activeRequest({
        requestId: "request-student-blocked",
        userId: "student-blocked",
        userRef: {id: "student-blocked"},
        filters: {},
      })),
      userDoc: doc("student-blocked", studentData()),
      language: "en",
      nowMillis: fixedNowMillis,
      requesterId: "requester-a",
      requesterBlockedIds: ["users/student-blocked"],
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-blocker", activeRequest({
        requestId: "request-student-blocker",
        userId: "student-blocker",
        userRef: {id: "student-blocker"},
        filters: {},
      })),
      userDoc: doc("student-blocker", studentData({
        blockedUsers: [{id: "requester-a"}],
      })),
      language: "en",
      nowMillis: fixedNowMillis,
      requesterId: "requester-a",
    }),
    null,
  );
});

test("student queue candidate normalizes path-form participant ids", () => {
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-blocker", activeRequest({
        requestId: "request-student-blocker",
        userId: "student-blocker",
        userRef: {id: "student-blocker"},
        filters: {},
      })),
      userDoc: doc("student-blocker", studentData({
        blockedUsers: ["requester-a"],
      })),
      language: "en",
      nowMillis: fixedNowMillis,
      requesterId: "users/requester-a",
    }),
    null,
  );
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-blocker", teacherData({
        blockedUsers: ["requester-a"],
      })),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
      requesterId: "users/requester-a",
    }),
    null,
  );
});

test("student queue candidate rejects users already in call", () => {
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-in-call", activeRequest({
        requestId: "request-student-in-call",
        userId: "student-in-call",
        userRef: {id: "student-in-call"},
      })),
      userDoc: doc("student-in-call", studentData({isInCall: true})),
      language: "en",
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-session", activeRequest({
        requestId: "request-student-session",
        userId: "student-session",
        userRef: {id: "student-session"},
      })),
      userDoc: doc("student-session", studentData({
        currentSessionId: "session-a",
      })),
      language: "en",
      nowMillis: fixedNowMillis,
    }),
    null,
  );
});

test("student queue candidate rejects missing user and changed role", () => {
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest()),
      userDoc: doc("student-a", null, false),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest()),
      userDoc: doc("student-a", studentData({role: "native_speaker"})),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest({
        userRef: {id: "student-b"},
      })),
      userDoc: doc("student-a", studentData()),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest({
        userId: "student-b",
        userRef: undefined,
      })),
      userDoc: doc("student-b", studentData()),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest({
        userId: undefined,
        userRef: undefined,
      })),
      userDoc: doc("student-a", studentData()),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest()),
      userDoc: doc("student-b", studentData()),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest({language: "en"})),
      userDoc: doc("student-a", studentData({
        learningLanguage: {code: "fr"},
      })),
      language: "en",
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest({language: "fr"})),
      userDoc: doc("student-a", studentData({
        learningLanguage: {code: "fr"},
      })),
      language: "en",
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildStudentQueueCandidateFromDocs({
      requestDoc: doc("student-a", activeRequest()),
      userDoc: doc("student-a", studentData()),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
});

test("teacher availability candidate requires approved available teacher", () => {
  const candidate = buildTeacherAvailabilityCandidateFromDoc({
    userDoc: doc("teacher-a", teacherData()),
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.equal(candidate.userId, "teacher-a");
  assert.equal(candidate.role, "native_speaker");
  assert.equal(candidate.source, MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY);
  assert.equal(candidate.searchRequestId, null);
  assert.equal(candidate.language, "en");
  assert.equal(candidate.availability.isAvailable, true);
  assert.equal(candidate.profile.approvedTeacher, true);

  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-a", teacherData({verif_NS: false})),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-a", teacherData({isAvailable: false})),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-a", teacherData({
        language_instruction_NS: {code: "es"},
        native_language_NS: {code: "en"},
      })),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-a", teacherData()),
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
});

test("teacher availability candidate rejects requester and candidate blocklists", () => {
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-blocked", teacherData()),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
      requesterId: "requester-a",
      requesterBlockedIds: ["teacher-blocked"],
    }),
    null,
  );
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-blocker", teacherData({
        blockedUsers: ["users/requester-a"],
      })),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
      requesterId: "requester-a",
    }),
    null,
  );
});

test("teacher availability candidate rejects users already in call", () => {
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-in-call", teacherData({isInCall: true})),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-session", teacherData({
        currentSessionId: "session-a",
      })),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
});

test("teacher availability candidate honors structured schedule", () => {
  const withinInterval = buildTeacherAvailabilityCandidateFromDoc({
    userDoc: doc("teacher-a", teacherData({
      availabilityToday: {
        enabled: true,
        intervals: [{start: "11:30", end: "12:30"}],
        timezoneOffsetMinutes: 0,
      },
    })),
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.equal(withinInterval.userId, "teacher-a");
  assert.equal(withinInterval.availability.reason, "within_interval");
  assert.equal(withinInterval.availability.localTime, "12:00");
  assert.equal(withinInterval.availability.timezoneOffsetMinutes, 0);

  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-a", teacherData({
        availabilityToday: {
          enabled: true,
          intervals: [{start: "08:00", end: "09:00"}],
          timezoneOffsetMinutes: 0,
        },
      })),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
});

test("teacher availability candidate rejects disabled teacher schedule", () => {
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-a", teacherData({
        isAvailable: true,
        availabilityToday: {
          enabled: false,
          intervals: [{start: "00:00", end: "23:59"}],
          timezoneOffsetMinutes: 0,
        },
      })),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
});

test("teacher availability candidate supports overnight interval boundaries", () => {
  const atStart = buildTeacherAvailabilityCandidateFromDoc({
    userDoc: doc("teacher-a", teacherData({
      availabilityToday: {
        enabled: true,
        intervals: [{start: "22:00", end: "02:00"}],
        timezoneOffsetMinutes: 0,
      },
    })),
    language: "en",
    now: new Date(Date.UTC(2026, 0, 1, 22, 0, 0)),
    nowMillis: fixedNowMillis,
  });
  const beforeEnd = buildTeacherAvailabilityCandidateFromDoc({
    userDoc: doc("teacher-a", teacherData({
      availabilityToday: {
        enabled: true,
        intervals: [{start: "22:00", end: "02:00"}],
        timezoneOffsetMinutes: 0,
      },
    })),
    language: "en",
    now: new Date(Date.UTC(2026, 0, 1, 1, 59, 0)),
    nowMillis: fixedNowMillis,
  });

  assert.equal(atStart.userId, "teacher-a");
  assert.equal(atStart.availability.reason, "within_interval");
  assert.equal(beforeEnd.userId, "teacher-a");
  assert.equal(beforeEnd.availability.reason, "within_interval");

  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-a", teacherData({
        availabilityToday: {
          enabled: true,
          intervals: [{start: "22:00", end: "02:00"}],
          timezoneOffsetMinutes: 0,
        },
      })),
      language: "en",
      now: new Date(Date.UTC(2026, 0, 1, 2, 0, 0)),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
});

test("teacher availability candidate rejects future availableAfter", () => {
  assert.equal(
    buildTeacherAvailabilityCandidateFromDoc({
      userDoc: doc("teacher-a", teacherData({
        availableAfter: timestampFromMillis(fixedNowMillis + 60 * 1000),
      })),
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    }),
    null,
  );
});

test("student queue candidate ignores legacy availability fields", () => {
  const candidate = buildStudentQueueCandidateFromDocs({
    requestDoc: doc("student-a", activeRequest()),
    userDoc: doc("student-a", studentData({
      isAvailable: false,
      availabilityToday: {
        enabled: false,
        intervals: [{start: "00:00", end: "00:01"}],
      },
    })),
    language: "en",
    nowMillis: fixedNowMillis,
  });

  assert.equal(candidate.userId, "student-a");
  assert.equal(candidate.availability.reason, "active_search_request");
});

test("candidate pool merge is ordered by waiting time, not role", () => {
  const candidates = mergeCandidatePools({
    studentCandidates: [
      {
        userId: "student-a",
        role: "student",
        source: MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE,
        joinedPoolAtMillis: fixedNowMillis - 60 * 1000,
      },
    ],
    teacherCandidates: [
      {
        userId: "teacher-a",
        role: "native_speaker",
        source: MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY,
        joinedPoolAtMillis: fixedNowMillis - 120 * 1000,
      },
    ],
  });

  assert.deepEqual(
    candidates.map((candidate) => candidate.userId),
    ["teacher-a", "student-a"],
  );
});

test("candidate pool merge ranks exact level before adjacent level", () => {
  const candidates = mergeCandidatePools({
    studentCandidates: [
      {
        userId: "student-exact",
        role: "student",
        source: MATCH_CANDIDATE_SOURCE.ACTIVE_STUDENT_QUEUE,
        joinedPoolAtMillis: fixedNowMillis - 60 * 1000,
        matchQuality: {levelDistance: 0},
      },
    ],
    teacherCandidates: [
      {
        userId: "teacher-adjacent",
        role: "native_speaker",
        source: MATCH_CANDIDATE_SOURCE.TEACHER_AVAILABILITY,
        joinedPoolAtMillis: fixedNowMillis - 120 * 1000,
        matchQuality: {levelDistance: 1},
      },
    ],
  });

  assert.deepEqual(
    candidates.map((candidate) => candidate.userId),
    ["student-exact", "teacher-adjacent"],
  );
});

test("candidate pool merge treats null level distance as no level ranking", () => {
  const candidates = mergeCandidatePools({
    studentCandidates: [
      {
        userId: "student-null-level",
        joinedPoolAtMillis: fixedNowMillis - 60 * 1000,
        matchQuality: {levelDistance: null},
      },
    ],
    teacherCandidates: [
      {
        userId: "teacher-older",
        joinedPoolAtMillis: fixedNowMillis - 120 * 1000,
      },
    ],
  });

  assert.deepEqual(
    candidates.map((candidate) => candidate.userId),
    ["teacher-older", "student-null-level"],
  );
});

test("candidate pool merge ranks city match before country match", () => {
  const candidates = mergeCandidatePools({
    studentCandidates: [
      {
        userId: "student-country",
        joinedPoolAtMillis: fixedNowMillis - 120 * 1000,
        matchQuality: {locationDistance: 1},
      },
    ],
    teacherCandidates: [
      {
        userId: "teacher-city",
        joinedPoolAtMillis: fixedNowMillis - 60 * 1000,
        matchQuality: {locationDistance: 0},
      },
    ],
  });

  assert.deepEqual(
    candidates.map((candidate) => candidate.userId),
    ["teacher-city", "student-country"],
  );
});

test("candidate pool merge excludes requester and dedupes by user", () => {
  const candidates = mergeCandidatePools({
    requesterId: "student-a",
    studentCandidates: [
      {userId: "student-a", joinedPoolAtMillis: 1},
      {userId: "student-b", joinedPoolAtMillis: 2},
    ],
    teacherCandidates: [
      {userId: "student-b", joinedPoolAtMillis: 1},
      {userId: "teacher-a", joinedPoolAtMillis: 3},
    ],
  });

  assert.deepEqual(
    candidates.map((candidate) => candidate.userId),
    ["student-b", "teacher-a"],
  );
});

test("collectMatchCandidatePool combines queue students and teachers", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-a", activeRequest({
        createdAt: timestampFromMillis(fixedNowMillis - 120 * 1000),
      })),
    ],
    teacherDocs: [
      doc("teacher-a", teacherData({
        availableSince: timestampFromMillis(fixedNowMillis - 240 * 1000),
      })),
    ],
    userDocsById: {
      "student-a": doc("student-a", studentData()),
    },
    privateTokenDocsById: {
      "teacher-a": doc("teacher-a", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-a", "student-a"],
  );
  assert.deepEqual(result.stats, {
    studentRequestsScanned: 1,
    studentCandidates: 1,
    teacherUsersScanned: 1,
    teacherCandidates: 1,
    totalCandidates: 2,
  });
});

test("collectMatchCandidatePool excludes requester from unified pool", async () => {
  const db = fakeDb({
    studentRequestDocs: [doc("student-a", activeRequest())],
    teacherDocs: [doc("teacher-a", teacherData())],
    userDocsById: {
      "student-a": doc("student-a", studentData()),
    },
    privateTokenDocsById: {
      "teacher-a": doc("teacher-a", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    requesterId: "users/teacher-a",
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["student-a"],
  );
  assert.equal(result.stats.totalCandidates, 1);
});

test("collectMatchCandidatePool fails closed without requested language", async () => {
  const db = fakeDb({
    studentRequestDocs: [doc("student-a", activeRequest())],
    teacherDocs: [doc("teacher-a", teacherData())],
    userDocsById: {
      "student-a": doc("student-a", studentData()),
    },
    privateTokenDocsById: {
      "teacher-a": doc("teacher-a", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(result.candidates, []);
  assert.deepEqual(result.stats, {
    studentRequestsScanned: 0,
    studentCandidates: 0,
    teacherUsersScanned: 0,
    teacherCandidates: 0,
    totalCandidates: 0,
  });
});

test("collectMatchCandidatePool excludes wrong-language candidates", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-stale-language", activeRequest({
        userId: "student-stale-language",
        userRef: {id: "student-stale-language"},
        language: "en",
      })),
      doc("student-request-language-mismatch", activeRequest({
        userId: "student-request-language-mismatch",
        userRef: {id: "student-request-language-mismatch"},
        language: "fr",
      })),
      doc("student-a", activeRequest({
        userId: "student-a",
        userRef: {id: "student-a"},
        language: "en",
      })),
    ],
    teacherDocs: [
      doc("teacher-native-only", teacherData({
        language_instruction_NS: {code: "es"},
        native_language_NS: {code: "en"},
      })),
      doc("teacher-a", teacherData({
        language_instruction_NS: {code: "en"},
      })),
    ],
    userDocsById: {
      "student-stale-language": doc(
        "student-stale-language",
        studentData({learningLanguage: {code: "fr"}}),
      ),
      "student-request-language-mismatch": doc(
        "student-request-language-mismatch",
        studentData({learningLanguage: {code: "fr"}}),
      ),
      "student-a": doc("student-a", studentData({learningLanguage: {code: "en"}})),
    },
    privateTokenDocsById: {
      "teacher-native-only": doc("teacher-native-only", privateTokenData()),
      "teacher-a": doc("teacher-a", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-a", "student-a"],
  );
});

test("collectMatchCandidatePool ranks exact level before older adjacent", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-exact", activeRequest({
        requestId: "request-student-exact",
        userId: "student-exact",
        userRef: {id: "student-exact"},
        filters: {},
        createdAt: timestampFromMillis(fixedNowMillis - 60 * 1000),
      })),
    ],
    teacherDocs: [
      doc("teacher-adjacent", teacherData({
        level: {value: "A2"},
        availableSince: timestampFromMillis(fixedNowMillis - 300 * 1000),
      })),
    ],
    userDocsById: {
      "student-exact": doc("student-exact", studentData({
        level: {value: "B1"},
      })),
    },
    privateTokenDocsById: {
      "teacher-adjacent": doc("teacher-adjacent", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    requesterFilters: {preferredLevel: "B1"},
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["student-exact", "teacher-adjacent"],
  );
  assert.deepEqual(
    result.candidates.map((candidate) => candidate.matchQuality.levelTier),
    ["exact", "adjacent"],
  );
});

test("collectMatchCandidatePool scans beyond limit for exact student level", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-adjacent", activeRequest({
        requestId: "request-student-adjacent",
        userId: "student-adjacent",
        userRef: {id: "student-adjacent"},
        filters: {},
        createdAt: timestampFromMillis(fixedNowMillis - 120 * 1000),
      })),
      doc("student-exact", activeRequest({
        requestId: "request-student-exact",
        userId: "student-exact",
        userRef: {id: "student-exact"},
        filters: {},
        createdAt: timestampFromMillis(fixedNowMillis - 60 * 1000),
      })),
    ],
    userDocsById: {
      "student-adjacent": doc(
        "student-adjacent",
        studentData({level: {value: "A2"}}),
      ),
      "student-exact": doc(
        "student-exact",
        studentData({level: {value: "B1"}}),
      ),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    requesterFilters: {preferredLevel: "B1"},
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
    studentLimit: 1,
    studentScanPageSize: 1,
    studentMaxScanPages: 3,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["student-exact"],
  );
  assert.equal(result.stats.studentRequestsScanned, 2);
  assert.equal(result.stats.studentCandidates, 1);
});

test("collectMatchCandidatePool scans beyond limit for exact teacher level", async () => {
  const db = fakeDb({
    teacherDocs: [
      doc("teacher-adjacent", teacherData({
        level: {value: "A2"},
        availableSince: timestampFromMillis(fixedNowMillis - 120 * 1000),
      })),
      doc("teacher-exact", teacherData({
        level: {value: "B1"},
        availableSince: timestampFromMillis(fixedNowMillis - 60 * 1000),
      })),
    ],
    privateTokenDocsById: {
      "teacher-adjacent": doc("teacher-adjacent", privateTokenData()),
      "teacher-exact": doc("teacher-exact", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    requesterFilters: {preferredLevel: "B1"},
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
    teacherLimit: 1,
    teacherScanPageSize: 1,
    teacherMaxScanPages: 3,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-exact"],
  );
  assert.equal(result.stats.teacherUsersScanned, 2);
  assert.equal(result.stats.teacherCandidates, 1);
});

test("collectMatchCandidatePool reads requester level for mutual student filter", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-strict", activeRequest({
        requestId: "request-student-strict",
        userId: "student-strict",
        userRef: {id: "student-strict"},
        filters: {preferredLevel: "B1", levelRank: 3},
      })),
      doc("student-flexible", activeRequest({
        requestId: "request-student-flexible",
        userId: "student-flexible",
        userRef: {id: "student-flexible"},
        filters: {preferredLevel: "B2", levelRank: 4},
      })),
    ],
    userDocsById: {
      "requester-a": doc("requester-a", studentData({
        level: {value: "C1"},
      })),
      "student-strict": doc("student-strict", studentData({
        level: {value: "B1"},
      })),
      "student-flexible": doc("student-flexible", studentData({
        level: {value: "B1"},
      })),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    requesterId: "requester-a",
    language: "en",
    requesterFilters: {preferredLevel: "B1"},
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["student-flexible"],
  );
});

test("collectMatchCandidatePool filters candidates by selected country", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-ca", activeRequest({
        requestId: "request-student-ca",
        userId: "student-ca",
        userRef: {id: "student-ca"},
        filters: {},
      })),
      doc("student-us", activeRequest({
        requestId: "request-student-us",
        userId: "student-us",
        userRef: {id: "student-us"},
        filters: {},
      })),
    ],
    teacherDocs: [
      doc("teacher-us", teacherData({Country_NS: {code: "us"}})),
      doc("teacher-ca", teacherData({Country_NS: {code: "CA"}})),
    ],
    userDocsById: {
      "student-ca": doc("student-ca", studentData({
        Country_NS: {code: "CA"},
      })),
      "student-us": doc("student-us", studentData({
        Country_NS: {code: "US"},
      })),
    },
    privateTokenDocsById: {
      "teacher-us": doc("teacher-us", privateTokenData()),
      "teacher-ca": doc("teacher-ca", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    requesterFilters: {countryCode: "us"},
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-us", "student-us"],
  );
});

test("collectMatchCandidatePool filters candidates by selected city", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-ny-ca", activeRequest({
        requestId: "request-student-ny-ca",
        userId: "student-ny-ca",
        userRef: {id: "student-ny-ca"},
        filters: {},
      })),
      doc("student-ny-us", activeRequest({
        requestId: "request-student-ny-us",
        userId: "student-ny-us",
        userRef: {id: "student-ny-us"},
        filters: {},
      })),
    ],
    teacherDocs: [
      doc("teacher-us-other-city", teacherData({
        Country_NS: {code: "US"},
        profileCity: {countryCode: "US", cityKey: "los_angeles"},
      })),
      doc("teacher-ny-us", teacherData({
        Country_NS: {code: "US"},
        profileCity: {countryCode: "US", cityKey: "new_york"},
      })),
    ],
    userDocsById: {
      "student-ny-ca": doc("student-ny-ca", studentData({
        Country_NS: {code: "US"},
        profileCity: {countryCode: "CA", cityKey: "new_york"},
      })),
      "student-ny-us": doc("student-ny-us", studentData({
        Country_NS: {code: "US"},
        profileCity: {countryCode: "US", cityKey: "new_york"},
      })),
    },
    privateTokenDocsById: {
      "teacher-us-other-city": doc(
        "teacher-us-other-city",
        privateTokenData(),
      ),
      "teacher-ny-us": doc("teacher-ny-us", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    requesterFilters: {countryCode: "US", cityKey: "new_york"},
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-ny-us", "student-ny-us"],
  );
  result.candidates.forEach((candidate) => {
    assert.equal(candidate.matchQuality.locationTier, "city_exact");
  });
});

test("collectMatchCandidatePool scans beyond limit for location match", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-ca", activeRequest({
        requestId: "request-student-ca",
        userId: "student-ca",
        userRef: {id: "student-ca"},
        filters: {},
      })),
      doc("student-us", activeRequest({
        requestId: "request-student-us",
        userId: "student-us",
        userRef: {id: "student-us"},
        filters: {},
      })),
    ],
    userDocsById: {
      "student-ca": doc("student-ca", studentData({
        Country_NS: {code: "CA"},
      })),
      "student-us": doc("student-us", studentData({
        Country_NS: {code: "US"},
      })),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    requesterFilters: {countryCode: "US"},
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
    studentLimit: 1,
    studentScanPageSize: 1,
    studentMaxScanPages: 3,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["student-us"],
  );
  assert.equal(result.stats.studentRequestsScanned, 2);
  assert.equal(result.stats.studentCandidates, 1);
});

test("collectMatchCandidatePool reads requester location for mutual filter", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-ca-only", activeRequest({
        requestId: "request-student-ca-only",
        userId: "student-ca-only",
        userRef: {id: "student-ca-only"},
        filters: {countryCode: "CA"},
      })),
      doc("student-us-city", activeRequest({
        requestId: "request-student-us-city",
        userId: "student-us-city",
        userRef: {id: "student-us-city"},
        filters: {countryCode: "US", cityKey: "new_york"},
      })),
    ],
    userDocsById: {
      "requester-a": doc("requester-a", studentData({
        Country_NS: {code: "US"},
        profileCity: {countryCode: "US", cityKey: "new_york"},
      })),
      "student-ca-only": doc("student-ca-only", studentData({
        Country_NS: {code: "US"},
      })),
      "student-us-city": doc("student-us-city", studentData({
        Country_NS: {code: "US"},
      })),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    requesterId: "requester-a",
    language: "en",
    requesterFilters: {countryCode: "US"},
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["student-us-city"],
  );
});

test("collectMatchCandidatePool filters blocklists in both directions", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-blocked", activeRequest({
        requestId: "request-student-blocked",
        userId: "student-blocked",
        userRef: {id: "student-blocked"},
        filters: {},
      })),
      doc("student-blocker", activeRequest({
        requestId: "request-student-blocker",
        userId: "student-blocker",
        userRef: {id: "student-blocker"},
        filters: {},
      })),
      doc("student-ok", activeRequest({
        requestId: "request-student-ok",
        userId: "student-ok",
        userRef: {id: "student-ok"},
        filters: {},
      })),
    ],
    teacherDocs: [
      doc("teacher-blocked", teacherData({
        availableSince: timestampFromMillis(fixedNowMillis - 260 * 1000),
      })),
      doc("teacher-blocker", teacherData({
        availableSince: timestampFromMillis(fixedNowMillis - 250 * 1000),
        blockedUsers: [{id: "requester-a"}],
      })),
      doc("teacher-ok", teacherData({
        availableSince: timestampFromMillis(fixedNowMillis - 240 * 1000),
      })),
    ],
    userDocsById: {
      "requester-a": doc("requester-a", studentData({
        blockedUsers: ["users/student-blocked", {id: "teacher-blocked"}],
      })),
      "student-blocked": doc("student-blocked", studentData()),
      "student-blocker": doc("student-blocker", studentData({
        blockedUsers: ["requester-a"],
      })),
      "student-ok": doc("student-ok", studentData()),
    },
    privateTokenDocsById: {
      "teacher-blocked": doc("teacher-blocked", privateTokenData()),
      "teacher-blocker": doc("teacher-blocker", privateTokenData()),
      "teacher-ok": doc("teacher-ok", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    requesterId: "users/requester-a",
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-ok", "student-ok"],
  );
  assert.equal(result.stats.studentCandidates, 1);
  assert.equal(result.stats.teacherCandidates, 1);
});

test("collectMatchCandidatePool keeps old callers working without requester doc", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-a", activeRequest({
        requestId: "request-student-a",
        userId: "student-a",
        userRef: {id: "student-a"},
        filters: {},
      })),
    ],
    userDocsById: {
      "student-a": doc("student-a", studentData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    requesterId: "missing-requester",
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["student-a"],
  );
});

test("collectMatchCandidatePool excludes teachers without usable token", async () => {
  const db = fakeDb({
    teacherDocs: [
      doc("teacher-empty", teacherData()),
      doc("teacher-whitespace", teacherData()),
    ],
    privateTokenDocsById: {
      "teacher-whitespace": doc("teacher-whitespace", {
        voipPushToken: "   ",
        voipToken: "",
      }),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
  });

  assert.deepEqual(result.candidates, []);
  assert.equal(result.stats.teacherUsersScanned, 2);
  assert.equal(result.stats.teacherCandidates, 0);
});

test(
  "collectMatchCandidatePool accepts private and legacy teacher tokens",
  async () => {
    const db = fakeDb({
      teacherDocs: [
        doc("teacher-private-push", teacherData({
          availableSince: timestampFromMillis(fixedNowMillis - 280 * 1000),
        })),
        doc("teacher-private-fcm", teacherData({
          availableSince: timestampFromMillis(fixedNowMillis - 240 * 1000),
        })),
        doc("teacher-legacy-fcm", teacherData({
          availableSince: timestampFromMillis(fixedNowMillis - 220 * 1000),
          voipToken: " legacy-fcm ",
        })),
        doc("teacher-legacy-push", teacherData({
          availableSince: timestampFromMillis(fixedNowMillis - 200 * 1000),
          voipPushToken: " legacy-push ",
        })),
        doc("teacher-cleared", teacherData({
          availableSince: timestampFromMillis(fixedNowMillis - 300 * 1000),
          voipToken: "stale-legacy-fcm",
        })),
      ],
      privateTokenDocsById: {
        "teacher-private-push": doc("teacher-private-push", {
          voipPushToken: " private-push ",
        }),
        "teacher-private-fcm": doc("teacher-private-fcm", {
          voipToken: " private-fcm ",
        }),
        "teacher-cleared": doc("teacher-cleared", {
          voipTokensClearedAt: timestampFromMillis(fixedNowMillis - 1000),
        }),
      },
    });

    const result = await collectMatchCandidatePool({
      db,
      language: "en",
      now: new Date(fixedNowMillis),
      nowMillis: fixedNowMillis,
    });

    assert.deepEqual(
      result.candidates.map((candidate) => candidate.userId),
      [
        "teacher-private-push",
        "teacher-private-fcm",
        "teacher-legacy-fcm",
        "teacher-legacy-push",
      ],
    );
    assert.deepEqual(result.candidates.map((candidate) => candidate.tokenState), [
      {hasFcmToken: false, hasVoipPushToken: true, source: "private"},
      {hasFcmToken: true, hasVoipPushToken: false, source: "private"},
      {hasFcmToken: true, hasVoipPushToken: false, source: "legacy"},
      {hasFcmToken: false, hasVoipPushToken: true, source: "legacy"},
    ]);
    result.candidates.forEach((candidate) => {
      assert.equal(candidate.voipToken, undefined);
      assert.equal(candidate.voipPushToken, undefined);
    });
  },
);

test("collectMatchCandidatePool scans past tokenless teachers", async () => {
  const db = fakeDb({
    teacherDocs: [
      doc("teacher-tokenless", teacherData()),
      doc("teacher-a", teacherData()),
    ],
    privateTokenDocsById: {
      "teacher-a": doc("teacher-a", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
    teacherLimit: 1,
    teacherScanPageSize: 1,
    teacherMaxScanPages: 3,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-a"],
  );
  assert.equal(result.stats.teacherUsersScanned, 2);
  assert.equal(result.stats.teacherCandidates, 1);
});

test("collectMatchCandidatePool scans past users already in call", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-in-call", activeRequest({
        requestId: "request-student-in-call",
        userId: "student-in-call",
        userRef: {id: "student-in-call"},
        createdAt: timestampFromMillis(fixedNowMillis - 180 * 1000),
      })),
      doc("student-session", activeRequest({
        requestId: "request-student-session",
        userId: "student-session",
        userRef: {id: "student-session"},
        createdAt: timestampFromMillis(fixedNowMillis - 160 * 1000),
      })),
      doc("student-a", activeRequest({
        requestId: "request-student-a",
        userId: "student-a",
        userRef: {id: "student-a"},
        createdAt: timestampFromMillis(fixedNowMillis - 140 * 1000),
      })),
    ],
    teacherDocs: [
      doc("teacher-in-call", teacherData({
        isInCall: true,
        availableSince: timestampFromMillis(fixedNowMillis - 300 * 1000),
      })),
      doc("teacher-session", teacherData({
        currentSessionId: "session-a",
        availableSince: timestampFromMillis(fixedNowMillis - 280 * 1000),
      })),
      doc("teacher-a", teacherData({
        availableSince: timestampFromMillis(fixedNowMillis - 260 * 1000),
      })),
    ],
    userDocsById: {
      "student-in-call": doc("student-in-call", studentData({isInCall: true})),
      "student-session": doc("student-session", studentData({
        currentSessionId: "session-a",
      })),
      "student-a": doc("student-a", studentData()),
    },
    privateTokenDocsById: {
      "teacher-in-call": doc("teacher-in-call", privateTokenData()),
      "teacher-session": doc("teacher-session", privateTokenData()),
      "teacher-a": doc("teacher-a", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
    studentLimit: 1,
    teacherLimit: 1,
    studentScanPageSize: 1,
    teacherScanPageSize: 1,
    studentMaxScanPages: 4,
    teacherMaxScanPages: 4,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-a", "student-a"],
  );
  assert.equal(result.stats.studentRequestsScanned, 3);
  assert.equal(result.stats.teacherUsersScanned, 3);
  assert.equal(result.stats.studentCandidates, 1);
  assert.equal(result.stats.teacherCandidates, 1);
});

test("collectMatchCandidatePool scans past invalid first page docs", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-stale", activeRequest({
        userId: "student-stale",
        userRef: {id: "student-stale"},
        heartbeatAt: timestampFromMillis(fixedNowMillis - 91 * 1000),
      })),
      doc("student-a", activeRequest()),
    ],
    teacherDocs: [
      doc("teacher-unavailable", teacherData({isAvailable: false})),
      doc("teacher-a", teacherData()),
    ],
    userDocsById: {
      "student-stale": doc("student-stale", studentData()),
      "student-a": doc("student-a", studentData()),
    },
    privateTokenDocsById: {
      "teacher-a": doc("teacher-a", privateTokenData()),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
    studentLimit: 1,
    teacherLimit: 1,
    studentScanPageSize: 1,
    teacherScanPageSize: 1,
    studentMaxScanPages: 3,
    teacherMaxScanPages: 3,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["teacher-a", "student-a"],
  );
  assert.equal(result.stats.studentRequestsScanned, 2);
  assert.equal(result.stats.teacherUsersScanned, 2);
  assert.equal(result.stats.studentCandidates, 1);
  assert.equal(result.stats.teacherCandidates, 1);
});

test("collectMatchCandidatePool scans past level mismatches", async () => {
  const db = fakeDb({
    studentRequestDocs: [
      doc("student-far", activeRequest({
        requestId: "request-student-far",
        userId: "student-far",
        userRef: {id: "student-far"},
        filters: {},
      })),
      doc("student-exact", activeRequest({
        requestId: "request-student-exact",
        userId: "student-exact",
        userRef: {id: "student-exact"},
        filters: {},
      })),
    ],
    userDocsById: {
      "student-far": doc("student-far", studentData({level: {value: "C1"}})),
      "student-exact": doc(
        "student-exact",
        studentData({level: {value: "B1"}}),
      ),
    },
  });

  const result = await collectMatchCandidatePool({
    db,
    language: "en",
    requesterFilters: {preferredLevel: "B1"},
    now: new Date(fixedNowMillis),
    nowMillis: fixedNowMillis,
    studentLimit: 1,
    studentScanPageSize: 1,
    studentMaxScanPages: 3,
  });

  assert.deepEqual(
    result.candidates.map((candidate) => candidate.userId),
    ["student-exact"],
  );
  assert.equal(result.stats.studentRequestsScanned, 2);
  assert.equal(result.stats.studentCandidates, 1);
});

test("candidate pool queries use canonical active queue and teacher sources", () => {
  const calls = [];
  const query = {
    where: (...args) => {
      calls.push(["where", ...args]);
      return query;
    },
    orderBy: (...args) => {
      calls.push(["orderBy", ...args]);
      return query;
    },
    limit: (...args) => {
      calls.push(["limit", ...args]);
      return query;
    },
  };
  const db = {
    collection: (name) => {
      calls.push(["collection", name]);
      return query;
    },
  };

  buildActiveStudentSearchRequestsQuery(db, {language: " EN ", limit: 10});
  buildAvailableTeachersQuery(db, {language: " EN ", limit: 20});

  assert.deepEqual(calls, [
    ["collection", "searchRequests"],
    ["where", "status", "==", "active"],
    ["where", "language", "==", "en"],
    ["orderBy", "createdAt", "asc"],
    ["limit", 10],
    ["collection", "users"],
    ["where", "role", "==", "native_speaker"],
    ["where", "language_instruction_NS.code", "==", "en"],
    ["limit", 20],
  ]);
});

test("candidate pool indexes support active search request queries", () => {
  const indexes = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "firestore.indexes.json"),
    "utf8",
  ));
  const hasStatusCreatedAtIndex = indexes.indexes.some((index) =>
    index.collectionGroup === "searchRequests" &&
    index.fields.some((field) => field.fieldPath === "status") &&
    index.fields.some((field) => field.fieldPath === "createdAt"),
  );
  const hasStatusLanguageCreatedAtIndex = indexes.indexes.some((index) =>
    index.collectionGroup === "searchRequests" &&
    index.fields.some((field) => field.fieldPath === "status") &&
    index.fields.some((field) => field.fieldPath === "language") &&
    index.fields.some((field) => field.fieldPath === "createdAt"),
  );

  assert.equal(hasStatusCreatedAtIndex, true);
  assert.equal(hasStatusLanguageCreatedAtIndex, true);
});
