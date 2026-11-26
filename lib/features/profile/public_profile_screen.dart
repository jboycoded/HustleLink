import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../data/services/engagement_service.dart';
import '../../data/models/gig_review.dart';
import 'models/user_profile.dart';
import 'widgets/profile_proof_video_player.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId, this.displayRole});

  final String userId;
  final String? displayRole;

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

  Future<void> _reportProfile(BuildContext context, EngagementService service) async {
    const reasons = ['spam', 'fraud', 'harassment', 'unsafe', 'inappropriate', 'other'];
    var reason = reasons.first;
    final details = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report profile'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(initialValue: reason, items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) { if (v != null) setState(() => reason = v); }),
            const SizedBox(height: 12),
            TextField(controller: details, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'Additional details (optional)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit report')),
          ],
        ),
      ),
    );
    if (submitted == true && context.mounted) {
      await service.report(targetType: 'user', targetId: widget.userId, reason: reason, details: details.text);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. Thank you.')));
    }
    details.dispose();
  }

  void _loadProfile() {
    _profileFuture = context.read<UserProfileRepository>().getPublicProfile(
      widget.userId,
      roleOverride: widget.displayRole,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PUBLIC PROFILE'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final engagement = context.read<EngagementService>();
              if (value == 'block') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Block this account?'),
                    content: const Text('You will no longer see this person’s gigs, and the two accounts will not be able to apply to or message each other.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Block')),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await engagement.blockUser(widget.userId);
                  if (context.mounted) context.pop();
                }
              } else if (value == 'report') {
                await _reportProfile(context, engagement);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report profile')),
              PopupMenuItem(value: 'block', child: Text('Block account')),
            ],
          ),
        ],
      ),
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
                      backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                          ? NetworkImage(profile.photoUrl!)
                          : null,
                      child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                          ? Text(profile.initials, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))
                          : null,
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
                    if (profile.activeRole == 'worker' && profile.location.isNotEmpty) ...[
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
                    if (profile.activeRole == 'poster')
                      Row(
                        children: [
                          Expanded(
                            child: _ProfileStat(
                              label: 'GIGS POSTED',
                              value: '${profile.postedGigs}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ProfileStat(
                              label: 'GIGS PAID',
                              value: '${profile.paidGigs}',
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: _ProfileStat(
                          label: 'COMPLETED',
                          value: '${profile.completedGigs} GIGS',
                        ),
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
              if (profile.activeRole == 'worker' &&
                  profile.proofVideoUrl != null &&
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
              _ProfileReviews(
                userId: profile.id,
                role: profile.activeRole,
                title: profile.activeRole == 'poster'
                    ? 'CREDIBILITY RATING'
                    : 'RATINGS & REVIEWS',
                paidGigs: profile.activeRole == 'poster'
                    ? profile.paidGigs
                    : null,
              ),
              if (profile.activeRole == 'worker') ...[
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
            ],
          );
        },
      ),
    );
  }
}

class _ProfileReviews extends StatelessWidget {
  const _ProfileReviews({required this.userId, required this.role, required this.title, this.paidGigs});
  final String userId;
  final String role;
  final String title;
  final int? paidGigs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return StreamBuilder<List<GigReview>>(
      stream: context.read<EngagementService>().watchReviewsFor(userId, role: role),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <GigReview>[];
        final average = reviews.isEmpty ? 0.0 :
            reviews.fold<int>(0, (sum, review) => sum + review.rating) / reviews.length;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: .7))),
            Text(
              [
                reviews.isEmpty
                    ? 'No reviews'
                    : '${average.toStringAsFixed(1)} ★  •  ${reviews.length} reviews',
                if (paidGigs != null) '$paidGigs verified paid',
              ].join('  •  '),
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ]),
          const SizedBox(height: 10),
          if (snapshot.hasError)
            Text('Reviews could not be loaded.', style: TextStyle(color: scheme.onSurfaceVariant))
          else if (reviews.isEmpty)
            Text('Reviews from completed gigs will appear here.',
              style: TextStyle(color: scheme.onSurfaceVariant))
          else
            ...reviews.take(8).map((review) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(review.reviewerName,
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800))),
                  Text('${review.rating} ★', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                ]),
                if (review.comment.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(review.comment),
                ],
              ]),
            )),
        ]);
      },
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
