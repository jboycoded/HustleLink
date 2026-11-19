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

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isVideoUploading => _isVideoUploading;
  String? get errorMessage => _errorMessage;

  bool get isAvailableForGigs =>
      _profile?.isAvailableForGigs ?? false;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _repository.getMyProfile();
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
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateProfile(
        fullName: fullName,
        location: location,
        skills: skills,
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

    try {
      await _repository.updateActiveRole(role);
      _profile = await _repository.getMyProfile();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleAvailability(bool value) async {
    try {
      await _repository.updateAvailability(value);
      _profile = await _repository.getMyProfile();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _friendlyError(error);
    }

    notifyListeners();
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
