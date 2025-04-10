import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/dart.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // コードエディタのコントローラー
  late final CodeController _codeController;
  
  // 言語選択用
  String _selectedLanguage = 'C++';
  final List<String> _languages = ['C++', 'Python', 'Java', 'Ruby', 'JavaScript', 'Dart'];
  
  // ダークモードか確認するための変数
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    // 初期コード
    _codeController = CodeController(
      text: '''// ここにコードを書いてください
#include <iostream>
using namespace std;

int main() {
    int n;
    cin >> n;
    cout << "Hello World!" << endl;
    return 0;
}''',
      language: dart, // 初期言語はDartを設定（実際には後で変更される）
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // 選択した言語に基づいてコードのテンプレートを取得
  String _getTemplateForLanguage(String language) {
    switch (language) {
      case 'C++':
        return '''#include <iostream>
using namespace std;

int main() {
    int n;
    cin >> n;
    cout << "Hello World!" << endl;
    return 0;
}''';
      case 'Python':
        return '''n = int(input())
print("Hello World!")''';
      case 'Java':
        return '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();
        System.out.println("Hello World!");
    }
}''';
      case 'Ruby':
        return '''n = gets.to_i
puts "Hello World!"''';
      case 'JavaScript':
        return '''function main(input) {
    const n = parseInt(input.trim());
    console.log("Hello World!");
}
main(require('fs').readFileSync('/dev/stdin', 'utf8'));''';
      case 'Dart':
        return '''void main() {
  final n = int.parse(stdin.readLineSync()!);
  print("Hello World!");
}''';
      default:
        return '// ここにコードを書いてください';
    }
  }

  // 言語が変更されたときの処理
  void _onLanguageChanged(String? newLanguage) {
    if (newLanguage != null && newLanguage != _selectedLanguage) {
      setState(() {
        _selectedLanguage = newLanguage;
        _codeController.text = _getTemplateForLanguage(newLanguage);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'コードエディタ',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('言語: ', style: TextStyle(fontSize: 16)),
              DropdownButton<String>(
                value: _selectedLanguage,
                onChanged: _onLanguageChanged,
                items: _languages.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CodeTheme(
                  data: CodeThemeData(
                    styles: _isDarkMode ? monokaiSublimeTheme : githubTheme,
                  ),
                  child: SingleChildScrollView(
                    child: CodeField(
                      controller: _codeController,
                      textStyle: GoogleFonts.sourceCodePro(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // コードを実行する処理
                  // 実際の実装ではAPIを使用して実行結果を取得する
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('実行機能は準備中です')),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('実行'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // コードを提出する処理
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('提出機能は準備中です')),
                  );
                },
                icon: const Icon(Icons.send),
                label: const Text('提出'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // コードをリセット
                  _codeController.text = _getTemplateForLanguage(_selectedLanguage);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('リセット'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
