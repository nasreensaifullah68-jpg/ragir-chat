import 'package:cloud_firestore/cloud_firestore.dart';

String digitsOf(String s) {
  var d = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('00')) d = d.substring(2);
  return d;
}

// نمبر کے آخری 10 ہندسے (تاکہ 0300 اور +92300 دونوں ملیں)
String phoneKey(String s) {
  final d = digitsOf(s);
  return d.length > 10 ? d.substring(d.length - 10) : d;
}

void _prefixes(Set<String> k, String w) {
  for (var i = 3; i <= w.length; i++) {
    k.add(w.substring(0, i));
  }
}

List<String> makeKeys(String name, String email, String phone) {
  final k = <String>{};
  final mail = email.trim().toLowerCase();
  if (mail.isNotEmpty) {
    k.add(mail);
    _prefixes(k, mail.split('@').first);
  }
  for (final w in name.trim().toLowerCase().split(RegExp(r'\s+'))) {
    _prefixes(k, w);
  }
  final p = phoneKey(phone);
  if (p.length >= 7) k.add(p);
  return k.toList()..sort();
}

Future<void> syncKeys(DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> d, String authEmail) async {
  try {
    final mail =
        ((d['email'] as String?) ?? authEmail).trim().toLowerCase();
    final keys = makeKeys((d['name'] as String?) ?? '', mail,
        (d['phone'] as String?) ?? '');
    final old = ((d['keys'] as List?) ?? const [])
        .map((e) => '$e')
        .toList()
      ..sort();
    final up = <String, dynamic>{};
    if (old.join('|') != keys.join('|')) up['keys'] = keys;
    if (d['discover'] == null) up['discover'] = true;
    if (d['email'] == null && mail.isNotEmpty) up['email'] = mail;
    if (up.isNotEmpty) await ref.set(up, SetOptions(merge: true));
  } catch (_) {}
}
