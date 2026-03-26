import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';

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

    // Get display name from auth metadata (always available) or profiles table
    final authUser = _client.auth.currentUser!;
    final displayName = authUser.userMetadata?['display_name'] as String?;
    String name = displayName ?? 'New Member';
    if (name == 'New Member') {
      final profile = await _client.from('profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      name = profile?['display_name'] as String? ?? name;
    }

    if (memberId != null) {
      await _client.from('members').update({
        'user_id': userId,
        'name': name,
      }).eq('id', memberId);
    } else {
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

    // Create household locally if it doesn't exist, then pull ALL members
    final db = await DatabaseHelper.instance.database;
    var localHouseholds = await db.query('households',
        where: 'remote_id = ?', whereArgs: [householdId]);

    int localHouseholdId;
    if (localHouseholds.isEmpty) {
      // Fetch household details from cloud and create locally
      final hData = await _client.from('households')
          .select('name, currency')
          .eq('id', householdId)
          .maybeSingle();
      localHouseholdId = await db.insert('households', {
        'name': hData?['name'] ?? 'Household',
        'currency': hData?['currency'] ?? 'TRY',
        'created_at': DateTime.now().toIso8601String(),
        'remote_id': householdId,
      });
    } else {
      localHouseholdId = localHouseholds.first['id'] as int;
    }

    // Pull ALL members of this household from cloud
    final allMembers = await _client.from('members')
        .select('id, name, is_admin, is_active, user_id, created_at')
        .eq('household_id', householdId);

    for (final m in allMembers) {
      final mRemoteId = m['id'] as String;
      final existing = await db.query('members',
          where: 'remote_id = ?', whereArgs: [mRemoteId]);
      if (existing.isEmpty) {
        await db.insert('members', {
          'household_id': localHouseholdId,
          'name': m['name'],
          'is_admin': (m['is_admin'] == true) ? 1 : 0,
          'is_active': (m['is_active'] == true) ? 1 : 0,
          'user_id': m['user_id'],
          'remote_id': mRemoteId,
          'created_at': m['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        });
      } else {
        // Update existing with latest data
        await db.update('members', {
          'name': m['name'],
          'user_id': m['user_id'],
          'remote_id': mRemoteId,
        }, where: 'id = ?', whereArgs: [existing.first['id']]);
      }
    }

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
