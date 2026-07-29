import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/store_listing_copy_validator.dart';

void main() {
  final document = File(
    '../../docs/release/store-listing-copy-ko.md',
  ).readAsStringSync();
  final copy = StoreListingCopy.parse(document);

  test('current store listing copy satisfies platform contracts', () {
    expect(const StoreListingCopyValidator().validate(copy), isEmpty);
  });
}
