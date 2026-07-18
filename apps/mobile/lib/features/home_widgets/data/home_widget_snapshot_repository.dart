import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../characters/data/couple_character_repository.dart';
import '../../couple/data/couple_repository.dart';
import '../../recordings/data/couple_recording_repository.dart';
import 'home_widget_partner_card_repository.dart';
import 'home_widget_snapshot.dart';

final homeWidgetSnapshotRepositoryProvider =
    Provider<HomeWidgetSnapshotRepository>((ref) {
      return SupabaseHomeWidgetSnapshotRepository(
        coupleRepository: ref.watch(coupleRepositoryProvider),
        characterRepository: ref.watch(coupleCharacterRepositoryProvider),
        recordingRepository: ref.watch(coupleRecordingRepositoryProvider),
        partnerCardRepository: ref.watch(
          homeWidgetPartnerCardRepositoryProvider,
        ),
      );
    });

abstract interface class HomeWidgetSnapshotRepository {
  Future<HomeWidgetSnapshot?> fetchSnapshot();
}

class SupabaseHomeWidgetSnapshotRepository
    implements HomeWidgetSnapshotRepository {
  const SupabaseHomeWidgetSnapshotRepository({
    required CoupleRepository coupleRepository,
    required CoupleCharacterRepository characterRepository,
    required CoupleRecordingRepository recordingRepository,
    required HomeWidgetPartnerCardRepository partnerCardRepository,
  }) : _coupleRepository = coupleRepository,
       _characterRepository = characterRepository,
       _recordingRepository = recordingRepository,
       _partnerCardRepository = partnerCardRepository;

  static const _maximumImageBytes = 5 * 1024 * 1024;
  static const _maximumAudioBytes = 4 * 1024 * 1024;

  final CoupleRepository _coupleRepository;
  final CoupleCharacterRepository _characterRepository;
  final CoupleRecordingRepository _recordingRepository;
  final HomeWidgetPartnerCardRepository _partnerCardRepository;

  @override
  Future<HomeWidgetSnapshot?> fetchSnapshot() async {
    if (!AppConfig.isSupabaseConfigured) {
      return null;
    }
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      return null;
    }

    final couple = await _coupleRepository.fetchCurrentCouple();
    if (couple == null || !couple.canReadSharedData) {
      return null;
    }

    final characterFuture = _characterRepository.fetchCurrentCharacter();
    final recordingFuture = _recordingRepository.fetchOverview();
    final partnerCardFuture = _partnerCardRepository.fetchLatestPartnerCard(
      coupleId: couple.id,
      currentUserId: currentUserId,
    );

    final character = await characterFuture;
    final recording = (await recordingFuture).currentRecording;
    final partnerCard = await partnerCardFuture;

    return HomeWidgetSnapshot(
      characterImage: switch (character?.imageUrl) {
        final String url when url.isNotEmpty => HomeWidgetRemoteAsset(
          url: url,
          version: character!.updatedAt.microsecondsSinceEpoch.toString(),
          extension: 'png',
          maxBytes: _maximumImageBytes,
        ),
        _ => null,
      },
      recordingAudio: recording == null
          ? null
          : HomeWidgetRemoteAsset(
              url: recording.audioUrl,
              version: '${recording.recordingId}:${recording.revision}',
              extension: 'm4a',
              maxBytes: _maximumAudioBytes,
            ),
      partnerCardImage: partnerCard == null
          ? null
          : HomeWidgetRemoteAsset(
              url: partnerCard.previewUrl,
              version:
                  '${partnerCard.id}:${partnerCard.revision}:'
                  '${partnerCard.updatedAt.microsecondsSinceEpoch}',
              extension: 'png',
              maxBytes: _maximumImageBytes,
            ),
    );
  }
}
