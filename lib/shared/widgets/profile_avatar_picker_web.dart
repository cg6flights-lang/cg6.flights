import 'package:cg6_flights/app/i18n/app_localizations.dart';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'dart:html' as html;

class ProfileImageData {
  const ProfileImageData({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}

Future<ProfileImageData?> pickProfileImageData() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;
  input.click();

  final file = await input.onChange.first.then((_) => input.files?.firstOrNull);
  if (file == null) return null;

  final reader = html.FileReader();
  reader.readAsDataUrl(file);
  await reader.onLoad.first;

  final dataUrl = reader.result?.toString() ?? '';
  if (dataUrl.isEmpty || !dataUrl.contains(',')) return null;

  final parts = dataUrl.split(',');
  final header = parts.first;
  final base64Str = parts.sublist(1).join(',');
  final mimeMatch = RegExp(r'data:(image/[\w+-]+)').firstMatch(header);
  final mimeType = mimeMatch?.group(1) ?? 'image/jpeg';
  final bytes = Uint8List.fromList(base64Decode(base64Str));
  if (bytes.isEmpty) return null;

  return ProfileImageData(
    bytes: bytes,
    mimeType: mimeType,
    fileName: file.name,
  );
}

Future<Uint8List> cropAvatarJpeg({
  required List<int> bytes,
  required List<double> transformStorage,
  required double previewSize,
  required int outputSize,
}) async {
  final sourceBlob = html.Blob([bytes]);
  final sourceUrl = html.Url.createObjectUrl(sourceBlob);

  try {
    final image = html.ImageElement()..src = sourceUrl;
    final completer = Completer<void>();
    image.onLoad.first.then((_) => completer.complete());
    image.onError.first.then(
      (_) => completer.completeError('No se pudo leer la imagen.'),
    );
    await completer.future;

    final naturalWidth = image.naturalWidth;
    final naturalHeight = image.naturalHeight;
    if (naturalWidth <= 0 || naturalHeight <= 0) {
      throw StateError('Invalid image dimensions');
    }

    final imageRatio = naturalWidth / naturalHeight;
    final displayWidth = imageRatio >= 1
        ? previewSize
        : previewSize * imageRatio;
    final displayHeight = imageRatio >= 1
        ? previewSize / imageRatio
        : previewSize;
    final baseLeft = (previewSize - displayWidth) / 2;
    final baseTop = (previewSize - displayHeight) / 2;

    final scale = transformStorage[0];
    final translateX = transformStorage[12];
    final translateY = transformStorage[13];
    final outputScale = outputSize / previewSize;

    final canvas = html.CanvasElement(width: outputSize, height: outputSize);
    final ctx = canvas.context2D;
    ctx
      ..fillStyle = '#FFFFFF'
      ..fillRect(0, 0, outputSize, outputSize)
      ..save()
      ..beginPath()
      ..arc(outputSize / 2, outputSize / 2, outputSize / 2, 0, math.pi * 2)
      ..clip();

    ctx.drawImageScaled(
      image,
      (baseLeft * scale + translateX) * outputScale,
      (baseTop * scale + translateY) * outputScale,
      displayWidth * scale * outputScale,
      displayHeight * scale * outputScale,
    );
    ctx.restore();

    final outputBlob = await canvas.toBlob('image/jpeg', 0.88);
    final reader = html.FileReader();
    reader.readAsDataUrl(outputBlob);
    await reader.onLoad.first;

    final dataUrl = reader.result?.toString() ?? '';
    if (!dataUrl.contains(',')) {
      throw StateError('Invalid cropped output');
    }
    return Uint8List.fromList(base64Decode(dataUrl.split(',').last));
  } finally {
    html.Url.revokeObjectUrl(sourceUrl);
  }
}

