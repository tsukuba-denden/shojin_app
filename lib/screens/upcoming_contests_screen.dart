import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contest.dart';
import '../providers/contest_provider.dart';

class UpcomingContestsScreen extends StatefulWidget {
  const UpcomingContestsScreen({super.key});

  @override
  State<UpcomingContestsScreen> createState() => _UpcomingContestsScreenState();
}

class _UpcomingContestsScreenState extends State<UpcomingContestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 初期化時にデータを取得
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContestProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今後のコンテスト'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ABC'),
            Tab(text: 'すべて'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ContestProvider>().refreshAll(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildABCTab(),
          _buildAllContestsTab(),
        ],
      ),
    );
  }

  Widget _buildABCTab() {
    return Consumer<ContestProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return _buildErrorWidget(provider.error!, () => provider.fetchUpcomingABCs());
        }

        final contests = provider.upcomingABCs;
        if (contests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('今後のABCが見つかりません'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.fetchUpcomingABCs(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contests.length,
            itemBuilder: (context, index) {
              return _buildContestCard(context, contests[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildAllContestsTab() {
    return Consumer<ContestProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return _buildErrorWidget(provider.error!, () => provider.fetchUpcomingContests());
        }

        final contests = provider.upcomingContests;
        if (contests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('今後のコンテストが見つかりません'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.fetchUpcomingContests(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contests.length,
            itemBuilder: (context, index) {
              return _buildContestCard(context, contests[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'エラーが発生しました',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContestCard(BuildContext context, Contest contest) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _launchURL(contest.url),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildContestTypeChip(context, contest),
                  const Spacer(),
                  Text(
                    contest.status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                contest.nameJa,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (contest.nameEn.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  contest.nameEn,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.event,
                contest.startTimeJapanese,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                Icons.timer,
                contest.durationString,
              ),
              if (contest.ratedRange != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  Icons.bar_chart,
                  'レート対象: ${contest.ratedRange}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContestTypeChip(BuildContext context, Contest contest) {
    final theme = Theme.of(context);
    
    String type = 'その他';
    Color color = theme.colorScheme.outline;
    
    if (contest.isABC) {
      type = 'ABC';
      color = Colors.green;
    } else if (contest.nameJa.contains('ARC') || contest.nameEn.contains('ARC')) {
      type = 'ARC';
      color = Colors.orange;
    } else if (contest.nameJa.contains('AGC') || contest.nameEn.contains('AGC')) {
      type = 'AGC';
      color = Colors.red;
    } else if (contest.nameJa.contains('AHC') || contest.nameEn.contains('AHC')) {
      type = 'AHC';
      color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        type,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URLを開けませんでした: $url')),
        );
      }
    }
  }
}
