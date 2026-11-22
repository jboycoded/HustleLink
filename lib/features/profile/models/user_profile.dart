class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String activeRole;
  final List<String> roles;
  final String location;
  final List<String> skills;
  final bool isVerified;
  final bool profileCompleted;
  final bool isAvailableForGigs;
  final double rating;
  final int completedGigs;
  final String? proofVideoUrl;
  final String? photoUrl;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.activeRole,
    required this.roles,
    required this.location,
    required this.skills,
    required this.isVerified,
    required this.profileCompleted,
    required this.isAvailableForGigs,
    required this.rating,
    required this.completedGigs,
    this.proofVideoUrl,
    this.photoUrl,
  });

  String get initials {
    final names = fullName.trim().split(RegExp(r'\s+'));
    if (names.isEmpty || names.first.isEmpty) return '?';

    if (names.length == 1) {
      return names.first.substring(0, 1).toUpperCase();
    }

    return '${names.first[0]}${names.last[0]}'.toUpperCase();
  }

  String get role {
    return activeRole == 'poster' ? 'Poster' : 'Worker';
  }

  factory UserProfile.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return UserProfile(
      id: id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      activeRole: data['activeRole'] as String? ?? 'worker',
      roles: List<String>.from(data['roles'] ?? ['worker', 'poster']),
      location: data['location'] as String? ?? '',
      skills: List<String>.from(data['skills'] ?? []),
      isVerified: data['isVerified'] as bool? ?? false,
      profileCompleted: data['profileCompleted'] as bool? ?? false,
      isAvailableForGigs:
          data['isAvailableForGigs'] as bool? ?? true,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      completedGigs: (data['completedGigs'] as num?)?.toInt() ?? 0,
      proofVideoUrl: data['proofVideoUrl'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'activeRole': activeRole,
      'roles': roles,
      'location': location,
      'skills': skills,
      'isVerified': isVerified,
      'profileCompleted': profileCompleted,
      'isAvailableForGigs': isAvailableForGigs,
      'rating': rating,
      'completedGigs': completedGigs,
      'proofVideoUrl': proofVideoUrl,
      'photoUrl': photoUrl,
    };
  }
}
