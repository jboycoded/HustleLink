import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/gig.dart';

class GigCard extends StatelessWidget {
  const GigCard({super.key, required this.gig});

  final Gig gig;

  static String _naira(int v) => '₦${v.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      )}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.peach,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: scheme.outline, width: AppTokens.borderWidth),
        boxShadow: AppTokens.hardShadow(scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _Tag(gig.category),
              const SizedBox(width: 10),
              Text(gig.when,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              _Tag('${gig.distanceKm}km', icon: Icons.place_outlined),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gig.title,
                style: text.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.05),
              ),
              const SizedBox(height: 12),
              Text(gig.posterName,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _naira(gig.pay),
                style: text.displayMedium
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1),
              ),
              const SizedBox(height: 12),
              const _Tag('30-sec proof', icon: Icons.videocam_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
