import '../models/gig.dart';
import '../services/gig_service.dart';

/// The single place the app asks for gigs and reports swipes.
class GigRepository {
  GigRepository(this._service);

  final GigService _service;

  Future<List<Gig>> getGigs() => _service.fetchGigs();

  Future<void> recordSwipe(String gigId, {required bool liked}) async {
    // TODO: send to the backend once it exists.
  }
}
