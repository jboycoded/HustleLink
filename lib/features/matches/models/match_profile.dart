/// Local domain model for the top horizontal list of profile bubbles 
/// shown on the Matches layout screen (e.g., AO, TS, BC, SD).
class MatchProfile {
  final String id;
  final String name;
  final String initials;
  final String? imageUrl;

  const MatchProfile({
    required this.id,
    required this.name,
    required this.initials,
    this.imageUrl,
  });
}
