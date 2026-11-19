
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/gig.dart';
import 'gig_card.dart';
import 'gig_form_dialog.dart';
import 'swipe_view_model.dart';

class SwipeScreen extends StatelessWidget {
  const SwipeScreen({super.key});

  Future<void> _showGigForm(
    BuildContext context,
    SwipeViewModel vm, {
    Gig? gig,
  }) async {
    final result = await showDialog<GigFormData>(
      context: context,
      builder: (_) => GigFormDialog(gig: gig),
    );

    if (result == null || !context.mounted) return;

    final success = gig == null
        ? await vm.createGig(
            title: result.title,
            description: result.description,
            category: result.category,
            pay: result.pay,
            location: result.location,
            when: result.when,
            proofVideoRequired: result.proofVideoRequired,
          )
        : await vm.updateGig(
            gigId: gig.id,
            title: result.title,
            description: result.description,
            category: result.category,
            pay: result.pay,
            location: result.location,
            when: result.when,
            proofVideoRequired: result.proofVideoRequired,
          );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (gig == null
                  ? 'Your gig has been posted.'
                  : 'Your gig has been updated.')
              : (vm.error ?? 'Unable to save your gig.'),
        ),
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _applyToGig(
    BuildContext context,
    SwipeViewModel vm,
  ) async {
    final gig = vm.currentGig;
    if (gig == null || vm.isApplying) return;

    final confirmed = await _confirm(
      context,
      title: 'Apply for this gig?',
      message:
          'Your application for "${gig.title}" will be sent to the poster. You can track its status in Matches.',
      action: 'Confirm application',
    );

    if (!confirmed || !context.mounted) return;

    final success = await vm.apply();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Application submitted. You can track it in Matches.'
              : (vm.error ?? 'Unable to submit your application.'),
        ),
      ),
    );
  }

  Future<void> _closeGig(
    BuildContext context,
    SwipeViewModel vm,
    Gig gig,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Close this gig?',
      message:
          'Workers will no longer see this gig in discovery. You can still view and delete it.',
      action: 'Close gig',
    );

    if (!confirmed || !context.mounted) return;

    final success = await vm.closeGig(gig.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Gig closed.' : (vm.error ?? 'Unable to close gig.'),
        ),
      ),
    );
  }

  Future<void> _deleteGig(
    BuildContext context,
    SwipeViewModel vm,
    Gig gig,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Delete this gig?',
      message: 'This action cannot be undone.',
      action: 'Delete',
    );

    if (!confirmed || !context.mounted) return;

    final success = await vm.deleteGig(gig.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Gig deleted.' : (vm.error ?? 'Unable to delete gig.'),
        ),
      ),
    );
  }

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
        child: CircularProgressIndicator(color: scheme.primary),
      );
    } else if (vm.error != null && vm.gigs.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 42, color: colors.muted),
              const SizedBox(height: 16),
              Text(
                vm.error!,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: vm.refresh,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    } else if (vm.isPosterMode) {
      body = _buildPosterBody(context, vm);
    } else {
      body = _buildWorkerBody(context, vm);
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
                if (vm.isPosterMode)
                  IconButton.filled(
                    tooltip: 'Post a gig',
                    onPressed: vm.isSaving
                        ? null
                        : () => _showGigForm(context, vm),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                    icon: Icon(Icons.add, color: scheme.onPrimary),
                  ),
                if (vm.isPosterMode) const SizedBox(width: 8),
                if (vm.isPosterMode)
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
                      'MY GIGS',
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        letterSpacing: 0.8,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: vm.isLoading ? null : vm.refresh,
                    child: const Text('DISCOVER'),
                  ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildWorkerBody(BuildContext context, SwipeViewModel vm) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

    return Column(
      children: [
        if (vm.categories.length > 1)
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: vm.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = vm.categories[index];
                final selected = vm.selectedCategory == category;

                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => vm.selectCategory(category),
                  selectedColor: colors.peachSoft,
                  side: BorderSide(
                    color: scheme.outline,
                    width: AppTokens.borderWidth,
                  ),
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: vm.currentGig == null
              ? const _EmptyState(
                  icon: Icons.explore_outlined,
                  title: 'No more gigs available.',
                  message: 'Check back soon for new opportunities.',
                )
              : _buildWorkerGig(context, vm),
        ),
      ],
    );
  }

  Widget _buildWorkerGig(BuildContext context, SwipeViewModel vm) {
    final gig = vm.currentGig!;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 25, 12),
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;

                if (velocity > 0) {
                  vm.previousGig();
                } else if (velocity < 0) {
                  vm.nextGig();
                }
              },
              child: GigCard(gig: gig),
            ),
          ),
        ),
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
                icon: vm.isApplying
                    ? Icons.hourglass_top_rounded
                    : Icons.check_rounded,
                label: 'Apply',
                size: 72,
                fill: scheme.primary,
                iconColor: scheme.onPrimary,
                onPressed: vm.isApplying
                    ? null
                    : () => _applyToGig(context, vm),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPosterBody(BuildContext context, SwipeViewModel vm) {
    if (vm.gigs.isEmpty) {
      return _EmptyState(
        icon: Icons.post_add_rounded,
        title: 'You haven’t posted any gigs yet.',
        message: 'Create a gig and let workers discover your opportunity.',
        action: FilledButton.icon(
          onPressed: vm.isSaving ? null : () => _showGigForm(context, vm),
          icon: const Icon(Icons.add),
          label: const Text('Post your first gig'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: vm.gigs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final gig = vm.gigs[index];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (!gig.isOpen)
                    const Expanded(
                      child: Text(
                        'CLOSED',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  OutlinedButton.icon(
                    onPressed: vm.isSaving
                        ? null
                        : () => _showGigForm(context, vm, gig: gig),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  if (gig.isOpen)
                    OutlinedButton.icon(
                      onPressed: () => _closeGig(context, vm, gig),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Close'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Delete gig',
                    onPressed: () => _deleteGig(context, vm, gig),
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 290,
                child: GigCard(gig: gig),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = context.appColors.muted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
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
  final VoidCallback? onPressed;
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
