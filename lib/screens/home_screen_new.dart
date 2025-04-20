
import 'package:flutter/material.dart';

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // appBar: AppBar(
      //   title: const Text('ホーム'),
      // ),
      body: Center(
        child: Text(
          '新しいホーム画面',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
