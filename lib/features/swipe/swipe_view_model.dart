import 'package:flutter/foundation.dart';

import '../../data/models/gig.dart';
import '../../data/repositories/gig_repository.dart';

class SwipeViewModel extends ChangeNotifier {
  SwipeViewModel(this._repo);

  final GigRepository _repo;

  List<Gig> _gigs = [];
  bool isLoading = false;
  String? error;

  Gig? get currentGig => _gigs.isEmpty ? null : _gigs.first;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      _gigs = await _repo.getGigs();
    } catch (e) {
      error = 'Could not load gigs. Check your network and try again.';
    }
    isLoading = false;
    notifyListeners();
  }

  void apply() => _swipe(liked: true);
  void pass() => _swipe(liked: false);

  void _swipe({required bool liked}) {
    final gig = currentGig;
    if (gig == null) return;
    _repo.recordSwipe(gig.id, liked: liked);
    _gigs = _gigs.sublist(1);
    notifyListeners();
  }
}
