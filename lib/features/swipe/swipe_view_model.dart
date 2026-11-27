
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/gig.dart';
import '../../data/models/gig_application.dart';
import '../../data/repositories/gig_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../profile/models/user_profile.dart';

class SwipeViewModel extends ChangeNotifier {
  SwipeViewModel(this._repo, this._profiles);

  final GigRepository _repo;
  final UserProfileRepository _profiles;

  List<Gig> _gigs = [];
  final List<Gig> _savedGigs = [];
  final Set<String> _appliedGigIds = {};
  final Set<String> _passedGigIds = {};

  StreamSubscription<UserProfile?>? _profileSubscription;
  StreamSubscription<List<Gig>>? _availableGigsSubscription;
  StreamSubscription<List<Gig>>? _myGigsSubscription;
  StreamSubscription<List<GigApplication>>? _workerApplicationsSubscription;
  StreamSubscription<List<GigApplication>>? _posterApplicationsSubscription;
  final Set<String> _acceptedGigIds = {};
  Gig? _focusedGig;

  bool isLoading = false;
  bool isSaving = false;
  bool isApplying = false;
  String? error;
  String activeRole = 'worker';
  bool hasWorkerProofVideo = false;

  String _selectedCategory = 'All';
  int _currentIndex = 0;
  int _roleReloadGeneration = 0;

  bool get isPosterMode => activeRole == 'poster';
  bool hasAcceptedApplication(String gigId) => _acceptedGigIds.contains(gigId);
  String get selectedCategory => _selectedCategory;

  List<Gig> get gigs => List.unmodifiable(_gigs);
  List<Gig> get savedGigs => List.unmodifiable(_savedGigs);

  List<String> get categories {
    final values = _gigs.map((gig) => gig.category).toSet().toList()
      ..sort();
    return ['All', ...values];
  }

  List<Gig> get _discoveryGigs {
    return _gigs.where((gig) {
      final notApplied = !_appliedGigIds.contains(gig.id);
      final notPassed = !_passedGigIds.contains(gig.id);
      final matchesCategory = _selectedCategory == 'All' ||
          gig.category.toLowerCase() == _selectedCategory.toLowerCase();

      return notApplied && notPassed && matchesCategory && gig.isOpen;
    }).toList();
  }

  List<Gig> get visibleGigs => List.unmodifiable(_discoveryGigs);

  Gig? get currentGig {
    if (_focusedGig != null) return _focusedGig;
    final available = _discoveryGigs;
    if (available.isEmpty) return null;

    if (_currentIndex >= available.length) {
      _currentIndex = 0;
    }

    return available[_currentIndex];
  }

  bool get hasMoreGigs => currentGig != null;

  Future<Gig?> focusGig(String gigId) async {
    final generation = _roleReloadGeneration;
    final gig = await _repo.getGigById(gigId);
    if (generation != _roleReloadGeneration ||
        gig == null || !gig.isOpen || gig.posterId.isEmpty) return null;
    _focusedGig = gig;
    notifyListeners();
    return gig;
  }

  void clearFocusedGig() {
    _focusedGig = null;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      activeRole = await _profiles.getActiveRole();

      await _loadGigs();
      await _startDiscoveryStreams();

      await _profileSubscription?.cancel();
      _profileSubscription = _profiles.watchMyProfile().listen(
        (profile) {
          if (profile == null) return;
          hasWorkerProofVideo = profile.proofVideoUrl?.trim().isNotEmpty == true;
          if (profile.activeRole == activeRole) {
            notifyListeners();
            return;
          }

          activeRole = profile.activeRole;
          _selectedCategory = 'All';
          _currentIndex = 0;
          _passedGigIds.clear();

          unawaited(_reloadForRole());
        },
        onError: (_) {
          error = 'Unable to monitor your account role.';
          notifyListeners();
        },
      );
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadForRole() async {
    final generation = ++_roleReloadGeneration;

    // Never render the previous role's gigs using the newly selected role's
    // layout while its replacement query is still in flight.
    isLoading = true;
    error = null;
    _gigs = [];
    _focusedGig = null;
    _appliedGigIds.clear();
    _acceptedGigIds.clear();
    _passedGigIds.clear();
    _currentIndex = 0;
    notifyListeners();

    await _cancelDiscoveryStreams();
    if (generation != _roleReloadGeneration) return;

    await _loadGigs(expectedRole: activeRole);
    if (generation != _roleReloadGeneration) return;

    await _startDiscoveryStreams();
    if (generation != _roleReloadGeneration) return;

    isLoading = false;
    notifyListeners();
  }

  Future<void> _cancelDiscoveryStreams() async {
    await _availableGigsSubscription?.cancel();
    await _myGigsSubscription?.cancel();
    await _workerApplicationsSubscription?.cancel();
    await _posterApplicationsSubscription?.cancel();
    _availableGigsSubscription = null;
    _myGigsSubscription = null;
    _workerApplicationsSubscription = null;
    _posterApplicationsSubscription = null;
  }

  Future<void> _startDiscoveryStreams() async {
    await _cancelDiscoveryStreams();
    final streamRole = activeRole;

    if (isPosterMode) {
      _myGigsSubscription = _repo.watchMyGigs().listen((gigs) {
        if (activeRole != streamRole) return;
        _gigs = gigs.where((gig) => gig.status != 'closed').toList();
        notifyListeners();
      }, onError: (Object error) {
        if (activeRole != streamRole) return;
        this.error = _friendlyError(error);
        notifyListeners();
      });
      _posterApplicationsSubscription =
          _repo.watchPosterApplications().listen((applications) {
        if (activeRole != streamRole) return;
        _acceptedGigIds
          ..clear()
          ..addAll(applications
              .where((application) =>
                  application.status == 'accepted' ||
                  application.status == 'completed')
              .map((application) => application.gigId));
        notifyListeners();
      }, onError: (Object error) {
        if (activeRole != streamRole) return;
        this.error = _friendlyError(error);
        notifyListeners();

      });
      return;
    }

    _acceptedGigIds.clear();
    _availableGigsSubscription = _repo.watchAvailableGigs().listen((gigs) {
      if (activeRole != streamRole) return;
      _gigs = gigs;
      if (_currentIndex >= _discoveryGigs.length) _currentIndex = 0;
      notifyListeners();
    }, onError: (Object error) {
      if (activeRole != streamRole) return;
      this.error = _friendlyError(error);
      notifyListeners();

    });

    _workerApplicationsSubscription =
        _repo.watchWorkerApplications().listen((applications) {
      if (activeRole != streamRole) return;
      _appliedGigIds
        ..clear()
        ..addAll(applications.map((application) => application.gigId));
      if (_currentIndex >= _discoveryGigs.length) _currentIndex = 0;
      notifyListeners();
    }, onError: (Object error) {
      if (activeRole != streamRole) return;
      this.error = _friendlyError(error);
      notifyListeners();

    });
  }

  Future<void> _loadGigs({String? expectedRole}) async {
    final requestedRole = expectedRole ?? activeRole;
    try {
      if (requestedRole == 'poster') {
        final applications = await _repo.getPosterApplications();
        if (activeRole != requestedRole) return;
        _acceptedGigIds
          ..clear()
          ..addAll(applications
              .where((application) =>
                  application.status == 'accepted' ||
                  application.status == 'completed')
              .map((application) => application.gigId));
        final gigs = await _repo.getMyGigs();
        if (activeRole != requestedRole) return;
        _gigs = gigs;
      } else {
        _acceptedGigIds.clear();
        final applications = await _repo.getWorkerApplications();
        if (activeRole != requestedRole) return;
        _appliedGigIds
          ..clear()
          ..addAll(applications.map((application) => application.gigId));

        final gigs = await _repo.getGigs();
        if (activeRole != requestedRole) return;
        _gigs = gigs;
      }

      _currentIndex = 0;
      error = null;
    } catch (e) {
      if (activeRole == requestedRole) {
        error = _friendlyError(e);
      }
    }

    if (activeRole == requestedRole) notifyListeners();
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    _passedGigIds.clear();
    _currentIndex = 0;
    notifyListeners();

    await _loadGigs();

    isLoading = false;
    notifyListeners();
  }

  void selectCategory(String category) {
    if (_selectedCategory == category) return;

    _selectedCategory = category;
    _currentIndex = 0;
    notifyListeners();
  }

  void nextGig() {
    final available = _discoveryGigs;
    if (available.length < 2) return;

    _currentIndex = (_currentIndex + 1) % available.length;
    notifyListeners();
  }

  void previousGig() {
    final available = _discoveryGigs;
    if (available.length < 2) return;

    _currentIndex = (_currentIndex - 1 + available.length) %
        available.length;
    notifyListeners();
  }

  void pass() {
  final gig = currentGig;
  if (gig == null) return;

  _passedGigIds.add(gig.id);

  final available = _discoveryGigs;
  if (available.isNotEmpty) {
    _currentIndex = (_currentIndex + 1) % available.length;
  } else {
    _currentIndex = 0;
  }

  notifyListeners();
}

  Future<bool> apply({Gig? targetGig}) async {
    final gig = targetGig ?? currentGig;
    if (gig == null || isApplying) return false;

    isApplying = true;
    error = null;
    notifyListeners();

    try {
      await _repo.applyToGig(gig);
      _appliedGigIds.add(gig.id);

      final remaining = _discoveryGigs;
      if (remaining.isEmpty || _currentIndex >= remaining.length) {
        _currentIndex = 0;
      }

      isApplying = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      isApplying = false;
      notifyListeners();
      return false;
    }
  }

  void save() {
    final gig = currentGig;
    if (gig == null) return;

    if (!_savedGigs.any((saved) => saved.id == gig.id)) {
      _savedGigs.add(gig);
    }

    nextGig();
  }

  Future<bool> createGig({
    required String title,
    required String description,
    required String category,
    required int pay,
    required String location,
    required String when,
    required bool proofVideoRequired,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await _repo.createGig(
        title: title,
        description: description,
        category: category,
        pay: pay,
        location: location,
        when: when,
        proofVideoRequired: proofVideoRequired,
      );
      await _loadGigs();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateGig({
    required String gigId,
    required String title,
    required String description,
    required String category,
    required int pay,
    required String location,
    required String when,
    required bool proofVideoRequired,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await _repo.updateGig(
        gigId: gigId,
        title: title,
        description: description,
        category: category,
        pay: pay,
        location: location,
        when: when,
        proofVideoRequired: proofVideoRequired,
      );
      await _loadGigs();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> closeGig(String gigId) async {
    try {
      await _repo.closeGig(gigId);
      await _loadGigs();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGig(String gigId) async {
    try {
      await _repo.deleteGig(gigId);
      await _loadGigs();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('30-second profile video')) {
      return 'This gig requires a 30-second profile video. Add one in your Profile before applying.';
    }
    if (message.contains('already applied')) {
      return 'You have already applied to this gig.';
    }
    if (message.contains('no longer available')) {
      return 'This gig is no longer available.';
    }
    if (message.contains('permission-denied')) {
      return 'Access denied. Please check your Firestore security rules.';
    }
    if (message.contains('network')) {
      return 'Network error. Please check your connection.';
    }

    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _availableGigsSubscription?.cancel();
    _myGigsSubscription?.cancel();
    _workerApplicationsSubscription?.cancel();
    _posterApplicationsSubscription?.cancel();
    super.dispose();
  }
}
