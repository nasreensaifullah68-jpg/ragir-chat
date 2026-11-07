import 'dart:math' as math;
import 'package:flutter/material.dart';

class OrbitBadge extends StatefulWidget {
  final Widget child;
  final double size;
  const OrbitBadge({super.key, required this.child, this.size = 220});

  @override
  State<OrbitBadge> createState() => _OrbitBadgeState();
}

class _OrbitBadgeState extends State<OrbitBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController ctrl;

  static const icons = <IconData>[
    Icons.chat_bubble,
    Icons.call,
    Icons.photo_camera,
    Icons.mic,
    Icons.videocam,
    Icons.favorite,
    Icons.location_on,
    Icons.attach_file,
  ];
  static const colors = <Color>[
    Color(0xFF0F8A5F),
    Color(0xFF1E88E5),
    Color(0xFFE53935),
    Color(0xFFF9A825),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
    Color(0xFF00897B),
    Color(0xFF6D4C41),
  ];

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final r = s / 2 - 20;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (context, child) {
          final kids = <Widget>[
            Center(
              child: Container(
                width: r * 2,
                height: r * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x330F8A5F), width: 2),
                ),
              ),
            ),
            Center(child: child),
          ];
          for (var i = 0; i < icons.length; i++) {
            final a = ctrl.value * 2 * math.pi + i * 2 * math.pi / icons.length;
            kids.add(Positioned(
              left: s / 2 + r * math.cos(a) - 18,
              top: s / 2 + r * math.sin(a) - 18,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 4)
                  ],
                ),
                child: Icon(icons[i], color: Colors.white, size: 20),
              ),
            ));
          }
          return Stack(children: kids);
        },
        child: widget.child,
      ),
    );
  }
}
