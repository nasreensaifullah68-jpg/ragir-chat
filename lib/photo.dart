import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

Future<String?> choosePhotoMode(BuildContext context) {
  Widget opt(BuildContext ctx, IconData icon, String text, String value) {
    return ListTile(
      leading: Icon(icon, color: green, size: 32),
      title: Text(text, style: const TextStyle(fontSize: 20)),
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('فوٹو کیسے بھیجیں؟',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          opt(ctx, Icons.download, 'دیکھیں اور ڈاؤنلوڈ بھی کریں', 'save'),
          opt(ctx, Icons.visibility, 'صرف دیکھیں (ڈاؤنلوڈ نہیں)', 'view'),
          opt(ctx, Icons.looks_one, 'ایک بار دیکھیں، پھر ختم', 'once'),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> savePhoto(BuildContext context, String url) async {
  try {
    final res = await http.get(Uri.parse(url));
    var ext = url.split('?').first.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) ext = 'jpg';
    final f = File(
        '${Directory.systemTemp.path}/p${DateTime.now().millisecondsSinceEpoch}.$ext');
    await f.writeAsBytes(res.bodyBytes);
    if (!await Gal.hasAccess()) await Gal.requestAccess();
    await Gal.putImage(f.path, album: 'Rahgeer Chat');
    if (context.mounted) showMsg(context, 'فوٹو گیلری میں محفوظ ہو گئی');
  } catch (e) {
    if (context.mounted) showMsg(context, 'خرابی: $e');
  }
}

Future<void> showPhoto(BuildContext context, String url, bool canSave) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Center(child: Image.network(url)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text('بند کریں',
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                  if (canSave)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: green),
                      onPressed: () => savePhoto(context, url),
                      icon: const Icon(Icons.download),
                      label: const Text('محفوظ کریں',
                          style: TextStyle(fontSize: 20)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PhotoBubble extends StatelessWidget {
  final String? url;
  final String mode;
  final bool mine;
  final bool viewed;
  final DocumentReference<Map<String, dynamic>> msgRef;
  const PhotoBubble({
    super.key,
    required this.url,
    required this.mode,
    required this.mine,
    required this.viewed,
    required this.msgRef,
  });

  Future<void> openOnce(BuildContext context, String u) async {
    await showPhoto(context, u, false);
    try {
      await msgRef.update({'viewed': true, 'imageUrl': FieldValue.delete()});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (mode == 'once') {
      final gone = viewed || u == null;
      final text = gone
          ? 'فوٹو دیکھی جا چکی ہے'
          : (mine ? 'ایک بار والی فوٹو بھیجی' : 'ایک بار دیکھیں (دبائیں)');
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          onTap: (gone || mine) ? null : () => openOnce(context, u),
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.black12, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(gone ? Icons.check_circle_outline : Icons.lock_outline,
                    color: green),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(text, style: const TextStyle(fontSize: 17))),
              ],
            ),
          ),
        ),
      );
    }
    if (u == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => showPhoto(context, u, mode == 'save' || mine),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            u,
            width: 220,
            fit: BoxFit.cover,
            loadingBuilder: (c, w, p) => p == null
                ? w
                : const SizedBox(
                    width: 220,
                    height: 160,
                    child: Center(child: CircularProgressIndicator())),
            errorBuilder: (c, e, st) => const SizedBox(
                width: 220,
                height: 80,
                child: Center(child: Icon(Icons.broken_image))),
          ),
        ),
      ),
    );
  }
}
