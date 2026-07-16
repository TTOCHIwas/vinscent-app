import 'dart:io';

Future<void> deleteRecordingDraftFile(String? filePath) async {
  if (filePath == null || filePath.isEmpty) {
    return;
  }

  try {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  } on FileSystemException {
    return;
  }
}
