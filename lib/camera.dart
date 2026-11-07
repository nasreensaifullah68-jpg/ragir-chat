import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'filter.dart';
import 'main.dart';

export 'package:image_picker/image_picker.dart' show ImageSource;

Future<bool?> askQuality() async {
  final nav = navKey.currentState;
  final overlay = nav?.overlay;
  if (nav == null || overlay == null) return false;
  Widget opt(BuildContext c, bool hd, String title, String sub, bool filled) {
    final child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 22)),
        Text(sub, style: const TextStyle(fontSize: 14)),
      ],
    );
    return SizedBox(
      width: double.infinity,
      height: 76,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(backgroundColor: green),
              onPressed: () => Navigator.pop(c, hd),
              child: child,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: green,
                  side: const BorderSide(color: green, width: 2)),
              onPressed: () => Navigator.pop(c, hd),
              child: child,
            ),
    );
  }

  return nav.push<bool>(DialogRoute<bool>(
    context: overlay.context,
    builder: (c) => AlertDialog(
      title: const Text('تصویر کی کوالٹی'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          opt(c, false, 'نارمل', 'کم ڈیٹا، جلدی پہنچے', true),
          const SizedBox(height: 12),
          opt(c, true, 'HD', 'زیادہ صاف، زیادہ ڈیٹا', false),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('منسوخ', style: TextStyle(fontSize: 18))),
      ],
    ),
  ));
}

Future<String?> pickAndUploadFrom(ImageSource source) async {
  final hd = await askQuality();
  if (hd == null) return null;
  final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: hd ? 2400 : 1280,
      imageQuality: hd ? 92 : 70);
  if (x == null) return null;
  final nav = navKey.currentState;
  if (nav == null) return null;
  final bytes = await nav.push<dynamic>(
      MaterialPageRoute(builder: (_) => FilterScreen(path: x.path, hd: hd)));
  if (bytes == null) return null;
  return uploadImageBytes(bytes);
}
