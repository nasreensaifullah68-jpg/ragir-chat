import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'avatar.dart';
import 'main.dart';

class MeTab extends StatelessWidget {
  final String name;
  final Future<void> Function() onLogout;
  const MeTab({super.key, required this.name, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(myId).snapshots(),
      builder: (context, snap) {
        final phone = (snap.data?.data()?['phone'] as String?) ?? '';
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () => changePhoto(context),
                child: UserAvatar(uid: myId, name: name, radius: 64),
              ),
            ),
            const SizedBox(height: 16),
            Text(name,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(phone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, color: Colors.black54)),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: () => changePhoto(context),
                icon: const Icon(Icons.photo_camera),
                label: const Text('میری فوٹو بدلیں',
                    style: TextStyle(fontSize: 21)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 58,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('باہر نکلیں', style: TextStyle(fontSize: 21)),
              ),
            ),
          ],
        );
      },
    );
  }
}
