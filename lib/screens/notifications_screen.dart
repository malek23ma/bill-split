import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';
import '../database/database_helper.dart';
import '../providers/bill_provider.dart';
import '../providers/household_provider.dart';
import '../services/notification_service.dart';
import '../services/settlement_service.dart';

String _timeAgo(String isoDate) {
  final date = DateTime.parse(isoDate);
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.day}/${date.month}/${date.year}';
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    // Reload notifications fresh each time this screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final householdRemoteId = context.read<HouseholdProvider>().currentHousehold?.remoteId;
      final svc = context.read<NotificationService>();
      svc.loadNotifications(householdId: householdRemoteId);
      svc.subscribeToRealtime();
    });
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'settlement_request':
      case 'settlement_confirmed':
      case 'settlement_rejected':
        return Icons.handshake_rounded;
      case 'admin_bill_delete':
        return Icons.delete_rounded;
      case 'invite':
      case 'member_joined':
        return Icons.group_add_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _iconColorForType(String type, bool isDark) {
    switch (type) {
      case 'settlement_request':
      case 'settlement_confirmed':
        return AppColors.positive;
      case 'settlement_rejected':
      case 'admin_bill_delete':
        return AppColors.negative;
      case 'invite':
      case 'member_joined':
        return AppColors.primary;
      default:
        return isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    }
  }

  Future<void> _confirmSettlement(
    Map<String, dynamic> notification,
    NotificationService notificationService,
  ) async {
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final settlementId = data['settlement_id'] as String?;
    if (settlementId == null) return;

    setState(() => _processingIds.add(notification['id']));
    try {
      // Mark settlement as confirmed in cloud
      await context.read<SettlementService>().confirmSettlement(settlementId);

      // Fetch the settlement details to get amount and member IDs
      final settlement = await Supabase.instance.client
          .from('settlements')
          .select()
          .eq('id', settlementId)
          .single();

      final amount = (settlement['amount'] as num).toDouble();
      final fromMemberRemoteId = settlement['from_member_id'] as String;
      final toMemberRemoteId = settlement['to_member_id'] as String;

      // Look up local member IDs from remote IDs
      final db = await DatabaseHelper.instance.database;
      final fromRows = await db.query('members',
          where: 'remote_id = ?', whereArgs: [fromMemberRemoteId]);
      final toRows = await db.query('members',
          where: 'remote_id = ?', whereArgs: [toMemberRemoteId]);

      if (fromRows.isNotEmpty && toRows.isNotEmpty) {
        final fromLocalId = fromRows.first['id'] as int;
        final toLocalId = toRows.first['id'] as int;
        final householdId = fromRows.first['household_id'] as int;

        // Create the actual settlement bill locally — this updates balances
        if (!mounted) return;
        final billProvider = context.read<BillProvider>();
        await billProvider.settleUp(
          householdId: householdId,
          payerMemberId: fromLocalId,
          receiverMemberId: toLocalId,
          amount: amount,
        );
      }

      await notificationService.markAsRead(notification['id']);

      // Send confirmation notification back to the requester
      final senderUserId = notification['sender_user_id'] as String?;
      if (senderUserId != null) {
        await notificationService.sendNotification(
          householdId: notification['household_id'],
          recipientUserId: senderUserId,
          type: 'settlement_confirmed',
          title: 'Settlement Confirmed',
          body: 'Your settlement of ${amount.toStringAsFixed(2)} has been confirmed.',
          data: {'settlement_id': settlementId, 'amount': amount},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement confirmed — balances updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(notification['id']));
    }
  }

  Future<void> _rejectSettlement(
    Map<String, dynamic> notification,
    NotificationService notificationService,
  ) async {
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final settlementId = data['settlement_id'] as String?;
    if (settlementId == null) return;

    setState(() => _processingIds.add(notification['id']));
    try {
      await context.read<SettlementService>().rejectSettlement(settlementId);
      await notificationService.markAsRead(notification['id']);

      final senderUserId = notification['sender_user_id'] as String?;
      if (senderUserId != null) {
        await notificationService.sendNotification(
          householdId: notification['household_id'],
          recipientUserId: senderUserId,
          type: 'settlement_rejected',
          title: 'Settlement Rejected',
          body: 'Your settlement request has been rejected.',
          data: {'settlement_id': settlementId},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(notification['id']));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationService = context.watch<NotificationService>();
    final notifications = notificationService.notifications;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: AppScale.fontSize(18),
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.done_all_rounded,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              size: AppScale.size(22),
            ),
            tooltip: 'Mark all read',
            onPressed: () {
              final householdRemoteId = context.read<HouseholdProvider>().currentHousehold?.remoteId;
              notificationService.markAllAsRead(householdId: householdRemoteId);
            },
          ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: EdgeInsets.symmetric(
                vertical: AppScale.padding(AppSpacing.sm),
              ),
              itemCount: notifications.length,
              itemBuilder: (context, index) =>
                  _buildNotificationCard(notifications[index], isDark, notificationService),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: AppScale.size(64),
            color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
          ),
          SizedBox(height: AppScale.padding(AppSpacing.lg)),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: AppScale.fontSize(16),
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
    bool isDark,
    NotificationService notificationService,
  ) {
    final id = notification['id'] as String;
    final type = notification['type'] as String? ?? '';
    final title = notification['title'] as String? ?? '';
    final body = notification['body'] as String? ?? '';
    final createdAt = notification['created_at'] as String? ?? '';
    final isRead = notification['read'] == true;
    final isSettlementRequest = type == 'settlement_request';
    final isProcessing = _processingIds.contains(id);

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: AppScale.padding(AppSpacing.xl)),
        color: AppColors.negative,
        child: Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: AppScale.size(24),
        ),
      ),
      onDismissed: (_) => notificationService.deleteNotification(id),
      child: GestureDetector(
        onTap: isSettlementRequest
            ? null
            : () {
                if (!isRead) notificationService.markAsRead(id);
              },
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: AppScale.padding(AppSpacing.lg),
            vertical: AppScale.padding(AppSpacing.xs),
          ),
          padding: EdgeInsets.all(AppScale.padding(AppSpacing.md)),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: AppScale.size(40),
                height: AppScale.size(40),
                decoration: BoxDecoration(
                  color: _iconColorForType(type, isDark).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  _iconForType(type),
                  color: _iconColorForType(type, isDark),
                  size: AppScale.size(20),
                ),
              ),
              SizedBox(width: AppScale.padding(AppSpacing.md)),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: AppScale.fontSize(14),
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: AppScale.size(8),
                            height: AppScale.size(8),
                            margin: EdgeInsets.only(
                              left: AppScale.padding(AppSpacing.sm),
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: AppScale.padding(AppSpacing.xs)),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: AppScale.fontSize(13),
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppScale.padding(AppSpacing.xs)),
                    Text(
                      createdAt.isNotEmpty ? _timeAgo(createdAt) : '',
                      style: TextStyle(
                        fontSize: AppScale.fontSize(11),
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textTertiary,
                      ),
                    ),
                    // Settlement action buttons
                    if (isSettlementRequest && !isRead) ...[
                      SizedBox(height: AppScale.padding(AppSpacing.sm)),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => _confirmSettlement(
                                        notification,
                                        notificationService,
                                      ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.positive,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: AppScale.padding(AppSpacing.sm),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                              ),
                              child: isProcessing
                                  ? SizedBox(
                                      width: AppScale.size(16),
                                      height: AppScale.size(16),
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Confirm',
                                      style: TextStyle(
                                        fontSize: AppScale.fontSize(13),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(width: AppScale.padding(AppSpacing.sm)),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => _rejectSettlement(
                                        notification,
                                        notificationService,
                                      ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.negative,
                                side: const BorderSide(
                                  color: AppColors.negative,
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: AppScale.padding(AppSpacing.sm),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                              ),
                              child: Text(
                                'Reject',
                                style: TextStyle(
                                  fontSize: AppScale.fontSize(13),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
