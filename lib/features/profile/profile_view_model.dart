import 'package:flutter/foundation.dart';
import 'models/user_profile.dart';

class ProfileViewModel extends ChangeNotifier {
  UserProfile? _profile;
  bool isAvailableForGigs = true;

  UserProfile? get profile => _profile;

  void load() {
    _profile = const UserProfile(
      id: 'u1',
      fullName: 'Chidi Obi',
      role: 'Hair Stylist & Makeup Artist',
      initials: 'CO',
      rating: 4.9,
      completedGigs: 24,
      isVerified: true,
      skills: ['Wig Install', 'Bridal Makeup', 'Braiding', 'Lash Extensions'],
    );
    notifyListeners();
  }

  void toggleAvailability(bool value) {
    isAvailableForGigs = value;
    notifyListeners();
  }
}
