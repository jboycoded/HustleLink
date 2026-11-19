
import 'package:flutter/foundation.dart';

import '../../data/models/gig_application.dart';
import '../../data/repositories/gig_repository.dart';
import '../../data/repositories/user_profile_repository.dart';

class MatchesViewModel extends ChangeNotifier {
  MatchesViewModel(this._repo, this._profiles);

  final GigRepository _repo;
  final UserProfileRepository _profiles;

  List<GigApplication> _workerApplications = [];
  Map<String, List<GigApplication>> _posterApplicationsByGig = {};

  bool isLoading = false;
  String? error;
  String activeRole = 'worker';

  bool get isPosterMode => activeRole == 'poster';

  List<GigApplication> get workerApplications =>
      List.unmodifiable(_workerApplications);

  Map<String, List<GigApplication>> get posterApplicationsByGig {
    return Map.unmodifiable(
      _posterApplicationsByGig.map(
        (key, value) => MapEntry(key, List.unmodifiable(value)),
      ),
    );
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

      if (isPosterMode) {
        _workerApplications = [];
        final applications = await _repo.getPosterApplications();

        final grouped = <String, List<GigApplication>>{};

        for (final application in applications) {
          grouped.putIfAbsent(application.gigId, () => []);
          grouped[application.gigId]!.add(application);
        }

        _posterApplicationsByGig = grouped;
      } else {
        _posterApplicationsByGig = {};
        _workerApplications = await _repo.getWorkerApplications();
      }
    } catch (e) {
      error = 'Could not load applications. Check your network and try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
