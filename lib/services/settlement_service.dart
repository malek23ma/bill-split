import 'package:supabase_flutter/supabase_flutter.dart';

class SettlementService {
  final SupabaseClient _client;

  SettlementService(this._client);

  Future<Map<String, dynamic>> createSettlement({
    required String householdId,
    required String fromMemberId,
    required String toMemberId,
    required double amount,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final result = await _client.from('settlements').insert({
      'household_id': householdId,
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
      'status': 'pending',
      'created_by_user_id': userId,
    }).select().single();
    return result;
  }

  Future<void> confirmSettlement(String settlementId) async {
    await _client.from('settlements').update({
      'status': 'confirmed',
      'confirmed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', settlementId);
  }

  Future<void> rejectSettlement(String settlementId) async {
    await _client.from('settlements').update({
      'status': 'rejected',
      'rejected_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', settlementId);
  }

  Future<List<Map<String, dynamic>>> getPendingSettlements(String householdId) async {
    return await _client
        .from('settlements')
        .select()
        .eq('household_id', householdId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getSettlements(String householdId) async {
    return await _client
        .from('settlements')
        .select()
        .eq('household_id', householdId)
        .order('created_at', ascending: false);
  }
}
