import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinscent/features/safety/data/safety_report.dart';
import 'package:vinscent/features/safety/data/safety_report_failure.dart';
import 'package:vinscent/features/safety/data/safety_report_repository.dart';

void main() {
  test('submits a provider-neutral safety report RPC contract', () async {
    Map<String, Object?>? receivedParams;
    final repository = SupabaseSafetyReportRepository(
      isConfigured: true,
      invoke: (params) async {
        receivedParams = params;
        return '47000000-0000-0000-0000-000000000001';
      },
    );

    await repository.submit(
      const SafetyReportRequest(
        target: SafetyReportTarget(
          type: SafetyReportTargetType.aiDirectAnswer,
          id: '37000000-0000-0000-0000-000000000001',
          contentSnapshot: '클라이언트 표시 문구',
        ),
        reason: SafetyReportReason.unsafeAi,
        details: '  부적절한 제안이 포함됐어요  ',
      ),
    );

    expect(receivedParams, {
      'requested_target_type': 'ai_direct_answer',
      'requested_target_id': '37000000-0000-0000-0000-000000000001',
      'requested_reason': 'unsafe_ai',
      'requested_details': '부적절한 제안이 포함됐어요',
      'requested_content_snapshot': '클라이언트 표시 문구',
    });
  });

  test('normalizes empty optional report text to null', () async {
    Map<String, Object?>? receivedParams;
    final repository = SupabaseSafetyReportRepository(
      isConfigured: true,
      invoke: (params) async {
        receivedParams = params;
        return '47000000-0000-0000-0000-000000000001';
      },
    );

    await repository.submit(
      const SafetyReportRequest(
        target: SafetyReportTarget(
          type: SafetyReportTargetType.partner,
          id: '17000000-0000-0000-0000-000000000002',
        ),
        reason: SafetyReportReason.harassment,
        details: '   ',
      ),
    );

    expect(receivedParams?['requested_details'], isNull);
    expect(receivedParams?['requested_content_snapshot'], isNull);
  });

  test('rejects submission when Supabase is not configured', () async {
    var invoked = false;
    final repository = SupabaseSafetyReportRepository(
      isConfigured: false,
      invoke: (params) async {
        invoked = true;
        return null;
      },
    );

    await expectLater(
      repository.submit(
        const SafetyReportRequest(
          target: SafetyReportTarget(
            type: SafetyReportTargetType.partner,
            id: 'partner-id',
          ),
          reason: SafetyReportReason.other,
        ),
      ),
      throwsA(
        isA<SafetyReportException>().having(
          (error) => error.reason,
          'reason',
          SafetyReportFailureReason.configMissing,
        ),
      ),
    );
    expect(invoked, isFalse);
  });

  test('maps an expired session response', () async {
    final repository = SupabaseSafetyReportRepository(
      isConfigured: true,
      invoke: (params) async {
        throw const PostgrestException(message: 'auth_required');
      },
    );

    await expectLater(
      repository.submit(
        const SafetyReportRequest(
          target: SafetyReportTarget(
            type: SafetyReportTargetType.aiFeedback,
            id: 'daily-question-id',
          ),
          reason: SafetyReportReason.unsafeAi,
        ),
      ),
      throwsA(
        isA<SafetyReportException>().having(
          (error) => error.reason,
          'reason',
          SafetyReportFailureReason.authRequired,
        ),
      ),
    );
  });

  test('maps a report request timeout', () async {
    final pending = Completer<Object?>();
    final repository = SupabaseSafetyReportRepository(
      isConfigured: true,
      timeout: const Duration(milliseconds: 1),
      invoke: (params) => pending.future,
    );

    await expectLater(
      repository.submit(
        const SafetyReportRequest(
          target: SafetyReportTarget(
            type: SafetyReportTargetType.aiProactiveSuggestion,
            id: 'suggestion-id',
            contentSnapshot: '추천 문구',
          ),
          reason: SafetyReportReason.unsafeAi,
        ),
      ),
      throwsA(
        isA<SafetyReportException>().having(
          (error) => error.reason,
          'reason',
          SafetyReportFailureReason.requestTimeout,
        ),
      ),
    );
  });
}
