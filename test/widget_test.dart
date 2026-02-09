import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart'; // 請確保這裡的路徑正確

void main() {
  testWidgets('基礎介面測試', (WidgetTester tester) async {
    // 修正：將 MyApp 改為 KariTrukuApp
    await tester.pumpWidget(const KariTrukuApp());

    // 檢查標題是否存在
    expect(find.text('KARI TRUKU'), findsOneWidget);
  });
}