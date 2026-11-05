import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'cloud.dart';

export 'package:image_picker/image_picker.dart' show ImageSource;

Future<String?> pickAndUploadFrom(ImageSource source) async {
  final x = await ImagePicker()
      .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
  if (x == null) return null;
  final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'));
  req.fields['upload_preset'] = uploadPreset;
  req.files.add(await http.MultipartFile.fromPath('file', x.path));
  final res = await http.Response.fromStream(await req.send());
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error']?['message'] ?? 'اپلوڈ نہیں ہوا');
  }
  return data['secure_url'] as String?;
}
