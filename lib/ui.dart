import 'package:flutter/material.dart';
import 'main.dart';

const gold = Color(0xFFFFC107);

void soon(BuildContext context) {
  showMsg(context, 'یہ فیچر جلد آ رہا ہے');
}

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1FB27A), Color(0xFF0B5F52)],
        ),
        border: Border.all(color: gold, width: size * 0.07),
      ),
      child: Icon(Icons.chat_bubble_rounded,
          color: Colors.white, size: size * 0.52),
    );
  }
}

class PillTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;
  const PillTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = i == selected;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? green : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: on ? green : Colors.black12),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: on ? Colors.white : Colors.black54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
