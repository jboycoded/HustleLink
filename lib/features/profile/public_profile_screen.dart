import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/repositories/user_profile_repository.dart';
import 'models/user_profile.dart';
import 'widgets/profile_proof_video_player.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _loadProfile();
  }

  void _loadProfile() {
    _profileFuture =
        context.read<UserProfileRepository>().getPublicProfile(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('PUBLIC PROFILE')),
      body: FutureBuilder<UserProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: scheme.secondary),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This profile is unavailable.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final profile = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppTokens.rLg),
                  border: Border.all(
                    color: scheme.outline,
                    width: AppTokens.borderWidth,
                  ),
                  boxShadow: AppTokens.hardShadow(scheme.outline, 3),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: scheme.secondary,
                      foregroundColor: scheme.onSecondary,
                      child: Text(
                        profile.initials,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      profile.fullName.isEmpty ? 'HustleLink member' : profile.fullName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      profile.role,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (profile.location.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(profile.location),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileStat(
                            label: 'RATING',
                            value: '${profile.rating} ★',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ProfileStat(
                            label: 'COMPLETED',
                            value: '${profile.completedGigs} GIGS',
                          ),
                        ),
                      ],
                    ),
                    if (profile.activeRole == 'worker') ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            profile.isAvailableForGigs
                                ? Icons.circle
                                : Icons.circle_outlined,
                            size: 10,
                            color: profile.isAvailableForGigs
                                ? Colors.green
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 7),
                          Text(profile.isAvailableForGigs
                              ? 'Available for gigs'
                              : 'Not currently available'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (profile.proofVideoUrl != null &&
                  profile.proofVideoUrl!.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  '30-SECOND PROOF VIDEO',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 12),
                ProfileProofVideoPlayer(videoUrl: profile.proofVideoUrl!),
              ],
              const SizedBox(height: 22),
              Text(
                'SKILLS & SERVICES',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: .8),
              ),
              const SizedBox(height: 12),
              if (profile.skills.isEmpty)
                Text(
                  'No skills or services added yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: profile.skills
                      .map(
                        (skill) => Chip(
                          label: Text(skill),
                          backgroundColor: scheme.secondaryContainer,
                        ),
                      )
                      .toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
