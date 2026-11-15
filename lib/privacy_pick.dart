import 'package:flutter/material.dart';
import 'main.dart';

const _opts = [
  ['public', 'سب کے لیے کھلا', 'کوئی بھی مجھے ڈھونڈ کر پیغام بھیج سکتا ہے'],
  ['friends', 'صرف میرے دوست', 'سرچ میں آؤں گا، پر پیغام تبھی جب میں دوستی منظور کروں'],
  ['me', 'صرف میں', 'کوئی مجھے سرچ یا پیغام نہیں کر سکتا'],
];

// پرائیویسی کے فیلڈ جو یوزر ڈاک میں لکھنے ہیں
Map<String, dynamic> privacyFields(String v) =>
    {'privacy': v, 'discover': v != 'me'};

class PrivacyChoice extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const PrivacyChoice(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in _opts)
          Card(
            color: value == o[0] ? const Color(0xFFE3F5EC) : Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: value == o[0] ? green : Colors.black12,
                  width: value == o[0] ? 2 : 1),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                  value == o[0]
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: green),
              title: Text(o[1],
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text(o[2], style: const TextStyle(fontSize: 14)),
              onTap: () => onChanged(o[0]),
            ),
          ),
      ],
    );
  }
}
