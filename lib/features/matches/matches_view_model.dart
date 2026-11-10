import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/match_profile.dart';
import '../../data/models/gig.dart';
import '../../data/repositories/gig_repository.dart';


class MatchesViewModel extends ChangeNotifier {
  MatchesViewModel(this._repo);

  final GigRepository _repo;

  List<Gig> _matchedGigs = [];
  List<MatchProfile> _newMatches = [];

  bool isLoading = false;
  String? error;

  // Getters for UI data binding
  List<Gig> get matchedGigs => List.unmodifiable(_matchedGigs);
  List<MatchProfile> get newMatches => List.unmodifiable(_newMatches);

  /// Fetches data for both horizontal new matches and vertical active matched gigs
  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      // 1. Fetch available gigs from your repository layer
      final allGigs = await _repo.getGigs();
      
      // For now, we display your gigs list. You can filter these later 
      // (e.g., allGigs.where((g) => g.isMatched).toList()) depending on your logic
      _matchedGigs = allGigs;

      // 2. Fetch the horizontal round profile bubbles data structure
      _newMatches = _getMockNewMatches();
    } catch (e) {
      error = 'Could not load matches. Check your network and try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Action modifier to dismiss or clear a gig from the vertical match list
  void removeMatch(String gigId) {
    _matchedGigs.removeWhere((gig) => gig.id == gigId);
    notifyListeners();
  }

  /// Generate local mock items matching your Figma layout: AO, TS, BC, SD
  List<MatchProfile> _getMockNewMatches() {
    return const [
      MatchProfile(id: 'm1', name: 'Ada O.', initials: 'AO'),
      MatchProfile(id: 'm2', name: 'Tunde S.', initials: 'TS'),
      MatchProfile(id: 'm3', name: 'Blessing C.', initials: 'BC'),
      MatchProfile(id: 'm4', name: 'Sodiq D.', initials: 'SD'),
    ];
  }
}
