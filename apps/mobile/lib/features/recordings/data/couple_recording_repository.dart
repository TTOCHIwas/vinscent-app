import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'couple_recording_repository_contract.dart';
import 'supabase_couple_recording_repository.dart';

export 'couple_recording_repository_contract.dart';
export 'supabase_couple_recording_repository.dart';

final coupleRecordingRepositoryProvider = Provider<CoupleRecordingRepository>((
  ref,
) {
  return const SupabaseCoupleRecordingRepository();
});
