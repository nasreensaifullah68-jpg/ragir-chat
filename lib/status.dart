import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'camera.dart';
import 'main.dart';
import 'media.dart';
import 'status_card.dart';
import 'vid.dart';

class StatusScreen extends StatefulWidget {
  final String name;
  const StatusScreen({super.key, required this.name});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  bool uploading = false;

  Future<void> post(Map<String, dynamic> data) async {
    final me = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance.collection('statuses').add({
      'authorId': me.uid,
      'authorName': widget.name,
      'color': DateTime.now().millisecond % statusColors.length,
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> run(Future<void> Function() job) async {
    setState(() => uploading = true);
    try {
      await job();
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
    if (mounted) setState(() => uploading = false);
  }

  Future<void> addText() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نیا اسٹیٹس'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 200,
          style: const TextStyle(fontSize: 22),
          decoration: const InputDecoration(hintText: 'اپنا اسٹیٹس لکھیں'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('منسوخ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: green),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('لگائیں'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    await run(() => post({'text': text.trim()}));
  }

  Future<void> addPhoto(ImageSource s) async {
    await run(() async {
      final url = await pickAndUploadFrom(s);
      if (url != null) await post({'imageUrl': url});
    });
  }

  Future<void> addVideo() async {
    await run(() async {
      final url = await pickAndUploadVideo();
      if (url != null) await post({'videoUrl': url});
    });
  }

  Future<void> addAudio() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('آواز ریکارڈ کریں'),
        content: SizedBox(
          width: 320,
          height: 70,
          child: RecorderBar(
            onCancel: () => Navigator.pop(ctx),
            onSend: (path, secs) {
              Navigator.pop(ctx);
              run(() async {
                final url = await uploadAudio(path);
                if (url != null) {
                  await post({'audioUrl': url, 'audioSecs': secs});
                }
              });
            },
          ),
        ),
      ),
    );
  }

  void chooseType() {
    Widget opt(IconData icon, String text, VoidCallback onTap) {
      return ListTile(
        leading: Icon(icon, color: green, size: 32),
        title: Text(text, style: const TextStyle(fontSize: 20)),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اسٹیٹس میں کیا لگانا ہے؟',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            opt(Icons.text_fields, 'لکھائی', addText),
            opt(Icons.photo, 'فوٹو (گیلری سے)',
                () => addPhoto(ImageSource.gallery)),
            opt(Icons.photo_camera, 'فوٹو (کیمرے سے)',
                () => addPhoto(ImageSource.camera)),
            opt(Icons.videocam, 'ویڈیو', addVideo),
            opt(Icons.mic, 'آواز', addAudio),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final since = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)));
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: const Text('اسٹیٹس'),
        backgroundColor: green,
        foregroundColor: Colors.white,
        bottom: uploading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator())
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: green,
        foregroundColor: Colors.white,
        onPressed: uploading ? null : chooseType,
        icon: const Icon(Icons.add),
        label: const Text('اسٹیٹس لگائیں', style: TextStyle(fontSize: 20)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('statuses')
            .where('createdAt', isGreaterThan: since)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('خرابی: ${snap.error}'),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('ابھی کوئی اسٹیٹس نہیں۔\nنیچے "اسٹیٹس لگائیں" دبائیں',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: docs.length,
            itemBuilder: (context, i) => StatusCard(
              key: ValueKey(docs[i].id),
              ref: docs[i].reference,
              d: docs[i].data(),
              myName: widget.name,
            ),
          );
        },
      ),
    );
  }
}
