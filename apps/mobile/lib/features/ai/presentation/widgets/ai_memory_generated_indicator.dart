import 'package:flutter/material.dart';

import '../../../safety/data/safety_report.dart';
import '../../../safety/presentation/safety_report_sheet.dart';
import 'ai_generated_content_indicator.dart';

class AiMemoryGeneratedIndicator extends StatelessWidget {
  const AiMemoryGeneratedIndicator({super.key, required this.memoryId});

  final String memoryId;

  @override
  Widget build(BuildContext context) {
    return AiGeneratedContentIndicator(
      onReportPressed: () => showSafetyReportSheet(
        context: context,
        target: SafetyReportTarget(
          type: SafetyReportTargetType.aiMemory,
          id: memoryId,
        ),
      ),
    );
  }
}
