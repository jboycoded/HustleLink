
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'profile_view_model.dart';

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
      return Center(
        child: CircularProgressIndicator(color: scheme.secondary),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          // Header
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
              ],
            ),
          ),

          // Scrollable profile content
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
                        profile.fullName,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.role,
                        style: text.bodyMedium?.copyWith(
                          color: colors.muted,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Statistics
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
                        activeThumbColor: scheme.onSecondary,
                        activeTrackColor: scheme.secondary,
                        onChanged: vm.toggleAvailability,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Skills
                Text(
                  'YOUR SKILLS',
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.muted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
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
              ],
            ),
          ),
        ],
      ),
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
