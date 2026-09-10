import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_launch_policy.dart';

void main() {
  group('HomeWidgetLaunchAction', () {
    test('카드와 녹음 위젯 URI만 해석한다', () {
      expect(
        HomeWidgetLaunchAction.fromUri(
          Uri.parse('vinscent://widget/card?homeWidget'),
        ),
        HomeWidgetLaunchAction.card,
      );
      expect(
        HomeWidgetLaunchAction.fromUri(
          Uri.parse('vinscent://widget/record?homeWidget'),
        ),
        HomeWidgetLaunchAction.record,
      );
      expect(
        HomeWidgetLaunchAction.fromUri(Uri.parse('vinscent://other/card')),
        isNull,
      );
    });
  });

  group('HomeWidgetCardLaunchPolicy', () {
    test('카드와 질문 상태에 관계없이 카드 위젯은 홈으로 이동한다', () {
      expect(HomeWidgetCardLaunchPolicy.resolve(), '/home');
    });
  });
}
