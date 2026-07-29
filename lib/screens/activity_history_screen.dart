import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../db/activity_db_helper.dart';
import '../models/activity_log.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/responsive.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';

/// Read-only audit feed of every data change in the app, newest first,
/// grouped by day. Opened from Settings.
class ActivityHistoryScreen extends StatefulWidget {
  static const routeName = '/activity-history';

  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  late Future<List<ActivityLog>> _future;

  @override
  void initState() {
    super.initState();
    _future = ActivityDBHelper().getAll();
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>();
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Activity'),
        elevation: 0,
      ),
      body: FutureBuilder<List<ActivityLog>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data ?? const <ActivityLog>[];
          if (logs.isEmpty) return _buildEmptyState(context);

          final groups = _groupByDay(logs);
          return context.constrainedContent(ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final group = groups[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 8 : 22, bottom: 10),
                    child: Text(
                      group.label,
                      style: AppTextStyles.caption.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...group.entries.map(
                    (log) => _buildTile(context, log, currency),
                  ),
                ],
              );
            },
          ));
        },
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, ActivityLog log, SettingsProvider currency) {
    final color = _actionColor(log.action);
    final amountText = log.amount == null
        ? null
        : UtilityFunction.formatMoney(
            log.amount!,
            symbol: currency.currencySymbol,
            currencyCode: currency.currencyCode,
            showDecimals: true,
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: context.textSecondary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(log.entity.icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    // "Added · Transaction" style action tag.
                    Text(
                      '${log.action.label} · ${log.entity.label}',
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '  ·  ${UtilityFunction.formatTime(log.timestamp)}',
                      style: AppTextStyles.caption.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (amountText != null) ...[
            const SizedBox(width: 10),
            Text(
              amountText,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded,
              size: 72, color: context.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: AppTextStyles.h3.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Changes you make — transactions, transfers, accounts, '
              'categories, budgets and goals — will show up here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _actionColor(ActivityAction action) {
    switch (action) {
      case ActivityAction.created:
        return AppColors.positive;
      case ActivityAction.updated:
        return AppColors.accentBlue;
      case ActivityAction.deleted:
        return AppColors.negative;
    }
  }

  List<_DayGroup> _groupByDay(List<ActivityLog> logs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <_DayGroup>[];
    String? currentKey;
    for (final log in logs) {
      final d = DateTime(
          log.timestamp.year, log.timestamp.month, log.timestamp.day);
      final key = d.toIso8601String();
      if (key != currentKey) {
        currentKey = key;
        String label;
        if (d == today) {
          label = 'TODAY';
        } else if (d == yesterday) {
          label = 'YESTERDAY';
        } else {
          label = UtilityFunction.formatDate(log.timestamp).toUpperCase();
        }
        groups.add(_DayGroup(label));
      }
      groups.last.entries.add(log);
    }
    return groups;
  }
}

class _DayGroup {
  final String label;
  final List<ActivityLog> entries = [];
  _DayGroup(this.label);
}
