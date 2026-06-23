import 'package:flutter/material.dart';
import 'package:mobileprogramming_p12/pages/home_page.dart'; // Pastikan path ini benar

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Saya',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false, 
      ),
      home: const HomePage(),
    );
  }
}