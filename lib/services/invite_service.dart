import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteService {
  final SupabaseClient _client;
  static final _random = Random.secure();

  InviteService(this._client);

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(8, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  Future<Map<String, dynamic>> createInvite({
    required String householdId,
    String? memberId,
    String? email,
    String? phone,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final code = _generateCode();
    final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 24));

    final result = await _client.from('household_invites').insert({
      'household_id': householdId,
      'invited_by_user_id': userId,
      'invite_code': code,
      'member_id': memberId,
      'invited_email': email,
      'invited_phone': phone,
      'expires_at': expiresAt.toIso8601String(),
    }).select().single();

    return result;
  }

  Future<Map<String, dynamic>?> getInviteByCode(String code) async {
    final result = await _client
        .from('household_invites')
        .select('*, households(name)')
        .eq('invite_code', code.toUpperCase())
        .isFilter('claimed_by_user_id', null)
        .maybeSingle();
    return result;
  }

  Future<bool> claimInvite(String inviteId) async {
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now().toUtc();

    final invite = await _client.from('household_invites')
        .select()
        .eq('id', inviteId)
        .single();

    final expiresAt = DateTime.parse(invite['expires_at'] as String);
    if (now.isAfter(expiresAt)) return false;
    if (invite['claimed_by_user_id'] != null) return false;

    final householdId = invite['household_id'] as String;
    final memberId = invite['member_id'] as String?;

    if (memberId != null) {
      await _client.from('members').update({
        'user_id': userId,
      }).eq('id', memberId);
    } else {
      final profile = await _client.from('profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      final name = profile?['display_name'] ?? 'New Member';
      await _client.from('members').insert({
        'household_id': householdId,
        'user_id': userId,
        'name': name,
      });
    }

    await _client.from('household_invites').update({
      'claimed_by_user_id': userId,
      'claimed_at': now.toIso8601String(),
    }).eq('id', inviteId);

    return true;
  }

  Future<List<Map<String, dynamic>>> getHouseholdInvites(String householdId) async {
    return await _client
        .from('household_invites')
        .select()
        .eq('household_id', householdId)
        .order('created_at', ascending: false);
  }

  Future<void> revokeInvite(String inviteId) async {
    await _client.from('household_invites').delete().eq('id', inviteId);
  }
}
