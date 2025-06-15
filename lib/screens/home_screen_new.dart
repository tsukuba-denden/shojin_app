
import 'package:flutter/material.dart';
import '../widgets/next_abc_contest_widget.dart';
import '../widgets/shared/custom_sliver_app_bar.dart';

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [          CustomSliverAppBar(
            isMainView: true,
            title: const Text('ホーム'),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  NextABCContestWidget(),
                  SizedBox(height: 16),
                  // 他のウィジェットをここに追加可能
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
