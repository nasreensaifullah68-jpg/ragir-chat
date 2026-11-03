import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const cloudName = 'uczheqrk';
const uploadPreset = 'ragir_unsigned';

Future<String?> pickAndUploadPhoto() async {
  final x = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 1280, imageQuality: 70);
  if (x == null) return null;
  final uri =
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
  final req = http.MultipartRequest('POST', uri)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(await http.MultipartFile.fromPath('file', x.path));
  final res = await req.send();
  final body = await res.stream.bytesToString();
  final j = jsonDecode(body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    final err = j['error'];
    throw Exception(err is Map ? err['message'] : body);
  }
  return j['secure_url'] as String?;
}
