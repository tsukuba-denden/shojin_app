import 'package:flutter/material.dart';
import '../widgets/tex_widget.dart';

class TexTestScreen extends StatelessWidget {
  const TexTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TeX表示テスト'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTestSection(
              'インライン数式',
              'この式 \$x = a + b\$ は足し算を表します。また、\$y \\leq 10\$ という制約があります。',
            ),
            _buildTestSection(
              'ディスプレイ数式',
              'この問題の解は次の式で表されます：\n\$\$x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}\$\$',
            ),
            _buildTestSection(
              '複数の数式',
              'まず \$n \\leq 10^5\$ とします。次に、総和は \$\\sum_{i=1}^{n} a_i\$ です。',
            ),
            _buildTestSection(
              'AtCoder風の制約',
              '制約：\n• \$1 \\leq N \\leq 2 \\times 10^5\$\n• \$1 \\leq A_i \\leq 10^9\$\n• \$\\sum A_i \\leq 10^{18}\$',
            ),
            _buildTestSection(
              'ギリシャ文字',
              '角度 \$\\theta\$ は \$0 \\leq \\theta \\leq \\pi\$ を満たします。また、\$\\alpha + \\beta = \\gamma\$ です。',
            ),
            _buildTestSection(
              '基本的なTeXコマンド',
              'a \\leq b, c \\geq d, e \\times f, g \\div h, \\pm 1, a \\neq b, x \\in S, A \\subset B',
            ),
            _buildTestSection(
              'コードブロック付き',
              '入力は以下の形式で与えられる：\n\n```\nN\nA_1 A_2 ... A_N\n```\n\nここで、\$1 \\leq N \\leq 10^5\$ です。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection(String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            TexWidget(content: content),
          ],
        ),
      ),
    );
  }
}
