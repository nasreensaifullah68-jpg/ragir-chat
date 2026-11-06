import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'filter.dart';

export 'package:image_picker/image_picker.dart' show ImageSource;

Future<String?> pickAndUploadFrom(ImageSource source) async {
  final x = await ImagePicker()
      .pickImage(source: source, maxWidth: 1600, imageQuality: 85);
  if (x == null) return null;
  final nav = navKey.currentState;
  if (nav == null) return null;
  final bytes = await nav.push<dynamic>(
      MaterialPageRoute(builder: (_) => FilterScreen(path: x.path)));
  if (bytes == null) return null;
  return uploadImageBytes(bytes);
}
