import 'package:characters/characters.dart';

const profileDisplayNameMinLength = 2;
const profileDisplayNameMaxLength = 8;

String normalizeProfileDisplayName(String value) => value.trim();

int profileDisplayNameLength(String value) {
  return normalizeProfileDisplayName(value).characters.length;
}

bool isValidProfileDisplayName(String value) {
  final length = profileDisplayNameLength(value);
  return length >= profileDisplayNameMinLength &&
      length <= profileDisplayNameMaxLength;
}
