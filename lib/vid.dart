import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'cloud.dart';
import 'main.dart';

Future<String?> pickAndUploadVideo() async {
  final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
  if (x == null) return null;
  if (await x.length() > 95 * 1024 * 1024) {
    throw Exception('ویڈیو 100 MB سے بڑی ہے');
  }
  final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload'));
  req.fields['upload_preset'] = uploadPreset;
  req.files.add(await http.MultipartFile.fromPath('file', x.path));
  final res = await http.Response.fromStream(await req.send());
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error']?['message'] ?? 'اپلوڈ نہیں ہوا');
  }
  return data['secure_url'] as String?;
}

class VideoPost extends StatefulWidget {
  final String url;
  const VideoPost({super.key, required this.url});

  @override
  State<VideoPost> createState() => _VideoPostState();
}

class _VideoPostState extends State<VideoPost> {
  VideoPlayerController? c;
  bool loading = false;

  Future<void> start() async {
    setState(() => loading = true);
    try {
      final ctl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await ctl.initialize();
      ctl.addListener(() {
        if (mounted) setState(() {});
      });
      await ctl.play();
      if (!mounted) {
        ctl.dispose();
        return;
      }
      setState(() {
        c = ctl;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMsg(context, 'ویڈیو نہیں چلی: $e');
    }
  }

  @override
  void dispose() {
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctl = c;
    if (ctl == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
            color: Colors.black, borderRadius: BorderRadius.circular(10)),
        child: Center(
          child: loading
              ? const CircularProgressIndicator(color: Colors.white)
              : IconButton(
                  onPressed: start,
                  iconSize: 70,
                  color: Colors.white,
                  icon: const Icon(Icons.play_circle_fill),
                ),
        ),
      );
    }
    return Column(
      children: [
        GestureDetector(
          onTap: () => ctl.value.isPlaying ? ctl.pause() : ctl.play(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: ctl.value.aspectRatio,
                child: VideoPlayer(ctl),
              ),
              if (!ctl.value.isPlaying)
                const Icon(Icons.play_circle_fill,
                    color: Colors.white70, size: 70),
            ],
          ),
        ),
        VideoProgressIndicator(ctl, allowScrubbing: true),
      ],
    );
  }
}
