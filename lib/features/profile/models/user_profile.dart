class UserProfile {
  final String id;
  final String fullName;
  final String role;
  final String initials;
  final double rating;
  final int completedGigs;
  final bool isVerified;
  final List<String> skills;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.initials,
    required this.rating,
    required this.completedGigs,
    required this.isVerified,
    required this.skills,
  });
}
