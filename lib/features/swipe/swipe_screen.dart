
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/services/engagement_service.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/gig.dart';
import 'gig_card.dart';
import 'gig_form_dialog.dart';
import 'swipe_view_model.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key, this.initialGigId});

  final String? initialGigId;

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialGigId != null && widget.initialGigId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openNotifiedGig(widget.initialGigId!);
      });
    }
  }

  Future<void> _openNotifiedGig(String gigId) async {
    final vm = context.read<SwipeViewModel>();
    while (mounted && vm.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    final gig = await vm.focusGig(gigId);
    if (!mounted) return;
    if (gig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This gig is no longer available.')),
      );
      return;
    }
    await _showWorkerGigDetails(context, vm, gig);
    if (mounted) vm.clearFocusedGig();
  }

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

    final success = await vm.apply(targetGig: gig);

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

  Future<void> _reportGig(BuildContext context, Gig gig) async {
    const reasons = ['spam', 'fraud', 'harassment', 'unsafe', 'inappropriate', 'other'];
    var reason = reasons.first;
    final details = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report gig'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(initialValue: reason, items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) { if (v != null) setState(() => reason = v); }),
            const SizedBox(height: 12),
            TextField(controller: details, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'Additional details (optional)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit report')),
          ],
        ),
      ),
    );
    if (submitted == true && context.mounted) {
      await context.read<EngagementService>().report(targetType: 'gig', targetId: gig.id, reason: reason, details: details.text);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. Thank you.')));
    }
    details.dispose();
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

  Future<void> _showWorkerGigDetails(
    BuildContext context,
    SwipeViewModel vm,
    Gig gig,
  ) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            18,
            22,
            22 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'GIG DETAILS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  gig.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(gig.category)),
                    Chip(
                      avatar: const Icon(Icons.place_outlined, size: 17),
                      label: Text(gig.location.isEmpty ? 'Location not provided' : gig.location),
                    ),
                    Chip(
                      avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(gig.when.isEmpty ? 'Date not specified' : gig.when),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'PAY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '₦${gig.pay.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'DESCRIPTION',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  gig.description.isEmpty ? 'No additional description provided.' : gig.description,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: gig.posterPhotoUrl != null &&
                            gig.posterPhotoUrl!.isNotEmpty
                        ? NetworkImage(gig.posterPhotoUrl!)
                        : null,
                    child: gig.posterPhotoUrl == null || gig.posterPhotoUrl!.isEmpty
                        ? const Icon(Icons.person_outline_rounded)
                        : null,
                  ),
                  title: Text(gig.posterName),
                  subtitle: const Text('View poster profile'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/profile/${gig.posterId}?role=poster');
                  },
                ),
                if (gig.proofVideoRequired) ...[
                  const Divider(),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.videocam_outlined),
                    title: Text('30-second profile video required'),
                    subtitle: Text('Add an introduction video to your profile before applying.'),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: vm.isApplying
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _applyToGig(context, vm);
                          },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Apply for this gig'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
              onTap: () => _showWorkerGigDetails(context, vm, gig),
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;

                if (velocity > 0) {
                  vm.previousGig();
                } else if (velocity < 0) {
                  vm.nextGig();
                }
              },
              child: GigCard(
                gig: gig,
                showDetailsHint: true,
                onReport: () => _reportGig(context, gig),
                onPosterTap: () => context.push('/profile/${gig.posterId}?role=poster'),
              ),
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

  bool _hasAcceptedParticipant(Gig gig, SwipeViewModel vm) =>
      gig.hasAcceptedParticipant ||
      (gig.acceptedApplicationId?.isNotEmpty ?? false) ||
      vm.hasAcceptedApplication(gig.id);

  bool _canDeleteGig(Gig gig, SwipeViewModel vm) {
    final hasAcceptedParticipant = _hasAcceptedParticipant(gig, vm);
    if (gig.status == 'closed') return !hasAcceptedParticipant;
    if (gig.status == 'completed') {
      return hasAcceptedParticipant && gig.paid;
    }
    return false;
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

          final hasAcceptedParticipant =
              _hasAcceptedParticipant(gig, vm);
          final isInProgress =
              gig.status == 'filled' || hasAcceptedParticipant;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 290,
                child: GigCard(gig: gig),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PosterGigAction(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      onTap: vm.isSaving || !gig.isOpen || hasAcceptedParticipant
                          ? null
                          : () => _showGigForm(context, vm, gig: gig),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: gig.isOpen && !hasAcceptedParticipant
                        ? _PosterGigAction(
                            label: 'Close',
                            icon: Icons.check_circle_outline,
                            onTap: () => _closeGig(context, vm, gig),
                          )
                        : _PosterGigAction(
                            label: gig.status == 'completed'
                                ? 'Completed'
                                : isInProgress
                                    ? 'In progress'
                                    : 'Closed',
                            icon: gig.status == 'completed'
                                ? Icons.task_alt_rounded
                                : isInProgress
                                    ? Icons.handshake_outlined
                                    : Icons.lock_outline_rounded,
                            onTap: null,
                          ),
                  ),
                  const SizedBox(width: 10),
                  _PosterGigAction(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                    onTap: _canDeleteGig(gig, vm)
                        ? () => _deleteGig(context, vm, gig)
                        : null,
                  ),
                ],
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


class _PosterGigAction extends StatelessWidget {
  const _PosterGigAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    final background = destructive
        ? scheme.surface
        : theme.brightness == Brightness.dark
            ? colors.peach
            : colors.peachSoft;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.rMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            border: Border.all(
              color: scheme.outline,
              width: AppTokens.borderWidth,
            ),
            boxShadow: AppTokens.hardShadow(scheme.outline, 3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
