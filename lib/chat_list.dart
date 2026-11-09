import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'avatar.dart';
import 'chat.dart';
import 'main.dart';
import 'ui.dart';

class _Row {
  final String id;
  final String otherId;
  final String otherName;
  final Map<String, dynamic> d;
  _Row(this.id, this.otherId, this.otherName, this.d);
}

class ChatList extends StatefulWidget {
  final String myId;
  final String query;
  final int filter;
  const ChatList({
    super.key,
    required this.myId,
    required this.query,
    required this.filter,
  });

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  Set<String> favs = {};

  @override
  void initState() {
    super.initState();
    loadFavs();
  }

  Future<void> loadFavs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => favs = (p.getStringList('fav') ?? []).toSet());
    } catch (_) {}
  }

  Future<void> toggleFav(String id) async {
    final on = !favs.contains(id);
    setState(() => on ? favs.add(id) : favs.remove(id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(on ? 'پسندیدہ میں شامل' : 'پسندیدہ سے ہٹا دیا'),
        duration: const Duration(seconds: 2)));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('fav', favs.toList());
    } catch (_) {}
  }

  String timeText(Timestamp? ts) {
    if (ts == null) return '';
    final l = ts.toDate().toLocal();
    final now = DateTime.now();
    final same = l.year == now.year && l.month == now.month && l.day == now.day;
    if (same) {
      final h = l.hour.toString().padLeft(2, '0');
      final m = l.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${l.day}/${l.month}';
  }

  Widget note(String t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, color: Colors.black54)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filter == 1) return note('گروپ چیٹ جلد آ رہی ہے');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: widget.myId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text('خرابی: ${snap.error}'),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = <_Row>[];
        for (final doc in snap.data!.docs) {
          final d = doc.data();
          final names = Map<String, dynamic>.from(d['names'] ?? {});
          final ids = List<String>.from(d['participants'] ?? []);
          final otherId = ids.firstWhere((x) => x != widget.myId, orElse: () => widget.myId);
          final otherName = (names[otherId] as String?) ?? 'نامعلوم';
          if (widget.query.isNotEmpty && !otherName.contains(widget.query)) continue;
          rows.add(_Row(doc.id, otherId, otherName, d));
        }
        if (widget.filter == 3) rows.removeWhere((r) => !favs.contains(r.id));
        rows.sort((a, b) {
          final fa = favs.contains(a.id) ? 1 : 0;
          final fb = favs.contains(b.id) ? 1 : 0;
          if (fa != fb) return fb - fa;
          final ta = a.d['updatedAt'] as Timestamp?;
          final tb = b.d['updatedAt'] as Timestamp?;
          return (tb?.millisecondsSinceEpoch ?? 0)
              .compareTo(ta?.millisecondsSinceEpoch ?? 0);
        });
        if (rows.isEmpty) {
          if (widget.filter == 3) {
            return note('کوئی پسندیدہ چیٹ نہیں۔\nکسی چیٹ کو دیر تک دبا کر ⭐ لگائیں');
          }
          return note(widget.query.isNotEmpty
              ? 'اس نام کی کوئی چیٹ نہیں ملی'
              : 'ابھی کوئی چیٹ نہیں۔\nاوپر کسی کا جی میل لکھ کر تلاش کریں');
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
          itemBuilder: (context, i) {
            final r = rows[i];
            final last = (r.d['lastMessage'] as String?) ?? 'پیغام لکھیں';
            final lastSender = r.d['lastSenderId'] as String?;
            final upd = r.d['updatedAt'] as Timestamp?;
            final lr = r.d['lastRead'] as Map<String, dynamic>?;
            final myRead = lr?[widget.myId] as Timestamp?;
            final unread = lastSender != null &&
                lastSender != widget.myId &&
                upd != null &&
                (myRead == null ||
                    myRead.millisecondsSinceEpoch < upd.millisecondsSinceEpoch);
            return ListTile(
              tileColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: UserAvatar(uid: r.otherId, name: r.otherName),
              title: Row(
                children: [
                  Flexible(
                    child: Text(r.otherName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 21, fontWeight: FontWeight.bold)),
                  ),
                  if (favs.contains(r.id))
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.star, color: gold, size: 20),
                    ),
                ],
              ),
              onLongPress: () => toggleFav(r.id),
              subtitle: Text(last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 17,
                      color: unread ? Colors.black : Colors.black54,
                      fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(timeText(upd),
                      style: TextStyle(
                          fontSize: 13,
                          color: unread ? green : Colors.black45)),
                  const SizedBox(height: 6),
                  unread
                      ? Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: green, shape: BoxShape.circle),
                        )
                      : const SizedBox(height: 16),
                ],
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(chatId: r.id, otherName: r.otherName))),
            );
          },
        );
      },
    );
  }
}
