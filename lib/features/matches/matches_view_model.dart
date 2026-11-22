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

  bool isLoading = false;
  String? error;
  String activeRole = 'worker';

  bool get isPosterMode => activeRole == 'poster';

  List<GigApplication> get workerApplications =>
      List.unmodifiable(_workerApplications);

  List<Gig> get posterGigs => List.unmodifiable(_posterGigs);

  Map<String, List<GigApplication>> get posterApplicationsByGig {
    final grouped = <String, List<GigApplication>>{};
    _posterApplicationsByGig.forEach((key, value) {
      grouped[key] = List<GigApplication>.unmodifiable(value);
    });
    return Map<String, List<GigApplication>>.unmodifiable(grouped);
  }

  int get applicationCount {
    if (isPosterMode) {
      return _posterApplicationsByGig.values
          .fold(0, (total, applications) => total + applications.length);
    }

    return _workerApplications.length;
  }

  final Set<String> _updatingApplicationIds = {};
  bool isUpdating(String id) => _updatingApplicationIds.contains(id);

  Future<void> reviewApplication(
    String applicationId,
    String status,
  ) async {
    if (_updatingApplicationIds.contains(applicationId)) return;
    _updatingApplicationIds.add(applicationId);
    notifyListeners();
    try {
      await _repo.setApplicationStatus(
        applicationId: applicationId,
        status: status,
      );
      await load();
    } finally {
      _updatingApplicationIds.remove(applicationId);
      notifyListeners();
    }
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final profile = await _profiles.getMyProfile();
      activeRole = profile.activeRole;
      _profileSubscription ??= _profiles.watchMyProfile().listen(
        _handleProfileUpdate,
        onError: (_) {
          error = 'Unable to monitor your account role.';
          notifyListeners();
        },
      );
      await _loadApplications();
    } catch (_) {
      error = 'Could not load applications. Check your network and try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _handleProfileUpdate(UserProfile? profile) {
    if (profile == null || profile.activeRole == activeRole) return;
    activeRole = profile.activeRole;
    unawaited(_reloadApplicationsForRole());
  }

  Future<void> _reloadApplicationsForRole() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _loadApplications();
    } catch (_) {
      error = 'Could not load applications. Check your network and try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadApplications() async {
    if (isPosterMode) {
      _workerApplications = [];
      _posterGigs = await _repo.getMyGigs();
      final applications = await _repo.getPosterApplications();
      final grouped = <String, List<GigApplication>>{
        for (final gig in _posterGigs) gig.id: <GigApplication>[],
      };

      for (final application in applications) {
        grouped.putIfAbsent(application.gigId, () => []);
        grouped[application.gigId]!.add(application);
      }

      _posterApplicationsByGig = grouped;
    } else {
      _posterGigs = [];
      _posterApplicationsByGig = {};
      _workerApplications = await _repo.getWorkerApplications();
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}
