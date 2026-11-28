import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/services/admin_access_service.dart';
import '../../data/services/admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final Future<String?> _roleFuture = AdminAccessService().getCurrentRole();
  static const modules = <(String, String, IconData, String)>[
    ('Overview', 'Platform activity and key totals', Icons.dashboard_outlined, 'overview'),
    ('User Management', 'Search accounts and manage access', Icons.people_outline, 'users'),
    ('Gig Management', 'Review and moderate posted gigs', Icons.work_outline, 'gigs'),
    ('Reports & Moderation', 'Investigate and resolve user reports', Icons.flag_outlined, 'reports'),
    ('Announcements', 'Send updates to platform users', Icons.campaign_outlined, 'announcements'),
    ('Audit Logs', 'Review administrative actions', Icons.history, 'audit_logs'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('ADMIN DASHBOARD')),
      body: FutureBuilder<String?>(
        future: _roleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final role = snapshot.data;
          if (snapshot.hasError || role == null) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('You do not have permission to access the Admin Dashboard.'),
            ));
          }
          return ListView(padding: const EdgeInsets.all(20), children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppTokens.rLg),
                border: Border.all(color: scheme.outline, width: AppTokens.borderWidth),
                boxShadow: AppTokens.hardShadow(scheme.outline, 3),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ADMIN ACCESS ACTIVE', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Signed in as ${AdminAccessService.roleLabel(role)}', style: text.bodyMedium),
                const SizedBox(height: 4),
                Text('Your available tools are determined by your protected administrator role.', style: text.bodySmall),
              ]),
            ),
            const SizedBox(height: 24),
            Text('ADMINISTRATION', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1)),
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
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AdminModuleScreen(role: role, module: module.$4, title: module.$1),
                    )),
                  ),
                ),
          ]);
        },
      ),
    );
  }
}

class AdminModuleScreen extends StatefulWidget {
  const AdminModuleScreen({required this.role, required this.module, required this.title, super.key});
  final String role;
  final String module;
  final String title;
  @override
  State<AdminModuleScreen> createState() => _AdminModuleScreenState();
}

class _AdminModuleScreenState extends State<AdminModuleScreen> {
  final _service = AdminService();
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _targetController = TextEditingController();
  String _search = '';
  String _audience = 'all';
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _dateLabel(dynamic value) {
    final d = _asDate(value);
    if (d == null) return 'Date unavailable';
    return '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _message(success);
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      SelectableText(value),
    ]),
  );

  Widget _empty(String message) => Center(child: Padding(
    padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center)));

  Widget _error(String message) => Center(child: Padding(
    padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center)));

  Widget _searchBox(String hint) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: hint, prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.isEmpty ? null : IconButton(
          onPressed: () { _searchController.clear(); setState(() => _search = ''); },
          icon: const Icon(Icons.close)),
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title.toUpperCase())),
    body: switch (widget.module) {
      'overview' => _overview(),
      'users' => _users(),
      'gigs' => _gigs(),
      'reports' => _reports(),
      'announcements' => _announcements(),
      'audit_logs' => _auditLogs(),
      _ => const Center(child: Text('Module unavailable.')),
    },
  );

  Widget _overview() => FutureBuilder<AdminOverview>(
    future: _service.loadOverview(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return _error('Could not load platform statistics. Check Firestore permissions.');
      final d = snapshot.data!;
      final items = <(String, int, IconData)>[
        ('Registered users', d.users, Icons.people_outline),
        ('Total gigs', d.gigs, Icons.work_outline),
        ('Open gigs', d.openGigs, Icons.work_history_outlined),
        ('Reports received', d.reports, Icons.flag_outlined),
        ('Open reports', d.pendingReports, Icons.pending_actions),
      ];
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('PLATFORM SNAPSHOT', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final item in items)
          Card(child: ListTile(
            leading: Icon(item.$3), title: Text(item.$1),
            trailing: Text('${item.$2}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          )),
        const SizedBox(height: 12),
        Text('Live counts from the current Firestore records.', style: Theme.of(context).textTheme.bodySmall),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: () => setState(() {}), icon: const Icon(Icons.refresh), label: const Text('Refresh statistics'))),
      ]);
    },
  );

  Widget _users() => Column(children: [
    _searchBox('Search name, email or user ID'),
    Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _error('Could not load users. Check the admin role and Firestore rules.');
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final d = doc.data();
          return '${d['fullName'] ?? ''} ${d['email'] ?? ''} ${doc.id}'.toLowerCase().contains(_search);
        }).toList();
        if (docs.isEmpty) return _empty('No matching user accounts.');
        return ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          itemCount: docs.length, itemBuilder: (context, i) {
            final doc = docs[i]; final d = doc.data();
            final name = d['fullName'] as String? ?? 'Unnamed user';
            final suspended = d['accountStatus'] == 'suspended';
            return Card(child: ListTile(
              leading: CircleAvatar(child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase())),
              title: Text(name),
              subtitle: Text('${d['email'] ?? 'No email'}\n${doc.id}', maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: Icon(suspended ? Icons.block : Icons.chevron_right,
                color: suspended ? Theme.of(context).colorScheme.error : null),
              onTap: () => _showUser(doc),
            ));
          });
      },
    )),
  ]);

  Future<void> _showUser(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final suspended = d['accountStatus'] == 'suspended';
    final reason = await _textDialog(
      title: d['fullName'] as String? ?? 'User account',
      initial: d['suspensionReason'] as String? ?? '',
      content: [
        _detail('Email', d['email'] as String? ?? '—'),
        _detail('User ID', doc.id),
        _detail('Location', d['location'] as String? ?? '—'),
        _detail('Roles', (d['roles'] as List?)?.join(', ') ?? '—'),
        _detail('Joined', _dateLabel(d['createdAt'])),
        _detail('Account status', suspended ? 'Suspended' : 'Active'),
      ],
      actionLabel: suspended ? 'Restore account' : 'Suspend account',
      destructive: !suspended,
    );
    if (reason == null) return;
    await _run(() => _service.setUserSuspended(
      userId: doc.id, suspended: !suspended, reason: reason),
      suspended ? 'User account restored.' : 'User account suspended.');
  }

  Widget _gigs() => Column(children: [
    _searchBox('Search gig title, category, poster or ID'),
    Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchGigs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _error('Could not load gigs.');
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final d = doc.data();
          return '${d['title'] ?? ''} ${d['category'] ?? ''} ${d['posterName'] ?? ''} ${doc.id}'.toLowerCase().contains(_search);
        }).toList();
        if (docs.isEmpty) return _empty('No matching gigs.');
        return ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          itemCount: docs.length, itemBuilder: (context, i) {
            final doc = docs[i]; final d = doc.data();
            return Card(child: ListTile(
              title: Text(d['title'] as String? ?? 'Untitled gig'),
              subtitle: Text('${d['category'] ?? 'Uncategorised'} · ₦${d['pay'] ?? 0}\n${d['posterName'] ?? 'Poster'} · ${d['status'] ?? 'unknown'}'),
              isThreeLine: true, trailing: const Icon(Icons.chevron_right),
              onTap: () => _showGig(doc),
            ));
          });
      },
    )),
  ]);

  Future<void> _showGig(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data(); final status = d['status'] as String? ?? 'unknown';
    final note = await _textDialog(
      title: d['title'] as String? ?? 'Gig details',
      content: [
        _detail('Gig ID', doc.id),
        _detail('Poster', d['posterName'] as String? ?? '—'),
        _detail('Poster ID', d['posterId'] as String? ?? '—'),
        _detail('Category', d['category'] as String? ?? '—'),
        _detail('Pay', '₦${d['pay'] ?? 0}'),
        _detail('Location', d['location'] as String? ?? '—'),
        _detail('Status', status),
        _detail('Description', d['description'] as String? ?? '—'),
      ],
      actionLabel: status == 'open' ? 'Close gig' : 'Remove gig',
      destructive: true,
    );
    if (note == null) return;
    final remove = status != 'open';
    await _run(() => _service.moderateGig(gigId: doc.id, remove: remove, note: note),
      remove ? 'Gig removed from the marketplace.' : 'Gig closed.');
  }

  Widget _reports() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _service.watchReports(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return _error('Could not load reports. Check admin read permissions.');
      final docs = (snapshot.data?.docs ?? []).where((doc) {
        final d = doc.data();
        return '${d['reason'] ?? ''} ${d['targetType'] ?? ''} ${d['targetId'] ?? ''} ${d['details'] ?? ''} ${d['status'] ?? ''}'.toLowerCase().contains(_search);
      }).toList();
      if (docs.isEmpty) return _empty('No reports have been submitted.');
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: docs.length,
        itemBuilder: (context, i) {
          final doc = docs[i]; final d = doc.data();
          return Card(child: ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text('${(d['reason'] as String? ?? 'other').toUpperCase()} · ${d['targetType'] ?? 'target'}'),
            subtitle: Text('Target: ${d['targetId'] ?? '—'}\n${d['status'] ?? 'open'} · ${_dateLabel(d['createdAt'])}'),
            isThreeLine: true, trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReport(doc),
          ));
        });
    },
  );

  Future<void> _showReport(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    String status = d['status'] as String? ?? 'open';
    final noteController = TextEditingController(text: d['resolutionNote'] as String? ?? '');
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Review report'),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detail('Report ID', doc.id),
            _detail('Reporter', d['reporterId'] as String? ?? '—'),
            _detail('Target', '${d['targetType'] ?? '—'} · ${d['targetId'] ?? '—'}'),
            _detail('Reason', d['reason'] as String? ?? '—'),
            _detail('Submitted', _dateLabel(d['createdAt'])),
            _detail('Details', d['details'] as String? ?? '—'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(labelText: 'Report status', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'under_review', child: Text('Under review')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
              ],
              onChanged: (v) { if (v != null) setDialogState(() => status = v); },
            ),
            const SizedBox(height: 12),
            TextField(controller: noteController, maxLines: 3, maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Resolution note', border: OutlineInputBorder())),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, (status, noteController.text.trim())),
            child: const Text('Save review')),
        ],
      )),
    );
    noteController.dispose();
    if (result == null) return;
    await _run(() => _service.reviewReport(
      reportId: doc.id, status: result.$1, resolutionNote: result.$2), 'Report updated.');
  }

  Future<String?> _textDialog({
    required String title,
    required List<Widget> content,
    required String actionLabel,
    bool destructive = false,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...content,
            const SizedBox(height: 12),
            TextField(controller: controller, maxLines: 3, maxLength: 500,
              decoration: const InputDecoration(labelText: 'Reason / moderation note', border: OutlineInputBorder())),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error) : null,
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _announcements() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('SEND ANNOUNCEMENT', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 12),
    TextField(controller: _titleController, maxLength: 100,
      decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _bodyController, maxLength: 1000, maxLines: 5,
      decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true, border: OutlineInputBorder())),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      value: _audience,
      decoration: const InputDecoration(labelText: 'Audience', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All users')),
        DropdownMenuItem(value: 'workers', child: Text('Workers')),
        DropdownMenuItem(value: 'posters', child: Text('Posters')),
        DropdownMenuItem(value: 'user', child: Text('One specific user')),
      ],
      onChanged: _busy ? null : (v) => setState(() => _audience = v ?? 'all'),
    ),
    if (_audience == 'user') ...[
      const SizedBox(height: 12),
      TextField(controller: _targetController,
        decoration: const InputDecoration(labelText: 'Recipient user ID', border: OutlineInputBorder())),
    ],
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: _busy ? null : _sendAnnouncement,
      icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
      label: Text(_busy ? 'Sending...' : 'Send announcement'),
    ),
    const Divider(height: 32),
    Text('RECENT ANNOUNCEMENTS', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Announcement history is unavailable. Check admin read permissions.');
        if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Text('No announcements sent yet.');
        return Column(children: docs.map((doc) {
          final d = doc.data();
          return Card(child: ListTile(
            title: Text(d['title'] as String? ?? 'Announcement'),
            subtitle: Text('${d['audience'] ?? 'all'} · ${d['recipientCount'] ?? 0} recipients · ${_dateLabel(d['createdAt'])}\n${d['body'] ?? ''}'),
            isThreeLine: true,
          ));
        }).toList());
      },
    ),
  ]);

  Future<void> _sendAnnouncement() async {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
      _message('Enter both a title and a message.'); return;
    }
    if (_audience == 'user' && _targetController.text.trim().isEmpty) {
      _message('Enter the recipient user ID.'); return;
    }
    await _run(() async {
      final result = await _service.sendAnnouncement(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        audience: _audience,
        targetUserId: _targetController.text.trim(),
      );
      _titleController.clear(); _bodyController.clear(); _targetController.clear();
      _message('Announcement sent to ${result['recipients'] ?? 0} users.');
    }, 'Announcement sent.');
  }

  Widget _auditLogs() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _service.watchAuditLogs(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return _error('Could not load audit logs. Check admin permissions.');
      final docs = snapshot.data?.docs ?? [];
      if (docs.isEmpty) return _empty('No administrative actions have been recorded yet.');
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: docs.length,
        itemBuilder: (context, i) {
          final d = docs[i].data();
          final action = (d['action'] as String? ?? 'admin_action').replaceAll('_', ' ').toUpperCase();
          return Card(child: ListTile(
            leading: const Icon(Icons.history),
            title: Text(action),
            subtitle: Text('${d['actorRole'] ?? 'Admin'} · ${d['actorId'] ?? '—'}\n${d['targetType'] ?? 'target'}: ${d['targetId'] ?? '—'} · ${_dateLabel(d['createdAt'])}\n${d['details'] ?? ''}'),
            isThreeLine: true,
          ));
        });
    },
  );
}
