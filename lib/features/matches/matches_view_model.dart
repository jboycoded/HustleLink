import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/gig.dart';
import '../../data/models/gig_application.dart';
import '../../data/repositories/gig_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../profile/models/user_profile.dart';

class MatchesViewModel extends ChangeNotifier {
  MatchesViewModel(this._repo, this._profiles);

  final GigRepository _repo;
  final UserProfileRepository _profiles;

  List<GigApplication> _workerApplications = [];
  List<Gig> _posterGigs = [];
  Map<String, List<GigApplication>> _posterApplicationsByGig = {};
  List<GigApplication> _posterApplications = [];
  StreamSubscription<UserProfile?>? _profileSubscription;
  StreamSubscription<List<GigApplication>>? _workerApplicationsSubscription;
  StreamSubscription<List<GigApplication>>? _posterApplicationsSubscription;
  StreamSubscription<List<Gig>>? _posterGigsSubscription;

  bool isLoading = false;
  String? offlineMessage;
  Timer? _initialSnapshotTimer;
  Timer? _cacheStateTimer;
  bool _posterGigsFromCache = false;
  bool _posterApplicationsFromCache = false;
  bool _workerApplicationsFromCache = false;
  int _roleDataGeneration = 0;
  bool _disposed = false;
  String statusFilter = 'all';

  void _updateCacheState(String source, bool fromCache) {
    if (source == 'posterGigs') {
      _posterGigsFromCache = fromCache;
    } else if (source == 'posterApplications') {
      _posterApplicationsFromCache = fromCache;
    } else {
      _workerApplicationsFromCache = fromCache;
    }

    final offline = isPosterMode
        ? _posterGigsFromCache || _posterApplicationsFromCache
        : _workerApplicationsFromCache;

    if (!offline) {
      _cacheStateTimer?.cancel();
      _cacheStateTimer = null;
      offlineMessage = null;
      if (error?.toLowerCase().contains('offline') == true) error = null;
      notifyListeners();
      return;
    }

    // Firestore commonly emits a cached snapshot first, even while online.
    // Wait briefly for its server-backed snapshot before showing an offline
    // warning, avoiding the misleading banner flash during refresh.
    _cacheStateTimer ??= Timer(const Duration(seconds: 2), () {
      final stillOffline = isPosterMode
          ? _posterGigsFromCache || _posterApplicationsFromCache
          : _workerApplicationsFromCache;
      if (!stillOffline) return;
      offlineMessage =
          'Offline mode: showing saved applications and gig details.';
      if (recordCount == 0) {
        error = 'You are offline and there are no saved applications to display.';
      } else {
        error = null;
      }
      notifyListeners();
    });
  }

  void setStatusFilter(String value) {
    statusFilter = value;
    notifyListeners();
  }

  List<GigApplication> get filteredWorkerApplications =>
      _workerApplications.where((item) => statusFilter == 'all' || item.status == statusFilter).toList();
  String? error;
  String activeRole = 'worker';
  bool get isPosterMode => activeRole == 'poster';

  List<GigApplication> get workerApplications =>
      List<GigApplication>.unmodifiable(_workerApplications);
  List<Gig> get posterGigs => List<Gig>.unmodifiable(_posterGigs);

  // The Applications tab only lists gigs that have application records.
  // My Gigs remains the single home for editing, closing, and deleting gigs.
  List<Gig> get filteredPosterGigs => _posterGigs.where((gig) {
        final applications =
            _posterApplicationsByGig[gig.id] ?? const <GigApplication>[];
        if (applications.isEmpty) return false;
        switch (statusFilter) {
          case 'pending':
            return applications.any((item) => item.status == 'pending');
          case 'confirmed':
            return applications.any((item) => item.status == 'accepted' || item.status == 'completed');
          case 'closed':
            return gig.status == 'closed' ||
                applications.every((item) => item.status == 'rejected');
          case 'completed':
            return gig.status == 'completed';
          case 'all':
          default:
            return true;
        }
      }).toList();

  Map<String, List<GigApplication>> get posterApplicationsByGig =>
      Map<String, List<GigApplication>>.unmodifiable({
        for (final entry in _posterApplicationsByGig.entries)
          entry.key: List<GigApplication>.unmodifiable(entry.value),
      });

  int get recordCount => isPosterMode
      ? _posterApplicationsByGig.values.fold<int>(
          0, (total, applications) => total + applications.length)
      : _workerApplications.length;

  final Set<String> _updatingApplicationIds = {};
  bool isUpdating(String id) => _updatingApplicationIds.contains(id);

  Future<void> reviewApplication(String applicationId, String status) async {
    if (_updatingApplicationIds.contains(applicationId)) return;
    _updatingApplicationIds.add(applicationId);
    notifyListeners();
    try {
      await _repo.setApplicationStatus(
        applicationId: applicationId,
        status: status,
      );
    } finally {
      _updatingApplicationIds.remove(applicationId);
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> removeRejectedApplication(String applicationId) async {
    await _repo.deleteWorkerApplication(applicationId);
  }

  Future<void> refresh() async {
    // Avoid a profile-document network read during pull-to-refresh. Existing
    // cached application data should remain visible and the refresh indicator
    // should not wait for a server response while offline.
    error = null;
    offlineMessage = null;
    await _listenToRoleData();
  }

  Future<void> load() async {
    isLoading = recordCount == 0;
    error = null;
    offlineMessage = null;
    _posterGigsFromCache = false;
    _posterApplicationsFromCache = false;
    _workerApplicationsFromCache = false;
    notifyListeners();
    try {
      activeRole = await _profiles.getActiveRole();
      statusFilter = activeRole == 'poster' ? 'pending' : 'all';
      _profileSubscription ??= _profiles.watchMyProfile().listen(
        _handleProfileUpdate,
        onError: (_) {
          error = 'Unable to monitor your account role.';
          notifyListeners();
        },
      );
      await _listenToRoleData();
    } catch (_) {
      if (_disposed) return;
      isLoading = false;
      if (recordCount > 0) {
        offlineMessage = 'Connection unavailable. Showing the last data loaded on this device.';
        error = null;
      } else {
        error = 'You appear to be offline. Reconnect and try again.';
      }
      notifyListeners();
    }
  }

  void _handleProfileUpdate(UserProfile? profile) {
    if (_disposed || profile == null || profile.activeRole == activeRole) return;
    activeRole = profile.activeRole;
    statusFilter = activeRole == 'poster' ? 'pending' : 'all';
    _workerApplications = [];
    _posterGigs = [];
    _posterApplicationsByGig = {};
    _posterApplications = [];
    isLoading = true;
    notifyListeners();
    unawaited(_listenToRoleData());
  }

  Future<void> _listenToRoleData() async {
    final generation = ++_roleDataGeneration;
    final roleForLoad = activeRole;
    await _workerApplicationsSubscription?.cancel();
    await _posterApplicationsSubscription?.cancel();
    await _posterGigsSubscription?.cancel();
    if (_disposed || generation != _roleDataGeneration) return;
    // Keep the last successful data in memory while reconnecting.
    isLoading = recordCount == 0;
    error = null;
    offlineMessage = null;
    _posterGigsFromCache = false;
    _posterApplicationsFromCache = false;
    _workerApplicationsFromCache = false;
    notifyListeners();

    var receivedFirstSnapshot = false;
    _initialSnapshotTimer?.cancel();
    _initialSnapshotTimer = Timer(const Duration(seconds: 8), () {
      if (_disposed || generation != _roleDataGeneration || receivedFirstSnapshot) return;
      isLoading = false;
      offlineMessage = 'You appear to be offline. Showing saved data where available.';
      if (recordCount == 0) {
        error = 'No saved applications are available. Reconnect and try again.';
      }
      notifyListeners();
    });
    void firstSnapshotReceived() {
      if (_disposed || generation != _roleDataGeneration || receivedFirstSnapshot) return;
      receivedFirstSnapshot = true;
      _initialSnapshotTimer?.cancel();
      isLoading = false;
      if (offlineMessage == null) {
        error = null;
      } else if (recordCount == 0) {
        error = 'You are offline and there are no saved applications to display.';
      } else {
        error = null;
      }
      notifyListeners();
    }

    void streamFailed(Object _) {
      if (_disposed || generation != _roleDataGeneration) return;
      _initialSnapshotTimer?.cancel();
      isLoading = false;
      if (receivedFirstSnapshot || recordCount > 0) {
        offlineMessage = 'Connection interrupted. Showing the last available data.';
        error = null;
      } else {
        error = 'You appear to be offline. Reconnect and try again.';
      }
      notifyListeners();
    }

    if (roleForLoad == 'poster') {
      _posterGigsSubscription = _repo.watchMyGigs(
        onCacheState: (fromCache) {
          if (!_disposed && generation == _roleDataGeneration) {
            _updateCacheState('posterGigs', fromCache);
          }
        },
      ).listen((gigs) {
        if (_disposed || generation != _roleDataGeneration) return;
        _posterGigs = gigs;
        _rebuildPosterApplicationGroups();
        firstSnapshotReceived();
        notifyListeners();
      }, onError: streamFailed);

      _posterApplicationsSubscription =
          _repo.watchPosterApplications(
            onCacheState: (fromCache) {
            if (!_disposed && generation == _roleDataGeneration) {
              _updateCacheState('posterApplications', fromCache);
            }
          },
          ).listen((applications) {
        if (_disposed || generation != _roleDataGeneration) return;
        // Keep all statuses; the UI filter exposes rejected applications as history.
        _posterApplications = applications;
        _rebuildPosterApplicationGroups();
        firstSnapshotReceived();
        notifyListeners();
      }, onError: streamFailed);
    } else {
      _workerApplicationsSubscription =
          _repo.watchWorkerApplications(
            onCacheState: (fromCache) {
            if (!_disposed && generation == _roleDataGeneration) {
              _updateCacheState('workerApplications', fromCache);
            }
          },
          ).listen((applications) {
        if (_disposed || generation != _roleDataGeneration) return;
        _workerApplications = applications;
        firstSnapshotReceived();
        notifyListeners();
      }, onError: streamFailed);
    }
  }

  void _rebuildPosterApplicationGroups() {
    final groups = <String, List<GigApplication>>{};
    for (final application in _posterApplications) {
      groups
          .putIfAbsent(application.gigId, () => <GigApplication>[])
          .add(application);
    }
    _posterApplicationsByGig = groups;
  }

  @override
  void dispose() {
    _disposed = true;
    _roleDataGeneration++;
    _initialSnapshotTimer?.cancel();
    _cacheStateTimer?.cancel();
    _profileSubscription?.cancel();
    _workerApplicationsSubscription?.cancel();
    _posterApplicationsSubscription?.cancel();
    _posterGigsSubscription?.cancel();
    super.dispose();
  }
}
