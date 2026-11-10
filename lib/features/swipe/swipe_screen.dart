
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'gig_card.dart';
import 'swipe_view_model.dart';

class SwipeScreen extends StatelessWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SwipeViewModel>();
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
    } else if (vm.currentGig == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_outlined,
                size: 52,
                color: colors.muted,
              ),
              const SizedBox(height: 16),
              Text(
                'No more gigs near you.',
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back soon for new opportunities.',
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
      final gig = vm.currentGig!;

      body = Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 25, 12),
        child: Dismissible(
          key: ValueKey(gig.id),
          direction: DismissDirection.horizontal,
          onDismissed: (direction) {
            if (direction == DismissDirection.startToEnd) {
              vm.apply();
            } else {
              vm.pass();
            }
          },
          background: _SwipeBackground(
            alignment: Alignment.centerLeft,
            label: 'APPLY',
            icon: Icons.check_circle_outline,
            color: scheme.primary,
          ),
          secondaryBackground: _SwipeBackground(
            alignment: Alignment.centerRight,
            label: 'PASS',
            icon: Icons.close_rounded,
            color: scheme.error,
          ),
          child: GigCard(gig: gig),
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
                  'HUSTLELINK',
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
                    'DISCOVER',
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

          if (vm.currentGig != null && !vm.isLoading && vm.error == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundButton(
                    icon: Icons.close_rounded,
                    label: 'Pass',
                    size: 64,
                    onPressed: vm.pass,
                  ),
                  const SizedBox(width: 28),
                  _RoundButton(
                    icon: Icons.check_rounded,
                    label: 'Apply',
                    size: 72,
                    fill: scheme.primary,
                    iconColor: scheme.onPrimary,
                    onPressed: vm.apply,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.label,
    required this.icon,
    required this.color,
  });

  final Alignment alignment;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    //final scheme = Theme.of(context).colorScheme;

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(
          color: color,
          width: AppTokens.borderWidth,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.size,
    required this.onPressed,
    this.fill,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final double size;
  final VoidCallback onPressed;
  final Color? fill;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill ?? scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: scheme.outline,
            width: AppTokens.borderWidth,
          ),
          boxShadow: AppTokens.hardShadow(scheme.outline, 3),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(
              icon,
              size: size * 0.4,
              color: iconColor ?? scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
