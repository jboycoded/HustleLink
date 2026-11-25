import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Resolves the latest public profile photo so existing conversations do not
/// keep displaying an outdated or missing photo copied when the chat began.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.userId,
    required this.name,
    required this.radius,
    this.fallbackPhotoUrl,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String userId;
  final String name;
  final double radius;
  final String? fallbackPhotoUrl;
  final Color? backgroundColor;
  final Color? foregroundColor;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\\s+')).where((part) => part.isNotEmpty).take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = fallbackPhotoUrl?.trim() ?? '';
    if (userId.isEmpty) return _avatar(context, fallback);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final latest = snapshot.data?.data()?['photoUrl'] as String?;
        final photo = latest?.trim().isNotEmpty == true ? latest!.trim() : fallback;
        return _avatar(context, photo);
      },
    );
  }

  Widget _avatar(BuildContext context, String photoUrl) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? scheme.secondary,
      foregroundColor: foregroundColor ?? scheme.onSecondary,
      child: photoUrl.isEmpty
          ? Text(_initials.isEmpty ? '?' : _initials)
          : ClipOval(
              child: Image.network(
                photoUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Center(child: Text(_initials.isEmpty ? '?' : _initials)),
              ),
            ),
    );
  }
}
