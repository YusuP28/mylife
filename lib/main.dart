import 'package:flutter/material.dart';

void main() {
  runApp(const MylifeApp());
}

class MylifeApp extends StatelessWidget {
  const MylifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mylife',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mylife App')),
      body: const Center(child: Text('Mylife App')),
    );
  }
}