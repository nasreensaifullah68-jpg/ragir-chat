import 'package:flutter/material.dart';
import 'main.dart';
import 'ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool dark = false;

  Widget item(IconData icon, Color color, String text) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        title: Text(text, style: const TextStyle(fontSize: 21)),
        trailing: const Icon(Icons.chevron_left, color: Colors.black38),
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
            Text('سیٹنگز',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            Text('Settings', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          item(Icons.person, const Color(0xFF1E88E5), 'اکاؤنٹ کی معلومات'),
          item(Icons.notifications, const Color(0xFFE53935), 'نوٹیفکیشنز'),
          item(Icons.storage, const Color(0xFF43A047), 'ڈیٹا اور اسٹوریج'),
          item(Icons.lock, const Color(0xFF1E88E5), 'پرائیویسی'),
          item(Icons.security, const Color(0xFFEF6C00), 'سیکیورٹی'),
          item(Icons.palette, const Color(0xFF5E35B1), 'ظاہری شکل (تھیم)'),
          Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              secondary: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: const Color(0xFF3949AB),
                    borderRadius: BorderRadius.circular(12)),
                child:
                    const Icon(Icons.dark_mode, color: Colors.white, size: 28),
              ),
              title: const Text('ڈارک موڈ', style: TextStyle(fontSize: 21)),
              value: dark,
              onChanged: (v) {
                setState(() => dark = false);
                soon(context);
              },
            ),
          ),
          item(Icons.info, const Color(0xFF1E88E5), 'ایپ کے بارے میں'),
        ],
      ),
    );
  }
}
