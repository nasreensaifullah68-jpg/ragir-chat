import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'cloud.dart';
import 'look.dart';
import 'main.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

int startFilter = 0;

Future<String?> uploadImageBytes(Uint8List bytes) async {
  final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'));
  req.fields['upload_preset'] = uploadPreset;
  req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: 'photo.png'));
  final res = await http.Response.fromStream(await req.send());
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error']?['message'] ?? 'اپلوڈ نہیں ہوا');
  }
  return data['secure_url'] as String?;
}

class FilterScreen extends StatefulWidget {
  final String path;
  final bool hd;
  const FilterScreen({super.key, required this.path, this.hd = false});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final boundaryKey = GlobalKey();
  Uint8List? bytes;
  ui.Image? orig;
  ui.Image? enh;
  double ratio = 1;
  int sel = 0;
  bool busy = false;
  bool enhance = true;
  double blur = 0;

  @override
  void initState() {
    super.initState();
    sel = startFilter.clamp(0, photoFilters.length - 1).toInt();
    startFilter = 0;
    load();
  }

  Future<ui.Image> fromPixels(Uint8List px, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  Future<void> load() async {
    final b = await File(widget.path).readAsBytes();
    final im = await decodeImageFromList(b);
    if (!mounted) return;
    setState(() {
      bytes = b;
      orig = im;
      ratio = im.width / im.height;
    });
    try {
      final bd = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bd == null) return;
      final px = bd.buffer.asUint8List();
      final out = await compute(enhancePixels, EnhanceJob(px, 1.0));
      if (identical(out, px)) return;
      final e = await fromPixels(out, im.width, im.height);
      if (mounted) setState(() => enh = e);
    } catch (_) {}
  }

  ui.Image? get current => (enhance && enh != null) ? enh : orig;

  Future<void> done() async {
    if (sel == 0 && blur == 0 && (!enhance || enh == null) && bytes != null) {
      Navigator.pop(context, bytes);
      return;
    }
    setState(() => busy = true);
    try {
      final rb = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final target = widget.hd ? 1500 : 900;
      var pr = (target / rb.size.width).clamp(1.0, 4.0).toDouble();
      Uint8List out;
      while (true) {
        final img = await rb.toImage(pixelRatio: pr);
        final bd = await img.toByteData(format: ui.ImageByteFormat.png);
        out = bd!.buffer.asUint8List();
        if (out.length < 9 * 1024 * 1024 || pr <= 1.0) break;
        pr = math.max(1.0, pr * 0.7);
      }
      if (!mounted) return;
      Navigator.pop(context, out);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      showMsg(context, 'خرابی: $e');
    }
  }

  Widget photo(ui.Image im) {
    final raw = RawImage(image: im, fit: BoxFit.fill);
    if (blur <= 0) return raw;
    final s = blur * 14;
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: s, sigmaY: s),
          child: raw,
        ),
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => const RadialGradient(
            radius: 0.7,
            colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
            stops: [0.0, 0.4, 0.8],
          ).createShader(r),
          child: raw,
        ),
      ],
    );
  }

  Widget controls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    enh == null && enhance
                        ? '✨ روشنی تیار ہو رہی ہے...'
                        : '✨ اندھیرے میں خودکار روشنی',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
              Switch(
                value: enhance,
                activeThumbColor: Colors.greenAccent,
                onChanged: (v) => setState(() => enhance = v),
              ),
            ],
          ),
          Row(
            children: [
              const Text('پس منظر دھندلا',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              Expanded(
                child: Slider(
                  value: blur,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => setState(() => blur = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = bytes;
    final cur = current;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('فلٹر چنیں'),
      ),
      body: (b == null || cur == null)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: ratio,
                      child: RepaintBoundary(
                        key: boundaryKey,
                        child: ColorFiltered(
                          colorFilter:
                              ColorFilter.matrix(photoFilters[sel].m),
                          child: photo(cur),
                        ),
                      ),
                    ),
                  ),
                ),
                controls(),
                SizedBox(
                  height: 112,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: photoFilters.length,
                    itemBuilder: (context, i) {
                      final f = photoFilters[i];
                      return GestureDetector(
                        onTap: () => setState(() => sel = i),
                        child: Container(
                          width: 78,
                          margin: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: i == sel
                                          ? Colors.greenAccent
                                          : Colors.transparent,
                                      width: 3),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.matrix(f.m),
                                    child: Image.memory(b,
                                        width: 64,
                                        height: 64,
                                        cacheWidth: 150,
                                        fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(f.name,
                                  style: TextStyle(
                                      color: i == sel
                                          ? Colors.greenAccent
                                          : Colors.white,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: green),
                      onPressed: busy ? null : done,
                      icon: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white))
                          : const Icon(Icons.check),
                      label: const Text('تیار ہے، آگے بڑھیں',
                          style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
