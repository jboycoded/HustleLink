
import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/models/gig.dart';

class MatchedGigTile extends StatelessWidget {
  const MatchedGigTile({
    super.key,
    required this.gig,
    this.onTap,
    this.onDelete,
  });

  final Gig gig;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          border: Border.all(
            color: scheme.outline,
            width: AppTokens.borderWidth,
          ),
          boxShadow: AppTokens.hardShadow(scheme.outline, 3),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTokens.rLg),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.outline,
                          width: AppTokens.borderWidth,
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${gig.title} • ${gig.distanceKm} km away',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
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
                            '₦${gig.pay}',
                            style: text.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
