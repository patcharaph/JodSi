import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/api_log.dart';
import '../../providers/providers.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/settings'),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Overview'),
            Tab(icon: Icon(Icons.list_alt_rounded), text: 'Logs'),
            Tab(icon: Icon(Icons.feedback_rounded), text: 'Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _LogsTab(),
          _FeedbackTab(),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminOverviewProvider);
    final dailyAsync = ref.watch(adminDailyStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminOverviewProvider);
        ref.invalidate(adminDailyStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overview cards
          statsAsync.when(
            data: (stats) => _OverviewCards(stats: stats),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const Gap(24),

          // Daily stats
          Text(
            'Daily Stats (Last 30 days)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(12),
          dailyAsync.when(
            data: (days) => _DailyStatsTable(days: days),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _OverviewCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          icon: Icons.api_rounded,
          label: 'Total Requests',
          value: '${stats['totalRequests']}',
          color: AppTheme.primaryColor,
        ),
        _StatCard(
          icon: Icons.error_outline_rounded,
          label: 'Errors',
          value: '${stats['errorCount']}',
          color: AppTheme.errorColor,
        ),
        _StatCard(
          icon: Icons.attach_money_rounded,
          label: 'Total Cost',
          value: '\$${(stats['totalCost'] as double).toStringAsFixed(4)}',
          color: AppTheme.successColor,
        ),
        _StatCard(
          icon: Icons.speed_rounded,
          label: 'Avg Duration',
          value: '${stats['avgDuration']}ms',
          color: Colors.blue,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const Gap(8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const Gap(2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyStatsTable extends StatelessWidget {
  final List<DailyStats> days;
  const _DailyStatsTable({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('No data yet'),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Reqs'), numeric: true),
            DataColumn(label: Text('Errors'), numeric: true),
            DataColumn(label: Text('Cost'), numeric: true),
            DataColumn(label: Text('Avg ms'), numeric: true),
            DataColumn(label: Text('Users'), numeric: true),
          ],
          rows: days.map((d) {
            final dateStr = DateFormat('MM/dd').format(d.day);
            return DataRow(cells: [
              DataCell(Text(dateStr)),
              DataCell(Text('${d.totalRequests}')),
              DataCell(Text(
                '${d.errorCount}',
                style: TextStyle(
                  color: d.errorCount > 0 ? AppTheme.errorColor : null,
                ),
              )),
              DataCell(Text('\$${d.totalCostUsd.toStringAsFixed(4)}')),
              DataCell(Text('${d.avgDurationMs}')),
              DataCell(Text('${d.uniqueUsers}')),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Logs Tab ─────────────────────────────────────────────

class _LogsTab extends ConsumerStatefulWidget {
  const _LogsTab();

  @override
  ConsumerState<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends ConsumerState<_LogsTab> {
  bool _errorsOnly = false;

  @override
  Widget build(BuildContext context) {
    final logsAsync = _errorsOnly
        ? ref.watch(adminErrorLogsProvider)
        : ref.watch(adminRecentLogsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: !_errorsOnly,
                onSelected: (_) => setState(() => _errorsOnly = false),
                selectedColor: AppTheme.primaryLight,
              ),
              const Gap(8),
              ChoiceChip(
                label: const Text('Errors Only'),
                selected: _errorsOnly,
                onSelected: (_) => setState(() => _errorsOnly = true),
                selectedColor: Colors.red.shade50,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  ref.invalidate(adminRecentLogsProvider);
                  ref.invalidate(adminErrorLogsProvider);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: logsAsync.when(
            data: (logs) => logs.isEmpty
                ? const Center(child: Text('No logs yet'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) =>
                        _LogTile(log: logs[index]),
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  final ApiLog log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('MM/dd HH:mm:ss').format(log.createdAt.toLocal());
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          log.isError ? Icons.error_rounded : Icons.check_circle_rounded,
          color: log.isError ? AppTheme.errorColor : AppTheme.successColor,
          size: 20,
        ),
        title: Text(
          log.functionName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$time  •  ${log.statusCode ?? '???'}  •  ${log.durationMs ?? 0}ms',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: log.totalCost > 0
            ? Text(
                '\$${log.totalCost.toStringAsFixed(4)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.errorMessage != null) ...[
                  _DetailRow('Error', log.errorMessage!, isError: true),
                  const Gap(4),
                ],
                if (log.noteId != null) _DetailRow('Note ID', log.noteId!),
                if (log.userId != null) _DetailRow('User ID', log.userId!),
                if (log.audioDurationSec != null)
                  _DetailRow('Audio', '${log.audioDurationSec}s'),
                if (log.transcriptChars != null)
                  _DetailRow('Transcript', '${log.transcriptChars} chars'),
                if (log.modelUsed != null)
                  _DetailRow('Model', log.modelUsed!),
                if (log.deepgramCost > 0)
                  _DetailRow(
                      'Deepgram', '\$${log.deepgramCost.toStringAsFixed(6)}'),
                if (log.openrouterCost > 0)
                  _DetailRow('OpenRouter',
                      '\$${log.openrouterCost.toStringAsFixed(6)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isError;

  const _DetailRow(this.label, this.value, {this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isError ? AppTheme.errorColor : AppTheme.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isError ? AppTheme.errorColor : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feedback Tab ─────────────────────────────────────────

class _FeedbackTab extends ConsumerWidget {
  const _FeedbackTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(adminFeedbackProvider);

    return feedbackAsync.when(
      data: (items) => items.isEmpty
          ? const Center(child: Text('No feedback yet'))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminFeedbackProvider),
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _FeedbackTile(item: items[index]),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  final FeedbackItem item;
  const _FeedbackTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('MM/dd HH:mm').format(item.createdAt.toLocal());
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _typeIcon(item.type),
        title: Text(
          item.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          '$time  •  ${item.type}  •  ${item.status}'
          '${item.rating != null ? '  •  ★${item.rating}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: _statusBadge(item.status),
      ),
    );
  }

  Widget _typeIcon(String type) {
    switch (type) {
      case 'bug':
        return const Icon(Icons.bug_report_rounded,
            color: AppTheme.errorColor, size: 24);
      case 'feature':
        return const Icon(Icons.lightbulb_rounded,
            color: AppTheme.primaryColor, size: 24);
      case 'quality':
        return const Icon(Icons.star_rounded,
            color: Colors.amber, size: 24);
      default:
        return const Icon(Icons.chat_rounded,
            color: AppTheme.textTertiary, size: 24);
    }
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'reviewed':
        color = Colors.blue;
        break;
      case 'resolved':
        color = AppTheme.successColor;
        break;
      default:
        color = AppTheme.textTertiary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
