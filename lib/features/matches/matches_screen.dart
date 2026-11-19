
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
    final colors = context.appColors;
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      gigTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '${applications.length} ${applications.length == 1 ? 'APPLICANT' : 'APPLICANTS'}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...applications.map(
                (application) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ApplicationCard(
                    application: application,
                    showWorkerName: true,
                  ),
                ),
              ),
            ],
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
