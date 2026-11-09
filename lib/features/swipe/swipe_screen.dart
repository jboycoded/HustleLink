import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import 'gig_card.dart';
import 'swipe_view_model.dart';

class SwipeScreen extends StatelessWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SwipeViewModel>();
    final gig = vm.currentGig;

    Widget body;
    if (vm.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(vm.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: vm.load, child: const Text('Try again')),
          ],
        ),
      );
    } else if (gig == null) {
      body = const Center(child: Text('No more gigs near you. Check back soon.'));
    } else {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 25, 12),
        child: Dismissible(
          key: ValueKey(gig.id),
          onDismissed: (direction) => direction == DismissDirection.startToEnd
              ? vm.apply()
              : vm.pass(),
          child: GigCard(gig: gig),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('HUSTLELINK',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(child: body),
          if (gig != null && !vm.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundButton(
                    icon: Icons.close,
                    label: 'Pass',
                    size: 64,
                    onPressed: vm.pass,
                  ),
                  const SizedBox(width: 24),
                  _RoundButton(
                    icon: Icons.check,
                    label: 'Apply',
                    size: 72,
                    fill: Theme.of(context).colorScheme.primary,
                    iconColor: Theme.of(context).colorScheme.onPrimary,
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
      child: Material(
        color: fill ?? scheme.surface,
        shape: CircleBorder(
          side: BorderSide(color: scheme.outline, width: AppTokens.borderWidth),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.4, color: iconColor ?? scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
