import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemplateProvider extends ChangeNotifier {
  final String _prefsKeyPrefix = 'code_template_';
  Map<String, String> _templates = {};
  bool _isLoading = true;

  // サポートする言語リスト
  final List<String> supportedLanguages = [
    'C++',
    'Python',
    'Java',
    'Ruby',
    'JavaScript',
    'Dart'
  ];

  TemplateProvider() {
    _loadFromPrefs();
  }

  // テンプレート読み込み中かどうか
  bool get isLoading => _isLoading;

  // 指定した言語のテンプレートを取得
  String getTemplate(String language) {
    // カスタムテンプレートがあればそれを返す
    if (_templates.containsKey(language)) {
      return _templates[language]!;
    }
    
    // なければデフォルトテンプレートを返す
    return getDefaultTemplate(language);
  }

  // デフォルトのテンプレートを取得
  String getDefaultTemplate(String language) {
    switch (language) {
      case 'C++':
        return '''#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
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

  // テンプレートを設定する
  Future<void> setTemplate(String language, String template) async {
    _templates[language] = template;
    await _saveToPrefs(language);
    notifyListeners();
  }

  // テンプレートをデフォルトに戻す
  Future<void> resetTemplate(String language) async {
    if (_templates.containsKey(language)) {
      _templates.remove(language);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefsKeyPrefix$language');
      notifyListeners();
    }
  }

  // テンプレートを設定から読み込む
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> templates = {};
    
    // 各言語のテンプレートを読み込む
    for (var language in supportedLanguages) {
      final template = prefs.getString('$_prefsKeyPrefix$language');
      if (template != null) {
        templates[language] = template;
      }
    }
    
    _templates = templates;
    _isLoading = false;
    notifyListeners();
  }

  // テンプレートを設定に保存
  Future<void> _saveToPrefs(String language) async {
    if (!_templates.containsKey(language)) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsKeyPrefix$language', _templates[language]!);
  }
}
