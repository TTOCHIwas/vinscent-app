final class AiFeatureKeys {
  const AiFeatureKeys._();

  static const focusedQuestions = 'focused_questions';
}

enum AiConsentStatus {
  granted,
  revoked;

  factory AiConsentStatus.fromJson(String value) {
    return switch (value) {
      'granted' => AiConsentStatus.granted,
      'revoked' => AiConsentStatus.revoked,
      _ => throw FormatException('Unknown AI consent status: $value'),
    };
  }
}

enum AiLearningStage {
  collecting,
  exploring,
  refining,
  ready;

  factory AiLearningStage.fromJson(String value) {
    return switch (value) {
      'collecting' => AiLearningStage.collecting,
      'exploring' => AiLearningStage.exploring,
      'refining' => AiLearningStage.refining,
      'ready' => AiLearningStage.ready,
      _ => throw FormatException('Unknown AI learning stage: $value'),
    };
  }
}

enum AiPersonalizationStatus {
  collecting,
  processing,
  processingError,
  reviewing,
  waitingPartner,
  ready;

  factory AiPersonalizationStatus.fromJson(String value) {
    return switch (value) {
      'collecting' => AiPersonalizationStatus.collecting,
      'processing' => AiPersonalizationStatus.processing,
      'processing_error' => AiPersonalizationStatus.processingError,
      'reviewing' => AiPersonalizationStatus.reviewing,
      'waiting_partner' => AiPersonalizationStatus.waitingPartner,
      'ready' => AiPersonalizationStatus.ready,
      _ => throw FormatException('Unknown AI personalization status: $value'),
    };
  }
}

enum AiLearningDomain {
  personalValues,
  emotionalSupport,
  communicationRepair,
  dailyLife,
  relationshipStrength,
  futureBoundaries;

  factory AiLearningDomain.fromJson(String value) {
    return switch (value) {
      'personal_values' => AiLearningDomain.personalValues,
      'emotional_support' => AiLearningDomain.emotionalSupport,
      'communication_repair' => AiLearningDomain.communicationRepair,
      'daily_life' => AiLearningDomain.dailyLife,
      'relationship_strength' => AiLearningDomain.relationshipStrength,
      'future_boundaries' => AiLearningDomain.futureBoundaries,
      _ => throw FormatException('Unknown AI learning domain: $value'),
    };
  }
}

enum AiMemoryScope {
  personal,
  couple;

  factory AiMemoryScope.fromJson(String value) {
    return switch (value) {
      'personal' => AiMemoryScope.personal,
      'couple' => AiMemoryScope.couple,
      _ => throw FormatException('Unknown AI memory scope: $value'),
    };
  }
}

enum AiMemoryState {
  pending,
  active,
  rejected,
  superseded;

  factory AiMemoryState.fromJson(String value) {
    return switch (value) {
      'pending' => AiMemoryState.pending,
      'active' => AiMemoryState.active,
      'rejected' => AiMemoryState.rejected,
      'superseded' => AiMemoryState.superseded,
      _ => throw FormatException('Unknown AI memory state: $value'),
    };
  }
}

enum AiMemoryDecision {
  confirmed,
  rejected;

  factory AiMemoryDecision.fromJson(String value) {
    return switch (value) {
      'confirmed' => AiMemoryDecision.confirmed,
      'rejected' => AiMemoryDecision.rejected,
      _ => throw FormatException('Unknown AI memory decision: $value'),
    };
  }

  String get jsonValue => switch (this) {
    AiMemoryDecision.confirmed => 'confirmed',
    AiMemoryDecision.rejected => 'rejected',
  };
}

class AiDomainProgress {
  const AiDomainProgress({
    required this.completedCount,
    required this.totalCount,
  });

  factory AiDomainProgress.fromJson(Map<String, dynamic> json) {
    return AiDomainProgress(
      completedCount: _readInt(json, 'completed_count'),
      totalCount: _readInt(json, 'total_count'),
    );
  }

  final int completedCount;
  final int totalCount;

  @override
  bool operator ==(Object other) {
    return other is AiDomainProgress &&
        other.completedCount == completedCount &&
        other.totalCount == totalCount;
  }

  @override
  int get hashCode => Object.hash(completedCount, totalCount);
}

class AiLearningProgress {
  const AiLearningProgress({
    required this.curriculumVersion,
    required this.completedCount,
    required this.totalCount,
    required this.stage,
    required this.domainProgress,
    required this.myConsent,
    required this.partnerConsent,
    required this.isEnabled,
    required this.foundationComplete,
    required this.memoryProcessingComplete,
    required this.personalizationStatus,
    required this.personalizationEnabled,
    required this.myPendingReviewCount,
    required this.partnerPendingReviewCount,
  });

  factory AiLearningProgress.fromJson(Map<String, dynamic> json) {
    final rawDomainProgress = _readMap(json, 'domain_progress');
    final domainProgress = <AiLearningDomain, AiDomainProgress>{};

    for (final entry in rawDomainProgress.entries) {
      domainProgress[AiLearningDomain.fromJson(entry.key)] =
          AiDomainProgress.fromJson(_asMap(entry.value, entry.key));
    }

    return AiLearningProgress(
      curriculumVersion: _readInt(json, 'curriculum_version'),
      completedCount: _readInt(json, 'completed_count'),
      totalCount: _readInt(json, 'total_count'),
      stage: AiLearningStage.fromJson(_readString(json, 'stage')),
      domainProgress: Map.unmodifiable(domainProgress),
      myConsent: AiConsentStatus.fromJson(
        _readString(json, 'my_consent_status'),
      ),
      partnerConsent: AiConsentStatus.fromJson(
        _readString(json, 'partner_consent_status'),
      ),
      isEnabled: _readBool(json, 'ai_enabled'),
      foundationComplete: _readBool(json, 'foundation_complete'),
      memoryProcessingComplete: _readBool(json, 'memory_processing_complete'),
      personalizationStatus: AiPersonalizationStatus.fromJson(
        _readString(json, 'personalization_status'),
      ),
      personalizationEnabled: _readBool(json, 'personalization_enabled'),
      myPendingReviewCount: _readInt(json, 'my_pending_review_count'),
      partnerPendingReviewCount: _readInt(json, 'partner_pending_review_count'),
    );
  }

  final int curriculumVersion;
  final int completedCount;
  final int totalCount;
  final AiLearningStage stage;
  final Map<AiLearningDomain, AiDomainProgress> domainProgress;
  final AiConsentStatus myConsent;
  final AiConsentStatus partnerConsent;
  final bool isEnabled;
  final bool foundationComplete;
  final bool memoryProcessingComplete;
  final AiPersonalizationStatus personalizationStatus;
  final bool personalizationEnabled;
  final int myPendingReviewCount;
  final int partnerPendingReviewCount;

  double get completionRatio {
    if (totalCount <= 0) {
      return 0;
    }

    return (completedCount / totalCount).clamp(0.0, 1.0).toDouble();
  }
}

class AiMemory {
  const AiMemory({
    required this.id,
    required this.scope,
    required this.kind,
    required this.statement,
    required this.confidence,
    required this.state,
    required this.confirmedCount,
    required this.requiredConfirmationCount,
    required this.canConfirm,
    required this.evidenceCount,
    required this.createdAt,
    required this.updatedAt,
    this.subjectUserId,
    this.myDecision,
  });

  factory AiMemory.fromJson(Map<String, dynamic> json) {
    final rawDecision = json['my_decision'];

    return AiMemory(
      id: _readString(json, 'memory_id'),
      scope: AiMemoryScope.fromJson(_readString(json, 'scope')),
      subjectUserId: json['subject_user_id'] as String?,
      kind: _readString(json, 'kind'),
      statement: _readString(json, 'statement'),
      confidence: _readNum(json, 'confidence').toDouble(),
      state: AiMemoryState.fromJson(_readString(json, 'state')),
      myDecision: rawDecision == null
          ? null
          : AiMemoryDecision.fromJson(rawDecision as String),
      confirmedCount: _readInt(json, 'confirmed_count'),
      requiredConfirmationCount: _readInt(json, 'required_confirmation_count'),
      canConfirm: _readBool(json, 'can_confirm'),
      evidenceCount: _readInt(json, 'evidence_count'),
      createdAt: DateTime.parse(_readString(json, 'created_at')),
      updatedAt: DateTime.parse(_readString(json, 'updated_at')),
    );
  }

  final String id;
  final AiMemoryScope scope;
  final String? subjectUserId;
  final String kind;
  final String statement;
  final double confidence;
  final AiMemoryState state;
  final AiMemoryDecision? myDecision;
  final int confirmedCount;
  final int requiredConfirmationCount;
  final bool canConfirm;
  final int evidenceCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isWaitingForPartner {
    return scope == AiMemoryScope.couple &&
        state == AiMemoryState.pending &&
        myDecision == AiMemoryDecision.confirmed &&
        confirmedCount < requiredConfirmationCount;
  }
}

class AiLearningDashboard {
  const AiLearningDashboard({
    required this.progress,
    required this.memories,
    this.enabledFeatures = const <String>{},
  });

  factory AiLearningDashboard.fromJson(Map<String, dynamic> json) {
    final rawMemories = json['memories'];
    if (rawMemories is! List) {
      throw const FormatException('Invalid AI memories payload');
    }

    return AiLearningDashboard(
      progress: AiLearningProgress.fromJson(_readMap(json, 'progress')),
      enabledFeatures: _readFeatureKeys(json['enabled_features']),
      memories: List.unmodifiable(
        rawMemories.map(
          (memory) => AiMemory.fromJson(_asMap(memory, 'memory')),
        ),
      ),
    );
  }

  final AiLearningProgress progress;
  final Set<String> enabledFeatures;
  final List<AiMemory> memories;

  bool hasFeature(String featureKey) => enabledFeatures.contains(featureKey);
}

class AiQuestionFeedback {
  const AiQuestionFeedback({
    required this.dailyQuestionId,
    required this.feedbackText,
    required this.publishedAt,
  });

  factory AiQuestionFeedback.fromJson(Map<String, dynamic> json) {
    return AiQuestionFeedback(
      dailyQuestionId: _readString(json, 'daily_question_id'),
      feedbackText: _readString(json, 'feedback_text'),
      publishedAt: DateTime.parse(_readString(json, 'published_at')),
    );
  }

  final String dailyQuestionId;
  final String feedbackText;
  final DateTime publishedAt;
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, String key) {
  return _asMap(json[key], key);
}

Map<String, dynamic> _asMap(Object? value, String key) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  throw FormatException('Invalid AI payload field: $key');
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }

  throw FormatException('Invalid AI string field: $key');
}

num _readNum(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value;
  }

  throw FormatException('Invalid AI number field: $key');
}

int _readInt(Map<String, dynamic> json, String key) {
  return _readNum(json, key).toInt();
}

bool _readBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Invalid AI boolean field: $key');
}

Set<String> _readFeatureKeys(Object? value) {
  if (value == null) {
    return const <String>{};
  }
  if (value is! List) {
    throw const FormatException('Invalid AI enabled features payload');
  }

  final features = <String>{};
  final featureKeyPattern = RegExp(r'^[a-z][a-z0-9_]{2,63}$');
  for (final feature in value) {
    if (feature is! String || !featureKeyPattern.hasMatch(feature)) {
      throw const FormatException('Invalid AI feature key');
    }
    features.add(feature);
  }
  return Set.unmodifiable(features);
}
