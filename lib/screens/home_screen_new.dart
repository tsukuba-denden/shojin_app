import 'package:flutter/material.dart';
import 'package:shojin_app/screens/recommend_screen.dart';
import '../widgets/next_abc_contest_widget.dart';
import '../widgets/shared/custom_sliver_app_bar.dart';
import 'reminder_settings_screen.dart'; // Import reminder settings screen

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const CustomSliverAppBar(
            isMainView: true,
            title: Text('ホーム'),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const NextABCContestWidget(),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('リマインダー設定'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      textStyle: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const ReminderSettingsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.recommend),
                    label: const Text('おすすめ問題'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      textStyle: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RecommendScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
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
