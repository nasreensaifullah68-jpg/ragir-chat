import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'cloud.dart';
import 'main.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

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

List<double> satMatrix(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return [
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

class PhotoFilter {
  final String name;
  final List<double> m;
  const PhotoFilter(this.name, this.m);
}

final List<PhotoFilter> photoFilters = [
  const PhotoFilter('اصل', [
    1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]),
  PhotoFilter('چمکدار', satMatrix(1.6)),
  const PhotoFilter('روشن', [
    1.15, 0, 0, 0, 25, 0, 1.15, 0, 0, 25, 0, 0, 1.15, 0, 25, 0, 0, 0, 1, 0]),
  const PhotoFilter('گرم', [
    1.12, 0, 0, 0, 12, 0, 1.0, 0, 0, 0, 0, 0, 0.82, 0, 0, 0, 0, 0, 1, 0]),
  const PhotoFilter('ٹھنڈا', [
    0.88, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 1.18, 0, 12, 0, 0, 0, 1, 0]),
  const PhotoFilter('ڈرامائی', [
    1.4, 0, 0, 0, -51, 0, 1.4, 0, 0, -51, 0, 0, 1.4, 0, -51, 0, 0, 0, 1, 0]),
  const PhotoFilter('پرانا', [
    0.6, 0.35, 0.1, 0, 15, 0.25, 0.6, 0.1, 0, 10, 0.2, 0.3, 0.4, 0, 10,
    0, 0, 0, 1, 0]),
  const PhotoFilter('سیپیا', [
    0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534,
    0.131, 0, 0, 0, 0, 0, 1, 0]),
  const PhotoFilter('کالا سفید', [
    0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126,
    0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0]),
];

class FilterScreen extends StatefulWidget {
  final String path;
  const FilterScreen({super.key, required this.path});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final boundaryKey = GlobalKey();
  Uint8List? bytes;
  double ratio = 1;
  int sel = 0;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final b = await File(widget.path).readAsBytes();
    final im = await decodeImageFromList(b);
    if (!mounted) return;
    setState(() {
      bytes = b;
      ratio = im.width / im.height;
    });
  }

  Future<void> done() async {
    setState(() => busy = true);
    try {
      final rb = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final pr = (1200 / rb.size.width).clamp(1.0, 3.0);
      final img = await rb.toImage(pixelRatio: pr);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.pop(context, bd!.buffer.asUint8List());
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      showMsg(context, 'خرابی: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = bytes;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('فلٹر چنیں'),
      ),
      body: b == null
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
                          child: Image.memory(b, fit: BoxFit.fill),
                        ),
                      ),
                    ),
                  ),
                ),
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
