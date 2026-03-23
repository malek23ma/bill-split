import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRepository {
  final SupabaseClient _client;

  SupabaseRepository(this._client);

  // ─── Households ───

  Future<Map<String, dynamic>> upsertHousehold(Map<String, dynamic> data) async {
    final result = await _client.from('households').upsert(data).select().single();
    return result;
  }

  Future<List<Map<String, dynamic>>> getHouseholdsSince(DateTime since) async {
    return await _client
        .from('households')
        .select()
        .gt('updated_at', since.toIso8601String())
        .order('updated_at');
  }

  Future<List<Map<String, dynamic>>> getHouseholdsForUser() async {
    // Get households where the current user is a member
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final memberRows = await _client
        .from('members')
        .select('household_id')
        .eq('user_id', userId)
        .isFilter('deleted_at', null);
    final householdIds = memberRows.map((r) => r['household_id'] as String).toList();
    if (householdIds.isEmpty) return [];
    return await _client
        .from('households')
        .select()
        .inFilter('id', householdIds)
        .isFilter('deleted_at', null);
  }

  // ─── Members ───

  Future<Map<String, dynamic>> upsertMember(Map<String, dynamic> data) async {
    final result = await _client.from('members').upsert(data).select().single();
    return result;
  }

  Future<List<Map<String, dynamic>>> getMembersSince(String householdId, DateTime since) async {
    return await _client
        .from('members')
        .select()
        .eq('household_id', householdId)
        .gt('updated_at', since.toIso8601String())
        .order('updated_at');
  }

  // ─── Bills ───

  Future<Map<String, dynamic>> upsertBill(Map<String, dynamic> data) async {
    final result = await _client.from('bills').upsert(data).select().single();
    return result;
  }

  Future<List<Map<String, dynamic>>> getBillsSince(String householdId, DateTime since) async {
    return await _client
        .from('bills')
        .select()
        .eq('household_id', householdId)
        .gt('updated_at', since.toIso8601String())
        .order('updated_at');
  }

  // ─── Bill Items ───

  Future<Map<String, dynamic>> upsertBillItem(Map<String, dynamic> data) async {
    final result = await _client.from('bill_items').upsert(data).select().single();
    return result;
  }

  Future<List<Map<String, dynamic>>> getBillItemsSince(String billId, DateTime since) async {
    return await _client
        .from('bill_items')
        .select()
        .eq('bill_id', billId)
        .gt('updated_at', since.toIso8601String())
        .order('updated_at');
  }

  Future<List<Map<String, dynamic>>> getBillItemsForBill(String billId) async {
    return await _client
        .from('bill_items')
        .select()
        .eq('bill_id', billId)
        .isFilter('deleted_at', null);
  }

  // ─── Bill Item Members ───

  Future<Map<String, dynamic>> upsertBillItemMember(Map<String, dynamic> data) async {
    final result = await _client.from('bill_item_members').upsert(data).select().single();
    return result;
  }

  Future<List<Map<String, dynamic>>> getBillItemMembersForItem(String billItemId) async {
    return await _client
        .from('bill_item_members')
        .select()
        .eq('bill_item_id', billItemId)
        .isFilter('deleted_at', null);
  }

  // ─── Recurring Bills ───

  Future<Map<String, dynamic>> upsertRecurringBill(Map<String, dynamic> data) async {
    final result = await _client.from('recurring_bills').upsert(data).select().single();
    return result;
  }

  Future<List<Map<String, dynamic>>> getRecurringBillsSince(String householdId, DateTime since) async {
    return await _client
        .from('recurring_bills')
        .select()
        .eq('household_id', householdId)
        .gt('updated_at', since.toIso8601String())
        .order('updated_at');
  }

  // ─── Receipt Storage ───

  Future<String> uploadReceipt(String householdId, String billId, Uint8List bytes) async {
    final path = '$householdId/$billId.jpg';
    await _client.storage.from('receipts').uploadBinary(path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    return _client.storage.from('receipts').getPublicUrl(path);
  }

  Future<void> deleteReceipt(String householdId, String billId) async {
    final path = '$householdId/$billId.jpg';
    await _client.storage.from('receipts').remove([path]);
  }

  // ─── Sync Log ───

  Future<DateTime> getSyncTimestamp(String deviceId, String householdId) async {
    final result = await _client
        .from('sync_log')
        .select('last_synced_at')
        .eq('device_id', deviceId)
        .eq('household_id', householdId)
        .maybeSingle();
    if (result == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.parse(result['last_synced_at'] as String);
  }

  Future<void> updateSyncTimestamp(String deviceId, String householdId) async {
    await _client.from('sync_log').upsert({
      'device_id': deviceId,
      'household_id': householdId,
      'last_synced_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'device_id,household_id');
  }

  // ─── Soft Delete ───

  Future<void> softDelete(String table, String id) async {
    await _client.from(table).update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
