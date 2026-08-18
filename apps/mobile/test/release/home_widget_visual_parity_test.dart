import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('Android character widget uses the card-sized visible surface', () {
    final characterLayout = _readXml(
      'android/app/src/main/res/layout/character_widget.xml',
    );
    final characterInfo = _readXml(
      'android/app/src/main/res/xml/character_widget_info.xml',
    );
    final cardInfo = _readXml(
      'android/app/src/main/res/xml/card_widget_info.xml',
    );
    final root = _elementById(characterLayout, 'character_widget_root');
    final surface = _elementById(characterLayout, 'character_widget_surface');
    final recordButton = _elementById(
      characterLayout,
      'character_widget_record',
    );

    expect(_attribute(root, 'background'), '@android:color/transparent');
    expect(_attribute(surface, 'layout_width'), 'wrap_content');
    expect(_attribute(surface, 'layout_height'), 'match_parent');
    expect(_attribute(surface, 'background'), '@android:color/white');
    expect(recordButton.ancestors, contains(surface));
    expect(_attribute(recordButton, 'layout_marginEnd'), '10dp');
    expect(_attribute(recordButton, 'layout_marginBottom'), '10dp');
    expect(
      _attribute(characterInfo.rootElement, 'targetCellWidth'),
      _attribute(cardInfo.rootElement, 'targetCellWidth'),
    );
    expect(
      _attribute(characterInfo.rootElement, 'targetCellHeight'),
      _attribute(cardInfo.rootElement, 'targetCellHeight'),
    );
  });

  test('iOS character and card widgets share one fitted surface', () {
    final source = File(
      'ios/VinscentWidgets/VinscentWidgets.swift',
    ).readAsStringSync();

    expect(source, contains('static let cardAspectRatio: CGFloat = 4.0 / 5.0'));
    expect(
      RegExp(r'VinscentCardSizedWidgetSurface \{').allMatches(source).length,
      2,
    );
    expect(
      RegExp(
        r'\.containerBackground\(\.clear, for: \.widget\)',
      ).allMatches(source).length,
      2,
    );
    expect(
      source,
      contains('.padding(VinscentWidgetLayout.recordingControlInset)'),
    );
  });
}

XmlDocument _readXml(String path) {
  return XmlDocument.parse(File(path).readAsStringSync());
}

XmlElement _elementById(XmlDocument document, String id) {
  return document.descendants.whereType<XmlElement>().singleWhere(
    (element) => _attribute(element, 'id') == '@+id/$id',
  );
}

String? _attribute(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) {
      return attribute.value;
    }
  }
  return null;
}
