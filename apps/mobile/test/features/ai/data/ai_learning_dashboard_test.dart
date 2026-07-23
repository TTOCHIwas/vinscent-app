import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';

void main() {
  test('parses learning progress and confirmation-aware memories', () {
    final dashboard = AiLearningDashboard.fromJson({
      'progress': {
        'curriculum_version': 1,
        'completed_count': 8,
        'total_count': 24,
        'stage': 'exploring',
        'domain_progress': {
          'daily_life': {'completed_count': 2, 'total_count': 4},
        },
        'my_consent_status': 'granted',
        'partner_consent_status': 'granted',
        'ai_enabled': true,
        'foundation_complete': true,
        'memory_processing_complete': true,
        'personalization_status': 'waiting_partner',
        'personalization_enabled': false,
        'my_pending_review_count': 0,
        'partner_pending_review_count': 1,
      },
      'enabled_features': ['focused_questions'],
      'memories': [
        {
          'memory_id': 'memory-id',
          'scope': 'couple',
          'subject_user_id': null,
          'is_mine': false,
          'kind': 'relationship_pattern',
          'statement': '함께 산책하는 시간을 좋아해요.',
          'confidence': 0.85,
          'state': 'pending',
          'my_decision': 'confirmed',
          'confirmed_count': 1,
          'required_confirmation_count': 2,
          'can_confirm': false,
          'evidence_count': 2,
          'created_at': '2026-07-20T10:00:00Z',
          'updated_at': '2026-07-20T11:00:00Z',
        },
      ],
    });

    expect(dashboard.progress.completedCount, 8);
    expect(dashboard.hasFeature(AiFeatureKeys.focusedQuestions), true);
    expect(dashboard.hasFeature('monthly_report'), false);
    expect(dashboard.progress.totalCount, 24);
    expect(dashboard.progress.stage, AiLearningStage.exploring);
    expect(dashboard.progress.isEnabled, true);
    expect(dashboard.progress.foundationComplete, true);
    expect(dashboard.progress.memoryProcessingComplete, true);
    expect(
      dashboard.progress.personalizationStatus,
      AiPersonalizationStatus.waitingPartner,
    );
    expect(dashboard.progress.personalizationEnabled, false);
    expect(
      dashboard.progress.domainProgress[AiLearningDomain.dailyLife],
      const AiDomainProgress(completedCount: 2, totalCount: 4),
    );
    expect(dashboard.memories.single.scope, AiMemoryScope.couple);
    expect(dashboard.memories.single.isMine, false);
    expect(dashboard.memories.single.myDecision, AiMemoryDecision.confirmed);
    expect(dashboard.memories.single.isWaitingForPartner, true);
  });

  test('rejects an unknown learning stage', () {
    expect(
      () => AiLearningProgress.fromJson({
        'curriculum_version': 1,
        'completed_count': 0,
        'total_count': 24,
        'stage': 'unknown',
        'domain_progress': <String, Object?>{},
        'my_consent_status': 'revoked',
        'partner_consent_status': 'revoked',
        'ai_enabled': false,
        'foundation_complete': false,
        'memory_processing_complete': false,
        'personalization_status': 'collecting',
        'personalization_enabled': false,
        'my_pending_review_count': 0,
        'partner_pending_review_count': 0,
      }),
      throwsFormatException,
    );
  });

  test('keeps feature access backward compatible when the field is absent', () {
    final dashboard = AiLearningDashboard.fromJson({
      'progress': {
        'curriculum_version': 1,
        'completed_count': 0,
        'total_count': 24,
        'stage': 'collecting',
        'domain_progress': <String, Object?>{},
        'my_consent_status': 'revoked',
        'partner_consent_status': 'revoked',
        'ai_enabled': false,
        'foundation_complete': false,
        'memory_processing_complete': false,
        'personalization_status': 'collecting',
        'personalization_enabled': false,
        'my_pending_review_count': 0,
        'partner_pending_review_count': 0,
      },
      'memories': <Object?>[],
    });

    expect(dashboard.enabledFeatures, isEmpty);
  });
}
