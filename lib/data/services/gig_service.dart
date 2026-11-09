import '../models/gig.dart';

/// Talks to the outside world. Fake data for now; replace the body of
/// [fetchGigs] with an API/Firebase/Supabase call when the backend is chosen.
class GigService {
  const GigService({this.delay = const Duration(milliseconds: 600)});

  final Duration delay;

  Future<List<Gig>> fetchGigs() async {
    await Future<void>.delayed(delay);
    return const [
      Gig(
        id: '1',
        title: 'Wig Install – Lekki',
        category: 'Hair',
        pay: 8000,
        distanceKm: 1.2,
        posterName: 'Ada O.',
        when: 'Today 2pm',
      ),
      Gig(
        id: '2',
        title: 'Flyer for Birthday',
        category: 'Graphics',
        pay: 5500,
        distanceKm: 2.4,
        posterName: 'Tunde S.',
        when: 'Urgent',
      ),
      Gig(
        id: '3',
        title: 'iPhone Screen Fix',
        category: 'Repair',
        pay: 12000,
        distanceKm: 3.1,
        posterName: 'Bisi C.',
        when: 'Now',
      ),
    ];
  }
}
