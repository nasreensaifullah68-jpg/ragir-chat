import 'package:flutter/material.dart';
import 'main.dart';
import 'ui.dart';

class ContactScreen extends StatefulWidget {
  final void Function(String text) onFind;
  const ContactScreen({super.key, required this.onFind});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final c = TextEditingController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void go() {
    final mail = c.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      showMsg(context, 'پورا جی میل لکھیں، جیسے name@gmail.com');
      return;
    }
    Navigator.pop(context);
    widget.onFind(mail);
  }

  Widget action(IconData icon, Color color, String text) {
    return Card(
      color: const Color(0xFFEAF3FF),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, color: color, size: 36),
        title: Text(text, style: const TextStyle(fontSize: 21)),
        onTap: () => soon(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: green,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('نیا رابطہ',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            Text('New Contact', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.person_add_alt_1, size: 30),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: c,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => go(),
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              hintText: 'جی میل لکھیں (name@gmail.com)',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search, color: green, size: 28),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: go,
              icon: const Icon(Icons.chat),
              label: const Text('چیٹ شروع کریں',
                  style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 20),
          action(Icons.group_add, const Color(0xFF1E88E5), 'نیا گروپ بنائیں'),
          action(Icons.campaign, const Color(0xFF1E88E5), 'نیا چینل بنائیں'),
          action(Icons.qr_code_scanner, const Color(0xFF1E88E5),
              'QR کوڈ سے اسکین کریں'),
          const SizedBox(height: 14),
          const Text('تجویز کردہ دوست',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('یہ فہرست جلد آ رہی ہے',
              style: TextStyle(fontSize: 18, color: Colors.black54)),
        ],
      ),
    );
  }
}
