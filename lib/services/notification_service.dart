import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService extends ChangeNotifier {
  final SupabaseClient _client;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  RealtimeChannel? _channel;

  /// Callback for when a settlement-related notification arrives in realtime.
  /// Receives the notification map; the registrant handles bill creation + balance refresh.
  void Function(Map<String, dynamic> notification)? onSettlementNotification;

  NotificationService(this._client);

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> loadNotifications({String? householdId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      var query = _client
          .from('notifications')
          .select()
          .eq('recipient_user_id', userId);
      if (householdId != null) {
        query = query.eq('household_id', householdId);
      }
      _notifications = await query
          .order('created_at', ascending: false)
          .limit(50);
      _unreadCount = _notifications.where((n) => n['read'] == false).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    }
  }

  void subscribeToRealtime() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    _channel = _client.channel('notifications:$userId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_user_id',
            value: userId,
          ),
          callback: (payload) {
            final newNotification = payload.newRecord;
            _notifications.insert(0, newNotification);
            _unreadCount++;
            notifyListeners();

            // Auto-process settlement confirmations in realtime
            final type = newNotification['type'] as String?;
            if (type == 'settlement_confirmed' && onSettlementNotification != null) {
              onSettlementNotification!(newNotification);
            }
          },
        )
        .subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  Future<void> sendNotification({
    String? householdId,
    required String recipientUserId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    await _client.from('notifications').insert({
      'household_id': householdId,
      'recipient_user_id': recipientUserId,
      'sender_user_id': senderId,
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? {},
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read': true}).eq('id', notificationId);
    final idx =
        _notifications.indexWhere((n) => n['id'] == notificationId);
    if (idx != -1 && _notifications[idx]['read'] == false) {
      _notifications[idx] = {..._notifications[idx], 'read': true};
      _unreadCount--;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead({String? householdId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    var query = _client
        .from('notifications')
        .update({'read': true})
        .eq('recipient_user_id', userId)
        .eq('read', false);
    if (householdId != null) {
      query = query.eq('household_id', householdId);
    }
    await query;
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = {..._notifications[i], 'read': true};
    }
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _client.from('notifications').delete().eq('id', notificationId);
    _notifications.removeWhere((n) => n['id'] == notificationId);
    _unreadCount = _notifications.where((n) => n['read'] == false).length;
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}
