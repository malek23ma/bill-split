import '../models/household.dart';
import '../models/member.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/recurring_bill.dart';

abstract class DataRepository {
  // Households
  Future<int> insertHousehold(Household household);
  Future<List<Household>> getHouseholds();
  Future<void> deleteHousehold(int id);
  Future<void> updateHouseholdCurrency(int id, String currency);

  // Members
  Future<int> insertMember(Member member);
  Future<List<Member>> getMembersByHousehold(int householdId);
  Future<List<Member>> getAllMembersByHousehold(int householdId);
  Future<void> updateMemberName(int memberId, String name);
  Future<void> setMemberActive(int memberId, bool active);

  // Bills
  Future<int> insertBill(Bill bill);
  Future<List<Bill>> getBillsByHousehold(int householdId);
  Future<Bill?> getBill(int id);
  Future<void> deleteBill(int id);

  // Bill Items
  Future<void> insertBillItems(List<BillItem> items);
  Future<List<BillItem>> getBillItems(int billId);
  Future<void> insertBillItemMembers(int billItemId, List<int> memberIds);
  Future<List<int>> getBillItemMemberIds(int billItemId);
  Future<void> deleteBillItemMembers(int billItemId);

  // Recurring Bills
  Future<int> insertRecurringBill(RecurringBill recurringBill);
  Future<List<RecurringBill>> getRecurringBillsByHousehold(int householdId);
  Future<List<RecurringBill>> getDueRecurringBills(int householdId);
  Future<void> updateRecurringBillNextDate(int id, DateTime nextDate);
  Future<void> deactivateRecurringBill(int id);
  Future<void> reactivateRecurringBill(int id);
  Future<void> updateRecurringBill(RecurringBill bill);
  Future<void> deleteRecurringBillPermanently(int id);

  // Utility
  Future<void> fixNewMemberDates(int householdId);
}
