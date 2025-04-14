// lib/models/test_result.dart
enum JudgeStatus { pending, running, ac, wa, re, tle, ce, ie }

class TestResult {
  final int index;
  final String input;
  final String expectedOutput;
  String actualOutput;
  String errorOutput;
  JudgeStatus status;
  String? signal; // REやTLEの場合のシグナル
  int? exitCode; // 正常終了/REの場合の終了コード
  // 必要に応じて実行時間やメモリ使用量も追加

  TestResult({
    required this.index,
    required this.input,
    required this.expectedOutput,
    this.actualOutput = '',
    this.errorOutput = '',
    this.status = JudgeStatus.pending,
    this.signal,
    this.exitCode,
  });

  String get statusLabel {
    switch (status) {
      case JudgeStatus.pending: return 'Pending';
      case JudgeStatus.running: return 'Running';
      case JudgeStatus.ac: return 'AC';
      case JudgeStatus.wa: return 'WA';
      case JudgeStatus.re: return 'RE';
      case JudgeStatus.tle: return 'TLE'; // TLEはWandboxのレスポンスからは直接判断難しい場合あり
      case JudgeStatus.ce: return 'CE'; // Compile Error
      case JudgeStatus.ie: return 'IE'; // Internal Error
      default: return 'Unknown';
    }
  }
}
