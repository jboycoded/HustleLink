import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/user_profile_repository.dart';
import 'models/user_profile.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(this._repository);

  final UserProfileRepository _repository;

  UserProfile? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isVideoUploading = false;
  String? _errorMessage;
  String? _localPhotoPath;
  int _roleSwitchGeneration = 0;
  StreamSubscription<UserProfile?>? _profileSubscription;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isVideoUploading => _isVideoUploading;
  String? get errorMessage => _errorMessage;
  String? get localPhotoPath => _localPhotoPath;

  void setProfilePhotoPreview(String? path) {
    _localPhotoPath = path;
    notifyListeners();
  }

  bool get isAvailableForGigs =>
      _profile?.isAvailableForGigs ?? false;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _repository.getMyProfile();
      _profileSubscription ??= _repository.watchMyProfile().listen(
        (profile) async {
          if (profile == null) return;
          final previous = _profile;
          if (previous != null && previous.activeRole == profile.activeRole) {
            // The lightweight profile stream intentionally omits aggregate
            // queries. Preserve the last computed credibility values while
            // applying live identity/availability changes.
            _profile = profile.copyWith(
              rating: previous.rating,
              acceptedGigs: previous.acceptedGigs,
              completedGigs: previous.completedGigs,
              postedGigs: previous.postedGigs,
              paidGigs: previous.paidGigs,
              repeatEngagements: previous.repeatEngagements,
            );
          } else {
            final generation = ++_roleSwitchGeneration;
            final refreshedProfile = await _repository.getMyProfile();
            // Ignore a slower role refresh if the user has since switched
            // roles again or a newer refresh has already completed.
            if (generation != _roleSwitchGeneration) return;
            _profile = refreshedProfile;
          }
          notifyListeners();
        },
        onError: (Object error) {
          _errorMessage = _friendlyError(error);
          notifyListeners();
        },
      );
    } catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String location,
    required List<String> skills,
    String? workerDescription,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateProfile(
        fullName: fullName,
        location: location,
        skills: skills,
        workerDescription: workerDescription,
      );

      _profile = await _repository.getMyProfile();
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void setVideoUploading(bool value) {
    _isVideoUploading = value;
    notifyListeners();
  }

  Future<bool> updateProfilePhotoUrl(String? url) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.updateProfilePhotoUrl(url);
      _profile = await _repository.getMyProfile();
      _localPhotoPath = null;
      return true;
    } catch (error) {
      _localPhotoPath = null;
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateProofVideoUrl(String? url) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.updateProofVideoUrl(url);
      _profile = await _repository.getMyProfile();
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> switchRole(String role) async {
    if (_profile == null || !_profile!.roles.contains(role)) {
      _errorMessage = 'This role is not available on your account.';
      notifyListeners();
      return false;
    }

    final previousProfile = _profile!;
    final generation = ++_roleSwitchGeneration;
    _profile = previousProfile.copyWith(activeRole: role);
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateActiveRole(role);
      final refreshedProfile = await _repository.getMyProfile();
      if (generation != _roleSwitchGeneration) return true;
      _profile = refreshedProfile;
      notifyListeners();
      return true;
    } catch (error) {
      if (generation != _roleSwitchGeneration) return false;
      _profile = previousProfile;
      _errorMessage = _friendlyError(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleAvailability(bool value) async {
    final previousProfile = _profile;
    _profile = previousProfile?.copyWith(isAvailableForGigs: value);
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateAvailability(value);
    } catch (error) {
      _profile = previousProfile;
      _errorMessage = _friendlyError(error);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('permission-denied')) {
      return 'Access denied. Please check your Firestore security rules.';
    }

    if (message.contains('network')) {
      return 'Network error. Please check your connection.';
    }

    return 'Unable to load or save your profile. Please try again.';
  }
}
