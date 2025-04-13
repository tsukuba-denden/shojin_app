import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboardのために追加
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/dart.dart'; // CodeControllerの初期化に必要
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // HTTPリクエスト用

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // コードエディタのコントローラー
  late final CodeController _codeController;
  // 標準入力用コントローラー
  final TextEditingController _stdinController = TextEditingController();
  // 実行結果表示用
  String _output = '';
  String _error = '';
  bool _isRunning = false; // 実行中フラグ

  // 言語選択用
  String _selectedLanguage = 'Python';
  // C#をリストから削除
  final List<String> _languages = ['Python', 'C++', 'Rust', 'Java'];

  // ダークモードか確認するための変数
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    // 初期コード
    _codeController = CodeController(
      text: _getTemplateForLanguage(_selectedLanguage), // 初期言語のテンプレートを設定
      language: dart, // CodeControllerにはdart言語が必要だが、表示には影響しない
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _stdinController.dispose();
    super.dispose();
  }

  // 言語が変更されたときの処理
  void _onLanguageChanged(String? newLanguage) {
    if (newLanguage != null && newLanguage != _selectedLanguage) {
      setState(() {
        _selectedLanguage = newLanguage;
        _codeController.text = _getTemplateForLanguage(newLanguage);
        // 言語変更時に実行結果もクリア
        _output = '';
        _error = '';
      });
    }
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
      case 'Rust':
        return '''use std::io;
fn main() {
   let mut input = String::new();
   io::stdin().read_line(&mut input).expect("Failed to read line");
   println!("Hello World!");
}''';
      case 'Java':
        return '''import java.util.Scanner;
public class Main {
   public static void main(String[] args) {
       Scanner sc = new Scanner(System.in);
       int n = sc.nextInt();
       System.out.println("Hello World!");
   }
}''';
      default:
        return '// ここにコードを書いてください';
    }
  }

  // Wandbox APIが要求する言語名を取得
  String _getWandboxLanguageName(String language) {
    switch (language) {
      case 'C++':
        return 'gcc-13.2.0'; // 例: 最新のGCC
      case 'Python':
        return 'cpython-3.12.7'; // 例: Python 3.12
      case 'Rust':
        return 'rust-1.70.0'; // 例: Rust 1.70
      case 'Java':
        return 'openjdk-jdk-22+36'; // 例: OpenJDK jdk-22+36
      default:
        // デフォルトもバージョン指定にしてみる
        return 'cpython-3.11.0';
    }
  }

  // Wandbox APIを使用してコードを実行する関数
  Future<void> _runCode() async {
    if (_isRunning) return; // 実行中なら何もしない

    setState(() {
      _isRunning = true;
      _output = '実行中...';
      _error = '';
    });

    final url = Uri.parse('https://wandbox.org/api/compile.json');
    final wandboxLanguage = _getWandboxLanguageName(_selectedLanguage);
    final code = _codeController.text;
    final stdin = _stdinController.text;

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'code': code,
          'compiler': wandboxLanguage,
          'stdin': stdin,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _output = result['program_output'] ?? '';
          _error = result['program_error'] ?? '';
          // コンパイルエラーなどもerrorに含まれる場合がある
          final compilerError = result['compiler_error'];
          if (compilerError != null && compilerError.isNotEmpty) {
             // 文字列補間を使って安全に結合
             _error += "\n--- Compiler Error ---\n$compilerError";
          }
        });
      } else {
        setState(() {
          // 文字列補間を使って安全に結合
          _error = 'APIエラー: ${response.statusCode}\n${response.body}';
          _output = '';
        });
      }
    } catch (e) {
      setState(() {
        // 文字列補間を使って安全に結合
        _error = '通信エラー: $e';
        _output = '';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('言語: ', style: TextStyle(fontSize: 14)),
                    DropdownButton<String>(
                      value: _selectedLanguage,
                      isDense: true, // コンパクト表示
                      underline: Container(height: 1, color: Colors.grey), // 細いアンダーライン
                      onChanged: _onLanguageChanged,
                      items: _languages.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: _isRunning
                          ? const SizedBox( // 実行中はインジケーター表示
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      tooltip: '実行',
                      onPressed: _isRunning ? null : _runCode, // 実行中は押せないように
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      tooltip: '提出',
                      onPressed: () {
                        // コードを提出する処理
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('提出機能は準備中です')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'リセット',
                      onPressed: () {
                        // コードをリセット
                        _codeController.text = _getTemplateForLanguage(_selectedLanguage);
                        _stdinController.clear();
                        setState(() {
                           _output = '';
                           _error = '';
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // コードエディタ部分
          Expanded(
            flex: 3, // コードエディタの領域を広めに取る
            child: Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: CodeTheme(
                  data: CodeThemeData(
                    styles: _isDarkMode ? monokaiSublimeTheme : githubTheme,
                  ),
                  child: SingleChildScrollView( // エディタ自体もスクロール可能に
                    child: CodeField(
                      controller: _codeController,
                      textStyle: GoogleFonts.sourceCodePro(),
                      gutterStyle: GutterStyle(
                        width: 32,
                        textAlign: TextAlign.right,
                      ),
                      lineNumberStyle: LineNumberStyle(
                        textStyle: TextStyle(
                          color: _isDarkMode ? Colors.grey : Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 標準入力フィールド
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: TextField(
              controller: _stdinController,
              maxLines: 3, // 複数行入力可能に
              decoration: InputDecoration(
                labelText: '標準入力 (stdin)',
                hintText: 'プログラムへの入力をここに入力します',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: GoogleFonts.sourceCodePro(fontSize: 13),
            ),
          ),
          // 実行結果表示エリア
          Expanded(
            flex: 2, // 実行結果の領域
            child: Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView( // 結果が長くなる場合に備えてスクロール可能に
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Standard Output Display ---
                      if (_output.isNotEmpty)
                        Text(
                          '実行結果 (stdout):',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      if (_output.isNotEmpty)
                        SelectableText(
                          _output,
                          style: GoogleFonts.sourceCodePro(fontSize: 13),
                        ),

                      // --- Error Output Display ---
                      if (_error.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: _output.isNotEmpty ? 8.0 : 0),
                          child: Row( // Rowを追加してタイトルとボタンを横並びにする
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, // 両端に寄せる
                            children: [
                              Text(
                                'エラー出力 (stderr):',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red),
                              ),
                              IconButton( // コピーボタンを追加
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: 'エラーをコピー',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _error));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('エラー出力をコピーしました')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      if (_error.isNotEmpty)
                        SelectableText( // エラー内容自体はSelectableTextのまま
                          _error,
                          style: GoogleFonts.sourceCodePro(fontSize: 13, color: Colors.red),
                        ),

                      // --- Placeholder Text ---
                      if (_output.isEmpty && _error.isEmpty && !_isRunning)
                         Text(
                           '実行ボタンを押すと、ここに結果が表示されます。',
                           style: TextStyle(color: Colors.grey),
                         ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
