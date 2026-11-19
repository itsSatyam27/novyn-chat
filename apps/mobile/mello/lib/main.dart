import 'package:flutter/material.dart';

void main() {
  runApp(const MelloApp());
}

class MelloApp extends StatelessWidget {
  const MelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8F7F4);
    const accent = Color(0xFF7557E8);

    return MaterialApp(
      title: 'Mello',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          surface: background,
        ),
        fontFamily: 'Roboto',
      ),
      home: const MelloHomePage(),
    );
  }
}

class MelloHomePage extends StatelessWidget {
  const MelloHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE4FF),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    size: 42,
                    color: Color(0xFF7557E8),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'mello',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Little chats, big connections.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black54,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                const Text(
                  'A fresh start is on its way.',
                  style: TextStyle(color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
