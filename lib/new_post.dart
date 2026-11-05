import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'camera.dart';
import 'main.dart';
import 'vid.dart';

class NewPostScreen extends StatefulWidget {
  final String channelId;
  const NewPostScreen({super.key, required this.channelId});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final text = TextEditingController();
  String? imageUrl;
  String? videoUrl;
  bool busy = false;
  String busyText = '';

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    setState(() {
      busy = true;
      busyText = 'فوٹو اپلوڈ ہو رہی ہے...';
    });
    try {
      final u = await pickAndUploadFrom(ImageSource.gallery);
      if (u != null) imageUrl = u;
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> pickVideo() async {
    setState(() {
      busy = true;
      busyText = 'ویڈیو اپلوڈ ہو رہی ہے، انتظار کریں...';
    });
    try {
      final u = await pickAndUploadVideo();
      if (u != null) videoUrl = u;
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> publish() async {
    final t = text.text.trim();
    if (t.isEmpty && imageUrl == null && videoUrl == null) {
      showMsg(context, 'کچھ لکھیں یا فوٹو / ویڈیو چنیں');
      return;
    }
    setState(() {
      busy = true;
      busyText = 'پوسٹ ہو رہی ہے...';
    });
    try {
      await FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.channelId)
          .collection('posts')
          .add({
        'text': t,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'authorId': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        showMsg(context, 'خرابی: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: const Text('نئی پوسٹ'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: text,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontSize: 21),
            decoration: InputDecoration(
              hintText: 'کچھ لکھیں...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : pickImage,
                  icon: Icon(imageUrl == null ? Icons.photo : Icons.check_circle),
                  label: const Text('فوٹو', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : pickVideo,
                  icon: Icon(
                      videoUrl == null ? Icons.videocam : Icons.check_circle),
                  label: const Text('ویڈیو', style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ),
          if (imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl!, height: 180, fit: BoxFit.cover),
              ),
            ),
          if (videoUrl != null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('✅ ویڈیو شامل ہو گئی',
                  style: TextStyle(fontSize: 18, color: green)),
            ),
          const SizedBox(height: 18),
          if (busy) const LinearProgressIndicator(),
          if (busy)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(busyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 58,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              onPressed: busy ? null : publish,
              child: const Text('پوسٹ کریں', style: TextStyle(fontSize: 22)),
            ),
          ),
        ],
      ),
    );
  }
}
