import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../couple/application/couple_controller.dart';
import '../data/couple_member_birthday.dart';
import '../data/couple_member_birthday_repository.dart';

final coupleMemberBirthdayProvider =
    FutureProvider.autoDispose<List<CoupleMemberBirthday>>((ref) async {
      final couple = await ref.watch(coupleControllerProvider.future);
      if (couple == null || !couple.isActive) {
        return const [];
      }

      return ref
          .watch(coupleMemberBirthdayRepositoryProvider)
          .fetchActiveCoupleBirthdays();
    }, retry: (_, _) => null);
