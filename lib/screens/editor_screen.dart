import 'dart:async'; // TimeoutExceptionのために追加
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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
import 'package:provider/provider.dart';
import '../models/problem.dart';
import '../models/test_result.dart';
import '../services/atcoder_service.dart';
import '../providers/theme_provider.dart';
import '../utils/text_style_helper.dart';
import 'dart:developer' as developer; // developerログのために追加
import 'submit_screen.dart'; // 提出画面を表示するWebViewスクリーン
import '../services/code_history_service.dart';
import 'code_history_screen.dart';

// 3点メニュー用のアクション列挙体（トップレベルに定義）
enum _ToolbarAction { runTests, save, history, restore, reset, share }

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
  final CodeHistoryService _codeHistoryService = CodeHistoryService();
  Timer? _debounce;
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
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _debounce?.cancel();
    _codeController.dispose();
    _stdinController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _saveHistory();
    });
  }

  Future<void> _saveHistory() async {
    if (widget.problemId.isEmpty || widget.problemId == 'default_problem') {
      return;
    }
    await _codeHistoryService.saveHistory(widget.problemId, _codeController.text);
    // Optional: Show a subtle feedback to the user
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text('History saved'), duration: Duration(seconds: 1)),
    // );
  }

  Future<String> _getFilePath() async {
    if (_currentProblem == null) {
      // 問題がロードされていない場合はデフォルトのパスを返す
      return '';
    }
    final directory = await getApplicationDocumentsDirectory();
    final contestId = _currentProblem!.contestId;
    // 問題タイトルからファイル名として不適切な文字を削除・置換
    final problemTitle = _currentProblem!.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final extension = _getExtension(_selectedLanguage);
    final path = '${directory.path}/$contestId/$problemTitle/main.$extension';
    return path;
  }

  String _getExtension(String language) {
    switch (language) {
      case 'Python':
        return 'py';
      case 'C++':
        return 'cpp';
      case 'Rust':
        return 'rs';
      case 'Java':
        return 'java';
      default:
        return 'txt';
    }
  }

  // 保存されたコードを読み込む関数
  Future<void> _loadSavedCode() async {
    setState(() {
      _isLoadingCode = true;
    });
    try {
      final filePath = await _getFilePath();
      if (filePath.isEmpty) {
        _codeController.text = _getTemplateForLanguage(_selectedLanguage);
        return;
      }
      final file = File(filePath);
      if (await file.exists()) {
        final savedCode = await file.readAsString();
        _codeController.text = savedCode;
      } else {
        _codeController.text = _getTemplateForLanguage(_selectedLanguage);
      }
    } catch (e) {
      print("コードの読み込みに失敗しました: $e");
      // エラー時もテンプレートを設定
      _codeController.text = _getTemplateForLanguage(_selectedLanguage);
    } finally {
      setState(() {
        _isLoadingCode = false;
      });
    }
  }

  // 現在のコードを保存する関数
  Future<void> _saveCode() async {
    try {
      final filePath = await _getFilePath();
      if (filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題がロードされていないため保存できません')),
        );
        return;
      }
      final file = File(filePath);
      // ディレクトリが存在しない場合は作成
      await file.parent.create(recursive: true);
      await file.writeAsString(_codeController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コードを $filePath に保存しました')),
      );
    } catch (e) {
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

  // 現在のコードを復元する関数
  Future<void> _restoreCode() async {
    try {
      final filePath = await _getFilePath();
      if (filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題がロードされていないため復元できません')),
        );
        return;
      }
      final file = File(filePath);
      if (await file.exists()) {
        final savedCode = await file.readAsString();
        setState(() {
          _codeController.text = savedCode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_selectedLanguage のコードを復元しました')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存されたコードが見つかりません')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コードの復元に失敗しました: $e')),
      );
    }
  }

  // 問題データを読み込む関数
  Future<void> _loadProblemData() async {
    // problemId が 'default_problem' の場合は何もしない
    if (widget.problemId == 'default_problem') {
      print("Default problem ID detected, skipping problem data load.");
      // 必要なら _isLoadingCode を false にする
      if (mounted) {
        setState(() {
          _isLoadingCode = false; // コード読み込みも完了扱いにする
        });
      }
      return;
    }
    // すでに読み込み済み、または読み込み中なら何もしない (isLoadingCode を流用)
    if (_currentProblem != null || !_isLoadingCode) return;

    // _isLoadingCode は initState で true になっているので、ここでは setState しない

    try {
      // 問題URLを決定する
      // problemIdがすでに完全なURLの場合はそのまま使用
      String url = widget.problemId;
      if (!url.startsWith('http')) {
        // URLでない場合は、従来の方法でURL構築を試みる
        final parts = widget.problemId.split('_');
        if (parts.isEmpty) {
          print("Invalid problem ID format: ${widget.problemId}");
          if (mounted) {
            setState(() {
              _isLoadingCode = false; // エラーでもローディング終了
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('無効な問題ID形式です: ${widget.problemId}')),
            );
          }
          return;
        }
        final contestId = parts[0];
        url = 'https://atcoder.jp/contests/$contestId/tasks/${widget.problemId}';
      }

      print("Fetching problem data from: $url"); // デバッグ用ログ
      final problem = await _atcoderService.fetchProblem(url);
      print("Problem data fetched: ${problem.title}"); // デバッグ用ログ
      if (mounted) {
        setState(() {
          _currentProblem = problem;
          // ★★★ デバッグログ追加 ★★★
          print("Problem loaded: ${_currentProblem?.title}");
          print("Samples found: ${_currentProblem?.samples.length ?? 0}");
          // ★★★ デバッグログ追加 ★★★
        });
      }
    } catch (e) {
      print("Failed to load problem data for testing: $e"); // 既存ログ
      if (mounted) {
        // ★★★ デバッグログ追加 ★★★
        print("Error loading problem data. _currentProblem is null.");
        // ★★★ デバッグログ追加 ★★★
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('テストケースの読み込みに失敗しました: $e')),
        );
      }
    } finally {
       // _loadSavedCode と両方終わったことを確認するために
       // _loadSavedCode 側で isLoadingCode を false にする
       // ★★★ デバッグログ追加 ★★★
       print("_loadProblemData finished. isLoadingCode: $_isLoadingCode");
       // ★★★ デバッグログ追加 ★★★
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
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
                style: getMonospaceTextStyle(
                  themeProvider.codeFontFamily,
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final codeFontFamily = themeProvider.codeFontFamily;
        final bool isLoadingProblem = _isLoadingCode || (widget.problemId != 'default_problem' && _currentProblem == null);
        final bool isButtonDisabled = isLoadingProblem || _isTesting || _currentProblem == null || (_currentProblem?.samples.isEmpty ?? true);
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
              // 3点メニュー（オーバーフローメニュー）
              PopupMenuButton<_ToolbarAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'その他',
                onSelected: (action) async {
                  switch (action) {
                    case _ToolbarAction.runTests:
                      if (!isButtonDisabled) {
                        print("★★★ Test Menu Selected! ★★★");
                        _runTests();
                      }
                      break;
                    case _ToolbarAction.save:
                      _saveCode();
                      break;
                    case _ToolbarAction.history:
                      if (widget.problemId.isEmpty || widget.problemId == 'default_problem') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No problem selected.')),
                        );
                        break;
                      }
                      final restoredCode = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CodeHistoryScreen(problemId: widget.problemId),
                        ),
                      );
                      if (restoredCode != null && restoredCode is String) {
                        setState(() {
                          _codeController.text = restoredCode;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code restored from history.')),
                        );
                      }
                      break;
                    case _ToolbarAction.restore:
                      _restoreCode();
                      break;
                    case _ToolbarAction.reset:
                      _codeController.text = _getTemplateForLanguage(_selectedLanguage);
                      _stdinController.clear();
                      setState(() {
                        _output = '';
                        _error = '';
                      });
                      break;
                    case _ToolbarAction.share:
                      final code = _codeController.text;
                      if (code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('共有するコードがありません')),
                        );
                        break;
                      }
                      String textToShare = code;
                      if (_currentProblem != null) {
                        textToShare = '${_currentProblem!.title} ($_selectedLanguage)\n\n$code';
                      }
                      SharePlus.instance.share(
                        ShareParams(text: textToShare),
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<_ToolbarAction>(
                    value: _ToolbarAction.runTests,
                    enabled: !isButtonDisabled,
                    child: Row(
                      children: [
                        const Icon(Icons.checklist_rtl),
                        const SizedBox(width: 8),
                        Text(_isTesting ? 'テスト実行中…' : 'テスト実行 (サンプルケース)'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<_ToolbarAction>(
                    value: _ToolbarAction.save,
                    child: Row(
                      children: const [Icon(Icons.save_alt), SizedBox(width: 8), Text('保存')],
                    ),
                  ),
                  PopupMenuItem<_ToolbarAction>(
                    value: _ToolbarAction.history,
                    child: Row(
                      children: const [Icon(Icons.history), SizedBox(width: 8), Text('コード履歴')],
                    ),
                  ),
                  PopupMenuItem<_ToolbarAction>(
                    value: _ToolbarAction.restore,
                    child: Row(
                      children: const [Icon(Icons.settings_backup_restore), SizedBox(width: 8), Text('復元')],
                    ),
                  ),
                  PopupMenuItem<_ToolbarAction>(
                    value: _ToolbarAction.reset,
                    child: Row(
                      children: const [Icon(Icons.replay), SizedBox(width: 8), Text('リセット')],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<_ToolbarAction>(
                    value: _ToolbarAction.share,
                    child: Row(
                      children: const [Icon(Icons.share), SizedBox(width: 8), Text('コード共有')],
                    ),
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
                      textStyle: getMonospaceTextStyle(codeFontFamily),
                      gutterStyle: const GutterStyle(
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

        // 入出力エリア: ボタン行 + 左右分割 (stdin | stdout/stderr)
        if (!isLoadingProblem) ...[
          // ボタンを一列に配置（実行、サンプル、提出）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              children: [
                // 実行（横幅1/3）
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _isRunning
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('実行'),
                    onPressed: _isRunning ? null : _runCode,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // サンプル（横幅1/3）
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _isTesting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.checklist_rtl),
                    label: Text(_isTesting ? 'サンプルテスト中…' : 'サンプル'),
                    onPressed: isButtonDisabled
                        ? null
                        : () {
                            print('★★★ Test Button Pressed! ★★★');
                            _runTests();
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 提出（横幅1/3）
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('提出'),
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
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 左右分割の入出力パネル
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
                          style: getMonospaceTextStyle(codeFontFamily, fontSize: 13),
                        ),

                      // --- Error Output Display ---
                      if (_error.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.only(top: _output.isNotEmpty ? 8.0 : 0),
                          child: Text(
                            'エラー出力 (stderr):',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red),
                          ),
                        ),
                        SelectableText(
                          _error,
                          style: getMonospaceTextStyle(codeFontFamily, fontSize: 13, color: Colors.red),
                        ),
                      ],
                        // --- stdin input ---
                        const SizedBox(height: 12),
                        Text('標準入力 (stdin)', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: _stdinController,
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: 'プログラムへの入力をここに入力します',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: GoogleFonts.sourceCodePro(fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ),
          ],
        );
      },
    );
  }
}
