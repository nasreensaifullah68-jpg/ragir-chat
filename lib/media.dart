import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart'
    show AudioPlayer, PlayerState, UrlSource;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart'
    show AudioEncoder, AudioRecorder, RecordConfig;
import 'cloud.dart';
import 'main.dart';

String lastSeenText(Map<String, dynamic>? u) {
  if (u == null) return '';
  final ts = u['lastSeen'] as Timestamp?;
  if (ts == null) return '';
  final t = ts.toDate();
  final now = DateTime.now();
  if (u['online'] == true && now.difference(t).inSeconds.abs() < 100) {
    return 'آن لائن';
  }
  final l = t.toLocal();
  final h = l.hour.toString().padLeft(2, '0');
  final m = l.minute.toString().padLeft(2, '0');
  final same = l.year == now.year && l.month == now.month && l.day == now.day;
  return same ? 'آخری بار آج $h:$m' : 'آخری بار ${l.day}/${l.month} $h:$m';
}

Future<String?> uploadAudio(String path) async {
  final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload'));
  req.fields['upload_preset'] = uploadPreset;
  req.files.add(await http.MultipartFile.fromPath('file', path));
  final res = await http.Response.fromStream(await req.send());
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error']?['message'] ?? 'اپلوڈ نہیں ہوا');
  }
  return data['secure_url'] as String?;
}

class ImageBubble extends StatelessWidget {
  final String url;
  const ImageBubble({super.key, required this.url});

  void open(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
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

class VoiceBubble extends StatefulWidget {
  final String url;
  final int secs;
  const VoiceBubble({super.key, required this.url, required this.secs});

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final player = AudioPlayer();
  bool playing = false;
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();
    sub = player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => playing = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    player.dispose();
    super.dispose();
  }

  Future<void> toggle() async {
    try {
      if (playing) {
        await player.pause();
      } else if (player.state == PlayerState.paused) {
        await player.resume();
      } else {
        await player.play(UrlSource(widget.url));
      }
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = (widget.secs ~/ 60).toString();
    final s = (widget.secs % 60).toString().padLeft(2, '0');
    return SizedBox(
      width: 210,
      child: Row(
        children: [
          IconButton.filled(
            onPressed: toggle,
            style: IconButton.styleFrom(
                backgroundColor: green, foregroundColor: Colors.white),
            icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 30),
          ),
          const SizedBox(width: 8),
          const Expanded(
              child: Icon(Icons.graphic_eq, color: green, size: 36)),
          Text('$m:$s', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class RecorderBar extends StatefulWidget {
  final void Function(String path, int secs) onSend;
  final VoidCallback onCancel;
  const RecorderBar({super.key, required this.onSend, required this.onCancel});

  @override
  State<RecorderBar> createState() => _RecorderBarState();
}

class _RecorderBarState extends State<RecorderBar> {
  final rec = AudioRecorder();
  Timer? timer;
  int secs = 0;

  @override
  void initState() {
    super.initState();
    begin();
  }

  Future<void> begin() async {
    try {
      if (!await rec.hasPermission()) {
        if (mounted) {
          showMsg(context, 'مائیک کی اجازت دیں');
          widget.onCancel();
        }
        return;
      }
      final path =
          '${Directory.systemTemp.path}/v${DateTime.now().millisecondsSinceEpoch}.m4a';
      await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path);
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => secs++);
      });
    } catch (e) {
      if (mounted) {
        showMsg(context, 'خرابی: $e');
        widget.onCancel();
      }
    }
  }

  Future<void> finish(bool send) async {
    timer?.cancel();
    String? path;
    try {
      path = await rec.stop();
    } catch (_) {}
    if (send && path != null && secs >= 1) {
      widget.onSend(path, secs);
    } else {
      widget.onCancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = (secs ~/ 60).toString();
    final s = (secs % 60).toString().padLeft(2, '0');
    return Row(
      children: [
        IconButton(
          onPressed: () => finish(false),
          icon: const Icon(Icons.delete, color: Colors.red, size: 32),
        ),
        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 18),
        const SizedBox(width: 6),
        Text('$m:$s', style: const TextStyle(fontSize: 22)),
        const Expanded(
            child: Text('ریکارڈنگ ہو رہی ہے...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54))),
        IconButton.filled(
          onPressed: () => finish(true),
          style: IconButton.styleFrom(
              backgroundColor: green, foregroundColor: Colors.white),
          icon: const Icon(Icons.send),
        ),
      ],
    );
  }
}
