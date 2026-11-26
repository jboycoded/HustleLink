import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/services/admin_access_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('ADMIN DASHBOARD')),
      body: FutureBuilder<String?>(
        future: AdminAccessService().getCurrentRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final role = snapshot.data;
          if (role == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('You do not have permission to access the Admin Dashboard.'),
              ),
            );
          }

          final modules = <(String, String, IconData, String)>[
            ('Overview', 'Platform activity and key totals', Icons.dashboard_outlined, 'overview'),
            ('User Management', 'Review accounts and account status', Icons.people_outline, 'users'),
            ('Gig Management', 'Review and moderate posted gigs', Icons.work_outline, 'gigs'),
            ('Reports', 'Review reports submitted by users', Icons.flag_outlined, 'reports'),
            ('Announcements', 'Send platform-wide updates', Icons.campaign_outlined, 'announcements'),
            ('Audit Logs', 'Review administrative activity', Icons.history, 'audit_logs'),
          ];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppTokens.rLg),
                  border: Border.all(color: scheme.outline, width: AppTokens.borderWidth),
                  boxShadow: AppTokens.hardShadow(scheme.outline, 3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ADMIN ACCESS ACTIVE', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Signed in as ${AdminAccessService.roleLabel(role)}', style: text.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Administrative permissions are checked against your protected account record.', style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('PHASE 1 MODULES', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 12),
              for (final module in modules)
                if (AdminAccessService.canAccess(role, module.$4))
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(module.$3),
                      title: Text(module.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(module.$2),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${module.$1} will be implemented in the next dashboard step.')),
                        );
                      },
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
