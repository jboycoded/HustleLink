import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'matches_view_model.dart';
import 'widgets/match_avatar_item.dart';
import 'widgets/matched_gig_tile.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  @override
  void initState() {
    super.initState();
    // Safely trigger data loading after initialization context binds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchesViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MatchesViewModel>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final text = theme.textTheme;

    Widget body;

    if (vm.isLoading) {
      body = Center(
        child: CircularProgressIndicator(
          color: scheme.primary,
        ),
      );
    } else if (vm.error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 42,
                color: colors.muted,
              ),
              const SizedBox(height: 16),
              Text(
                vm.error!,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: vm.load,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    } else if (vm.newMatches.isEmpty && vm.matchedGigs.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 52,
                color: colors.muted,
              ),
              const SizedBox(height: 16),
              Text(
                'No matches yet.',
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep swiping to discover new connections!',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: colors.muted,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        children: [
          // 1. Horizontal New Matches Segment
          if (vm.newMatches.isNotEmpty) ...[
            Text(
              'NEW MATCHES',
              style: text.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.muted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 86,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: vm.newMatches.length,
                itemBuilder: (context, index) {
                  final profile = vm.newMatches[index];
                  return MatchAvatarItem(
                    profile: profile,
                    onTap: () {
                      // Handle router navigation step to chat screen
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 2. Vertical Your Gigs Segment
          if (vm.matchedGigs.isNotEmpty) ...[
            Text(
              'YOUR GIGS',
              style: text.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.muted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vm.matchedGigs.length,
              itemBuilder: (context, index) {
                final gig = vm.matchedGigs[index];
                return MatchedGigTile(
                  gig: gig,
                  onTap: () {
                    // Navigate to chat room for this gig
                  },
                  onDelete: () => vm.removeMatch(gig.id),
                );
              },
            ),
          ],
        ],
      );
    }

    return SafeArea(
      child: Column(
        children: [
          // Screen Custom App Bar Header matching Swipe Screen layout style
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'MATCHES',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.peachSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: scheme.outline,
                      width: AppTokens.borderWidth,
                    ),
                  ),
                  child: Text(
                    '${vm.matchedGigs.length} ACTIVE',
                    style: text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(child: body),
        ],
      ),
    );
  }
}
