import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/app_loading_indicator.dart';
import '/components/basic_page_header.dart';
import '/components/empty/empty_widget.dart';
import '/components/ux_error_state.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'black_list_model.dart';
export 'black_list_model.dart';

const ValueKey<String> blackListLoadingKey =
    ValueKey<String>('black_list_loading');
const ValueKey<String> blackListEmptyKey = ValueKey<String>('black_list_empty');
const ValueKey<String> blackListErrorKey = ValueKey<String>('black_list_error');
const ValueKey<String> blackListRetryButtonKey =
    ValueKey<String>('black_list_retry_button');
const ValueKey<String> blackListRefreshErrorKey =
    ValueKey<String>('black_list_refresh_error');
const ValueKey<String> blackListRefreshingKey =
    ValueKey<String>('black_list_refreshing');
const ValueKey<String> blackListListKey = ValueKey<String>('black_list_list');

ValueKey<String> blackListUserRowKey(DocumentReference userReference) =>
    ValueKey<String>('black_list_row_${userReference.path}');

ValueKey<String> blackListDeleteButtonKey(DocumentReference userReference) =>
    ValueKey<String>('black_list_delete_${userReference.path}');

typedef BlackListCurrentUidProvider = String Function();
typedef BlackListProfileLoader = Future<UserPublicProfilesRecord?> Function(
  DocumentReference userReference,
);
typedef BlackListOwnerStateStreamFactory = Stream<BlackListOwnerState> Function(
  String ownerUid,
);
typedef BlackListBlockedUserRemover = Future<void> Function(
  String ownerUid,
  DocumentReference userReference,
);

List<DocumentReference> _mergeBlockedUsersWithAuthoritativeBaseline({
  required List<DocumentReference> authoritativeBaseline,
  required List<DocumentReference> incoming,
}) {
  final mergedByPath = <String, DocumentReference>{};
  for (final reference in authoritativeBaseline) {
    mergedByPath[reference.path] = reference;
  }
  for (final reference in incoming) {
    mergedByPath.putIfAbsent(reference.path, () => reference);
  }
  return List<DocumentReference>.unmodifiable(mergedByPath.values);
}

sealed class BlackListOwnerState {
  const BlackListOwnerState({required this.ownerUid});

  final String ownerUid;
}

final class BlackListOwnerLoading extends BlackListOwnerState {
  const BlackListOwnerLoading({required super.ownerUid});
}

final class BlackListOwnerData extends BlackListOwnerState {
  BlackListOwnerData({
    required super.ownerUid,
    required List<DocumentReference> blockedUsers,
    required this.isServerConfirmed,
  }) : blockedUsers = List<DocumentReference>.unmodifiable(blockedUsers);

  final List<DocumentReference> blockedUsers;
  final bool isServerConfirmed;
}

final class BlackListOwnerDocumentSnapshot {
  BlackListOwnerDocumentSnapshot({
    required String ownerUid,
    required List<DocumentReference> blockedUsers,
    required this.documentExists,
    required this.isFromCache,
    required this.hasPendingWrites,
  })  : ownerUid = ownerUid.trim(),
        blockedUsers = List<DocumentReference>.unmodifiable(blockedUsers);

  final String ownerUid;
  final List<DocumentReference> blockedUsers;
  final bool documentExists;
  final bool isFromCache;
  final bool hasPendingWrites;
}

bool blackListSnapshotIsServerConfirmed({
  required bool isFromCache,
  required bool hasPendingWrites,
}) =>
    !isFromCache && !hasPendingWrites;

BlackListOwnerState resolveBlackListOwnerDocumentSnapshot({
  required String expectedOwnerUid,
  required BlackListOwnerDocumentSnapshot snapshot,
}) {
  final ownerUid = expectedOwnerUid.trim();
  if (ownerUid.isEmpty || snapshot.ownerUid != ownerUid) {
    return BlackListOwnerLoading(ownerUid: ownerUid);
  }

  final isServerConfirmed = blackListSnapshotIsServerConfirmed(
    isFromCache: snapshot.isFromCache,
    hasPendingWrites: snapshot.hasPendingWrites,
  );
  if (!snapshot.documentExists) {
    if (!isServerConfirmed) {
      return BlackListOwnerLoading(ownerUid: ownerUid);
    }
    throw StateError('BlackListWidget: owner document is missing');
  }
  if (snapshot.blockedUsers.isEmpty && !isServerConfirmed) {
    return BlackListOwnerLoading(ownerUid: ownerUid);
  }

  return BlackListOwnerData(
    ownerUid: ownerUid,
    blockedUsers: snapshot.blockedUsers,
    isServerConfirmed: isServerConfirmed,
  );
}

Stream<BlackListOwnerState> adaptBlackListOwnerDocumentSnapshots({
  required String expectedOwnerUid,
  required Stream<BlackListOwnerDocumentSnapshot> snapshots,
}) =>
    snapshots.map(
      (snapshot) => resolveBlackListOwnerDocumentSnapshot(
        expectedOwnerUid: expectedOwnerUid,
        snapshot: snapshot,
      ),
    );

Stream<BlackListOwnerDocumentSnapshot> _watchBlackListOwnerDocument(
  String ownerUid,
) {
  return UsersRecord.collection
      .doc(ownerUid)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
    final userDocument = snapshot.exists && snapshot.data() != null
        ? UsersRecord.fromSnapshot(snapshot)
        : null;
    return BlackListOwnerDocumentSnapshot(
      ownerUid: snapshot.reference.id,
      blockedUsers: userDocument?.blockedUsers ?? const <DocumentReference>[],
      documentExists: snapshot.exists,
      isFromCache: snapshot.metadata.isFromCache,
      hasPendingWrites: snapshot.metadata.hasPendingWrites,
    );
  });
}

Stream<BlackListOwnerState> _watchBlackListOwnerForUid(String ownerUid) async* {
  yield BlackListOwnerLoading(ownerUid: ownerUid);
  if (ownerUid.isNotEmpty) {
    yield* adaptBlackListOwnerDocumentSnapshots(
      expectedOwnerUid: ownerUid,
      snapshots: _watchBlackListOwnerDocument(ownerUid),
    );
  }
}

Stream<String> _watchBlackListOwnerIds() => FirebaseAuth.instance
    .authStateChanges()
    .map((user) => user?.uid.trim() ?? '');

class BlackListWidget extends StatefulWidget {
  const BlackListWidget({
    super.key,
    this.ownerStateStream,
    this.authUidStream,
    this.ownerStateStreamFactory,
    this.currentUidProvider,
    this.profileLoader,
    this.blockedUserRemover,
  });

  static String routeName = 'blackList';
  static String routePath = '/blackList';

  final Stream<BlackListOwnerState>? ownerStateStream;
  @visibleForTesting
  final Stream<String>? authUidStream;
  @visibleForTesting
  final BlackListOwnerStateStreamFactory? ownerStateStreamFactory;
  final BlackListCurrentUidProvider? currentUidProvider;
  final BlackListProfileLoader? profileLoader;
  @visibleForTesting
  final BlackListBlockedUserRemover? blockedUserRemover;

  @override
  State<BlackListWidget> createState() => _BlackListWidgetState();
}

class _BlackListWidgetState extends State<BlackListWidget> {
  late BlackListModel _model;
  final _userFutureCache = <String, Future<UserPublicProfilesRecord?>>{};
  StreamSubscription<String>? _authUidSubscription;
  StreamSubscription<BlackListOwnerState>? _ownerStateSubscription;
  BlackListOwnerData? _displayedOwnerData;
  List<DocumentReference> _authoritativeBlockedUsers = const [];
  bool _hasAuthoritativeOwnerData = false;
  bool _ownerRefreshing = false;
  Object? _ownerStateError;
  String _activeOwnerUid = '';
  String _sourceOwnerUid = '';
  String? _lastObservedSessionCacheOwnerUid;
  int _ownerEpoch = 0;
  int _ownerCacheGeneration = 0;
  int _authSubscriptionGeneration = 0;
  int _subscriptionGeneration = 0;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _hasDisplayableOwnerData {
    final ownerData = _displayedOwnerData;
    return ownerData != null &&
        ownerData.ownerUid == _activeOwnerUid &&
        (_hasAuthoritativeOwnerData || ownerData.blockedUsers.isNotEmpty);
  }

  String _currentUid() {
    final providedUid = widget.currentUidProvider?.call();
    if (providedUid != null) {
      return providedUid.trim();
    }
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  }

  Future<UserPublicProfilesRecord?> _getUserFuture(
    DocumentReference ref,
    int ownerEpoch,
  ) {
    return _userFutureCache.putIfAbsent(
      '$ownerEpoch:${ref.path}',
      () =>
          widget.profileLoader?.call(ref) ??
          UserPublicProfilesRecord.maybeGetDocumentOnce(
            UserPublicProfilesRecord.collection.doc(ref.id),
          ),
    );
  }

  String _publicProfileDisplayName(
    BuildContext context,
    UserPublicProfilesRecord? profile,
  ) {
    final displayName = profile?.displayName.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Пользователь',
      enText: 'User',
    );
  }

  String _publicProfilePhotoUrl(UserPublicProfilesRecord? profile) =>
      profile?.photoUrl.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BlackListModel());
    BlackListModel.ensureSessionCacheLifecycleRegistered();
    final initialOwnerUid = _currentUid();
    _lastObservedSessionCacheOwnerUid =
        initialOwnerUid.isEmpty ? null : initialOwnerUid;
    _beginOwnerSession(initialOwnerUid, force: true);
    _sourceOwnerUid = _activeOwnerUid;
    _subscribeToConfiguredSources();
  }

  @override
  void didUpdateWidget(covariant BlackListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentUid = _currentUid();
    _observeSessionCacheOwner(currentUid);
    _applyOwnerBoundary(currentUid);
    if (oldWidget.ownerStateStream != widget.ownerStateStream ||
        oldWidget.authUidStream != widget.authUidStream ||
        oldWidget.ownerStateStreamFactory != widget.ownerStateStreamFactory) {
      _restartConfiguredSources();
    }
    if (oldWidget.profileLoader != widget.profileLoader) {
      _userFutureCache.clear();
    }
  }

  @override
  void dispose() {
    _authSubscriptionGeneration += 1;
    _subscriptionGeneration += 1;
    unawaited(_authUidSubscription?.cancel());
    unawaited(_ownerStateSubscription?.cancel());
    _model.dispose();
    super.dispose();
  }

  bool get _usesCombinedOwnerStateStream =>
      widget.ownerStateStream != null &&
      widget.authUidStream == null &&
      widget.ownerStateStreamFactory == null;

  Stream<BlackListOwnerState> _createOwnerStateStream(String ownerUid) =>
      widget.ownerStateStreamFactory?.call(ownerUid) ??
      widget.ownerStateStream ??
      _watchBlackListOwnerForUid(ownerUid);

  void _subscribeToConfiguredSources() {
    if (_usesCombinedOwnerStateStream) {
      _subscribeToOwnerState(
        ++_subscriptionGeneration,
        stream: widget.ownerStateStream!,
      );
      return;
    }
    _subscribeToAuthUidStream(++_authSubscriptionGeneration);
  }

  void _restartConfiguredSources() {
    _authSubscriptionGeneration += 1;
    _subscriptionGeneration += 1;
    final previousAuthSubscription = _authUidSubscription;
    final previousOwnerSubscription = _ownerStateSubscription;
    _authUidSubscription = null;
    _ownerStateSubscription = null;
    unawaited(previousAuthSubscription?.cancel());
    unawaited(previousOwnerSubscription?.cancel());
    if (!mounted) {
      return;
    }
    _subscribeToConfiguredSources();
  }

  void _subscribeToAuthUidStream(int generation) {
    final authUidStream = widget.authUidStream ?? _watchBlackListOwnerIds();
    _authUidSubscription = authUidStream.listen(
      (rawOwnerUid) => _handleRawAuthUid(generation, rawOwnerUid),
      onError: (Object error, StackTrace stackTrace) {
        _handleRawAuthError(generation, error);
      },
    );
  }

  void _handleRawAuthUid(int generation, String rawOwnerUid) {
    if (!mounted || generation != _authSubscriptionGeneration) {
      return;
    }
    final ownerUid = rawOwnerUid.trim();
    _observeSessionCacheOwner(ownerUid);
    late final int ownerEpoch;
    setState(() {
      _beginOwnerSession(ownerUid, force: true);
      ownerEpoch = _ownerEpoch;
    });
    _restartOwnerStateSubscription(
      ownerUid: ownerUid,
      ownerEpoch: ownerEpoch,
    );
  }

  void _handleRawAuthError(int generation, Object error) {
    if (!mounted || generation != _authSubscriptionGeneration) {
      return;
    }
    _observeSessionCacheOwner('');
    setState(() {
      _beginOwnerSession('', force: true);
      _ownerStateError = error;
    });
  }

  void _subscribeToOwnerState(
    int generation, {
    required Stream<BlackListOwnerState> stream,
    String? expectedOwnerUid,
    int? ownerEpoch,
  }) {
    _sourceOwnerUid = expectedOwnerUid ?? _currentUid();
    try {
      _ownerStateSubscription = stream.listen(
        (ownerState) => _handleOwnerState(
          generation,
          ownerState,
          expectedOwnerUid: expectedOwnerUid,
          ownerEpoch: ownerEpoch,
        ),
        onError: (Object error, StackTrace stackTrace) {
          _handleOwnerStateError(
            generation,
            error,
            expectedOwnerUid: expectedOwnerUid,
            ownerEpoch: ownerEpoch,
          );
        },
      );
    } on Object catch (error) {
      _handleOwnerStateError(
        generation,
        error,
        expectedOwnerUid: expectedOwnerUid,
        ownerEpoch: ownerEpoch,
      );
    }
  }

  void _restartOwnerStateSubscription({
    String? ownerUid,
    int? ownerEpoch,
  }) {
    final generation = ++_subscriptionGeneration;
    final previousSubscription = _ownerStateSubscription;
    _ownerStateSubscription = null;
    unawaited(previousSubscription?.cancel());
    if (!mounted || generation != _subscriptionGeneration) {
      return;
    }
    if (_usesCombinedOwnerStateStream) {
      _subscribeToOwnerState(
        generation,
        stream: widget.ownerStateStream!,
      );
      return;
    }
    final effectiveOwnerUid = ownerUid ?? _activeOwnerUid;
    final effectiveOwnerEpoch = ownerEpoch ?? _ownerEpoch;
    _subscribeToOwnerState(
      generation,
      stream: _createOwnerStateStream(effectiveOwnerUid),
      expectedOwnerUid: effectiveOwnerUid,
      ownerEpoch: effectiveOwnerEpoch,
    );
  }

  void _applyOwnerBoundary(String currentUid) {
    _beginOwnerSession(currentUid, force: false);
  }

  void _observeSessionCacheOwner(String ownerUid) {
    final previousOwnerUid = _lastObservedSessionCacheOwnerUid;
    if (previousOwnerUid != null && previousOwnerUid != ownerUid) {
      BlackListModel.debugClearSessionCache();
    }
    _lastObservedSessionCacheOwnerUid = ownerUid;
  }

  void _beginOwnerSession(String ownerUid, {required bool force}) {
    if (!force && _activeOwnerUid == ownerUid) {
      return;
    }
    final cachedBlockedUsers =
        ownerUid.isEmpty ? null : BlackListModel.cachedBlockedUsers(ownerUid);
    _ownerEpoch += 1;
    _ownerCacheGeneration = BlackListModel.sessionCacheGeneration;
    _activeOwnerUid = ownerUid;
    _authoritativeBlockedUsers = cachedBlockedUsers == null
        ? const []
        : List<DocumentReference>.unmodifiable(cachedBlockedUsers);
    _displayedOwnerData = cachedBlockedUsers == null
        ? null
        : BlackListOwnerData(
            ownerUid: ownerUid,
            blockedUsers: _authoritativeBlockedUsers,
            isServerConfirmed: true,
          );
    _hasAuthoritativeOwnerData = cachedBlockedUsers != null;
    _ownerRefreshing = cachedBlockedUsers != null;
    _ownerStateError = null;
    _userFutureCache.clear();
  }

  bool _ownerBoundaryMatches({
    required String ownerUid,
    required int ownerEpoch,
  }) {
    final currentUid = _currentUid();
    _observeSessionCacheOwner(currentUid);
    return ownerUid.isNotEmpty &&
        ownerUid == _activeOwnerUid &&
        ownerEpoch == _ownerEpoch &&
        currentUid == ownerUid &&
        _displayedOwnerData?.ownerUid == ownerUid;
  }

  void _invalidateForDirectOwnerBoundaryMismatch() {
    final currentUid = _currentUid();
    _observeSessionCacheOwner(currentUid);
    if (!mounted || currentUid == _activeOwnerUid) {
      return;
    }
    setState(() => _applyOwnerBoundary(currentUid));
  }

  void _scheduleDirectOwnerBoundaryCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _invalidateForDirectOwnerBoundaryMismatch();
    });
  }

  void _handleOwnerState(
    int generation,
    BlackListOwnerState ownerState, {
    required String? expectedOwnerUid,
    required int? ownerEpoch,
  }) {
    if (!mounted ||
        generation != _subscriptionGeneration ||
        (ownerEpoch != null && ownerEpoch != _ownerEpoch)) {
      return;
    }
    _observeSessionCacheOwner(_currentUid());
    setState(() {
      final currentUid = _currentUid();
      _applyOwnerBoundary(currentUid);
      if (ownerEpoch != null && ownerEpoch != _ownerEpoch) {
        return;
      }
      final sourceOwnerUid = expectedOwnerUid ?? ownerState.ownerUid.trim();
      _sourceOwnerUid = sourceOwnerUid;
      if (currentUid.isEmpty ||
          sourceOwnerUid != currentUid ||
          ownerState.ownerUid.trim() != currentUid) {
        return;
      }

      _ownerStateError = null;
      if (ownerState is BlackListOwnerLoading) {
        _ownerRefreshing = _hasDisplayableOwnerData;
        return;
      }
      if (ownerState is! BlackListOwnerData) {
        return;
      }

      if (ownerState.isServerConfirmed) {
        _authoritativeBlockedUsers = List<DocumentReference>.unmodifiable(
          ownerState.blockedUsers,
        );
        _displayedOwnerData = BlackListOwnerData(
          ownerUid: currentUid,
          blockedUsers: _authoritativeBlockedUsers,
          isServerConfirmed: true,
        );
        _hasAuthoritativeOwnerData = true;
        _ownerRefreshing = false;
        BlackListModel.cacheBlockedUsers(
          currentUid,
          _authoritativeBlockedUsers,
          expectedGeneration: _ownerCacheGeneration,
        );
        return;
      }

      final mergedBlockedUsers = _mergeBlockedUsersWithAuthoritativeBaseline(
        authoritativeBaseline: _authoritativeBlockedUsers,
        incoming: ownerState.blockedUsers,
      );
      if (mergedBlockedUsers.isEmpty && !_hasAuthoritativeOwnerData) {
        _ownerRefreshing = false;
        return;
      }
      _displayedOwnerData = BlackListOwnerData(
        ownerUid: currentUid,
        blockedUsers: mergedBlockedUsers,
        isServerConfirmed: false,
      );
      _ownerRefreshing = true;
    });
  }

  void _handleOwnerStateError(
    int generation,
    Object error, {
    required String? expectedOwnerUid,
    required int? ownerEpoch,
  }) {
    if (!mounted ||
        generation != _subscriptionGeneration ||
        (ownerEpoch != null && ownerEpoch != _ownerEpoch)) {
      return;
    }
    if (kDebugMode) {
      debugPrint(
        'BlackListWidget: owner state source failed: ${error.runtimeType}',
      );
    }
    _observeSessionCacheOwner(_currentUid());
    setState(() {
      final currentUid = _currentUid();
      _applyOwnerBoundary(currentUid);
      if (ownerEpoch != null && ownerEpoch != _ownerEpoch) {
        return;
      }
      final sourceOwnerUid = expectedOwnerUid ?? _sourceOwnerUid;
      _ownerRefreshing = false;
      if (currentUid.isNotEmpty && sourceOwnerUid == currentUid) {
        _ownerStateError = error;
      }
    });
  }

  void _retryOwnerState() {
    setState(() {
      _applyOwnerBoundary(_currentUid());
      _ownerStateError = null;
      _ownerRefreshing = _hasDisplayableOwnerData;
    });
    _restartOwnerStateSubscription();
  }

  Widget _buildLoadingState(BuildContext context) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Загрузка чёрного списка',
      enText: 'Loading blocked list',
    );
    return Semantics(
      key: blackListLoadingKey,
      container: true,
      liveRegion: true,
      label: label,
      child: const ExcludeSemantics(
        child: Center(child: AppLoadingIndicator()),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось загрузить чёрный список',
      enText: 'Unable to load blocked list',
    );
    final message = FFLocalizations.of(context).getVariableText(
      ruText: 'Попробуйте позже.',
      enText: 'Please try again later.',
    );
    return Center(
      child: SizedBox(
        height: 500.0,
        child: Center(
          child: UxErrorState(
            stateKey: blackListErrorKey,
            title: title,
            message: message,
            liveRegion: true,
            onRetry: _retryOwnerState,
            retryLabel: FFLocalizations.of(context).getVariableText(
              ruText: 'Повторить',
              enText: 'Try again',
            ),
            retrySemanticsLabel: FFLocalizations.of(context).getVariableText(
              ruText: 'Повторить загрузку чёрного списка',
              enText: 'Retry loading blocked list',
            ),
            retryButtonKey: blackListRetryButtonKey,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      key: blackListEmptyKey,
      child: SizedBox(
        height: 500.0,
        child: EmptyWidget(
          txt: FFLocalizations.of(context).getVariableText(
            ruText:
                'В этом разделе будут отображаться собеседники, которых вы добавили в чёрный список. Если список пуст, все пользователи доступны для подбора звонков.',
            enText:
                'People you block will appear here. When the list is empty, all users remain available for call matching.',
          ),
        ),
      ),
    );
  }

  Future<void> _removeBlockedUser({
    required String ownerUid,
    required int ownerEpoch,
    required DocumentReference userReference,
  }) async {
    if (!_ownerBoundaryMatches(
      ownerUid: ownerUid,
      ownerEpoch: ownerEpoch,
    )) {
      _invalidateForDirectOwnerBoundaryMismatch();
      return;
    }
    final remover = widget.blockedUserRemover;
    if (remover != null) {
      await remover(ownerUid, userReference);
      return;
    }
    final signedInUserRef = currentUserReference;
    if (signedInUserRef?.id != ownerUid) {
      return;
    }
    await signedInUserRef!.update({
      ...mapToFirestore(
        {
          'blockedUsers': FieldValue.arrayRemove([userReference]),
        },
      ),
    });
  }

  Widget _buildList(
    BuildContext context, {
    required String ownerUid,
    required int ownerEpoch,
    required List<DocumentReference> blockedUsers,
  }) {
    return ListView.separated(
      key: blackListListKey,
      padding: const EdgeInsets.fromLTRB(
        ExpatlioDesign.space0,
        ExpatlioDesign.space112,
        ExpatlioDesign.space0,
        ExpatlioDesign.space112,
      ),
      itemCount: blockedUsers.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: ExpatlioDesign.space8),
      itemBuilder: (context, listIndex) {
        final listItem = blockedUsers[listIndex];
        return SizedBox(
          key: blackListUserRowKey(listItem),
          height: 72.0,
          child: FutureBuilder<UserPublicProfilesRecord?>(
            key: ValueKey<String>(
              'black_list_profile_${ownerEpoch}_${listItem.path}',
            ),
            future: _getUserFuture(listItem, ownerEpoch),
            builder: (context, snapshot) {
              if (!_ownerBoundaryMatches(
                ownerUid: ownerUid,
                ownerEpoch: ownerEpoch,
              )) {
                _scheduleDirectOwnerBoundaryCheck();
                return const SizedBox.shrink();
              }
              if (kDebugMode && snapshot.hasError) {
                debugPrint(
                  'BlackListWidget: failed to load public profile: '
                  '${snapshot.error.runtimeType}',
                );
              }
              final profile = snapshot.data;
              return _buildUserRow(
                context,
                displayName: _publicProfileDisplayName(context, profile),
                photoUrl: _publicProfilePhotoUrl(profile),
                profileLoading:
                    snapshot.connectionState == ConnectionState.waiting,
                onTap: profile?.role == UserRole.native_speaker &&
                        profile?.approvedTeacher == true
                    ? () => _openNativeSpeakerProfile(
                          context: context,
                          ownerUid: ownerUid,
                          ownerEpoch: ownerEpoch,
                          userReference: listItem,
                        )
                    : null,
                onDelete: () => _removeBlockedUser(
                  ownerUid: ownerUid,
                  ownerEpoch: ownerEpoch,
                  userReference: listItem,
                ),
                deleteButtonKey: blackListDeleteButtonKey(listItem),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOwnerData(
    BuildContext context,
    BlackListOwnerData ownerData,
  ) {
    return ownerData.blockedUsers.isEmpty
        ? _buildEmptyState(context)
        : _buildList(
            context,
            ownerUid: ownerData.ownerUid,
            ownerEpoch: _ownerEpoch,
            blockedUsers: ownerData.blockedUsers,
          );
  }

  void _openNativeSpeakerProfile({
    required BuildContext context,
    required String ownerUid,
    required int ownerEpoch,
    required DocumentReference userReference,
  }) {
    if (!_ownerBoundaryMatches(
      ownerUid: ownerUid,
      ownerEpoch: ownerEpoch,
    )) {
      _invalidateForDirectOwnerBoundaryMismatch();
      return;
    }
    context.pushNamed(
      NativeSpeakerPageWidget.routeName,
      queryParameters: {
        'nsUserDocRef': serializeParam(
          userReference,
          ParamType.DocumentReference,
        ),
      }.withoutNulls,
    );
  }

  Widget _buildRefreshErrorButton(BuildContext context) {
    final localizations = FFLocalizations.of(context);
    final label = localizations.getVariableText(
      ruText: 'Не удалось обновить чёрный список',
      enText: 'Unable to refresh blocked list',
    );
    final semanticsLabel = localizations.getVariableText(
      ruText: '$label. Повторить',
      enText: '$label. Try again',
    );

    return Semantics(
      key: blackListRefreshErrorKey,
      container: true,
      liveRegion: true,
      button: true,
      label: semanticsLabel,
      onTap: _retryOwnerState,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Material(
            color: ExpatlioDesign.mutedSurface,
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
            child: InkWell(
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
              onTap: _retryOwnerState,
              child: const SizedBox.square(
                dimension: 44.0,
                child: Center(
                  child: Icon(
                    Icons.cloud_off_outlined,
                    size: 20.0,
                    color: ExpatlioDesign.danger,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshingIndicator(BuildContext context) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Обновление чёрного списка',
      enText: 'Refreshing blocked list',
    );
    return Semantics(
      key: blackListRefreshingKey,
      container: true,
      liveRegion: true,
      label: label,
      child: const ExcludeSemantics(
        child: SizedBox.square(
          dimension: 44.0,
          child: Padding(
            padding: EdgeInsets.all(12.0),
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: ExpatlioDesign.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserRow(
    BuildContext context, {
    required String displayName,
    required String photoUrl,
    required bool profileLoading,
    required VoidCallback? onTap,
    required Future<void> Function() onDelete,
    required Key deleteButtonKey,
  }) {
    final deleteLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Удалить пользователя $displayName из чёрного списка',
      enText: 'Remove $displayName from blocked list',
    );
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 72.0,
        decoration: const BoxDecoration(
          color: ExpatlioDesign.background,
          border: Border(
            bottom: BorderSide(color: ExpatlioDesign.border),
          ),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space0,
          ExpatlioDesign.space8,
          ExpatlioDesign.space0,
          ExpatlioDesign.space8,
        ),
        child: Row(
          children: [
            Container(
              width: 52.0,
              height: 52.0,
              decoration: BoxDecoration(
                color: ExpatlioDesign.mutedSurface,
                image: photoUrl.isNotEmpty
                    ? DecorationImage(
                        fit: BoxFit.cover,
                        image: CachedNetworkImageProvider(
                          photoUrl,
                          maxWidth: 104,
                          maxHeight: 104,
                        ),
                      )
                    : null,
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
              ),
              child: photoUrl.isNotEmpty
                  ? null
                  : Center(
                      child: profileLoading
                          ? SpinKitCircle(
                              color: FlutterFlowTheme.of(context).secondary,
                              size: 24.0,
                            )
                          : Text(
                              displayName.characters.first.toUpperCase(),
                              style: ExpatlioDesign.textStyle(
                                context,
                                color: ExpatlioDesign.muted,
                                size: 16.0,
                                weight: FontWeight.w700,
                              ),
                            ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: ExpatlioDesign.space12,
                ),
                child: Text(
                  displayName,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        color: ExpatlioDesign.text,
                        fontSize: 16.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w700,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Semantics(
              key: deleteButtonKey,
              container: true,
              button: true,
              label: deleteLabel,
              onTap: onDelete,
              excludeSemantics: true,
              child: Tooltip(
                message: deleteLabel,
                child: FlutterFlowIconButton(
                  borderRadius: ExpatlioDesign.radiusMedium,
                  buttonSize: 52.0,
                  icon: Icon(
                    FFIcons.ktrash03,
                    color: FlutterFlowTheme.of(context).error,
                    size: 18.0,
                  ),
                  onPressed: onDelete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space16,
                ExpatlioDesign.space0,
                ExpatlioDesign.space16,
                ExpatlioDesign.space0,
              ),
              child: Builder(builder: (context) {
                final currentUid = _currentUid();
                _observeSessionCacheOwner(currentUid);
                if (currentUid.isEmpty || currentUid != _activeOwnerUid) {
                  _scheduleDirectOwnerBoundaryCheck();
                  return _buildLoadingState(context);
                }
                final ownerData = _displayedOwnerData;
                if (ownerData != null && ownerData.ownerUid == currentUid) {
                  return _buildOwnerData(context, ownerData);
                }
                if (_ownerStateError != null) {
                  return _buildErrorState(context);
                }
                return _buildLoadingState(context);
              }),
            ),
            BasicPageHeader(
              title: FFLocalizations.of(context).getVariableText(
                ruText: 'Черный список',
                enText: 'Blacklist',
              ),
              trailing: _activeOwnerUid.isNotEmpty &&
                      _currentUid() == _activeOwnerUid &&
                      _hasDisplayableOwnerData &&
                      _displayedOwnerData?.ownerUid == _activeOwnerUid
                  ? _ownerStateError != null
                      ? _buildRefreshErrorButton(context)
                      : _ownerRefreshing
                          ? _buildRefreshingIndicator(context)
                          : null
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
