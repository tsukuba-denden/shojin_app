import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// TeXコンテンツを解析して適切にレンダリングするウィジェット
class TexWidget extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;
  final double? mathTextScaleFactor;

  const TexWidget({
    super.key,
    required this.content,
    this.textStyle,
    this.mathTextScaleFactor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextStyle = textStyle ?? theme.textTheme.bodyMedium!;
    
    // TeX記法を検出するための正規表現
    final texPattern = RegExp(r'(\$\$[^$]+\$\$|\$[^$]+\$|\\[a-zA-Z]+(?:\{[^}]*\})*|\\[^a-zA-Z]?)');
    
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    
    for (final match in texPattern.allMatches(content)) {
      // マッチ前の通常テキストを追加
      if (match.start > lastEnd) {
        final text = content.substring(lastEnd, match.start);
        if (text.isNotEmpty) {
          spans.add(TextSpan(text: text, style: defaultTextStyle));
        }
      }
      
      final texContent = match.group(0)!;
      
      try {
        // 数式として解析を試みる
        Widget mathWidget;
        
        if (texContent.startsWith(r'$$') && texContent.endsWith(r'$$')) {
          // ディスプレイ数式 ($$...$$)
          final mathContent = texContent.substring(2, texContent.length - 2);
          mathWidget = Math.tex(
            mathContent,
            textStyle: defaultTextStyle.copyWith(
              fontSize: (defaultTextStyle.fontSize ?? 14) * (mathTextScaleFactor ?? 1.2),
            ),
            mathStyle: MathStyle.display,
          );
        } else if (texContent.startsWith(r'$') && texContent.endsWith(r'$')) {
          // インライン数式 ($...$)
          final mathContent = texContent.substring(1, texContent.length - 1);
          mathWidget = Math.tex(
            mathContent,
            textStyle: defaultTextStyle,
            mathStyle: MathStyle.text,
          );
        } else {
          // 単一のTeXコマンド
          final replacement = _getTexReplacement(texContent);
          if (replacement != null) {
            spans.add(TextSpan(text: replacement, style: defaultTextStyle));
            lastEnd = match.end;
            continue;
          } else {
            // TeXとして解析できない場合は通常テキストとして扱う
            spans.add(TextSpan(text: texContent, style: defaultTextStyle));
            lastEnd = match.end;
            continue;
          }
        }
        
        // 数式ウィジェットを埋め込む
        spans.add(WidgetSpan(
          child: mathWidget,
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
        ));
      } catch (e) {
        // 数式の解析に失敗した場合は基本的な置換を行う
        final replacement = _getTexReplacement(texContent);
        spans.add(TextSpan(
          text: replacement ?? texContent,
          style: defaultTextStyle,
        ));
      }
      
      lastEnd = match.end;
    }
    
    // 残りのテキストを追加
    if (lastEnd < content.length) {
      final text = content.substring(lastEnd);
      if (text.isNotEmpty) {
        spans.add(TextSpan(text: text, style: defaultTextStyle));
      }
    }
    
    // スパンがない場合は通常のテキストとして表示
    if (spans.isEmpty) {
      return Text(content, style: defaultTextStyle);
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// 基本的なTeXコマンドをUnicode文字に置換
  String? _getTexReplacement(String tex) {
    switch (tex) {
      case r'\leq':
      case r'\le':
        return '≤';
      case r'\geq':
      case r'\ge':
        return '≥';
      case r'\times':
        return '×';
      case r'\div':
        return '÷';
      case r'\pm':
        return '±';
      case r'\mp':
        return '∓';
      case r'\neq':
      case r'\ne':
        return '≠';
      case r'\approx':
        return '≈';
      case r'\equiv':
        return '≡';
      case r'\sim':
        return '∼';
      case r'\propto':
        return '∝';
      case r'\infty':
        return '∞';
      case r'\partial':
        return '∂';
      case r'\nabla':
        return '∇';
      case r'\int':
        return '∫';
      case r'\sum':
        return '∑';
      case r'\prod':
        return '∏';
      case r'\sqrt':
        return '√';
      case r'\angle':
        return '∠';
      case r'\perp':
        return '⊥';
      case r'\parallel':
        return '∥';
      case r'\in':
        return '∈';
      case r'\notin':
        return '∉';
      case r'\subset':
        return '⊂';
      case r'\supset':
        return '⊃';
      case r'\subseteq':
        return '⊆';
      case r'\supseteq':
        return '⊇';
      case r'\cup':
        return '∪';
      case r'\cap':
        return '∩';
      case r'\emptyset':
        return '∅';
      case r'\forall':
        return '∀';
      case r'\exists':
        return '∃';
      case r'\alpha':
        return 'α';
      case r'\beta':
        return 'β';
      case r'\gamma':
        return 'γ';
      case r'\delta':
        return 'δ';
      case r'\epsilon':
        return 'ε';
      case r'\zeta':
        return 'ζ';
      case r'\eta':
        return 'η';
      case r'\theta':
        return 'θ';
      case r'\lambda':
        return 'λ';
      case r'\mu':
        return 'μ';
      case r'\pi':
        return 'π';
      case r'\sigma':
        return 'σ';
      case r'\phi':
        return 'φ';
      case r'\omega':
        return 'ω';
      case r'\Gamma':
        return 'Γ';
      case r'\Delta':
        return 'Δ';
      case r'\Theta':
        return 'Θ';
      case r'\Lambda':
        return 'Λ';
      case r'\Pi':
        return 'Π';
      case r'\Sigma':
        return 'Σ';
      case r'\Phi':
        return 'Φ';
      case r'\Omega':
        return 'Ω';
      case r'\dots':
      case r'\ldots':
        return '…';
      case r'\cdots':
        return '⋯';
      case r'\vdots':
        return '⋮';
      case r'\ddots':
        return '⋱';
      default:
        return null;
    }
  }
}

/// TeXコンテンツ専用のウィジェット（複数行対応）
class TexDocument extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;
  final double? mathTextScaleFactor;

  const TexDocument({
    super.key,
    required this.content,
    this.textStyle,
    this.mathTextScaleFactor,
  });

  @override
  Widget build(BuildContext context) {
    // 改行で分割してそれぞれを処理
    final lines = content.split('\n');
    final widgets = <Widget>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else {
        widgets.add(TexWidget(
          content: line,
          textStyle: textStyle,
          mathTextScaleFactor: mathTextScaleFactor,
        ));
        if (i < lines.length - 1) {
          widgets.add(const SizedBox(height: 4));
        }
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
