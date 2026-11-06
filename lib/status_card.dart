import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'media.dart';
import 'photo.dart';
import 'vid.dart';

const statusColors = [
  Color(0xFF0F8A5F),
  Color(0xFF1E6FD9),
  Color(0xFF8E44AD),
  Color(0xFFD35400),
  Color(0xFFC0392B),
];

Future<void> saveVideo(BuildContext context, String url) async {
  try {
    final res = await http.Client().send(http.Request('GET', Uri.parse(url)));
    final f = File(
        '${Directory.systemTemp.path}/s${DateTime.now().millisecondsSinceEpoch}.mp4');
    await res.stream.pipe(f.openWrite());
    if (!await Gal.hasAccess()) await Gal.requestAccess();
    await Gal.putVideo(f.path, album: 'Rahgeer Chat');
    if (context.mounted) showMsg(context, 'ویڈیو گیلری میں محفوظ ہو گئی');
  } catch (e) {
    if (context.mounted) showMsg(context, 'خرابی: $e');
  }
}

class StatusCard extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> d;
  final String myName;
  const StatusCard(
      {super.key, required this.ref, required this.d, required this.myName});

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard> {
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  Map<String, dynamic> get d => widget.d;
  bool get mine => d['authorId'] == uid;

  Map<String, dynamic> mapOf(String k) =>
      Map<String, dynamic>.from((d[k] as Map?) ?? {});
  List<String> listOf(String k) => List<String>.from(d[k] ?? []);

  @override
  void initState() {
    super.initState();
    if (!mine && !mapOf('viewers').containsKey(uid)) {
      widget.ref
          .update({'viewers.$uid': widget.myName})
          .catchError((_) {});
    }
  }

  Future<void> react(bool like) async {
    final likes = listOf('likes');
    final dislikes = listOf('dislikes');
    final u = like
        ? {
            'likes': likes.contains(uid)
                ? FieldValue.arrayRemove([uid])
                : FieldValue.arrayUnion([uid]),
            'dislikes': FieldValue.arrayRemove([uid]),
          }
        : {
            'dislikes': dislikes.contains(uid)
                ? FieldValue.arrayRemove([uid])
                : FieldValue.arrayUnion([uid]),
            'likes': FieldValue.arrayRemove([uid]),
          };
    try {
      await widget.ref.update(u);
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
  }

  Future<void> download() async {
    final img = d['imageUrl'] as String?;
    final vid = d['videoUrl'] as String?;
    if (img != null) {
      await savePhoto(context, img);
    } else if (vid != null) {
      showMsg(context, 'ڈاؤنلوڈ ہو رہا ہے…');
      await saveVideo(context, vid);
    }
    try {
      await widget.ref.update({'downloads.$uid': widget.myName});
    } catch (_) {}
  }

  Future<void> share() async {
    final parts = <String>['📢 ${d['authorName'] ?? ''}'];
    for (final k in ['text', 'imageUrl', 'videoUrl', 'audioUrl']) {
      final v = d[k] as String?;
      if (v != null && v.isNotEmpty) parts.add(v);
    }
    parts.add('— راہگیر چیٹ');
    await Clipboard.setData(ClipboardData(text: parts.join('\n')));
    try {
      await widget.ref.update({'shares.$uid': widget.myName});
    } catch (_) {}
    if (mounted) {
      showMsg(context, 'کاپی ہو گیا۔ اب کسی چیٹ میں پیسٹ کر کے بھیج دیں');
    }
  }

  void showNames(String title, Map<String, dynamic> m) {
    if (!mine) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$title (${m.length})',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            if (m.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('ابھی کوئی نہیں', style: TextStyle(fontSize: 19)),
              ),
            for (final n in m.values)
              ListTile(
                  leading: const Icon(Icons.person, color: green),
                  title: Text('$n', style: const TextStyle(fontSize: 20))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget stat(IconData icon, int n, VoidCallback? onTap, {bool on = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: on ? Colors.yellowAccent : Colors.white, size: 24),
            const SizedBox(width: 4),
            Text('$n',
                style: TextStyle(
                    color: on ? Colors.yellowAccent : Colors.white,
                    fontSize: 17)),
          ],
        ),
      ),
    );
  }

  String timeText(DateTime t) {
    final l = t.toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final m = l.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final same = l.year == now.year && l.month == now.month && l.day == now.day;
    return same ? 'آج $h:$m' : 'کل $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final ts = d['createdAt'] as Timestamp?;
    final text = (d['text'] as String?) ?? '';
    final img = d['imageUrl'] as String?;
    final vid = d['videoUrl'] as String?;
    final aud = d['audioUrl'] as String?;
    final media = img != null || vid != null || aud != null;
    final ci = ((d['color'] as num?) ?? 0).toInt() % statusColors.length;
    final likes = listOf('likes');
    final dislikes = listOf('dislikes');
    final views = mapOf('viewers');
    final downs = mapOf('downloads');
    final shares = mapOf('shares');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: media ? const Color(0xFF263238) : statusColors[ci],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mine ? 'آپ' : ((d['authorName'] as String?) ?? ''),
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (ts != null)
                Text(timeText(ts.toDate()),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              if (mine)
                IconButton(
                  tooltip: 'ہٹائیں',
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => widget.ref.delete(),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (img != null)
            GestureDetector(
              onTap: () => showPhoto(context, img, true),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(img,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const SizedBox(
                        height: 80,
                        child: Center(child: Icon(Icons.broken_image)))),
              ),
            ),
          if (vid != null) VideoPost(url: vid),
          if (aud != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12)),
              child: VoiceBubble(
                  url: aud, secs: ((d['audioSecs'] as num?) ?? 0).toInt()),
            ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text,
                  style: TextStyle(
                      color: Colors.white, fontSize: media ? 20 : 26)),
            ),
          const Divider(color: Colors.white24, height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: [
              stat(Icons.thumb_up, likes.length, () => react(true),
                  on: likes.contains(uid)),
              stat(Icons.thumb_down, dislikes.length, () => react(false),
                  on: dislikes.contains(uid)),
              if (img != null || vid != null)
                stat(Icons.download, downs.length, download,
                    on: downs.containsKey(uid)),
              stat(Icons.share, shares.length, share,
                  on: shares.containsKey(uid)),
              stat(Icons.visibility, views.length,
                  () => showNames('دیکھنے والے', views)),
            ],
          ),
          if (mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 14,
                children: [
                  GestureDetector(
                    onTap: () => showNames('دیکھنے والے', views),
                    child: Text('👁 ${views.length} نے دیکھا',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ),
                  if (img != null || vid != null)
                    GestureDetector(
                      onTap: () => showNames('ڈاؤنلوڈ کرنے والے', downs),
                      child: Text('⬇ ${downs.length} نے ڈاؤنلوڈ کیا',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ),
                  GestureDetector(
                    onTap: () => showNames('شیئر کرنے والے', shares),
                    child: Text('↗ ${shares.length} نے شیئر کیا',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
