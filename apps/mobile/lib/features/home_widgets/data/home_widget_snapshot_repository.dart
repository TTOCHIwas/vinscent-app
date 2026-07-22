import 'package:flutter/foundation.dart';
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
  SupabaseHomeWidgetSnapshotRepository({
    required CoupleRepository coupleRepository,
    required CoupleCharacterRepository characterRepository,
    required CoupleRecordingRepository recordingRepository,
    required HomeWidgetPartnerCardRepository partnerCardRepository,
  }) : _coupleRepository = coupleRepository,
       _assetLoader = HomeWidgetSnapshotAssetLoader(
         characterRepository: characterRepository,
         recordingRepository: recordingRepository,
         partnerCardRepository: partnerCardRepository,
       );

  final CoupleRepository _coupleRepository;
  final HomeWidgetSnapshotAssetLoader _assetLoader;

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

    return _assetLoader.fetch(
      coupleId: couple.id,
      currentUserId: currentUserId,
    );
  }
}

class HomeWidgetSnapshotAssetLoader {
  const HomeWidgetSnapshotAssetLoader({
    required CoupleCharacterRepository characterRepository,
    required CoupleRecordingRepository recordingRepository,
    required HomeWidgetPartnerCardRepository partnerCardRepository,
  }) : _characterRepository = characterRepository,
       _recordingRepository = recordingRepository,
       _partnerCardRepository = partnerCardRepository;

  static const _maximumImageBytes = 5 * 1024 * 1024;
  static const _maximumAudioBytes = 4 * 1024 * 1024;

  final CoupleCharacterRepository _characterRepository;
  final CoupleRecordingRepository _recordingRepository;
  final HomeWidgetPartnerCardRepository _partnerCardRepository;

  Future<HomeWidgetSnapshot> fetch({
    required String coupleId,
    required String currentUserId,
  }) async {
    final updates = await Future.wait([
      _fetchCharacterImage(),
      _fetchRecordingAudio(),
      _fetchPartnerCardImage(coupleId: coupleId, currentUserId: currentUserId),
    ]);

    return HomeWidgetSnapshot(
      characterImage: updates[0],
      recordingAudio: updates[1],
      partnerCardImage: updates[2],
    );
  }

  Future<HomeWidgetAssetUpdate> _fetchCharacterImage() async {
    try {
      final character = await _characterRepository.fetchCurrentCharacter();
      final imageUrl = character?.imageUrl;
      if (character == null || imageUrl == null || imageUrl.isEmpty) {
        return const HomeWidgetAssetUpdate.remove();
      }

      return HomeWidgetAssetUpdate.replace(
        HomeWidgetRemoteAsset(
          url: imageUrl,
          version: character.updatedAt.microsecondsSinceEpoch.toString(),
          extension: 'png',
          maxBytes: _maximumImageBytes,
        ),
      );
    } catch (error) {
      _logSourceFailure('character', error);
      return const HomeWidgetAssetUpdate.preserve();
    }
  }

  Future<HomeWidgetAssetUpdate> _fetchRecordingAudio() async {
    try {
      final recording =
          (await _recordingRepository.fetchOverview()).currentRecording;
      if (recording == null) {
        return const HomeWidgetAssetUpdate.remove();
      }

      return HomeWidgetAssetUpdate.replace(
        HomeWidgetRemoteAsset(
          url: recording.audioUrl,
          version: '${recording.recordingId}:${recording.revision}',
          extension: 'm4a',
          maxBytes: _maximumAudioBytes,
        ),
      );
    } catch (error) {
      _logSourceFailure('recording', error);
      return const HomeWidgetAssetUpdate.preserve();
    }
  }

  Future<HomeWidgetAssetUpdate> _fetchPartnerCardImage({
    required String coupleId,
    required String currentUserId,
  }) async {
    try {
      final partnerCard = await _partnerCardRepository.fetchLatestPartnerCard(
        coupleId: coupleId,
        currentUserId: currentUserId,
      );
      if (partnerCard == null) {
        return const HomeWidgetAssetUpdate.remove();
      }

      return HomeWidgetAssetUpdate.replace(
        HomeWidgetRemoteAsset(
          url: partnerCard.previewUrl,
          version:
              '${partnerCard.id}:${partnerCard.revision}:'
              '${partnerCard.updatedAt.microsecondsSinceEpoch}',
          extension: 'png',
          maxBytes: _maximumImageBytes,
        ),
      );
    } catch (error) {
      _logSourceFailure('partner-card', error);
      return const HomeWidgetAssetUpdate.preserve();
    }
  }

  void _logSourceFailure(String source, Object error) {
    if (kDebugMode) {
      debugPrint('[widget] $source snapshot fetch failed: $error');
    }
  }
}
