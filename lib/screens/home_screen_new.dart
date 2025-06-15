
import 'package:flutter/material.dart';
import '../widgets/next_abc_contest_widget.dart';

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NextABCContestWidget(),
            SizedBox(height: 16),
            // 他のウィジェットをここに追加可能
          ],
        ),
      ),
    );
  }
}
