import 'package:flutter/material.dart';
import 'package:shojin_app/widgets/next_contest_card.dart'; // Add this line

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Remove const
      // appBar: AppBar(
      //   title: const Text('ホーム'),
      // ),
      body: ListView( // Change to ListView to accommodate multiple widgets
        children: const [
          NextContestCard(), // Add this line
          Center(
            child: Text(
              '新しいホーム画面',
              style: TextStyle(fontSize: 24),
            ),
          ),
        ],
      ),
    );
  }
}
