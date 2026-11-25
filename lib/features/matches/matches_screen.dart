import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/gig_application.dart';
import '../../data/models/gig.dart';
import '../../data/repositories/gig_repository.dart';
import '../../data/services/engagement_service.dart';
import 'matches_view_model.dart';
import '../notifications/notification_bell.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MatchesViewModel>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MatchesViewModel>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    //final colors = context.appColors;
    final text = theme.textTheme;

    Widget body;

    if (vm.isLoading) {
      body = Center(
        child: CircularProgressIndicator(color: scheme.secondary),
      );
    } else if (vm.error != null) {
      body = _EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Unable to load applications.',
        message: vm.error!,
        action: FilledButton(
          onPressed: vm.load,
          child: const Text('Try again'),
        ),
      );
    } else if (vm.isPosterMode && vm.filteredPosterGigs.isEmpty) {
      body = const _EmptyState(
        icon: Icons.filter_list_off_rounded,
        title: 'No gigs in this category.',
        message: 'Choose another filter to see more gigs.',
      );
    } else if (vm.isPosterMode) {
      body = _buildPosterApplications(context, vm);
    } else if (vm.recordCount == 0) {
      body = const _EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No applications yet.',
        message: 'Gigs you apply for will appear here so you can track their status.',
      );
    } else if (vm.filteredWorkerApplications.isEmpty) {
      body = const _EmptyState(
        icon: Icons.filter_list_off_rounded,
        title: 'No applications in this status.',
        message: 'Choose another filter to see more applications.',
      );
    } else {
      body = _buildWorkerApplications(context, vm);
    }

    return SafeArea(
      child: Column(
        children: [
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
                const NotificationBell(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
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
                    '${vm.recordCount} ${vm.isPosterMode ? 'GIGS' : 'APPLICATIONS'}',
                    style: text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!vm.isLoading && vm.error == null && vm.recordCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final filter in (vm.isPosterMode
                      ? ['all', 'pending', 'confirmed', 'closed', 'completed']
                      : ['all', 'pending', 'accepted', 'rejected', 'completed']))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter == 'all' ? 'All' : filter[0].toUpperCase() + filter.substring(1)),
                        selected: vm.statusFilter == filter,
                        onSelected: (_) => vm.setStatusFilter(filter),
                      ),
                    ),
                ]),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildWorkerApplications(
    BuildContext context,
    MatchesViewModel vm,
  ) {
    return RefreshIndicator(
      onRefresh: vm.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: vm.filteredWorkerApplications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final application = vm.filteredWorkerApplications[index];

          return _ApplicationCard(
            application: application,
            showWorkerName: false,
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteCompletedGig(
    BuildContext context,
    Gig gig,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete completed gig?'),
        content: Text(
          'Delete "${gig.title}" and remove its application records? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<GigRepository>().deleteGig(gig.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completed gig deleted from your records.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this gig. Please try again.')),
        );
      }
    }
  }

  Future<void> _showGigDetails(
    BuildContext context,
    String gigId,
    String gigTitle,
    List<GigApplication> applications,
  ) async {
    final gigFuture = context.read<GigRepository>().getGigById(gigId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ThemeAwareBottomSheet(
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .72,
            child: FutureBuilder<Gig?>(
              future: gigFuture,
              builder: (sheetContentContext, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final gig = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(sheetContentContext).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      gig?.title ?? gigTitle,
                      style: Theme.of(sheetContentContext).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          if ((gig?.description ?? '').isNotEmpty) ...[
                            Text(
                              'DESCRIPTION',
                              style: Theme.of(sheetContentContext).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(gig!.description),
                            const SizedBox(height: 16),
                          ],
                          _DetailRow(
                            label: 'Category',
                            value: gig?.category ??
                                (applications.isNotEmpty ? applications.first.gigCategory : ''),
                          ),
                          _DetailRow(
                            label: 'Payment',
                            value: '₦${gig?.pay ?? (applications.isNotEmpty ? applications.first.gigPay : 0)}',
                          ),
                          _DetailRow(
                            label: 'Location',
                            value: gig?.location ??
                                (applications.isNotEmpty ? applications.first.gigLocation : ''),
                          ),
                          _DetailRow(
                            label: 'Schedule',
                            value: gig?.when ?? 'Not available',
                          ),
                          _DetailRow(
                            label: 'Video required',
                            value: gig == null
                                ? 'Check gig settings'
                                : (gig.proofVideoRequired ? 'Yes' : 'No'),
                          ),
                          _DetailRow(
                            label: 'Applicants',
                            value: '${applications.length}',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showGigApplicants(
                            context,
                            gig?.title ?? gigTitle,
                            applications,
                          );
                        },
                        child: const Text('View applicants'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _showGigApplicants(
    BuildContext context,
    String gigTitle,
    List<GigApplication> applications,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ThemeAwareBottomSheet(
        child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _themeFor(sheetContext).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  gigTitle,
                  style: _themeFor(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${applications.length} applicants',
                  style: _themeFor(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: applications.isEmpty
                      ? const Center(
                          child: Text('No applications have been received for this gig yet.'),
                        )
                      : ListView.separated(
                    itemCount: applications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (itemContext, index) {
                      final application = applications[index];
                      final initials = application.workerName
                          .trim()
                          .split(RegExp(r'\s+'))
                          .where((part) => part.isNotEmpty)
                          .take(2)
                          .map((part) => part[0].toUpperCase())
                          .join();
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Theme.of(itemContext).colorScheme.outline,
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(itemContext).colorScheme.secondary,
                          foregroundColor:
                              Theme.of(itemContext).colorScheme.onSecondary,
                          child: Text(initials.isEmpty ? '?' : initials),
                        ),
                        title: Text(
                          application.workerName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${application.status[0].toUpperCase()}${application.status.substring(1)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _showApplicantDetails(context, application);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _showApplicantDetails(
    BuildContext context,
    GigApplication application,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ThemeAwareBottomSheet(
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                      color: _themeFor(sheetContext).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          _themeFor(sheetContext).colorScheme.secondary,
                      foregroundColor:
                          _themeFor(sheetContext).colorScheme.onSecondary,
                      child: Text(
                        application.workerName
                            .trim()
                            .split(RegExp(r'\s+'))
                            .where((part) => part.isNotEmpty)
                            .take(2)
                            .map((part) => part[0].toUpperCase())
                            .join(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application.workerName,
                            style: _themeFor(sheetContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Text('Worker applicant'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'APPLICATION DETAILS',
                  style: _themeFor(sheetContext).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: 12),
                _DetailRow(label: 'Gig', value: application.gigTitle),
                _DetailRow(label: 'Category', value: application.gigCategory),
                _DetailRow(
                  label: 'Payment',
                  value: '₦${application.gigPay}',
                ),
                _DetailRow(label: 'Location', value: application.gigLocation),
                _DetailRow(
                  label: 'Applied',
                  value: application.createdAt == null
                      ? 'Date unavailable'
                      : MaterialLocalizations.of(sheetContext)
                          .formatMediumDate(application.createdAt!),
                ),
                _DetailRow(
                  label: 'Status',
                  value: application.status.toUpperCase(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push('/profile/${application.workerId}');
                    },
                    icon: const Icon(Icons.person_outline_rounded),
                    label: const Text('View public profile'),
                  ),
                ),
                const SizedBox(height: 18),
                if (application.status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _reviewFromSheet(
                            sheetContext,
                            context,
                            application,
                            'rejected',
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _reviewFromSheet(
                            sheetContext,
                            context,
                            application,
                            'accepted',
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  )
                else if (application.status == 'accepted' ||
                    application.status == 'completed') ...[
                  if (application.status == 'accepted')
                    const Text(
                      'This application has been accepted. You can find the conversation in your Chats tab.',
                    ),
                  _CompletionPanel(application: application),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _reviewFromSheet(
    BuildContext sheetContext,
    BuildContext pageContext,
    GigApplication application,
    String status,
  ) async {
    final accepted = status == 'accepted';
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(accepted ? 'Accept applicant?' : 'Reject applicant?'),
        content: Text(
          accepted
              ? 'Accept ${application.workerName} for ${application.gigTitle}?'
              : 'Reject ${application.workerName}\'s application?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(accepted ? 'Accept' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !pageContext.mounted) return;
    try {
      await pageContext.read<MatchesViewModel>().reviewApplication(
            application.id,
            status,
          );
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      if (pageContext.mounted) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(
            content: Text(
              accepted ? 'Applicant accepted.' : 'Application rejected.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!pageContext.mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(
          content: Text('Could not update this application. Please try again.'),
        ),
      );
    }
  }

  // Retained for the next diagnostic stage; the poster subtree is bypassed for now.
  Widget _buildPosterApplications(
    BuildContext context,
    MatchesViewModel vm,
  ) {
    final gigs = vm.filteredPosterGigs;

    return RefreshIndicator(
      onRefresh: vm.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: gigs.length,
        itemBuilder: (listContext, index) {
          final gig = gigs[index];
          final applications =
              vm.posterApplicationsByGig[gig.id] ?? const <GigApplication>[];

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == gigs.length - 1 ? 0 : 20,
            ),
            child: _GigApplicationsCard(
              key: ValueKey(gig.id),
              gigTitle: gig.title,
              applications: applications,
              onTap: () => _showGigDetails(
                listContext,
                gig.id,
                gig.title,
                applications,
              ),
              onDelete: gig.status == 'completed'
                  ? () => _confirmDeleteCompletedGig(listContext, gig)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.showWorkerName,
  });

  final GigApplication application;
  final bool showWorkerName;

  Future<void> _review(BuildContext context, String status) async {
    final accepted = status == 'accepted';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(accepted ? 'Accept applicant?' : 'Reject applicant?'),
        content: Text(accepted
            ? 'Accept ${application.workerName} for ${application.gigTitle}? This will allow both of you to chat.'
            : 'Reject ${application.workerName}\'s application for ${application.gigTitle}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(accepted ? 'Accept' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<MatchesViewModel>().reviewApplication(application.id, status);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this application. Please try again.')),
      );
    }
  }

  Future<void> _removeRejected(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove rejected application?'),
        content: const Text(
          'This will remove the rejected application from your Matches list. It will not delete the poster\'s gig.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<MatchesViewModel>()
          .removeRejectedApplication(application.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove this application.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outline,
          width: AppTokens.borderWidth,
        ),
        boxShadow: AppTokens.hardShadow(scheme.outline, 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showWorkerName && application.workerPhotoUrl != null && application.workerPhotoUrl!.isNotEmpty) ...[
                CircleAvatar(radius: 20, backgroundImage: NetworkImage(application.workerPhotoUrl!)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: InkWell(
                  onTap: showWorkerName ? () => context.push('/profile/${application.workerId}') : null,
                  child: Text(
                  showWorkerName ? application.workerName : application.gigTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    decoration: showWorkerName ? TextDecoration.underline : null,
                  ),
                ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.peachSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: scheme.outline),
                ),
                child: Text(
                  application.status.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (showWorkerName) ...[
            Text(
              application.gigTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (showWorkerName && application.status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: context.read<MatchesViewModel>().isUpdating(application.id)
                        ? null
                        : () => _review(context, 'rejected'),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: context.read<MatchesViewModel>().isUpdating(application.id)
                        ? null
                        : () => _review(context, 'accepted'),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
          if (!showWorkerName && application.status == 'rejected') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _removeRejected(context),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove'),
              ),
            ),
          ],
          if (application.status == 'accepted' || application.status == 'completed')
            _CompletionPanel(application: application),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              if (application.gigCategory.isNotEmpty)
                _InfoItem(
                  icon: Icons.work_outline_rounded,
                  text: application.gigCategory,
                ),
              _InfoItem(
                icon: Icons.payments_outlined,
                text: '₦${application.gigPay}',
              ),
              if (application.gigLocation.isNotEmpty)
                _InfoItem(
                  icon: Icons.location_on_outlined,
                  text: application.gigLocation,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletionPanel extends StatefulWidget {
  const _CompletionPanel({required this.application});
  final GigApplication application;

  @override
  State<_CompletionPanel> createState() => _CompletionPanelState();
}

class _CompletionPanelState extends State<_CompletionPanel> {
  bool _busy = false;

  Future<void> _confirm(Gig gig) async {
    final service = context.read<EngagementService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm gig completion?'),
        content: const Text('Confirm only if the work has actually been completed. The gig will be marked completed after both the worker and poster confirm.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm completion')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await service.confirmGigCompletion(gigId: gig.id, gigTitle: gig.title);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(Gig gig) async {
    final service = context.read<EngagementService>();
    if (await service.hasReviewed(gig.id)) return;
    if (!mounted) return;
    var rating = 5;
    final comment = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Leave a review'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Rating: $rating / 5 stars'),
            Slider(value: rating.toDouble(), min: 1, max: 5, divisions: 4,
              onChanged: (value) => setDialogState(() => rating = value.round())),
            TextField(controller: comment, maxLines: 3, maxLength: 500,
              decoration: const InputDecoration(labelText: 'Comment (optional)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit review')),
          ],
        ),
      ),
    );
    if (submitted == true && mounted) {
      try {
        await service.submitReview(gigId: gig.id, rating: rating, comment: comment.text);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted.')));
        }
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
    comment.dispose();
  }

  Future<void> _confirmPayment(Gig gig, {required bool isWorker}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isWorker ? 'Confirm payment received?' : 'Mark gig as paid?'),
        content: Text(isWorker
            ? 'Confirm only if you have actually received the payment for this gig.'
            : 'Confirm only after you have actually paid the worker for this gig. The worker will also be asked to confirm receipt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isWorker ? 'Confirm receipt' : 'Mark as paid'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<EngagementService>().confirmGigPayment(gigId: gig.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<EngagementService>();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('gigs')
          .doc(widget.application.gigId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final gig = data == null
            ? null
            : Gig.fromMap(widget.application.gigId, data);
        if (gig == null ||
            (widget.application.status != 'accepted' &&
                widget.application.status != 'completed')) {
          return const SizedBox.shrink();
        }

        final uid = service.currentUserId;
        final isWorker = uid == widget.application.workerId;
        final confirmed =
            isWorker ? gig.workerCompletionConfirmed : gig.posterCompletionConfirmed;

        if (gig.status == 'completed') {
          final paymentConfirmed =
              isWorker ? gig.workerPaymentConfirmed : gig.posterPaymentConfirmed;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gig.paid
                      ? 'Payment confirmed by both parties • PAID'
                      : 'Payment: Poster ${gig.posterPaymentConfirmed ? 'marked paid' : 'pending'} • Worker ${gig.workerPaymentConfirmed ? 'confirmed receipt' : 'pending'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!gig.paid && isWorker && !gig.posterPaymentConfirmed)
                  const Text('Waiting for the poster to mark this gig as paid.')
                else if (!gig.paid && !paymentConfirmed)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _confirmPayment(gig, isWorker: isWorker),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(isWorker
                              ? Icons.account_balance_wallet_outlined
                              : Icons.payments_outlined),
                      label: Text(isWorker
                          ? 'Confirm payment received'
                          : 'Mark as paid'),
                    ),
                  )
                else if (!gig.paid)
                  const Text('Your confirmation is saved. Waiting for the other party.'),
                const SizedBox(height: 10),
                FutureBuilder<bool>(
                  future: service.hasReviewed(gig.id),
                  builder: (context, reviewSnapshot) {
                    if (reviewSnapshot.data == true) {
                      return const Text('Review submitted');
                    }
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _review(gig),
                        icon: const Icon(Icons.star_outline_rounded),
                        label: const Text('Leave a review'),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        if (gig.status != 'filled') return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completion: Worker ${gig.workerCompletionConfirmed ? 'confirmed' : 'waiting'} • Poster ${gig.posterCompletionConfirmed ? 'confirmed' : 'waiting'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!confirmed)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _confirm(gig),
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.task_alt_rounded),
                    label: const Text('Confirm completion'),
                  ),
                )
              else
                const Text('You confirmed completion. Waiting for the other party.'),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _GigApplicationsCard extends StatelessWidget {
  const _GigApplicationsCard({
    super.key,
    required this.gigTitle,
    required this.applications,
    required this.onTap,
    this.onDelete,
  });

  final String gigTitle;
  final List<GigApplication> applications;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = applications.where((item) => item.status == 'pending').length;
    final radius = BorderRadius.circular(18);

    // Keep the visible surface and its tap target in the same clipped Material.
    // The outer decoration owns the border and hard shadow; InkWell paints its
    // feedback on the Material instead of behind an opaque decorated Container.
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppTokens.hardShadow(scheme.outline, 3),
      ),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: scheme.outline,
            width: AppTokens.borderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gigTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${applications.length} applicants • $pending pending',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'VIEW GIG DETAILS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete completed gig',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: scheme.error,
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
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


class _ThemeAwareBottomSheet extends StatelessWidget {
  const _ThemeAwareBottomSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Modal routes capture the Theme that existed when they were opened.
    // Read platform brightness independently so an already-open sheet can
    // rebuild with the current app theme when the system theme changes.
    final theme = _themeFor(context);

    return Theme(
      data: theme,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}


ThemeData _themeFor(BuildContext context) {
  return MediaQuery.platformBrightnessOf(context) == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();
}
