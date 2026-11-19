import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/gig.dart';
import '../../data/repositories/gig_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../profile/models/user_profile.dart';

class SwipeViewModel extends ChangeNotifier {
  SwipeViewModel(this._repo, this._profiles);

  final GigRepository _repo;
  final UserProfileRepository _profiles;

  List<Gig> _gigs = [];
  final List<Gig> _savedGigs = [];
  final Set<String> _processedGigIds = {};

  StreamSubscription<UserProfile?>? _profileSubscription;

  bool isLoading = false;
  bool isSaving = false;
  String? error;
  String activeRole = 'worker';

  String _selectedCategory = 'All';

  bool get isPosterMode => activeRole == 'poster';
  String get selectedCategory => _selectedCategory;
  List<Gig> get gigs => List.unmodifiable(_gigs);
  List<Gig> get savedGigs => List.unmodifiable(_savedGigs);

  List<String> get categories {
    final values = _gigs.map((gig) => gig.category).toSet().toList()
      ..sort();
    return ['All', ...values];
  }

  List<Gig> get visibleGigs {
    return _gigs.where((gig) {
      final notProcessed = !_processedGigIds.contains(gig.id);
      final matchesCategory = _selectedCategory == 'All' ||
          gig.category.toLowerCase() == _selectedCategory.toLowerCase();
      return notProcessed && matchesCategory;
    }).toList();
  }

  Gig? get currentGig =>
      visibleGigs.isEmpty ? null : visibleGigs.first;

  bool get hasMoreGigs => visibleGigs.isNotEmpty;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final profile = await _profiles.getMyProfile();
      activeRole = profile.activeRole;
      await _loadGigs();

      await _profileSubscription?.cancel();
      _profileSubscription = _profiles.watchMyProfile().listen(
        (profile) {
          if (profile == null || profile.activeRole == activeRole) return;
          activeRole = profile.activeRole;
          _processedGigIds.clear();
          _selectedCategory = 'All';
          unawaited(_loadGigs());
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

  Future<void> _loadGigs() async {
    try {
      _gigs = isPosterMode
          ? await _repo.getMyGigs()
          : await _repo.getGigs();
      error = null;
    } catch (e) {
      error = _friendlyError(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();

    await _loadGigs();

    isLoading = false;
    notifyListeners();
  }

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
  }

  void apply() {
    _recordCurrentGig(liked: true);
  }

  void pass() {
    _recordCurrentGig(liked: false);
  }

  void save() {
    final gig = currentGig;
    if (gig == null) return;

    if (!_savedGigs.any((saved) => saved.id == gig.id)) {
      _savedGigs.add(gig);
    }

    _processedGigIds.add(gig.id);
    notifyListeners();
  }

  void _recordCurrentGig({required bool liked}) {
    final gig = currentGig;
    if (gig == null) return;

    _processedGigIds.add(gig.id);
    unawaited(_repo.recordSwipe(gig.id, liked: liked));
    notifyListeners();
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
    super.dispose();
  }
}
