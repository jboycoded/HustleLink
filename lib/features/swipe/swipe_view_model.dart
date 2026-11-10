
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/gig.dart';
import '../../data/repositories/gig_repository.dart';

class SwipeViewModel extends ChangeNotifier {
  SwipeViewModel(this._repo);

  final GigRepository _repo;

  List<Gig> _gigs = [];
  final List<Gig> _savedGigs = [];
  final Set<String> _processedGigIds = {};

  bool isLoading = false;
  String? error;

  String _selectedCategory = 'All';

  // Available categories
  String get selectedCategory => _selectedCategory;

  List<String> get categories {
    final availableCategories = _gigs
        .map((gig) => gig.category)
        .toSet()
        .toList()
      ..sort();

    return ['All', ...availableCategories];
  }

  // Filter gigs according to the selected category
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

  List<Gig> get savedGigs => List.unmodifiable(_savedGigs);

  bool get hasMoreGigs => visibleGigs.isNotEmpty;

  // Load gigs
  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      _gigs = await _repo.getGigs();
    } catch (e) {
      error = 'Could not load gigs. Check your network and try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Change category filter
  void selectCategory(String category) {
    if (_selectedCategory == category) return;

    _selectedCategory = category;
    notifyListeners();
  }

  // Apply for current gig
  void apply() {
    _recordCurrentGig(liked: true);
  }

  // Pass current gig
  void pass() {
    _recordCurrentGig(liked: false);
  }

  // Save current gig
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

    // Send the swipe to the repository.
    unawaited(_repo.recordSwipe(gig.id, liked: liked));

    notifyListeners();
  }
}
