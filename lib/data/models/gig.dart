class Gig {
  const Gig({
    required this.id,
    required this.title,
    required this.category,
    required this.pay,
    required this.distanceKm,
    required this.posterName,
    required this.when,
  });

  final String id;
  final String title;
  final String category;
  final int pay; // naira
  final double distanceKm;
  final String posterName;
  final String when;
}
