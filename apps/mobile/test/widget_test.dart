import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/app/app.dart';

void main() {
  testWidgets('renders home screen', (tester) async {
    await tester.pumpWidget(const VinscentApp());

    expect(find.text('Vinscent'), findsOneWidget);
    expect(find.text('오늘의 질문'), findsOneWidget);
  });
}
