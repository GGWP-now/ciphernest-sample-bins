import 'package:flutter/material.dart';

void main() {
  runApp(const VictimApp());
}

class VictimApp extends StatefulWidget {
  const VictimApp({super.key});

  @override
  State<VictimApp> createState() => _VictimAppState();
}

class _VictimAppState extends State<VictimApp> {
  final controller = TextEditingController(text: 'matrix-safe');

  String get digest {
    var hash = 2166136261;
    for (final unit in controller.text.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Victim',
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Windows Victim')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: controller, onChanged: (_) => setState(() {})),
              const SizedBox(height: 16),
              Text('${controller.text} -> $digest'),
            ],
          ),
        ),
      ),
    );
  }
}
