import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'avatar.dart';
import 'camera.dart';
import 'main.dart';
import 'media.dart';
import 'status_card.dart';
import 'ui.dart';
import 'vid.dart';

class StatusScreen extends StatefulWidget {
  final String name;
  const StatusScreen({super.key, required this.name});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  bool uploading = false;
  int sTab = 0;

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

  Widget note(String t) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Text(t,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, color: Colors.black54)),
    );
  }

  Widget myHeader(String myId) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: ListTile(
        onTap: uploading ? null : chooseType,
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            UserAvatar(uid: myId, name: widget.name, radius: 30),
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: green, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
        title: const Text('میرا اسٹیٹس',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        subtitle: const Text('نیا اسٹیٹس لگانے کے لیے دبائیں',
            style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget othersRow(Map<String, String> people) {
    final ids = people.keys.toList();
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ids.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final nm = people[ids[i]] ?? '';
          return SizedBox(
            width: 76,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: green, width: 3),
                  ),
                  child: UserAvatar(uid: ids[i], name: nm, radius: 30),
                ),
                const SizedBox(height: 4),
                Text(nm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15)),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final since = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)));
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        toolbarHeight: 70,
        centerTitle: true,
        backgroundColor: green,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 40),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('اسٹیٹس',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                Text('Status', style: TextStyle(fontSize: 13)),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkResponse(
              onTap: uploading ? null : chooseType,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: green, size: 30),
              ),
            ),
          ),
        ],
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
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: PillTabs(
              labels: const ['میرے اسٹیٹس', 'دوسروں کے اسٹیٹس'],
              selected: sTab,
              onTap: (i) => setState(() => sTab = i),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                final mine =
                    docs.where((x) => x.data()['authorId'] == myId).toList();
                final others =
                    docs.where((x) => x.data()['authorId'] != myId).toList();
                final people = <String, String>{};
                for (final x in others) {
                  final dd = x.data();
                  people[(dd['authorId'] as String?) ?? ''] =
                      (dd['authorName'] as String?) ?? '';
                }
                final shown = sTab == 0 ? mine : others;
                final kids = <Widget>[];
                if (sTab == 0) {
                  kids.add(myHeader(myId));
                  if (mine.isEmpty) kids.add(note('آپ نے ابھی کوئی اسٹیٹس نہیں لگایا'));
                } else {
                  if (others.isEmpty) {
                    kids.add(note('ابھی کسی اور کا اسٹیٹس نہیں'));
                  } else {
                    kids.add(othersRow(people));
                  }
                }
                for (final x in shown) {
                  kids.add(StatusCard(
                    key: ValueKey(x.id),
                    ref: x.reference,
                    d: x.data(),
                    myName: widget.name,
                  ));
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  children: kids,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
