import '../models/gig.dart';
import '../services/gig_service.dart';

class GigRepository {
  GigRepository(this._service);

  final GigService _service;

  // Worker discovery.
  Future<List<Gig>> getGigs() => _service.fetchAvailableGigs();

  // Poster management.
  Future<List<Gig>> getMyGigs() => _service.fetchMyGigs();

  Future<String> createGig({
    required String title,
    required String description,
    required String category,
    required int pay,
    required String location,
    required String when,
    bool proofVideoRequired = true,
  }) {
    return _service.createGig(
      title: title,
      description: description,
      category: category,
      pay: pay,
      location: location,
      when: when,
      proofVideoRequired: proofVideoRequired,
    );
  }

  Future<void> updateGig({
    required String gigId,
    required String title,
    required String description,
    required String category,
    required int pay,
    required String location,
    required String when,
    required bool proofVideoRequired,
  }) {
    return _service.updateGig(
      gigId: gigId,
      title: title,
      description: description,
      category: category,
      pay: pay,
      location: location,
      when: when,
      proofVideoRequired: proofVideoRequired,
    );
  }

  Future<void> closeGig(String gigId) =>
      _service.closeGig(gigId);

  Future<void> deleteGig(String gigId) =>
      _service.deleteGig(gigId);

  // Swipe persistence will be implemented in Stage 4.
  Future<void> recordSwipe(String gigId, {required bool liked}) async {}
}
