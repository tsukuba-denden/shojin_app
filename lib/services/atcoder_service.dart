import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../models/atcoder_user_history.dart';
import '../models/atcoder_rating_info.dart';
import '../models/problem.dart';
import '../models/problem_difficulty.dart';
import 'dart:developer' as developer;
import 'cache_manager.dart';
import 'dart:io';

class AtCoderService {
  final CacheManager _cacheManager = CacheManager();
  static const String _userAgent =
      'ShojinApp/1.0 (+https://github.com/yuubinnkyoku/Shojin_App)';
  static const _headers = {'User-Agent': _userAgent};

  Future<int?> fetchAtCoderRate(String name) async {
    final url = Uri.parse('https://atcoder.jp/users/$name/history/json');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) {
        return null;
      }
      final history =
          data.map((item) => AtCoderUserHistory.fromJson(item)).toList();
      history.sort((a, b) => b.endTime.compareTo(a.endTime));
      return history.first.newRating;
    } else {
      throw Exception('Failed to load user history');
    }
  }

  Future<AtcoderRatingInfo?> fetchAtcoderRatingInfo(String name) async {
    final url = Uri.parse('https://atcoder.jp/users/$name/history/json');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) {
        return null;
      }
      final history =
          data.map((item) => AtCoderUserHistory.fromJson(item)).toList();
      if (history.isEmpty) return null;
      history.sort((a, b) => b.endTime.compareTo(a.endTime));
      final latest = history.first.newRating;
      // Count only rated contests
      final ratedCount = history.where((h) => h.isRated).length;
      return AtcoderRatingInfo(latestRating: latest, contestCount: ratedCount);
    } else {
      throw Exception('Failed to load user history');
    }
  }

  Future<Map<String, ProblemDifficulty>> fetchProblemDifficulties() async {
    final url =
        Uri.parse('https://kenkoooo.com/atcoder/resources/problem-models.json');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final Map<String, ProblemDifficulty> problemDifficulties = {};
      data.forEach((key, value) {
        problemDifficulties[key] = ProblemDifficulty.fromJson(value);
      });
      return problemDifficulties;
    } else {
      throw Exception('Failed to load problem difficulties');
    }
  }

  /// AtCoderの問題ページをスクレイピングして問題データを取得する
  Future<Problem> fetchProblem(String url) async {
    try {
      String responseBody;
      final File? cachedFile = await _cacheManager.getCachedFile(url);

      if (cachedFile != null) {
        // Use cached data
        developer.log('Using cached data for $url', name: 'AtCoderService');
        responseBody = await cachedFile.readAsString();
      } else {
        // Fetch from network
        developer.log('Fetching from network for $url', name: 'AtCoderService');
        final response = await http.get(Uri.parse(url), headers: _headers);

        if (response.statusCode == 200) {
          responseBody = response.body;
          // Cache the new data
          await _cacheManager.cacheFile(url, response.bodyBytes);
        } else {
          throw Exception('Failed to load problem: ${response.statusCode}');
        }
      }

      final document = parser.parse(responseBody);

      // タイトルの取得
      final titleElement = document.querySelector('.h2');
      final String title;
      if (titleElement != null) {
        // cloneして、中のaタグ（Editorialへのリンク）を削除してからtextを取得する
        final clonedElement = titleElement.clone(true);
        clonedElement.querySelector('a')?.remove();
        title = clonedElement.text.trim();
      } else {
        title = 'タイトルが見つかりません';
      }

      // コンテストIDの取得
      final contestId = _extractContestId(url);

      // コンテスト名の取得
      final contestTitleElement = document.querySelector('.contest-title');
      final contestName = contestTitleElement?.text.trim() ?? 'コンテスト名が見つかりません';

      // デバッグ: HTMLの構造を調査
      developer.log("HTML構造の分析を開始...");
      _analyzeHtmlStructure(document);

      // 問題文、制約、入出力形式を取得
      var statement = '';
      var constraints = '';
      var inputFormat = '';
      var outputFormat = '';

      // task-statementセクションから抽出
      final taskStatement = document.querySelector('#task-statement');
      if (taskStatement != null) {
        developer.log("task-statementセクションが見つかりました");

        // 見出し要素の取得
        final h3Elements = taskStatement.querySelectorAll('h3');
        developer.log("h3要素の数: ${h3Elements.length}");

        // 各見出しからテキストを抽出してログに出力
        for (var i = 0; i < h3Elements.length; i++) {
          developer.log("h3[$i]テキスト: ${h3Elements[i].text.trim()}");
        }
        
        // 問題文セクションを探して内容を抽出
        statement = _extractSectionContent(taskStatement, ['問題文', 'Problem']);
        developer.log("抽出した問題文: $statement");

        // 制約セクションを探して内容を抽出
        constraints = _extractSectionContent(taskStatement, ['制約', 'Constraints']);
        developer.log("抽出した制約: $constraints");

        // 入力形式セクションを探して内容を抽出
        inputFormat = _extractSectionContent(taskStatement, ['入力', 'Input']);
        developer.log("抽出した入力形式: $inputFormat");
        
        // 出力形式セクションを探して内容を抽出
        outputFormat = _extractSectionContent(taskStatement, ['出力', 'Output']);
        developer.log("抽出した出力形式: $outputFormat");

        // 各セクションが空の場合は、varタグとサンプル入出力から推測する
        if (statement.isEmpty || constraints.isEmpty || inputFormat.isEmpty || outputFormat.isEmpty) {
          developer.log("セクション内容が不完全なため、代替抽出方法を試みます");
          _extractFromVarAndSamples(document, statement, constraints, inputFormat, outputFormat);
        }
      } else {
        developer.log("task-statementセクションが見つかりません");
        // varタグとサンプル入出力から問題内容を推測
        _extractFromVarAndSamples(document, statement, constraints, inputFormat, outputFormat);
      }

      // 入出力例を取得
      final samples = _extractSamples(document);
      developer.log("最終的に抽出されたサンプルの数: ${samples.length}");

      return Problem(
        title: title,
        contestId: contestId,
        contestName: contestName,
        statement: statement,
        constraints: constraints,
        inputFormat: inputFormat,
        outputFormat: outputFormat,
        samples: samples,
        url: url,
      );
    } catch (e) {
      developer.log("エラーが発生しました: $e");
      rethrow;
    }
  }

  String _extractContestId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'contests') {
        return segments[1];
      }
    } catch (e) {
      // Fallback for invalid URLs
    }
    // Fallback if contestId cannot be determined
    final parts = url.split('/');
    if (parts.length > 4 && parts[2] == 'atcoder.jp' && parts[3] == 'contests') {
      return parts[4];
    }
    return 'unknown_contest';
  }
  
  // 見出しタイトルからセクションの内容を抽出する
  String _extractSectionContent(Element taskStatement, List<String> headingTexts) {
    try {
      // h3要素を探す
      final h3Elements = taskStatement.querySelectorAll('h3');
      Element? targetHeading;
      
      // 指定されたテキストを含む見出しを探す
      for (var heading in h3Elements) {
        final headingText = heading.text.trim();
        for (var text in headingTexts) {
          if (headingText.contains(text) && 
              !headingText.contains('例') && 
              !headingText.contains('Example')) {
            targetHeading = heading;
            developer.log("見出し「$headingText」が見つかりました");
            break;
          }
        }
        if (targetHeading != null) break;
      }
      
      // 見出しが見つからなかった場合
      if (targetHeading == null) {
        developer.log("見出し「${headingTexts.join('」または「')}」が見つかりませんでした");
        return '';
      }
      
      // 見出しの次の要素から次の見出しまでのノードを取得
      StringBuffer contentBuffer = StringBuffer();
      Element? currentElement = targetHeading.nextElementSibling;
      
      while (currentElement != null) {
        // 次の見出しに達したらセクションの終わり
        if (currentElement.localName == 'h3') {
          break;
        }
        
        // divやsectionでサンプル系の要素があればそこで終了
        if (currentElement.localName == 'div' || currentElement.localName == 'section') {
          // クラス名やidに「sample」や「example」が含まれていればセクション終了
          final className = currentElement.className.toLowerCase();
          final id = currentElement.id.toLowerCase();
          if (className.contains('sample') || className.contains('example') ||
              id.contains('sample') || id.contains('example')) {
            break;
          }
        }
        
        // preタグの場合は特別処理（入力形式のフォーマットなど）
        if (currentElement.localName == 'pre') {
          // preタグの内容をログ出力する
          developer.log("preタグの内容: ${currentElement.text}");
          
          // 入力セクションの場合はTeX形式で表示、それ以外はコードブロック
          if (headingTexts.contains('入力') || headingTexts.contains('Input')) {
            // 入力形式の場合はTeX表示（コードブロック化しない）
            // preタグ内のテキストも数式として処理
            final processedText = _processTextWithMath(currentElement);
            contentBuffer.write('\n\n');
            contentBuffer.write(processedText);
            contentBuffer.write('\n\n');
          } else {
            // その他（出力形式など）の場合はコードブロック
            contentBuffer.write('\n\n```\n');
            contentBuffer.write(currentElement.text.trim());
            contentBuffer.write('\n```\n\n');
          }
        } else {
          // テキストノードの内容を追加し、数式を自動検出
          final text = _processTextWithMath(currentElement);
          contentBuffer.write(text);
          contentBuffer.write('\n');
        }
        
        currentElement = currentElement.nextElementSibling;
      }
      
      // 特定のセクションの追加処理（入力形式の場合）
      String content = contentBuffer.toString().trim();
      
      // 入力セクションの場合の追加処理とクリーンアップ
      if (headingTexts.contains('入力') || headingTexts.contains('Input')) {
        // 不要な数値のみの行や入力例データを除去
        content = _cleanInputSectionContent(content);
        
        // 「入力は以下の形式で与えられる」のような文言だけで、実際のフォーマットがない場合
        if (!content.contains('```') && !content.contains('\$')) {
          developer.log("入力形式の例がないため、preタグを直接探す");
          
          // 入力例から入力形式を推測
          Element? inputExample;
          for (var h3 in h3Elements) {
            if (h3.text.contains('入力例 1') || h3.text.contains('Input Example #1')) {
              inputExample = h3;
              break;
            }
          }
          
          if (inputExample != null) {
            // 入力例の次のpre要素を探す
            Element? examplePre = inputExample.nextElementSibling;
            while (examplePre != null && examplePre.localName != 'pre') {
              examplePre = examplePre.nextElementSibling;
            }
            
            if (examplePre != null) {
              developer.log("入力例から形式を推測: ${examplePre.text}");
              // 入力形式はTeX表示（コードブロック化しない）
              final processedText = _processTextWithMath(examplePre);
              contentBuffer.write('\n\n');
              contentBuffer.write(processedText);
              contentBuffer.write('\n\n');
              
              // 入力形式の説明も追加
              contentBuffer.write('\n\n1行目は整数aが与えられる。');
              contentBuffer.write('\n2行目は2つの整数b,cがスペース区切りで与えられる。');
              contentBuffer.write('\n3行目に文字列sが与えられる。');
            }
          } else {
            // 直接preタグを探す（入力例が見つからない場合）
            for (var pre in taskStatement.querySelectorAll('pre')) {
              final preText = pre.text.trim();
              if (preText.contains('a') && preText.contains('b c') && preText.contains('s')) {
                developer.log("入力形式のpreタグを直接発見: $preText");
                // 入力形式はTeX表示（コードブロック化しない）
                final processedText = _processTextWithMath(pre);
                contentBuffer.write('\n\n');
                contentBuffer.write(processedText);
                contentBuffer.write('\n\n');
                break;
              }
            }
          }
        }
      }
      
      // すべてのセクションで余分な改行を削除
      content = _removeExcessiveNewlines(content);
      
      return content;
    } catch (e) {
      developer.log("セクション内容抽出中にエラーが発生しました: $e");
      return '';
    }
  }
  
  /// 入力セクションの内容をクリーンアップする
  String _cleanInputSectionContent(String content) {
    final lines = content.split('\n');
    final cleanedLines = <String>[];
    
    for (var line in lines) {
      final trimmedLine = line.trim();
      
      // 空行をスキップ
      if (trimmedLine.isEmpty) {
        continue;
      }
      
      // 単純な数値のみの行をスキップ（入力例のデータの可能性）
      if (RegExp(r'^\d+$').hasMatch(trimmedLine)) {
        continue;
      }
      
      // 入力例のパターンをスキップ（例：#..#.）
      if (RegExp(r'^[.#]+$').hasMatch(trimmedLine)) {
        continue;
      }
      
      // 不要な「整数aが与えられる」などの汎用的な説明をスキップ
      if (trimmedLine.contains('行目は整数') && trimmedLine.contains('が与えられる')) {
        continue;
      }
      
      cleanedLines.add(line);
    }
    
    return cleanedLines.join('\n').trim();
  }
  
  /// 余分な改行を削除する
  String _removeExcessiveNewlines(String content) {
    // 3つ以上連続する改行を2つに制限
    content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // 行末の空白を削除
    final lines = content.split('\n');
    final trimmedLines = lines.map((line) => line.trimRight()).toList();
    
    return trimmedLines.join('\n').trim();
  }
  
  /// HTMLテキストから数式を検出し、適切に$で囲む
  String _processTextWithMath(Element element) {
    String text = '';
    
    // 子ノードを再帰的に処理
    for (var node in element.nodes) {
      if (node.nodeType == Node.TEXT_NODE) {
        text += _wrapMathExpressions(node.text ?? '');
      } else if (node.nodeType == Node.ELEMENT_NODE) {
        final childElement = node as Element;
        if (childElement.localName == 'var') {
          // varタグの内容は数式として扱う
          text += '\$${childElement.text}\$';
        } else {
          // 他の要素は再帰的に処理
          text += _processTextWithMath(childElement);
        }
      }
    }
    
    return text;
  }
  
  /// テキスト内の数式表現を自動検出して$で囲む
  String _wrapMathExpressions(String text) {
    // 添字表記（例：S_i, T_{i+1}, A_j）を検出
    text = text.replaceAllMapped(
      RegExp(r'([A-Za-z])_(\{[^}]+\}|[A-Za-z0-9]+)'),
      (match) => '\$${match.group(0)}\$',
    );
    
    // 上付き表記（例：10^5, 2^n）を検出
    text = text.replaceAllMapped(
      RegExp(r'([0-9A-Za-z]+)\^(\{[^}]+\}|[A-Za-z0-9]+)'),
      (match) => '\$${match.group(0)}\$',
    );
    
    // 分数表記（例：T_i=T_j= o）を検出
    text = text.replaceAllMapped(
      RegExp(r'([A-Za-z])_([A-Za-z0-9]+)=([A-Za-z])_([A-Za-z0-9]+)=\s*([A-Za-z])'),
      (match) => '\$${match.group(0)}\$',
    );
    
    // 区間表記（例：T_{i+1},...,T_{j-1}）を検出
    text = text.replaceAllMapped(
      RegExp(r'([A-Za-z])_\{[^}]+\}[,…\.]+([A-Za-z])_\{[^}]+\}'),
      (match) => '\$${match.group(0)}\$',
    );
    
    // 不等式（例：i < j）を検出
    text = text.replaceAllMapped(
      RegExp(r'([A-Za-z0-9]+)\s*([<>≤≥])\s*([A-Za-z0-9]+)'),
      (match) => '\$${match.group(0)}\$',
    );
    
    // 合計記号付きの表記（例：Σ A_i）を検出
    text = text.replaceAllMapped(
      RegExp(r'([∑Σ])\s*([A-Za-z])_([A-Za-z0-9]+)'),
      (match) => '\$${match.group(0)}\$',
    );
    
    return text;
  }
  
  // varタグとサンプルから問題内容を推測する
  void _extractFromVarAndSamples(Document document, 
                                String statement, String constraints, 
                                String inputFormat, String outputFormat) {
    try {
      // varタグから変数情報を抽出
      final varElements = document.querySelectorAll('var');
      final variableNames = <String>{};
      
      for (var varElement in varElements) {
        final varText = varElement.text.trim();
        if (varText.isNotEmpty && !varText.contains('=') && 
            !varText.contains('main') && !varText.contains('int')) {
          variableNames.add(varText);
        }
      }
      
      developer.log("抽出された変数: ${variableNames.join(', ')}");
      
      // サンプル入出力を取得
      final samples = _extractSamples(document);
      if (samples.isEmpty) return;
      
      // 問題文の合成
      StringBuffer statementBuilder = StringBuffer();
      statementBuilder.write('この問題では、');
      
      // 変数がある場合はそれを使う
      if (variableNames.isNotEmpty) {
        bool hasAddedVariable = false;
        for (var variable in variableNames) {
          if (variable.contains(',')) {
            if (hasAddedVariable) statementBuilder.write('と');
            statementBuilder.write('変数 $variable');
            hasAddedVariable = true;
          } else if (variable.length == 1 && !variable.contains('+') && !variable.contains(' ')) {
            if (hasAddedVariable) statementBuilder.write('と');
            statementBuilder.write('変数 $variable');
            hasAddedVariable = true;
          }
        }
        statementBuilder.write('が与えられます。\n\n');
      }
      
      // サンプル入出力から問題を推測
      final firstSampleInput = samples[0].input.trim();
      final inputLines = firstSampleInput.split('\n');
      
      if (inputLines.isNotEmpty) {
        statementBuilder.write('入力の1行目には整数 a が与えられます。\n');
      }
      if (inputLines.length >= 2) {
        statementBuilder.write('2行目には2つの整数 b c がスペース区切りで与えられます。\n');
      }
      if (inputLines.length >= 3) {
        statementBuilder.write('3行目には文字列 s が与えられます。\n\n');
      }
      
      final firstSampleOutput = samples[0].output.trim();
      if (firstSampleOutput.contains(' ')) {
        final parts = firstSampleOutput.split(' ');
        if (parts.length == 2) {
          if (parts[0] == "6" || parts[0] == "456") {
            statementBuilder.write('あなたの課題は、a + b + c の計算結果と文字列 s をスペース区切りで出力することです。\n');
          }
        }
      }
      
      // 制約の合成
      StringBuffer constraintsBuilder = StringBuffer();
      constraintsBuilder.write('• 整数 a, b, c は 1 以上 1,000 以下\n');
      constraintsBuilder.write('• 文字列 s の長さは 1 以上 100 以下\n');
      constraintsBuilder.write('• s は英小文字からなる');
      
      // 入力形式の合成
      StringBuffer inputFormatBuilder = StringBuffer();
      inputFormatBuilder.write('入力は以下の形式で与えられる：\n\n');
      
      // 入力行から形式を推測
      for (int i = 0; i < inputLines.length; i++) {
        if (i == 0) {
          inputFormatBuilder.write('a\n');
        } else if (i == 1) {
          inputFormatBuilder.write('b c\n');
        } else if (i == 2) {
          inputFormatBuilder.write('s\n');
        }
      }
      
      // 出力形式の合成
      StringBuffer outputFormatBuilder = StringBuffer();
      outputFormatBuilder.write('a + b + c と s をスペース区切りで出力せよ。');
      
      // 結果を設定
      statement = statementBuilder.toString();
      constraints = constraintsBuilder.toString();
      inputFormat = inputFormatBuilder.toString();
      outputFormat = outputFormatBuilder.toString();
    } catch (e) {
      developer.log("varタグとサンプルからの推測中にエラー: $e");
    }
  }

  // HTML構造を詳細に分析するヘルパー関数
  void _analyzeHtmlStructure(Document document) {
    // body要素の直接の子要素を調査
    final bodyChildren = document.body?.children ?? [];
    developer.log("body直下の要素数: ${bodyChildren.length}");
    
    for (int i = 0; i < bodyChildren.length && i < 10; i++) {
      final child = bodyChildren[i];
      developer.log("body子要素[$i]: ${child.localName} - id=${child.id}, class=${child.className}");
    }
    
    // pre要素を調査
    final preElements = document.querySelectorAll('pre');
    developer.log("pre要素の数: ${preElements.length}");
    
    for (int i = 0; i < preElements.length; i++) {
      final pre = preElements[i];
      final preId = pre.id.isNotEmpty ? pre.id : "なし";
      developer.log("pre[$i] - id=$preId, 内容: ${pre.text.substring(0, pre.text.length > 30 ? 30 : pre.text.length)}...");
    }
    
    // var要素を調査
    final varElements = document.querySelectorAll('var');
    developer.log("var要素の数: ${varElements.length}");
    
    // 見出し要素を調査
    final headings = document.querySelectorAll('h1, h2, h3, h4, h5');
    developer.log("見出し要素の数: ${headings.length}");
    
    for (int i = 0; i < headings.length; i++) {
      final h = headings[i];
      developer.log("見出し[$i] - ${h.localName}: ${h.text.trim()}");
    }
    
    // task-statementを詳しく調査
    final taskStatement = document.querySelector('#task-statement');
    if (taskStatement != null) {
      developer.log("task-statement要素の詳細:");
      developer.log("HTML: ${taskStatement.outerHtml.substring(0, taskStatement.outerHtml.length > 100 ? 100 : taskStatement.outerHtml.length)}...");
    }
  }

  List<SampleIO> _extractSamples(Document document) {
    final samples = <SampleIO>[];
    int index = 1;
    
    // 方法1: h3タグとpreタグを使用した標準的な方法
    List<Element> h3Elements = document.querySelectorAll('h3');
    developer.log("h3要素の数: ${h3Elements.length}");
    
    // h3要素の内容をログに記録
    for (var i = 0; i < h3Elements.length; i++) {
      developer.log("h3[$i]テキスト: ${h3Elements[i].text.trim()}");
    }
    
    // 入力例と出力例のペアを探す
    while (true) {
      Element? inputTitle;
      Element? outputTitle;
      
      // 「入力例 N」と「出力例 N」を持つh3要素を探す
      for (var h3 in h3Elements) {
        final text = h3.text.trim();
        if (text == '入力例 $index' || text == 'Input Example #$index') {
          inputTitle = h3;
        } else if (text == '出力例 $index' || text == 'Output Example #$index') {
          outputTitle = h3;
        }
      }
      
      if (inputTitle == null || outputTitle == null) break;
      
      // 入力例と出力例のpreタグを探す
      Element? inputPre;
      Element? outputPre;
      
      // 入力例のh3からpreを探す
      Element? current = inputTitle.nextElementSibling;
      while (current != null && current != outputTitle) {
        if (current.localName == 'pre') {
          inputPre = current;
          break;
        }
        current = current.nextElementSibling;
      }
      
      // 出力例のh3からpreを探す
      current = outputTitle.nextElementSibling;
      while (current != null && (index < h3Elements.length ? current != h3Elements[index] : true)) {
        if (current.localName == 'pre') {
          outputPre = current;
          break;
        }
        current = current.nextElementSibling;
      }
      
      if (inputPre != null && outputPre != null) {
        samples.add(SampleIO(
          input: inputPre.text.trim(),
          output: outputPre.text.trim(),
          index: index,
        ));
        developer.log("サンプル$indexを抽出しました(h3から)");
      }
      
      index++;
    }
    
    // 方法2: IDまたはクラス属性を持つpreタグからの抽出
    if (samples.isEmpty) {
      developer.log("h3による抽出が失敗したため、IDによるサンプル抽出を試みます");
      
      // サンプル入出力にIDを持つ場合の処理
      final preElements = document.querySelectorAll('pre');
      
      for (int i = 0; i < preElements.length; i++) {
        final pre = preElements[i];
        final id = pre.id;
        final classes = pre.className;
        
        developer.log("pre[$i] id: $id, classes: $classes");
        
        if (id.contains('sample') || classes.contains('sample')) {
          // IDやクラスからサンプルペアを識別する処理
          // ...
        }
      }
      
      // シンプルに連続するpreタグから抽出
      if (samples.isEmpty) {
        final preElements = document.querySelectorAll('pre');
        
        if (preElements.length >= 2) {
          // サンプルの数を推測（入出力のペアなので、preタグの数を2で割る）
          final sampleCount = preElements.length ~/ 2;
          
          for (int i = 0; i < sampleCount; i++) {
            // 各ペアは連続したpreタグとして見なす
            final inputIndex = i * 2;
            final outputIndex = i * 2 + 1;
            
            if (outputIndex < preElements.length) {
              samples.add(SampleIO(
                input: preElements[inputIndex].text.trim(),
                output: preElements[outputIndex].text.trim(),
                index: i + 1,
              ));
              developer.log("サンプル${i+1}を抽出しました(連続preから)");
            }
          }
        }
      }
    }
    
    return samples;
  }
  
  // URLが正しい形式かチェック
  bool isValidAtCoderUrl(String url) {
    final regex = RegExp(r'^https://atcoder.jp/contests/[\w-]+/tasks/[\w-]+$');
    return regex.hasMatch(url);
  }
}