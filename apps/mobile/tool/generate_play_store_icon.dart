import 'dart:io';

import 'package:image/image.dart' as image;

const _sourcePath =
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
    'Icon-App-1024x1024@1x.png';
const _outputPath = '../../store-assets/google-play/app-icon-512.png';
const _sourceSize = 1024;
const _outputSize = 512;

void main() {
  final source = File(_sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('Missing source app icon: ${source.path}');
    exitCode = 1;
    return;
  }

  final decoded = image.decodePng(source.readAsBytesSync());
  if (decoded == null ||
      decoded.width != _sourceSize ||
      decoded.height != _sourceSize) {
    stderr.writeln('Source app icon must be 1024x1024 PNG.');
    exitCode = 1;
    return;
  }

  final resized = image.copyResize(
    decoded,
    width: _outputSize,
    height: _outputSize,
    interpolation: image.Interpolation.cubic,
  );
  final rgba = resized.convert(numChannels: 4, alpha: 255);
  final output = File(_outputPath);

  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(image.encodePng(rgba, level: 9), flush: true);
  stdout.writeln('Generated ${output.path}');
}
