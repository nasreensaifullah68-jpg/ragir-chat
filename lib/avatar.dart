import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'main.dart';

class UserAvatar extends StatelessWidget {
  final String uid;
  final String name;
  final double radius;
  const UserAvatar(
      {super.key, required this.uid, required this.name, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '؟' : name.substring(0, 1);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final photo = snap.data?.data()?['photo'] as String?;
        ImageProvider? img;
        if (photo != null && photo.isNotEmpty) {
          try {
            img = MemoryImage(base64Decode(photo));
          } catch (_) {}
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: green,
          backgroundImage: img,
          child: img == null
              ? Text(letter,
                  style: TextStyle(color: Colors.white, fontSize: radius * 0.85))
              : null,
        );
      },
    );
  }
}

Future<void> changePhoto(BuildContext context) async {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null) return;
  try {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 60);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await FirebaseFirestore.instance.collection('users').doc(me.uid).set({
      'photo': base64Encode(bytes),
    }, SetOptions(merge: true));
    if (!context.mounted) return;
    showMsg(context, 'فوٹو لگ گئی');
  } catch (e) {
    if (!context.mounted) return;
    showMsg(context, 'خرابی: $e');
  }
}
