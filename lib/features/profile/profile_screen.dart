
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/proof_video_service.dart';
import '../../../data/services/profile_photo_service.dart';
import '../../../data/services/engagement_service.dart';
import '../../../data/models/gig_review.dart';
import 'profile_view_model.dart';
import 'models/user_profile.dart';
import 'widgets/profile_proof_video_player.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final profile = vm.profile;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final text = theme.textTheme;

    if (profile == null) {
      return SafeArea(
        child: Center(
          child: vm.isLoading
              ? CircularProgressIndicator(color: scheme.secondary)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vm.errorMessage ?? 'Unable to load your profile.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: vm.load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'PROFILE',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                if (profile.isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondary,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: scheme.outline,
                        width: AppTokens.borderWidth,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: scheme.onSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'VERIFIED',
                          style: text.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  tooltip: 'Log out',
                  onPressed: () async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'Are you sure you want to sign out of HustleLink?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  await context.read<AuthService>().signOut();
},
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Identity card
                Container(
                  padding: const EdgeInsets.all(20),
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.secondary,
                          border: Border.all(
                            color: scheme.outline,
                            width: AppTokens.borderWidth,
                          ),
                          boxShadow: AppTokens.hardShadow(
                            scheme.outline,
                            2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                            ? ClipOval(child: Image.network(profile.photoUrl!, width: 76, height: 76, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(profile.initials, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSecondary)))))
                            : Text(profile.initials, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSecondary)),
                      ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: IconButton.filled(
                              tooltip: 'Change profile photo',
                              onPressed: vm.isSaving ? null : () => _chooseProfilePhoto(context, vm),
                              icon: const Icon(Icons.camera_alt_rounded, size: 17),
                              style: IconButton.styleFrom(minimumSize: const Size(34, 34), padding: EdgeInsets.zero),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.fullName.isEmpty
                            ? 'Complete your profile'
                            : profile.fullName,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        style: text.bodySmall?.copyWith(
                          color: colors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.location.isEmpty
                            ? 'Location not added'
                            : profile.location,
                        style: text.bodyMedium?.copyWith(
                          color: colors.muted,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Worker / Poster selector
                      Wrap(
                        spacing: 10,
                        children: [
                          _RoleButton(
                            label: 'Worker',
                            selected: profile.activeRole == 'worker',
                            onPressed: () async {
                              await vm.switchRole('worker');
                            },
                          ),
                          _RoleButton(
                            label: 'Poster',
                            selected: profile.activeRole == 'poster',
                            onPressed: () async {
                              await vm.switchRole('poster');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: () => _editProfile(
                          context,
                          vm,
                          profile,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit profile'),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              label: 'RATING',
                              value: '${profile.rating} ★',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatBox(
                              label: 'COMPLETED',
                              value: '${profile.completedGigs} GIGS',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _ProfileCompleteness(profile: profile),
                const SizedBox(height: 20),

                // Availability
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    border: Border.all(
                      color: scheme.outline,
                      width: AppTokens.borderWidth,
                    ),
                    boxShadow: AppTokens.hardShadow(scheme.outline, 3),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available for Gigs',
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              'Show your profile to nearby clients',
                              style: text.labelSmall?.copyWith(
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vm.isAvailableForGigs,
                        thumbColor:
                            WidgetStateProperty.resolveWith<Color?>(
                          (states) {
                            if (states.contains(WidgetState.selected)) {
                              return scheme.onSecondary;
                            }
                            return scheme.surface;
                          },
                        ),
                        trackColor:
                            WidgetStateProperty.resolveWith<Color?>(
                          (states) {
                            if (states.contains(WidgetState.selected)) {
                              return scheme.secondary;
                            }
                            return scheme.outlineVariant;
                          },
                        ),
                        onChanged: vm.toggleAvailability,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'YOUR SKILLS',
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.muted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                if (profile.skills.isEmpty)
                  Text(
                    'No skills added yet. Edit your profile to add skills.',
                    style: text.bodyMedium?.copyWith(color: colors.muted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profile.skills.map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: scheme.outline,
                            width: AppTokens.borderWidth,
                          ),
                        ),
                        child: Text(
                          skill,
                          style: text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 24),
                _OwnProfileReviews(userId: profile.id),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _manageBlockedAccounts(context),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Manage blocked accounts'),
                  ),
                ),
                const SizedBox(height: 8),
                _ProfileProofVideoSection(
                  videoUrl: profile.proofVideoUrl,
                  isBusy: vm.isSaving || vm.isVideoUploading,
                  onUpload: () => _chooseProofVideo(context, vm),
                  onRemove: profile.proofVideoUrl == null
                      ? null
                      : () => _removeProofVideo(context, vm),
                ),
                if (vm.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    vm.errorMessage!,
                    style: TextStyle(color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manageBlockedAccounts(BuildContext context) async {
    final service = context.read<EngagementService>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .55,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('BLOCKED ACCOUNTS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Expanded(child: FutureBuilder<List<Map<String, String>>>(
                future: service.getBlockedUsers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final users = snapshot.data!;
                  if (users.isEmpty) return const Center(child: Text('You have not blocked any accounts.'));
                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        title: Text(user['name'] ?? 'HustleLink member'),
                        subtitle: Text('Blocked account'),
                        trailing: TextButton(
                          onPressed: () async {
                            await service.unblockUser(user['id']!);
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                            if (context.mounted) _manageBlockedAccounts(context);
                          },
                          child: const Text('Unblock'),
                        ),
                      );
                    },
                  );
                },
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseProfilePhoto(BuildContext context, ProfileViewModel vm) async {
    try {
      final url = await context.read<ProfilePhotoService>().pickAndUpload();
      if (url == null || !context.mounted) return;
      final saved = await vm.updateProfilePhotoUrl(url);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved ? 'Profile photo updated.' : vm.errorMessage ?? 'Could not save profile photo.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  Future<void> _chooseProofVideo(
    BuildContext context,
    ProfileViewModel vm,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Record a video'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    vm.setVideoUploading(true);
    try {
      final url = await context.read<ProofVideoService>().pickAndUpload(source);
      if (url == null || !context.mounted) return;
      final saved = await vm.updateProofVideoUrl(url);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Your profile video has been saved.'
                : vm.errorMessage ?? 'Could not save your profile video.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (context.mounted) vm.setVideoUploading(false);
    }
  }

  Future<void> _removeProofVideo(
    BuildContext context,
    ProfileViewModel vm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove profile video?'),
        content: const Text(
          'Posters will no longer see a proof video on your public profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep video'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      // Delete the stored object first so a failed deletion never leaves a
      // publicly accessible video behind after its profile link is cleared.
      await context.read<ProofVideoService>().deleteProfileVideo();
      if (!context.mounted) return;

      final saved = await vm.updateProofVideoUrl(null);
      if (!context.mounted) return;
      if (!saved) {
        throw StateError(vm.errorMessage ?? 'Could not update your profile.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your profile video has been removed.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _editProfile(
    BuildContext context,
    ProfileViewModel vm,
    UserProfile profile,
  ) async {
    final nameController = TextEditingController(
      text: profile.fullName,
    );
    final locationController = TextEditingController(
      text: profile.location,
    );
    final skillsController = TextEditingController(
      text: profile.skills.join(', '),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g. Lagos, Nigeria',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skillsController,
                  decoration: const InputDecoration(
                    labelText: 'Skills',
                    hintText: 'e.g. Plumbing, Design, Coding',
                    helperText: 'Separate skills with commas.',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your full name.'),
                    ),
                  );
                  return;
                }

                final skills = skillsController.text
                    .split(',')
                    .map((skill) => skill.trim())
                    .where((skill) => skill.isNotEmpty)
                    .toSet()
                    .toList();

                final saved = await vm.updateProfile(
                  fullName: name,
                  location: locationController.text,
                  skills: skills,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, saved);
                }
              },
              child: const Text('Save changes'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    locationController.dispose();
    skillsController.dispose();

    if (result == false && context.mounted && vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage!)),
      );
    }
  }
}

class _ProfileProofVideoSection extends StatelessWidget {
  const _ProfileProofVideoSection({
    required this.videoUrl,
    required this.isBusy,
    required this.onUpload,
    required this.onRemove,
  });

  final String? videoUrl;
  final bool isBusy;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasVideo = videoUrl != null && videoUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '30-SECOND PROFILE VIDEO',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add one short introduction or demonstration. Posters can view this same video when reviewing your applications.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (hasVideo) ...[
            const SizedBox(height: 14),
            ProfileProofVideoPlayer(videoUrl: videoUrl!),
          ] else ...[
            const SizedBox(height: 14),
            Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.video_camera_back_outlined,
                size: 42,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isBusy ? null : onUpload,
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(hasVideo
                          ? Icons.refresh_rounded
                          : Icons.video_call_outlined),
                  label: Text(isBusy
                      ? 'Please wait...'
                      : hasVideo
                          ? 'Replace video'
                          : 'Add video'),
                ),
              ),
              if (hasVideo) ...[
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Remove video',
                  onPressed: isBusy ? null : onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
          Text(
            'Maximum 30 seconds • Maximum 50 MB',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _OwnProfileReviews extends StatelessWidget {
  const _OwnProfileReviews({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GigReview>>(
      stream: context.read<EngagementService>().watchReviewsFor(userId),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <GigReview>[];
        final average = reviews.isEmpty ? 0.0 : reviews.fold<int>(0, (s, r) => s + r.rating) / reviews.length;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('YOUR REVIEWS', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(reviews.isEmpty ? 'No reviews yet.' : '${average.toStringAsFixed(1)} ★ from ${reviews.length} reviews'),
          ...reviews.take(5).map((r) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(r.reviewerName),
            subtitle: r.comment.isEmpty ? null : Text(r.comment),
            trailing: Text('${r.rating} ★'),
          )),
        ]);
      },
    );
  }
}

class _ProfileCompleteness extends StatelessWidget {
  const _ProfileCompleteness({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final checks = <String, bool>{
      'Add your full name': profile.fullName.trim().isNotEmpty,
      'Add your location': profile.location.trim().isNotEmpty,
      'List your skills or services': profile.skills.isNotEmpty,
      'Upload a profile photo': profile.photoUrl?.isNotEmpty == true,
      'Add your 30-second introduction video': profile.proofVideoUrl?.isNotEmpty == true,
    };
    final completed = checks.values.where((value) => value).length;
    final progress = completed / checks.length;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: scheme.outline, width: AppTokens.borderWidth),
        boxShadow: AppTokens.hardShadow(scheme.outline, 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('PROFILE COMPLETENESS',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            Text('${(progress * 100).round()}%',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress, minHeight: 8,
              borderRadius: BorderRadius.circular(20)),
          const SizedBox(height: 10),
          ...checks.entries.map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(entry.value ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 17, color: entry.value ? Colors.green : scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(entry.key,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: entry.value ? scheme.onSurfaceVariant : scheme.onSurface,
                    decoration: entry.value ? TextDecoration.lineThrough : null,
                  ))),
            ]),
          )),
        ],
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: selected ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? scheme.secondary : scheme.surface,
        foregroundColor:
            selected ? scheme.onSecondary : scheme.onSurface,
        side: BorderSide(
          color: scheme.outline,
          width: AppTokens.borderWidth,
        ),
      ),
      child: Text(label),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final text = theme.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(
          color: scheme.outline,
          width: AppTokens.borderWidth,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: colors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
