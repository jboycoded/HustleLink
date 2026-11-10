
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/models/gig.dart';

class GigCard extends StatelessWidget {
  const GigCard({super.key, required this.gig});

  final Gig gig;

  static String _naira(int value) => '₦${value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      )}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(
          color: scheme.outline,
          width: AppTokens.borderWidth,
        ),
        boxShadow: AppTokens.hardShadow(scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Category, time and distance
          Row(
            children: [
              _Tag(gig.category),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  gig.when,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondary,
                  ),
                ),
              ),
              const Spacer(),
              _Tag(
                '${gig.distanceKm}km',
                icon: Icons.place_outlined,
              ),
            ],
          ),

          // Gig title and poster
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gig.title,
                style: text.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  color: scheme.onSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                gig.posterName,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSecondary.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),

          // Payment and proof requirement
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _naira(gig.pay),
                style: text.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: scheme.onSecondary,
                ),
              ),
              const SizedBox(height: 12),
              const _Tag(
                '30-sec proof',
                icon: Icons.videocam_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(
    this.label, {
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outline,
          width: AppTokens.borderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: scheme.onSurface,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
