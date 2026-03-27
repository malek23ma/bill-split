import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/bill.dart';
import '../models/bill_filter.dart';
import '../services/image_compress_service.dart';
import '../models/bill_item.dart';
import '../models/member.dart';

class MonthlySummary {
  final int billCount;
  final Map<int, double> memberSpend; // memberId -> total spent
  final String monthLabel;

  MonthlySummary({
    required this.billCount,
    required this.memberSpend,
    required this.monthLabel,
  });
}

class MonthlyInsights {
  final String monthLabel;
  final int year;
  final int month;
  final int billCount;
  final double totalSpent;
  final Map<String, double> categorySpend;
  final Map<int, double> memberSpend;

  MonthlyInsights({
    required this.monthLabel,
    required this.year,
    required this.month,
    required this.billCount,
    required this.totalSpent,
    required this.categorySpend,
    required this.memberSpend,
  });
}

class OptimalSettlement {
  final int fromMemberId;
  final int toMemberId;
  final double amount;

  OptimalSettlement({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
  });
}

class BillProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Bill> _bills = [];
  Map<int, double> _memberBalances = {};
  // Pairwise balances: _pairwise[a][b] > 0 means b owes a that amount
  Map<int, Map<int, double>> _pairwiseBalances = {};
  MonthlySummary? _monthlySummary;

  // Cache key: bill count + sum of IDs to detect changes cheaply
  int _balanceCacheKey = -1;

  BillFilter? _activeFilter;
  BillFilter? get activeFilter => _activeFilter;
  Map<int, List<int>> _billSharedMemberIds = {};

  // Cached quick stats for UI (computed once in loadBills, not per build)
  double _thisMonthTotal = 0;
  int _thisMonthCount = 0;
  double _lastMonthTotal = 0;
  List<OptimalSettlement>? _cachedSettlements;

  List<Bill> get bills => _bills;
  Map<int, double> get memberBalances => _memberBalances;
  Map<int, Map<int, double>> get pairwiseBalances => _pairwiseBalances;
  MonthlySummary? get monthlySummary => _monthlySummary;
  double get thisMonthTotal => _thisMonthTotal;
  int get thisMonthCount => _thisMonthCount;
  double get lastMonthTotal => _lastMonthTotal;

  List<Bill> get filteredBills {
    if (_activeFilter == null || !_activeFilter!.hasActiveFilters) return _bills;
    return _bills.where((bill) => _matchesFilter(bill)).toList();
  }

  int _computeCacheKey() {
    if (_bills.isEmpty) return 0;
    return Object.hash(
      _bills.length,
      _bills.fold<int>(0, (sum, b) => sum + (b.id ?? 0)),
    );
  }

  Future<void> loadBills(int householdId) async {
    _bills = await _db.getBillsByHousehold(householdId);
    final newKey = _computeCacheKey();
    if (newKey != _balanceCacheKey) {
      await _calculateBalances(householdId);
      _balanceCacheKey = newKey;
    }
    _calculateMonthlySummary();
    notifyListeners();
  }

  Future<void> _calculateBalances(int householdId) async {
    final members = await _db.getMembersByHousehold(householdId);
    _memberBalances = {for (final m in members) m.id!: 0.0};
    _pairwiseBalances = {
      for (final m in members) m.id!: {for (final n in members) if (n.id != m.id) n.id!: 0.0}
    };

    // Helper: record a pairwise debt (debtor owes creditor)
    void addDebt(int creditorId, int debtorId, double amount) {
      _memberBalances[creditorId] =
          (_memberBalances[creditorId] ?? 0) + amount;
      _memberBalances[debtorId] =
          (_memberBalances[debtorId] ?? 0) - amount;
      // Pairwise: creditor is owed by debtor
      if (_pairwiseBalances.containsKey(creditorId) &&
          _pairwiseBalances[creditorId]!.containsKey(debtorId)) {
        _pairwiseBalances[creditorId]![debtorId] =
            (_pairwiseBalances[creditorId]![debtorId] ?? 0) + amount;
        _pairwiseBalances[debtorId]![creditorId] =
            (_pairwiseBalances[debtorId]![creditorId] ?? 0) - amount;
      }
    }

    // Batch-load all items for 'full' bills in 2 queries (not N)
    final fullBillIds = _bills
        .where((b) => b.billType != 'settlement' && b.billType != 'quick')
        .map((b) => b.id!)
        .toList();
    final allItems = await _db.getBillItemsForBills(fullBillIds);

    for (final bill in _bills) {
      final payerId = bill.paidByMemberId;

      if (bill.billType == 'settlement') {
        final receiverId = bill.receiverMemberId;
        if (receiverId != null) {
          addDebt(payerId, receiverId, bill.totalAmount);
        } else {
          final otherMembers = members.where((m) =>
              m.id != payerId && !m.createdAt.isAfter(bill.billDate)).toList();
          if (otherMembers.isNotEmpty) {
            final perPerson = bill.totalAmount / otherMembers.length;
            for (final other in otherMembers) {
              addDebt(payerId, other.id!, perPerson);
            }
          }
        }
      } else if (bill.billType == 'quick') {
        final eligibleMembers = members.where((m) =>
            !m.createdAt.isAfter(bill.billDate)).toList();
        final totalMembers = eligibleMembers.length;
        if (totalMembers > 1) {
          final perPersonShare = bill.totalAmount / totalMembers;
          final otherMembers = eligibleMembers.where((m) => m.id != payerId).toList();
          for (final other in otherMembers) {
            addDebt(payerId, other.id!, perPersonShare);
          }
        }
      } else {
        final items = allItems[bill.id!] ?? [];

        for (final item in items) {
          if (item.isIncluded && item.sharedByMemberIds.isNotEmpty) {
            final perMemberShare = item.price / item.sharedByMemberIds.length;
            for (final memberId in item.sharedByMemberIds) {
              if (memberId != payerId) {
                addDebt(payerId, memberId, perMemberShare);
              }
            }
          }
        }
      }
    }
  }

  void _calculateMonthlySummary() {
    final now = DateTime.now();
    final lastMonth = now.month == 1
        ? DateTime(now.year - 1, 12)
        : DateTime(now.year, now.month - 1);

    double thisTotal = 0;
    int thisCount = 0;
    double lastTotal = 0;
    final memberSpend = <int, double>{};

    for (final b in _bills) {
      if (b.billType == 'settlement') continue;
      if (b.billDate.year == now.year && b.billDate.month == now.month) {
        thisTotal += b.totalAmount;
        thisCount++;
        memberSpend[b.paidByMemberId] =
            (memberSpend[b.paidByMemberId] ?? 0) + b.totalAmount;
      } else if (b.billDate.year == lastMonth.year && b.billDate.month == lastMonth.month) {
        lastTotal += b.totalAmount;
      }
    }

    _thisMonthTotal = thisTotal;
    _thisMonthCount = thisCount;
    _lastMonthTotal = lastTotal;
    _cachedSettlements = null; // Invalidate settlement cache

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    _monthlySummary = MonthlySummary(
      billCount: thisCount,
      memberSpend: memberSpend,
      monthLabel: '${months[now.month - 1]} ${now.year}',
    );
  }

  Future<void> saveBill({
    required Bill bill,
    required List<BillItem> items,
    String? tempPhotoPath,
  }) async {
    String? permanentPhotoPath;
    if (tempPhotoPath != null) {
      permanentPhotoPath = await _savePhoto(tempPhotoPath);
    }

    final billToSave = Bill(
      householdId: bill.householdId,
      enteredByMemberId: bill.enteredByMemberId,
      paidByMemberId: bill.paidByMemberId,
      billType: bill.billType,
      totalAmount: bill.totalAmount,
      photoPath: permanentPhotoPath,
      billDate: bill.billDate,
      category: bill.category,
      recurringBillId: bill.recurringBillId,
    );

    final billId = await _db.insertBill(billToSave);

    if (items.isNotEmpty) {
      final itemsWithBillId = items
          .map((item) => BillItem(
                billId: billId,
                name: item.name,
                price: item.price,
                isIncluded: item.isIncluded,
                sharedByMemberIds: item.sharedByMemberIds,
              ))
          .toList();
      await _db.insertBillItems(itemsWithBillId);
    }

    // Push bill to Supabase in background (don't block UI)
    _pushBillToCloud(billId, bill.householdId);

    await loadBills(bill.householdId);
  }

  /// Push a bill + its items directly to Supabase.
  Future<void> _pushBillToCloud(int localBillId, int householdId) async {
    try {
      final db = await _db.database;
      final supabase = Supabase.instance.client;
      const uuid = Uuid();

      // Resolve household remote_id
      final hRows = await db.query('households',
          columns: ['remote_id'], where: 'id = ?', whereArgs: [householdId]);
      if (hRows.isEmpty || hRows.first['remote_id'] == null) return;
      final householdRemoteId = hRows.first['remote_id'] as String;

      // Pre-load all member remote_ids in one query
      final allMembers = await db.query('members',
          columns: ['id', 'remote_id'],
          where: 'household_id = ?',
          whereArgs: [householdId]);
      final memberRemoteIds = <int, String?>{};
      for (final m in allMembers) {
        memberRemoteIds[m['id'] as int] = m['remote_id'] as String?;
      }

      // Read bill
      final billRows = await db.query('bills', where: 'id = ?', whereArgs: [localBillId]);
      if (billRows.isEmpty) return;
      final bill = billRows.first;

      // Skip if already pushed (has remote_id)
      if (bill['remote_id'] != null && (bill['remote_id'] as String).length > 8) return;

      final billRemoteId = uuid.v4();
      final enteredBy = memberRemoteIds[bill['entered_by_member_id'] as int];
      final paidBy = memberRemoteIds[bill['paid_by_member_id'] as int];
      if (enteredBy == null || paidBy == null) return;

      String? receiverBy;
      if (bill['receiver_member_id'] != null) {
        receiverBy = memberRemoteIds[bill['receiver_member_id'] as int];
      }

      await supabase.from('bills').upsert({
        'id': billRemoteId,
        'household_id': householdRemoteId,
        'entered_by_member_id': enteredBy,
        'paid_by_member_id': paidBy,
        'bill_type': bill['bill_type'],
        'total_amount': bill['total_amount'],
        'bill_date': bill['bill_date'],
        'category': bill['category'],
        if (receiverBy != null) 'receiver_member_id': receiverBy,
        if (bill['photo_url'] != null) 'photo_url': bill['photo_url']!,
      });

      // Save remote_id locally
      await db.update('bills', {'remote_id': billRemoteId},
          where: 'id = ?', whereArgs: [localBillId]);

      // Push bill items
      final items = await db.query('bill_items',
          where: 'bill_id = ?', whereArgs: [localBillId]);
      for (final item in items) {
        // Skip if already pushed
        if (item['remote_id'] != null && (item['remote_id'] as String).length > 8) continue;

        final itemRemoteId = uuid.v4();
        await supabase.from('bill_items').upsert({
          'id': itemRemoteId,
          'bill_id': billRemoteId,
          'name': item['name'],
          'price': item['price'],
          'is_included': (item['is_included'] as int?) == 1,
        });
        await db.update('bill_items', {'remote_id': itemRemoteId},
            where: 'id = ?', whereArgs: [item['id']]);

        // Push bill_item_members
        final bimRows = await db.query('bill_item_members',
            where: 'bill_item_id = ?', whereArgs: [item['id']]);
        for (final bim in bimRows) {
          // Skip if already pushed
          if (bim['remote_id'] != null && (bim['remote_id'] as String).length > 8) continue;

          final memberRid = memberRemoteIds[bim['member_id'] as int];
          if (memberRid == null) continue;
          final bimRemoteId = uuid.v4();
          await supabase.from('bill_item_members').upsert({
            'id': bimRemoteId,
            'bill_item_id': itemRemoteId,
            'member_id': memberRid,
          });
          await db.update('bill_item_members', {'remote_id': bimRemoteId},
              where: 'id = ?', whereArgs: [bim['id']]);
        }
      }
      // Clean up sync queue entries to prevent double-push (batch)
      await db.delete('sync_queue',
          where: 'table_name = ? AND row_id = ?',
          whereArgs: ['bills', localBillId]);
      final itemIds = items.map((i) => i['id'] as int).toList();
      if (itemIds.isNotEmpty) {
        final ph = List.filled(itemIds.length, '?').join(',');
        await db.delete('sync_queue',
            where: 'table_name = ? AND row_id IN ($ph)',
            whereArgs: ['bill_items', ...itemIds]);
        // Batch get all bill_item_member IDs
        final allBimRows = await db.rawQuery(
            'SELECT id FROM bill_item_members WHERE bill_item_id IN ($ph)',
            itemIds);
        final bimIds = allBimRows.map((r) => r['id'] as int).toList();
        if (bimIds.isNotEmpty) {
          final bimPh = List.filled(bimIds.length, '?').join(',');
          await db.delete('sync_queue',
              where: 'table_name = ? AND row_id IN ($bimPh)',
              whereArgs: ['bill_item_members', ...bimIds]);
        }
      }
    } catch (e) {
      debugPrint('Failed to push bill to cloud: $e');
    }
  }

  Future<void> settleUp({
    required int householdId,
    required int payerMemberId,
    required int receiverMemberId,
    required double amount,
  }) async {
    final bill = Bill(
      householdId: householdId,
      enteredByMemberId: payerMemberId,
      paidByMemberId: payerMemberId,
      billType: 'settlement',
      totalAmount: amount,
      billDate: DateTime.now(),
      category: 'other',
      receiverMemberId: receiverMemberId,
    );
    final billId = await _db.insertBill(bill);
    // Push settlement to Supabase (like saveBill does for regular bills)
    _pushBillToCloud(billId, householdId);
    await loadBills(householdId);
  }

  Future<String> _savePhoto(String tempPath) async {
    final compressed = await ImageCompressService.compress(File(tempPath));
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'receipt_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final fileName =
        'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedFile =
        await compressed.copy(p.join(photosDir.path, fileName));
    return savedFile.path;
  }

  Future<Bill?> getBill(int billId) async {
    return await _db.getBill(billId);
  }

  Future<List<BillItem>> getBillItems(int billId) async {
    return await _db.getBillItems(billId);
  }

  Future<void> deleteBill(int billId, int householdId) async {
    final bill = await _db.getBill(billId);
    if (bill?.photoPath != null) {
      final file = File(bill!.photoPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _db.deleteBill(billId);
    await loadBills(householdId);
  }

  /// Re-insert a bill for undo support
  Future<void> reinsertBill(Bill bill, List<BillItem> items) async {
    final billId = await _db.insertBill(bill);
    if (items.isNotEmpty) {
      final itemsWithBillId = items
          .map((item) => BillItem(
                billId: billId,
                name: item.name,
                price: item.price,
                isIncluded: item.isIncluded,
                sharedByMemberIds: item.sharedByMemberIds,
              ))
          .toList();
      await _db.insertBillItems(itemsWithBillId);
    }
    await loadBills(bill.householdId);
  }

  Future<void> setFilter(BillFilter? filter) async {
    _activeFilter = filter;
    if (filter?.memberId != null && !(filter?.filterByPaidBy ?? true)) {
      await _loadSharedMemberIds();
    }
    notifyListeners();
  }

  void clearFilter() {
    _activeFilter = null;
    notifyListeners();
  }

  bool _matchesFilter(Bill bill) {
    final f = _activeFilter!;
    if (f.category != null && bill.category != f.category) return false;
    if (f.dateFrom != null && bill.billDate.isBefore(f.dateFrom!)) return false;
    if (f.dateTo != null && bill.billDate.isAfter(
        DateTime(f.dateTo!.year, f.dateTo!.month, f.dateTo!.day, 23, 59, 59))) {
      return false;
    }
    if (f.memberId != null) {
      if (f.filterByPaidBy) {
        if (bill.paidByMemberId != f.memberId) return false;
      } else {
        final sharedIds = _billSharedMemberIds[bill.id!] ?? [];
        if (!sharedIds.contains(f.memberId)) return false;
      }
    }
    return true;
  }

  Future<void> _loadSharedMemberIds() async {
    _billSharedMemberIds = {};
    final fullBillIds = _bills
        .where((b) => b.billType == 'full')
        .map((b) => b.id!)
        .toList();
    final allItems = await _db.getBillItemsForBills(fullBillIds);

    for (final bill in _bills) {
      if (bill.billType == 'full') {
        final items = allItems[bill.id!] ?? [];
        final memberIds = <int>{};
        for (final item in items) {
          memberIds.addAll(item.sharedByMemberIds);
        }
        _billSharedMemberIds[bill.id!] = memberIds.toList();
      } else {
        _billSharedMemberIds[bill.id!] = [];
      }
    }
  }

  MonthlyInsights getInsightsForMonth(int year, int month) {
    final monthBills = _bills.where((b) =>
        b.billDate.year == year &&
        b.billDate.month == month &&
        b.billType != 'settlement').toList();

    final categorySpend = <String, double>{};
    final memberSpend = <int, double>{};
    double totalSpent = 0;

    for (final bill in monthBills) {
      totalSpent += bill.totalAmount;
      categorySpend[bill.category] =
          (categorySpend[bill.category] ?? 0) + bill.totalAmount;
      memberSpend[bill.paidByMemberId] =
          (memberSpend[bill.paidByMemberId] ?? 0) + bill.totalAmount;
    }

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return MonthlyInsights(
      monthLabel: '${months[month - 1]} $year',
      year: year,
      month: month,
      billCount: monthBills.length,
      totalSpent: totalSpent,
      categorySpend: categorySpend,
      memberSpend: memberSpend,
    );
  }

  Future<String> exportFilteredBillsCsv(List<Member> allMembers) async {
    final bills = filteredBills;
    final buf = StringBuffer();
    buf.writeln('Date,Bill Type,Category,Paid By,Total,Items,Shared With');

    // Batch-load all items for full bills
    final fullBillIds = bills
        .where((b) => b.billType == 'full')
        .map((b) => b.id!)
        .toList();
    final allBillItems = await _db.getBillItemsForBills(fullBillIds);

    for (final bill in bills) {
      final payer = allMembers.where((m) => m.id == bill.paidByMemberId).firstOrNull;
      final payerName = payer?.name ?? 'Unknown';
      final date = '${bill.billDate.year}-${bill.billDate.month.toString().padLeft(2, '0')}-${bill.billDate.day.toString().padLeft(2, '0')}';

      String items = '';
      String sharedWith = '';
      if (bill.billType == 'full') {
        final billItems = allBillItems[bill.id!] ?? [];
        items = billItems.map((i) => i.name).join(';');
        final memberIds = <int>{};
        for (final item in billItems) {
          memberIds.addAll(item.sharedByMemberIds);
        }
        sharedWith = memberIds
            .map((id) => allMembers.where((m) => m.id == id).firstOrNull?.name ?? 'Unknown')
            .join(';');
      } else {
        sharedWith = allMembers.map((m) => m.name).join(';');
      }

      buf.writeln('"$date","${bill.billType}","${bill.category}","$payerName",${bill.totalAmount},"$items","$sharedWith"');
    }

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName = 'billsplit_export_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buf.toString());
    return file.path;
  }

  /// Returns the date of the oldest bill, or null if no bills exist.
  DateTime? get oldestBillDate {
    if (_bills.isEmpty) return null;
    return _bills
        .map((b) => b.billDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Greedy minimum-transfers settlement algorithm.
  /// Nets out all pairwise balances per member, then repeatedly matches
  /// the largest creditor with the largest debtor.
  /// Results are cached and invalidated when bills change.
  List<OptimalSettlement> computeOptimalSettlements() {
    if (_cachedSettlements != null) return _cachedSettlements!;
    final Map<int, double> net = Map.of(_memberBalances);

    // Separate into creditors and debtors
    final List<MapEntry<int, double>> creditors = [];
    final List<MapEntry<int, double>> debtors = [];
    net.forEach((id, balance) {
      if (balance > 0.01) {
        creditors.add(MapEntry(id, balance));
      } else if (balance < -0.01) {
        debtors.add(MapEntry(id, -balance)); // store as positive amount
      }
    });

    // Sort descending by amount
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final List<OptimalSettlement> settlements = [];
    int ci = 0, di = 0;
    final cAmounts = creditors.map((e) => e.value).toList();
    final dAmounts = debtors.map((e) => e.value).toList();

    while (ci < creditors.length && di < debtors.length) {
      final transfer = cAmounts[ci] < dAmounts[di] ? cAmounts[ci] : dAmounts[di];
      if (transfer > 0.01) {
        settlements.add(OptimalSettlement(
          fromMemberId: debtors[di].key,
          toMemberId: creditors[ci].key,
          amount: double.parse(transfer.toStringAsFixed(2)),
        ));
      }
      cAmounts[ci] -= transfer;
      dAmounts[di] -= transfer;
      if (cAmounts[ci] < 0.01) ci++;
      if (dAmounts[di] < 0.01) di++;
    }

    _cachedSettlements = settlements;
    return settlements;
  }

  /// Returns all non-zero pairwise debts as a flat list of OptimalSettlement.
  List<OptimalSettlement> getRawPairwiseDebts() {
    final List<OptimalSettlement> debts = [];
    final Set<String> seen = {};

    _pairwiseBalances.forEach((a, inner) {
      inner.forEach((b, amount) {
        if (amount == 0) return;
        final key = a < b ? '$a-$b' : '$b-$a';
        if (seen.contains(key)) return;
        seen.add(key);

        if (amount > 0) {
          // b owes a
          debts.add(OptimalSettlement(
            fromMemberId: b,
            toMemberId: a,
            amount: double.parse(amount.toStringAsFixed(2)),
          ));
        } else {
          // a owes b
          debts.add(OptimalSettlement(
            fromMemberId: a,
            toMemberId: b,
            amount: double.parse((-amount).toStringAsFixed(2)),
          ));
        }
      });
    });

    return debts;
  }
}
