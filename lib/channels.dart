import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'channel_page.dart';
import 'main.dart';

class ChannelsScreen extends StatefulWidget {
  final String name;
  const ChannelsScreen({super.key, required this.name});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final search = TextEditingController();
  String q = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> createChannel() async {
    final me = FirebaseAuth.instance.currentUser!;
    final nameC = TextEditingController();
    final aboutC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نیا چینل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              autofocus: true,
              maxLength: 40,
              style: const TextStyle(fontSize: 22),
              decoration: const InputDecoration(hintText: 'چینل کا نام'),
            ),
            TextField(
              controller: aboutC,
              maxLength: 120,
              maxLines: 2,
              style: const TextStyle(fontSize: 18),
              decoration:
                  const InputDecoration(hintText: 'چینل کے بارے میں (اختیاری)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('منسوخ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بنائیں'),
          ),
        ],
      ),
    );
    final cname = nameC.text.trim();
    final about = aboutC.text.trim();
    if (ok != true || cname.isEmpty) return;
    try {
      final ref = await FirebaseFirestore.instance.collection('channels').add({
        'name': cname,
        'about': about,
        'ownerId': me.uid,
        'ownerName': widget.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChannelPage(
              channelId: ref.id,
              name: cname,
              about: about,
              ownerId: me.uid,
              ownerName: widget.name)));
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: const Text('چینل',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: green,
        foregroundColor: Colors.white,
        onPressed: createChannel,
        icon: const Icon(Icons.add),
        label: const Text('نیا چینل بنائیں', style: TextStyle(fontSize: 20)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: TextField(
              controller: search,
              onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                hintText: 'چینل تلاش کریں',
                prefixIcon: const Icon(Icons.search, color: green),
                filled: true,
                fillColor: softBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('channels')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
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
                final docs = snap.data!.docs.where((d) {
                  final n = ((d.data()['name'] as String?) ?? '').toLowerCase();
                  return q.isEmpty || n.contains(q);
                }).toList();
                docs.sort((a, b) {
                  final am = a.data()['ownerId'] == myId ? 0 : 1;
                  final bm = b.data()['ownerId'] == myId ? 0 : 1;
                  return am.compareTo(bm);
                });
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'کوئی چینل نہیں ملا۔\nنیچے "نیا چینل بنائیں" دبائیں',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 22, color: Colors.black54)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 80),
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final cname = (d['name'] as String?) ?? '';
                    final about = (d['about'] as String?) ?? '';
                    final ownerName = (d['ownerName'] as String?) ?? '';
                    final ownerId = (d['ownerId'] as String?) ?? '';
                    return ListTile(
                      tileColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: green,
                        child: Text(cname.isEmpty ? '؟' : cname.substring(0, 1),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 24)),
                      ),
                      title: Text(cname,
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          about.isEmpty ? ownerName : '$ownerName • $about',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16)),
                      trailing: ownerId == myId
                          ? const Text('میرا',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: green,
                                  fontWeight: FontWeight.bold))
                          : null,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChannelPage(
                              channelId: docs[i].id,
                              name: cname,
                              about: about,
                              ownerId: ownerId,
                              ownerName: ownerName))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
