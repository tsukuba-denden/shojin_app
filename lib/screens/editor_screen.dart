import 'dart:async'; // TimeoutExceptionのために追加
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboardのために追加
import 'package:share_plus/share_plus.dart'; // コード共有用
import 'package:flutter_code_editor/flutter_code_editor.dart';
// ハイライト言語のインポートを修正
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/cpp.dart'; // clike.dart から cpp.dart に修正
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/dart.dart'; // デフォルト用
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // HTTPリクエスト用
// import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences を削除
import 'dart:io'; // File I/O
import 'package:path_provider/path_provider.dart'; // path_provider
import '../models/problem.dart';
import '../models/test_result.dart';
import '../services/atcoder_service.dart';
import 'dart:developer' as developer; // developerログのために追加
import 'submit_screen.dart'; // 提出画面を表示するWebViewスクリーン

class EditorScreen extends StatefulWidget {
  final String problemId; // 問題IDを追加

  const EditorScreen({
    super.key,
    required this.problemId, // コンストラクタで受け取る
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // コードエディタのコントローラー
  late final CodeController _codeController; // late final のまま
  // 標準入力用コントローラー
  final TextEditingController _stdinController = TextEditingController();
  // 実行結果表示用
  String _output = '';
  String _error = '';
  bool _isRunning = false; // 実行中フラグ
  bool _isTesting = false; // テスト実行中フラグ
  List<TestResult> _testResults = []; // テスト結果リスト
  Problem? _currentProblem; // 現在の問題データ
  final AtCoderService _atcoderService = AtCoderService(); // AtCoderServiceインスタンス
  // ダイアログの状態更新用 GlobalKey (StatefulBuilder を使う場合)
  final GlobalKey<State> _testResultsDialogKey = GlobalKey<State>();

  // 言語選択用
  String _selectedLanguage = 'Python';
  // C#をリストから削除
  final List<String> _languages = ['Python', 'C++', 'Rust', 'Java'];

  // ダークモードか確認するための変数
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  bool _isLoadingCode = true; // コード読み込み中フラグ

  @override
  void initState() {
    super.initState();
    // CodeController を初期化する際に、選択されている言語のハイライトを設定
    _codeController = CodeController(
      language: _getHighlightLanguage(_selectedLanguage), // 修正
      text: '// Loading code...',
    );
    _loadSavedCode();
    _loadProblemData(); // 問題データを読み込む
  }

  // ファイル名/ディレクトリ名に使えない文字を置換するヘルパー関数
  String _sanitizeFileName(String name) {
    // Windowsで使えない文字: < > : " / \ | ? *
    // Linux/macOSで使えない文字: / (NULL文字もだが、通常入力されない)
    // ここでは一般的なものをアンダースコアに置換
    String sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    // 長すぎるファイル名を避ける (オプション)
    // if (sanitized.length > 50) {
    //   sanitized = sanitized.substring(0, 50);
    // }
    return sanitized;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _stdinController.dispose();
    super.dispose();
  }

  // 保存されたコードを読み込む関数 (ファイルシステム版)
  Future<void> _loadSavedCode() async {
    setState(() {
      _isLoadingCode = true;
    });
    try {
      if (widget.problemId == 'default_problem' || _currentProblem == null || _currentProblem!.contestName.isEmpty || _currentProblem!.title.isEmpty) {
        developer.log('Load: Default problem or missing problem data. Loading template.', name: 'EditorScreen');
        _codeController.text = _getTemplateForLanguage(_selectedLanguage);
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final extension = _getExtension(_selectedLanguage);
      final contestNameSanitized = _sanitizeFileName(_currentProblem!.contestName);
      final problemTitleSanitized = _sanitizeFileName(_currentProblem!.title);
      final path = '${directory.path}/$contestNameSanitized/$problemTitleSanitized/main$extension';
      final file = File(path);

      developer.log('Load: Attempting to load code from: $path', name: 'EditorScreen');

      if (await file.exists()) {
        _codeController.text = await file.readAsString();
        developer.log('Load: Code loaded successfully from $path', name: 'EditorScreen');
      } else {
        developer.log('Load: File not found. Loading template.', name: 'EditorScreen');
        _codeController.text = _getTemplateForLanguage(_selectedLanguage);
      }
    } catch (e) {
      developer.log("Load: Failed to load code: $e", name: 'EditorScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コードの読み込みに失敗しました: $e')),
      );
      _codeController.text = _getTemplateForLanguage(_selectedLanguage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCode = false;
        });
      }
    }
  }

  // 言語名からファイル拡張子を取得するヘルパー関数
  String _getExtension(String language) {
    switch (language) {
      case 'Python':
        return '.py';
      case 'C++':
        return '.cpp';
      case 'Java':
        return '.java';
      case 'Rust':
        return '.rs';
      default:
        return '.txt'; // 不明な場合は .txt
    }
  }

  // 現在のコードを保存する関数 (ファイルシステム版)
  Future<void> _saveCode() async {
    if (widget.problemId == 'default_problem') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('デフォルト問題のコードは保存できません')),
      );
      return;
    }

    if (_currentProblem == null || _currentProblem!.contestName.isEmpty || _currentProblem!.title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存不可: コンテストまたは問題データがありません')),
      );
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final extension = _getExtension(_selectedLanguage);
      final contestNameSanitized = _sanitizeFileName(_currentProblem!.contestName);
      final problemTitleSanitized = _sanitizeFileName(_currentProblem!.title);
      // ディレクトリパスを修正
      final dirPath = '${directory.path}/$contestNameSanitized/$problemTitleSanitized';
      final filePath = '$dirPath/main$extension';
      
      final file = File(filePath);

      developer.log('Save: Attempting to save code to: $filePath', name: 'EditorScreen');

      // ディレクトリを作成
      await Directory(dirPath).create(recursive: true);
      developer.log('Save: Directory created/ensured: $dirPath', name: 'EditorScreen');

      // ファイルに書き込み
      await file.writeAsString(_codeController.text);
      developer.log('Save: Code saved successfully to $filePath', name: 'EditorScreen');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コードを $filePath に保存しました')),
      );
    } catch (e) {
      developer.log("Save: Failed to save code: $e", name: 'EditorScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コードの保存に失敗しました: $e')),
      );
    }
  }

  // 言語名から highlight パッケージの言語オブジェクトを取得するヘルパー関数
  dynamic _getHighlightLanguage(String language) {
    switch (language) {
      case 'Python':
        return python;
      case 'C++':
        return cpp; // clike を cpp として使用
      case 'Rust':
        return rust;
      case 'Java':
        return java;
      default:
        return dart; // 不明な場合は dart または plaintext
    }
  }

  // 言語が変更されたときの処理
  void _onLanguageChanged(String? newLanguage) {
    if (newLanguage != null && newLanguage != _selectedLanguage) {
      // コードを保存するかユーザーに確認するなどの処理を追加しても良い
      setState(() {
        _selectedLanguage = newLanguage;
        // CodeController の言語も更新
        _codeController.language = _getHighlightLanguage(_selectedLanguage);
        developer.log('Language changed to: $_selectedLanguage, loading code...', name: 'EditorScreen');
        _loadSavedCode(); // 新しい言語に対応するコードを読み込む
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

  // 現在のコードを復元する関数 (ファイルシステム版)
  Future<void> _restoreCode() async {
    // _loadSavedCode を呼び出すだけ
    await _loadSavedCode();
    // _loadSavedCode内でメッセージが表示されるので、ここでは不要な場合もある
    // 必要であれば、成功した旨のメッセージを出す
    // ただし、_loadSavedCodeがテンプレートをロードした場合も「復元した」と出るのは紛らわしいので注意
    // ここでは、_loadSavedCode が適切なメッセージを出すことを期待する
    // もしファイルが存在して読み込めた場合に特化したメッセージが必要なら、_loadSavedCodeからbool値を返すなど工夫が必要
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_selectedLanguage のコードの読み込みを試みました')),
    );
  }

  // 問題データを読み込む関数
  Future<void> _loadProblemData() async {
    // problemId が 'default_problem' の場合は何もしない
    if (widget.problemId == 'default_problem') {
      developer.log("Default problem ID detected, skipping problem data load.", name: 'EditorScreen');
      // _loadSavedCodeがテンプレートをロードし、_isLoadingCodeをfalseにする
      // ここで _loadSavedCode を呼ぶと二重になるので、initStateの呼び出しに任せる
      // ただし、_loadProblemData が _loadSavedCode より先に完了するケースを考慮すると、
      // やはりここで _isLoadingCode を適切に管理する必要がある。
      // _loadSavedCode が完了するまで _isLoadingCode は true のままかもしれないので、
      // _loadProblemData 側で _isLoadingCode を false にするのは _loadSavedCode 側と協調させる必要がある。
      // 現状、_loadSavedCode の finally で _isLoadingCode = false にしているので、
      // default_problem の場合は _loadSavedCode が呼ばれた時点で template がロードされ、isLoadingCode が false になる。
      // そのため、ここでは特別な isLoadingCode の操作は不要かもしれない。
      // 念のため、もし _loadSavedCode がまだ呼ばれていない場合を考慮し、
      // _currentProblem が null のままなら _isLoadingCode は false にする。
      if (mounted && _currentProblem == null) { // _currentProblem が設定されないことを確認
         setState(() {
           _isLoadingCode = false;
         });
      }
      return;
    }

    // すでに読み込み済み、または _isLoadingCode が false (つまりロード処理が完了) なら何もしない
    // ただし、_loadProblemData は _currentProblem を設定するので、_currentProblem が null の場合のみ実行する
    if (_currentProblem != null) {
        developer.log("Problem data already loaded or loading process handled by _loadSavedCode.", name: 'EditorScreen');
        return;
    }
    
    // _isLoadingCode は initState または _loadSavedCode で管理されているので、ここでは直接 true にしない。
    // _loadSavedCode が先に完了した場合、_isLoadingCode は false になっている可能性がある。
    // _loadProblemData は _currentProblem の設定が主目的。

    try {
      String url = widget.problemId;
      if (!url.startsWith('http')) {
        final parts = widget.problemId.split('_');
        if (parts.isEmpty) {
          developer.log("Invalid problem ID format: ${widget.problemId}", name: 'EditorScreen');
          if (mounted) {
            // setState(() { _isLoadingCode = false; }); // _loadSavedCodeに任せる
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('無効な問題ID形式です: ${widget.problemId}')),
            );
          }
          return;
        }
        final contestId = parts[0];
        url = 'https://atcoder.jp/contests/$contestId/tasks/${widget.problemId}';
      }

      developer.log("Fetching problem data from: $url", name: 'EditorScreen');
      final problem = await _atcoderService.fetchProblem(url);
      developer.log("Problem data fetched: ${problem.title}, Contest: ${problem.contestName}", name: 'EditorScreen');
      if (mounted) {
        setState(() {
          _currentProblem = problem;
          developer.log("Problem loaded: ${_currentProblem?.title}, Samples: ${_currentProblem?.samples.length ?? 0}", name: 'EditorScreen');
        });
        // 問題データがロードされた後に、再度コードをロードする（ファイルパスが確定するため）
        // ただし、これが _loadSavedCode の初回呼び出しと競合しないように注意
        // initState -> _loadSavedCode (problem null -> template) -> _loadProblemData (problem set) -> _loadSavedCode (problem not null -> file)
        // この流れなら、_loadProblemData の後に _loadSavedCode を呼ぶのが正しい
        await _loadSavedCode();
      }
    } catch (e) {
      developer.log("Failed to load problem data for testing: $e", name: 'EditorScreen');
      if (mounted) {
        // setState(() { _isLoadingCode = false; }); // _loadSavedCodeに任せる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('テストケースの読み込みに失敗しました: $e')),
        );
      }
    } finally {
      // _isLoadingCode の管理は主に _loadSavedCode に移譲したので、ここでの直接操作は慎重に。
      // _loadProblemData が完了しても、_loadSavedCode (ファイルからの読み込み) がまだの場合がある。
      // _loadSavedCode の finally で _isLoadingCode = false になるので、ここでは不要。
      developer.log("_loadProblemData finished. Current problem: ${_currentProblem?.title}", name: 'EditorScreen');
    }
  }
  // Wandbox APIを使用して単一のテストケースを実行する内部関数
  Future<TestResult> _runSingleTest(TestResult testCase, String code, String wandboxLanguage, Function(VoidCallback) setDialogState) async {
    // 詳細なデバッグログを追加
    print("★★★ Running test case ${testCase.index} ★★★");
    print("Language: $wandboxLanguage");
    print("Input length: ${testCase.input.length} chars");
    print("Code length: ${code.length} chars");

    // ダイアログの状態を更新
    setDialogState(() {
      testCase.status = JudgeStatus.running;
    });

    final url = Uri.parse('https://wandbox.org/api/compile.json');
    try {
      print("Sending request to Wandbox API...");
      final requestBody = {
        'code': code,
        'compiler': wandboxLanguage,
        'stdin': testCase.input,
        'save': false,
        // 'compiler-option-raw': '-O2\n-Wall', // 必要ならコンパイラオプション
        // 'runtime-option-raw': '', // 必要なら実行時オプション
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30)); // タイムアウト時間を30秒に延長

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        testCase.actualOutput = result['program_output'] ?? '';
        testCase.errorOutput = result['program_error'] ?? '';
        final compilerError = result['compiler_error'];
        // final programMessage = result['program_message']; // TLE判定に使えるか？
        testCase.exitCode = int.tryParse(result['status']?.toString() ?? '');
        testCase.signal = result['signal']?.toString();

        if (compilerError != null && compilerError.isNotEmpty) {
          testCase.status = JudgeStatus.ce;
          testCase.errorOutput += "\n--- Compiler Error ---\n$compilerError";
        } else if (testCase.signal != null && (testCase.signal!.contains('TLE') || testCase.signal!.contains('Killed') || testCase.signal!.contains('Terminated'))) {
           // WandboxのTLEシグナルは環境によるかも。Killed/TerminatedもTLEの可能性
           testCase.status = JudgeStatus.tle;
        } else if (testCase.exitCode != 0) {
          testCase.status = JudgeStatus.re;
        } else if (testCase.errorOutput.isNotEmpty && !testCase.errorOutput.contains("Permission denied")) {
          // 標準エラー出力がある場合REとみなす（Permission deniedは無視）
           testCase.status = JudgeStatus.re;
        } else {
          // 出力を比較 (改行コードや末尾の空白を考慮して比較)
          final expected = testCase.expectedOutput.trim().replaceAll('\r\n', '\n');
          final actual = testCase.actualOutput.trim().replaceAll('\r\n', '\n');
          if (expected == actual) {
            testCase.status = JudgeStatus.ac;
          } else {
            testCase.status = JudgeStatus.wa;
          }
        }
      } else {
        testCase.status = JudgeStatus.ie; // Internal Error
        testCase.errorOutput = 'APIエラー: ${response.statusCode}\n${response.body}';
      }
    } on TimeoutException {
       testCase.status = JudgeStatus.tle; // HTTPリクエストのタイムアウト
       testCase.errorOutput = '実行リクエストがタイムアウトしました (15秒)。';
    } catch (e) {
      testCase.status = JudgeStatus.ie; // Internal Error
      testCase.errorOutput = 'テスト実行中にエラーが発生しました: $e';
    }

    // ダイアログの状態を更新
    setDialogState(() {}); // 結果を反映
    return testCase;
  }

  // 複数のテストケースを実行する関数
  Future<void> _runTests() async {
    // --- 開始時のチェック ---
    developer.log('★★★ Test Button Pressed! ★★★', name: 'EditorScreen'); // ログ追加
    if (_isTesting) {
      developer.log('Already testing, returning.', name: 'EditorScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テスト実行中です')),
      );
      return;
    }
    // 問題データとサンプルケースの存在確認
    if (_currentProblem == null || _currentProblem!.samples.isEmpty) {
       developer.log('Problem data or samples missing.', name: 'EditorScreen');
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(_currentProblem == null ? '問題データがありません' : 'テストケースが見つかりません')),
       );
       return;
    }
    developer.log('Checks passed, starting test process.', name: 'EditorScreen');

    // --- 状態更新と準備 ---
    // 外側のStateを更新してボタンを無効化 & テスト結果リスト初期化
    setState(() {
      _isTesting = true;
      _testResults = _currentProblem!.samples.map((sample) => TestResult(
        index: sample.index,
        input: sample.input,
        expectedOutput: sample.output,
        // 初期状態は pending
      )).toList();
    });
    developer.log('Outer state updated: _isTesting=true, _testResults initialized with ${_testResults.length} cases.', name: 'EditorScreen');


    final code = _codeController.text;
    final wandboxLanguage = _getWandboxLanguageName(_selectedLanguage);
    developer.log('Code length: ${code.length}, Wandbox language: $wandboxLanguage', name: 'EditorScreen');


    // --- ダイアログ表示と非同期テスト実行 ---
    bool testsStarted = false; // 非同期処理の重複実行を防ぐフラグ

    // ダイアログを表示 (await しない)
    showDialog(
      context: context,
      barrierDismissible: false, // 実行中は閉じさせない
      builder: (BuildContext context) {
        // ダイアログ内の状態を管理
        return StatefulBuilder(
          key: _testResultsDialogKey, // Keyを渡す
          builder: (context, setDialogState) {

            // --- 非同期テスト実行トリガー ---
            // StatefulBuilder の初回ビルド後 or 状態更新後に非同期処理を開始
            if (!testsStarted) {
              testsStarted = true;
              developer.log('Dialog built, scheduling test execution loop.', name: 'EditorScreen');
              // Future.microtask を使い、現在のビルドサイクルの直後に実行
              Future.microtask(() async {
                developer.log('★★★ Starting test execution loop (async) ★★★', name: 'EditorScreen');
                for (int i = 0; i < _testResults.length; i++) {
                  // ダイアログがまだ表示されているか確認
                  if (_testResultsDialogKey.currentContext == null) {
                     developer.log("★★★ Dialog closed during test execution, stopping loop. ★★★", name: 'EditorScreen');
                     break; // ダイアログが閉じていたらループ中断
                  }
                  developer.log("★★★ Preparing to run test case ${i + 1} (async) ★★★", name: 'EditorScreen');
                  // 個々のテストを実行し、ダイアログの setState を渡して更新させる
                  final result = await _runSingleTest(_testResults[i], code, wandboxLanguage, setDialogState);

                  // エラーが発生したら以降のテストを中断 (CE, RE, IE)
                  if (result.status == JudgeStatus.ce || result.status == JudgeStatus.re || result.status == JudgeStatus.ie) {
                    developer.log("Stopping tests due to error in case ${result.index}: ${result.statusLabel}", name: 'EditorScreen');
                    // オプション: エラー発生時に残りのテストを Pending のままにするか、Skip などにするか
                    // for (int j = i + 1; j < _testResults.length; j++) {
                    //   setDialogState(() => _testResults[j].status = JudgeStatus.sk); // 例: Skip
                    // }
                    break; // ループ中断
                  }
                }
                developer.log("★★★ Finished test execution loop (async) ★★★", name: 'EditorScreen');

                // --- テスト完了後の状態更新 ---
                // メイン画面の State がまだ有効か確認
                if (mounted) {
                  developer.log('Main screen mounted, updating _isTesting to false.', name: 'EditorScreen');
                  setState(() {
                    _isTesting = false; // メイン画面の状態更新 (ボタン有効化など)
                  });
                }
                 // ダイアログがまだ表示されていれば、ダイアログの状態も更新 (閉じるボタン有効化のため)
                if (_testResultsDialogKey.currentContext != null) {
                   developer.log('Dialog mounted, calling setDialogState to update close button.', name: 'EditorScreen');
                   setDialogState(() {}); // ダイアログの状態を更新
                }
              });
            }

            // --- ダイアログUIの構築 ---
            return AlertDialog(
              title: Text('テスト実行結果 (${_currentProblem?.title ?? ""})'),
              content: SizedBox(
                width: double.maxFinite, // 横幅を最大に
                child: ListView.builder(
                  shrinkWrap: true, // 内容に合わせて高さを調整
                  itemCount: _testResults.length,
                  itemBuilder: (context, index) {
                    final result = _testResults[index];
                    // 各テストケースの結果を表示する ListTile
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: _getStatusColor(result.status),
                        child: result.status == JudgeStatus.running || result.status == JudgeStatus.pending
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                result.index.toString(), // ケース番号
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                      ),
                      title: Text('ケース ${result.index}'), // タイトル
                      subtitle: Text(result.statusLabel), // サブタイトル (AC, WA, TLE...)
                      trailing: result.status != JudgeStatus.running && result.status != JudgeStatus.pending
                          ? const Icon(Icons.chevron_right) // 完了後は詳細表示アイコン
                          : null, // 実行中はなし
                      onTap: result.status == JudgeStatus.running || result.status == JudgeStatus.pending
                          ? null // 実行中・待機中はタップ無効
                          : () {
                              // タップで詳細表示ダイアログを開く
                              _showResultDetailDialog(result);
                            },
                    );
                  },
                ),
              ),
              actions: <Widget>[
                // 閉じるボタン
                TextButton(
                  onPressed: _isTesting ? null : () {
                    developer.log('Close button pressed.', name: 'EditorScreen');
                    Navigator.of(context).pop(); // ダイアログを閉じる
                  },
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    ); // showDialog の呼び出し終了

    developer.log('_runTests function finished (dialog shown, async tests scheduled).', name: 'EditorScreen');
    // この関数自体は showDialog を呼び出した直後に終了する
    // 実際のテスト実行と完了後の処理は Future.microtask 内で行われる
  }

  // テスト結果詳細ダイアログ
  void _showResultDetailDialog(TestResult result) {
     showDialog(
        context: context,
        builder: (context) => AlertDialog(
           title: Text('ケース ${result.index} - ${result.statusLabel}'),
           content: SingleChildScrollView(
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    _buildDetailSection('入力 (stdin)', result.input),
                    _buildDetailSection('期待される出力 (Expected)', result.expectedOutput),
                    _buildDetailSection('実際の出力 (stdout)', result.actualOutput),
                    if (result.errorOutput.isNotEmpty)
                       _buildDetailSection('エラー出力 (stderr)', result.errorOutput, isError: true),
                    if (result.exitCode != null)
                       Text('終了コード: ${result.exitCode}'),
                    if (result.signal != null)
                       Text('シグナル: ${result.signal}'),
                 ],
              ),
           ),
           actions: [
              TextButton(
                 child: const Text('コピー (入力)'),
                 onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.input));
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('入力をコピーしました')),
                    );
                 },
              ),
              TextButton(
                 child: const Text('閉じる'),
                 onPressed: () => Navigator.of(context).pop(),
              ),
           ],
        ),
     );
  }

  Widget _buildDetailSection(String title, String content, {bool isError = false}) {
     return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Container(
                 padding: const EdgeInsets.all(8),
                 width: double.infinity,
                 constraints: const BoxConstraints(maxHeight: 150), // 高さに制限
                 decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                 ),
                 child: SingleChildScrollView( // 内容が長い場合にスクロール可能に
                    child: SelectableText(
                       content.isEmpty ? '(空)' : content,
                       style: GoogleFonts.sourceCodePro(
                          fontSize: 13,
                          color: isError ? Colors.red : null,
                       ),
                    ),
                 ),
              ),
           ],
        ),
     );
  }


  Color _getStatusColor(JudgeStatus status) {
    switch (status) {
      case JudgeStatus.ac: return Colors.green.shade600;
      case JudgeStatus.wa: return Colors.orange.shade700;
      case JudgeStatus.re:
      case JudgeStatus.tle:
      case JudgeStatus.ce:
      case JudgeStatus.ie: return Colors.red.shade600;
      case JudgeStatus.running: return Colors.blue.shade600;
      case JudgeStatus.pending: return Colors.grey.shade600;
    }
  }


  @override
  Widget build(BuildContext context) {
    final bool isLoadingProblem = _isLoadingCode || (widget.problemId != 'default_problem' && _currentProblem == null);

    // ★★★ デバッグログ追加 ★★★
    final bool isButtonDisabled = isLoadingProblem || _isTesting || _currentProblem == null || (_currentProblem?.samples.isEmpty ?? true);
    // _currentProblemがnullの場合にsamplesにアクセスしないように修正
    print("--- Test Button State ---");
    print("isLoadingProblem: $isLoadingProblem (_isLoadingCode: $_isLoadingCode, _currentProblem == null: ${_currentProblem == null}) (problemId: ${widget.problemId})");
    print("_isTesting: $_isTesting");
    print("_currentProblem == null: ${_currentProblem == null}");
    print("_currentProblem?.samples.isEmpty: ${_currentProblem?.samples.isEmpty}"); // nullの場合はnullが出力される
    print("Button disabled: $isButtonDisabled");
    print("-------------------------");
    // ★★★ デバッグログ追加 ★★★


    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 言語選択 Dropdown
              Row(
                children: [
                  const Text('言語: ', style: TextStyle(fontSize: 14)),
                  DropdownButton<String>(
                    value: _selectedLanguage,
                    isDense: true,
                    underline: Container(height: 1, color: Colors.grey),
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
              // ツールバーボタン (実行ボタンは削除)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ... other buttons ...
                  IconButton( // テスト実行ボタン
                    icon: _isTesting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.checklist_rtl),
                    tooltip: 'テスト実行 (サンプルケース)',
                    onPressed: isButtonDisabled
                        ? null
                        : () { // onPressedがnullでない場合の処理
                            print("★★★ Test Button Pressed! ★★★"); // このログが出るか確認
                            _runTests();
                          },
                  ),
                  IconButton( // 提出ボタン
                    icon: const Icon(Icons.cloud_upload),
                    tooltip: '提出',
                    onPressed: () {
                      final parts = widget.problemId.split('_');
                      final contestId = parts.isNotEmpty ? parts[0] : widget.problemId;
                      final url = 'https://atcoder.jp/contests/$contestId/submit?taskScreenName=${widget.problemId}';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubmitScreen(
                            url: url,
                            initialCode: _codeController.text,
                            initialLanguage: _selectedLanguage,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton( // 保存ボタン
                    icon: const Icon(Icons.save_alt),
                    tooltip: '保存',
                    onPressed: _saveCode,
                  ),
                  IconButton( // 復元ボタン
                    icon: const Icon(Icons.settings_backup_restore),
                    tooltip: '復元',
                    onPressed: _restoreCode,
                  ),
                  IconButton( // リセットボタン
                    icon: const Icon(Icons.replay),
                    tooltip: 'リセット',
                    onPressed: () {
                      _codeController.text = _getTemplateForLanguage(_selectedLanguage);
                      _stdinController.clear();
                      setState(() {
                         _output = '';
                         _error = '';
                      });
                    },
                  ),
                  IconButton( // 共有ボタン
                    icon: const Icon(Icons.share),
                    tooltip: 'コード共有',
                    onPressed: () {
                      final code = _codeController.text;
                      if (code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('共有するコードがありません')),
                        );
                        return;
                      }
                      String textToShare = code;
                      if (_currentProblem != null) {
                        // textToShare に問題のタイトルと言語を追加
                        textToShare = '${_currentProblem!.title} ($_selectedLanguage)\n\n$code';
                      }
                      // SharePlus.instance.share を使用するように変更
                      // 共有するテキストを ShareParams の text パラメータに渡す
                      SharePlus.instance.share(
                        ShareParams(text: textToShare),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // ローディング表示 or コードエディタ
        if (isLoadingProblem)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            flex: 3,
            child: Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: CodeTheme(
                  data: CodeThemeData(
                    styles: _isDarkMode ? monokaiSublimeTheme : githubTheme,
                  ),
                  child: SingleChildScrollView(
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

        // 標準入力フィールドと実行ボタン
        if (!isLoadingProblem)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row( // RowでTextFieldとButtonを囲む
              crossAxisAlignment: CrossAxisAlignment.end, // ボタンとフィールドの高さを揃える
              children: [
                Expanded( // TextFieldが可能な限り幅を取るように
                  child: TextField(
                    controller: _stdinController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: '標準入力 (stdin)',
                      hintText: 'プログラムへの入力をここに入力します',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: GoogleFonts.sourceCodePro(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8), // フィールドとボタンの間隔
                // 実行ボタン (ElevatedButtonに変更)
                ElevatedButton.icon(
                  icon: _isRunning
                      ? SizedBox( // 実行中はインジケーター
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary, // ボタン色に合わせた色
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('実行'),
                  onPressed: _isRunning ? null : _runCode, // 実行中は無効
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 少し大きめに
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // 実行結果表示エリア
        if (!isLoadingProblem)
          Expanded(
            flex: 2,
            child: Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'エラー出力 (stderr):',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red),
                              ),
                              IconButton(
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
                        SelectableText(
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
    );
  }

  // ... other methods (_runCode, _runTests, etc.) ...
}
