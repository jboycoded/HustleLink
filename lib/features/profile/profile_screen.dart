
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/services/auth_service.dart';
import 'profile_view_model.dart';
import 'models/user_profile.dart';

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
                        child: Text(
                          profile.initials,
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSecondary,
                          ),
                        ),
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
