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
  StreamSubscription<UserProfile?>? _profileSubscription;
  StreamSubscription<List<GigApplication>>? _workerApplicationsSubscription;
  StreamSubscription<List<GigApplication>>? _posterApplicationsSubscription;
  StreamSubscription<List<Gig>>? _posterGigsSubscription;

  bool isLoading = false;
  String? offlineMessage;
  Timer? _initialSnapshotTimer;
  bool _posterGigsFromCache = false;
  bool _posterApplicationsFromCache = false;
  bool _workerApplicationsFromCache = false;
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
    offlineMessage = offline
        ? 'Offline mode: showing saved applications and gig details.'
        : null;
    if (offline && recordCount == 0) {
      error = 'You are offline and there are no saved applications to display.';
    } else if (offline) {
      error = null;
    } else if (error?.contains('offline') == true) {
      error = null;
    }
    notifyListeners();
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

  // Poster filters classify each gig by its overall lifecycle, not by the
  // individual application statuses attached to that gig.
  List<Gig> get filteredPosterGigs => _posterGigs.where((gig) {
        switch (statusFilter) {
          case 'pending':
            return gig.status == 'open';
          case 'confirmed':
            return gig.status == 'filled';
          case 'closed':
            return gig.status == 'closed';
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

  int get recordCount =>
      isPosterMode ? _posterGigs.length : _workerApplications.length;

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
      notifyListeners();
    }
  }

  Future<void> removeRejectedApplication(String applicationId) async {
    await _repo.deleteWorkerApplication(applicationId);
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
      final profile = await _profiles.getMyProfile();
      activeRole = profile.activeRole;
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
    if (profile == null || profile.activeRole == activeRole) return;
    activeRole = profile.activeRole;
    statusFilter = activeRole == 'poster' ? 'pending' : 'all';
    _workerApplications = [];
    _posterGigs = [];
    _posterApplicationsByGig = {};
    unawaited(_listenToRoleData());
  }

  Future<void> _listenToRoleData() async {
    await _workerApplicationsSubscription?.cancel();
    await _posterApplicationsSubscription?.cancel();
    await _posterGigsSubscription?.cancel();
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
      if (receivedFirstSnapshot) return;
      isLoading = false;
      offlineMessage = 'You appear to be offline. Showing saved data where available.';
      if (recordCount == 0) {
        error = 'No saved applications are available. Reconnect and try again.';
      }
      notifyListeners();
    });
    void firstSnapshotReceived() {
      if (receivedFirstSnapshot) return;
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

    if (isPosterMode) {
      _posterGigsSubscription = _repo.watchMyGigs(
        onCacheState: (fromCache) => _updateCacheState('posterGigs', fromCache),
      ).listen((gigs) {
        _posterGigs = gigs;
        _rebuildPosterApplicationGroups();
        firstSnapshotReceived();
        notifyListeners();
      }, onError: streamFailed);

      _posterApplicationsSubscription =
          _repo.watchPosterApplications(
            onCacheState: (fromCache) => _updateCacheState('posterApplications', fromCache),
          ).listen((applications) {
        // Keep all statuses; the UI filter exposes rejected applications as history.
        _posterApplicationsByGig = {};
        for (final application in applications) {
          _posterApplicationsByGig
              .putIfAbsent(application.gigId, () => <GigApplication>[])
              .add(application);
        }
        _rebuildPosterApplicationGroups();
        firstSnapshotReceived();
        notifyListeners();
      }, onError: streamFailed);
    } else {
      _workerApplicationsSubscription =
          _repo.watchWorkerApplications(
            onCacheState: (fromCache) => _updateCacheState('workerApplications', fromCache),
          ).listen((applications) {
        _workerApplications = applications;
        firstSnapshotReceived();
        notifyListeners();
      }, onError: streamFailed);
    }
  }

  void _rebuildPosterApplicationGroups() {
    for (final gig in _posterGigs) {
      _posterApplicationsByGig.putIfAbsent(gig.id, () => <GigApplication>[]);
    }
    _posterApplicationsByGig.removeWhere(
      (gigId, _) => !_posterGigs.any((gig) => gig.id == gigId),
    );
  }

  @override
  void dispose() {
    _initialSnapshotTimer?.cancel();
    _profileSubscription?.cancel();
    _workerApplicationsSubscription?.cancel();
    _posterApplicationsSubscription?.cancel();
    _posterGigsSubscription?.cancel();
    super.dispose();
  }
}
