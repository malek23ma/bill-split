import 'package:flutter_test/flutter_test.dart';
import 'package:bill_split/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const BillSplitApp());
    expect(find.text('Bill Split'), findsOneWidget);
  });
}
