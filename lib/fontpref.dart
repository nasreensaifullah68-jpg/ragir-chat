import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<double> typeSize = ValueNotifier<double>(20);

const _sizes = [17.0, 20.0, 25.0];
const _names = ['چھوٹا', 'درمیانہ', 'بڑا'];

Future<void> loadTypeSize() async {
  try {
    final p = await SharedPreferences.getInstance();
    typeSize.value = p.getDouble('typeSize') ?? 20;
  } catch (_) {}
}

Future<void> setTypeSize(double v) async {
  typeSize.value = v;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('typeSize', v);
  } catch (_) {}
}

String typeSizeName() {
  final i = _sizes.indexOf(typeSize.value);
  return i < 0 ? 'درمیانہ' : _names[i];
}

void pickTypeSize(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: ValueListenableBuilder<double>(
          valueListenable: typeSize,
          builder: (c, cur, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('لکھائی کا سائز',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ),
              for (var i = 0; i < 3; i++)
                ListTile(
                  title: Text(_names[i],
                      style: TextStyle(fontSize: _sizes[i])),
                  trailing: cur == _sizes[i]
                      ? const Icon(Icons.check_circle,
                          color: Colors.green)
                      : null,
                  onTap: () => setTypeSize(_sizes[i]),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

