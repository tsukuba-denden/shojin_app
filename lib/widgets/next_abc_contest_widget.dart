import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contest.dart';
import '../providers/contest_provider.dart';
import '../screens/upcoming_contests_screen.dart';

class NextABCContestWidget extends StatefulWidget {
  const NextABCContestWidget({super.key});

  @override
  State<NextABCContestWidget> createState() => _NextABCContestWidgetState();
}

class _NextABCContestWidgetState extends State<NextABCContestWidget> {
  @override
  void initState() {
    super.initState();
    // 初期化時に次回のABCを取得
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContestProvider>().fetchNextABC();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContestProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (provider.error != null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(
                    'コンテスト情報の取得に失敗しました',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => provider.fetchNextABC(),
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          );
        }

        final nextABC = provider.nextABC;
        if (nextABC == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.event_busy, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    '次回のABCが見つかりません',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        return _buildContestCard(context, nextABC);
      },
    );
  }

  Widget _buildContestCard(BuildContext context, Contest contest) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UpcomingContestsScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildContestTypeChip(context, contest),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.code,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '次回のABC',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
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
              const SizedBox(height: 12),              _buildInfoRow(
                context,
                Icons.event,
                '開始時刻',
                contest.startTimeWithWeekday,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                Icons.timer,
                '時間',
                contest.durationString,
              ),
              if (contest.ratedRange != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  Icons.bar_chart,
                  'レート対象',
                  contest.ratedRange!,
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'タップして今後のコンテストを見る',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }  Widget _buildContestTypeChip(BuildContext context, Contest contest) {
    final theme = Theme.of(context);
    
    String type = 'その他';
    Color color = theme.colorScheme.outline;
    
    // より確実な文字列マッチング
    final nameJa = contest.nameJa;
    final nameEn = contest.nameEn;
    
    if (contest.isABC || 
        nameJa.contains('Beginner Contest') || 
        nameEn.contains('Beginner Contest') ||
        nameJa.contains('AtCoder Beginner Contest') || 
        nameEn.contains('AtCoder Beginner Contest')) {
      type = 'ABC';
      color = Colors.green;
    } else if (nameJa.contains('Regular Contest') || 
               nameEn.contains('Regular Contest') ||
               nameJa.contains('AtCoder Regular Contest') || 
               nameEn.contains('AtCoder Regular Contest')) {
      type = 'ARC';
      color = Colors.orange;
    } else if (nameJa.contains('Grand Contest') || 
               nameEn.contains('Grand Contest') ||
               nameJa.contains('AtCoder Grand Contest') || 
               nameEn.contains('AtCoder Grand Contest')) {
      type = 'AGC';
      color = Colors.red;
    } else if (nameJa.contains('Heuristic Contest') || 
               nameEn.contains('Heuristic Contest') ||
               nameJa.contains('AtCoder Heuristic Contest') || 
               nameEn.contains('AtCoder Heuristic Contest')) {
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
}
