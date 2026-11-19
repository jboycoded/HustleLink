
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/gig_application.dart';
import 'matches_view_model.dart';

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
    } else if (vm.applicationCount == 0) {
      body = _EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No applications yet.',
        message: vm.isPosterMode
            ? 'Applications from workers will appear here when they apply to your gigs.'
            : 'Gigs you apply for will appear here so you can track their status.',
      );
    } else if (vm.isPosterMode) {
      body = _buildPosterApplications(context, vm);
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
                    '${vm.applicationCount} PENDING',
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
        itemCount: vm.workerApplications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final application = vm.workerApplications[index];

          return _ApplicationCard(
            application: application,
            showWorkerName: false,
          );
        },
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
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
                      color: Theme.of(sheetContext).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  gigTitle,
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${applications.length} applicants',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: applications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final application = applications[index];
                      final initials = application.workerName
                          .trim()
                          .split(RegExp(r'\\s+'))
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
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSecondary,
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
    );
  }

  Future<void> _showApplicantDetails(
    BuildContext context,
    GigApplication application,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
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
                      color: Theme.of(sheetContext).colorScheme.outlineVariant,
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
                          Theme.of(sheetContext).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(sheetContext).colorScheme.onSecondary,
                      child: Text(
                        application.workerName
                            .trim()
                            .split(RegExp(r'\\s+'))
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
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text('Worker applicant'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'APPLICATION DETAILS',
                  style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
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
                else if (application.status == 'accepted')
                  const Text(
                    'This application has been accepted. Chat access will be available once conversations are enabled.',
                  ),
              ],
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

  Widget _buildPosterApplications(
    BuildContext context,
    MatchesViewModel vm,
  ) {
    final groups = vm.posterApplicationsByGig.entries.toList();

    return RefreshIndicator(
      onRefresh: vm.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final entry = groups[index];
          final applications = entry.value;
          final gigTitle = applications.first.gigTitle;

          return _GigApplicationsCard(
            gigTitle: gigTitle,
            applications: applications,
            onTap: () => _showGigApplicants(context, gigTitle, applications),
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
              Expanded(
                child: Text(
                  showWorkerName ? application.workerName : application.gigTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
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
    required this.gigTitle,
    required this.applications,
    required this.onTap,
  });

  final String gigTitle;
  final List<GigApplication> applications;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = applications.where((item) => item.status == 'pending').length;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outline,
              width: AppTokens.borderWidth,
            ),
            boxShadow: AppTokens.hardShadow(scheme.outline, 3),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gigTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${applications.length} applicants • $pending pending',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'VIEW APPLICANTS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: scheme.secondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
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
