import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'cloud.dart';
import 'main.dart';

Future<String?> chooseAttach(BuildContext context) {
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
            child: Text('کیا بھیجنا ہے؟',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          opt(ctx, Icons.picture_as_pdf, 'پی ڈی ایف فائل', 'pdf'),
          opt(ctx, Icons.location_on, 'میری موجودہ لوکیشن', 'location'),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<Map<String, String>?> pickAndUploadPdf() async {
  final r = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (r == null || r.isEmpty) return null;
  final f = r.first;
  if (f.path == null) return null;
  if (f.size > 10 * 1024 * 1024) {
    throw Exception('فائل 10 MB سے بڑی ہے');
  }
  final req = http.MultipartRequest('POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/raw/upload'));
  req.fields['upload_preset'] = uploadPreset;
  req.files.add(await http.MultipartFile.fromPath('file', f.path!));
  final res = await http.Response.fromStream(await req.send());
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error']?['message'] ?? 'اپلوڈ نہیں ہوا');
  }
  return {'url': data['secure_url'] as String, 'name': f.name};
}

Future<Position?> getMyPosition(BuildContext context) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (context.mounted) showMsg(context, 'فون کی لوکیشن (GPS) چالو کریں');
    return null;
  }
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) {
    p = await Geolocator.requestPermission();
  }
  if (p == LocationPermission.denied ||
      p == LocationPermission.deniedForever) {
    if (context.mounted) showMsg(context, 'لوکیشن کی اجازت نہیں ملی');
    return null;
  }
  return Geolocator.getCurrentPosition();
}

Future<void> openLink(BuildContext context, String url) async {
  try {
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showMsg(context, 'کھل نہیں سکا');
  } catch (e) {
    if (context.mounted) showMsg(context, 'خرابی: $e');
  }
}

class FileBubble extends StatelessWidget {
  final String url;
  final String name;
  const FileBubble({super.key, required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => openLink(context, url),
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.black12, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.red, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17)),
                    const Text('کھولنے کے لیے دبائیں',
                        style: TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationBubble extends StatelessWidget {
  final double lat;
  final double lng;
  const LocationBubble({super.key, required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => openLink(context, url),
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.black12, borderRadius: BorderRadius.circular(10)),
          child: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.red, size: 38),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('میری لوکیشن', style: TextStyle(fontSize: 18)),
                    Text('نقشے میں کھولیں',
                        style: TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> postMsg(DocumentReference<Map<String, dynamic>> chatRef,
    String uid, Map<String, dynamic> data, String last) async {
  await chatRef.collection('messages').add({
    'text': '',
    ...data,
    'senderId': uid,
    'createdAt': FieldValue.serverTimestamp(),
  });
  await chatRef.update({
    'lastMessage': last,
    'lastSenderId': uid,
    'updatedAt': FieldValue.serverTimestamp(),
    'lastRead.$uid': FieldValue.serverTimestamp(),
  });
}

Future<void> sendAttachment(BuildContext context,
    DocumentReference<Map<String, dynamic>> chatRef, String uid) async {
  final what = await chooseAttach(context);
  if (what == null) return;
  if (what == 'pdf') {
    final f = await pickAndUploadPdf();
    if (f != null) {
      await postMsg(chatRef, uid,
          {'fileUrl': f['url'], 'fileName': f['name']}, '📄 PDF');
    }
  } else {
    if (!context.mounted) return;
    final p = await getMyPosition(context);
    if (p != null) {
      await postMsg(
          chatRef, uid, {'lat': p.latitude, 'lng': p.longitude}, '📍 لوکیشن');
    }
  }
}

class AttachBubble extends StatelessWidget {
  final Map<String, dynamic> m;
  const AttachBubble({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (m['fileUrl'] != null)
          FileBubble(
              url: m['fileUrl'] as String,
              name: (m['fileName'] as String?) ?? 'PDF'),
        if (m['lat'] != null && m['lng'] != null)
          LocationBubble(
              lat: (m['lat'] as num).toDouble(),
              lng: (m['lng'] as num).toDouble()),
      ],
    );
  }
}
