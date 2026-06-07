import 'dart:typed_data';

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

Future<ProfileImageData?> pickProfileImageData() async => null;

Future<Uint8List> cropAvatarJpeg({
  required List<int> bytes,
  required List<double> transformStorage,
  required double previewSize,
  required int outputSize,
}) async {
  throw UnsupportedError('Avatar cropping is only available on Flutter Web.');
}
