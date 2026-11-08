import 'dart:convert';
import 'package:crypto/crypto.dart';

Map<String, dynamic> iceConfig() {
  const h = 'staticauth.openrelay.metered.ca';
  final user = '${DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400}';
  final cred = base64.encode(Hmac(sha1, utf8.encode('openrelayprojectsecret'))
      .convert(utf8.encode(user))
      .bytes);
  return {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:$h:80',
        ]
      },
      {
        'urls': [
          'turn:$h:80',
          'turn:$h:80?transport=tcp',
          'turn:$h:443',
          'turns:$h:443?transport=tcp',
        ],
        'username': user,
        'credential': cred,
      },
    ],
    'sdpSemantics': 'unified-plan',
  };
}

String candType(String c) {
  if (c.contains(' typ relay')) return 'r';
  if (c.contains(' typ srflx')) return 's';
  return 'h';
}
