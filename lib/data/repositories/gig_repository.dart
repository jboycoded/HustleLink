import '../models/gig.dart';
import '../models/gig_application.dart';
import '../services/gig_service.dart';

class GigRepository {
  GigRepository(this._service);

  final GigService _service;

  Future<List<Gig>> getGigs() => _service.fetchAvailableGigs();

  Future<List<Gig>> getMyGigs() => _service.fetchMyGigs();

  Future<Gig?> getGigById(String gigId) => _service.fetchGigById(gigId);

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

  Future<void> closeGig(String gigId) => _service.closeGig(gigId);

  Future<void> deleteGig(String gigId) => _service.deleteGig(gigId);

  Future<void> applyToGig(Gig gig) => _service.submitApplication(gig);

  Future<void> setApplicationStatus({
    required String applicationId,
    required String status,
  }) =>
      _service.updateApplicationStatus(
        applicationId: applicationId,
        status: status,
      );

  Future<List<GigApplication>> getWorkerApplications() =>
      _service.fetchWorkerApplications();

  Future<List<GigApplication>> getPosterApplications() =>
      _service.fetchPosterApplications();
}
