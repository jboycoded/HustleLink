import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/models/gig.dart';

class GigCard extends StatelessWidget {
  const GigCard({super.key, required this.gig, this.onReport, this.onPosterTap, this.showDetailsHint = false});

  final Gig gig;
  final VoidCallback? onReport;
  final VoidCallback? onPosterTap;
  final bool showDetailsHint;

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (gig.posterPhotoUrl != null &&
                      gig.posterPhotoUrl!.isNotEmpty) ...[
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(gig.posterPhotoUrl!),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: _Tag(gig.category, maxLines: 2)),
                  if (onReport != null)
                    PopupMenuButton<String>(
                      tooltip: 'Gig options',
                      onSelected: (value) {
                        if (value == 'report') onReport!();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'report',
                          child: Text('Report gig'),
                        ),
                      ],
                      icon: Icon(Icons.more_vert_rounded, color: scheme.onSecondary),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _Tag(
                      gig.location,
                      icon: Icons.place_outlined,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _Tag(
                      gig.when,
                      icon: Icons.schedule_rounded,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
              InkWell(
                onTap: onPosterTap,
                child: Text(
                  gig.posterName,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondary.withValues(alpha: 0.75),
                    decoration: onPosterTap == null ? null : TextDecoration.underline,
                  ),
                ),
              ),
              if (gig.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  gig.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
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
              if (gig.proofVideoRequired) ...[
                const SizedBox(height: 12),
                const _Tag(
                  '30-sec proof',
                  icon: Icons.videocam_outlined,
                ),
              ],
              if (showDetailsHint) ...[
                const SizedBox(height: 10),
                Text(
                  'TAP FOR FULL DETAILS',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSecondary.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.icon, this.maxLines = 1});

  final String label;
  final IconData? icon;
  final int maxLines;

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
            Icon(icon, size: 16, color: scheme.onSurface),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: maxLines,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
