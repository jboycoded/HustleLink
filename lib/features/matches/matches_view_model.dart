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
  String statusFilter = 'all';

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

  Map<String, List<GigApplication>> get posterApplicationsByGig {
    final grouped = <String, List<GigApplication>>{};
    _posterApplicationsByGig.forEach((key, value) {
      final visible = value.where((item) => statusFilter == 'all' || item.status == statusFilter).toList();
      if (visible.isNotEmpty) grouped[key] = List<GigApplication>.unmodifiable(visible);
    });
    return Map<String, List<GigApplication>>.unmodifiable(grouped);
  }

  int get applicationCount => isPosterMode
      ? _posterApplicationsByGig.values.fold(
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
      notifyListeners();
    }
  }

  Future<void> removeRejectedApplication(String applicationId) async {
    await _repo.deleteWorkerApplication(applicationId);
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
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
      error = 'Could not load applications. Check your network and try again.';
      notifyListeners();
    }
  }

  void _handleProfileUpdate(UserProfile? profile) {
    if (profile == null || profile.activeRole == activeRole) return;
    activeRole = profile.activeRole;
    statusFilter = activeRole == 'poster' ? 'pending' : 'all';
    unawaited(_listenToRoleData());
  }

  Future<void> _listenToRoleData() async {
    await _workerApplicationsSubscription?.cancel();
    await _posterApplicationsSubscription?.cancel();
    await _posterGigsSubscription?.cancel();
    _workerApplications = [];
    _posterGigs = [];
    _posterApplicationsByGig = {};
    isLoading = true;
    error = null;
    notifyListeners();

    var receivedFirstSnapshot = false;
    void firstSnapshotReceived() {
      if (receivedFirstSnapshot) return;
      receivedFirstSnapshot = true;
      isLoading = false;
      notifyListeners();
    }

    void streamFailed(Object _) {
      error = 'Could not load applications. Check your network and try again.';
      isLoading = false;
      notifyListeners();
    }

    if (isPosterMode) {
      _posterGigsSubscription = _repo.watchMyGigs().listen((gigs) {
        _posterGigs = gigs;
        _rebuildPosterApplicationGroups();
        firstSnapshotReceived();
        notifyListeners();
      }, onError: streamFailed);

      _posterApplicationsSubscription =
          _repo.watchPosterApplications().listen((applications) {
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
          _repo.watchWorkerApplications().listen((applications) {
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
    _profileSubscription?.cancel();
    _workerApplicationsSubscription?.cancel();
    _posterApplicationsSubscription?.cancel();
    _posterGigsSubscription?.cancel();
    super.dispose();
  }
}
