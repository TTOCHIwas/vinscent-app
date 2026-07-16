import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/application/recording_draft_file.dart';

void main() {
  test('녹음 임시 파일이 존재하면 삭제한다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vinscent-recording-draft-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final draft = File('${directory.path}${Platform.pathSeparator}draft.m4a');
    await draft.writeAsBytes([1, 2, 3]);

    await deleteRecordingDraftFile(draft.path);

    expect(await draft.exists(), isFalse);
  });

  test('경로가 없거나 파일이 이미 없어도 실패하지 않는다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vinscent-recording-missing-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final missingPath = '${directory.path}${Platform.pathSeparator}missing.m4a';

    await expectLater(deleteRecordingDraftFile(null), completes);
    await expectLater(deleteRecordingDraftFile(missingPath), completes);
  });
}
