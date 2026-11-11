import 'package:flutter/material.dart';

//import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/match_profile.dart';

class MatchAvatarItem extends StatelessWidget {
  const MatchAvatarItem({
    super.key,
    required this.profile,
    this.onTap,
  });

  final MatchProfile profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondary,
                border: Border.all(
                  color: scheme.outline,
                  width: AppTokens.borderWidth,
                ),
                boxShadow: AppTokens.hardShadow(scheme.outline, 2),
              ),
              alignment: Alignment.center,
              child: Text(
                profile.initials,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 64,
              child: Text(
                profile.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
