import 'dart:convert'; // for auto-paste code
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SubmitScreen extends StatefulWidget {
  final String url;
  final String initialCode;
  const SubmitScreen({Key? key, required this.url, required this.initialCode}) : super(key: key);

  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          // ページ読み込み完了後にコードをtextareaに自動貼り付け
          _controller.runJavaScript(
            '''(function() {
  var code = ${jsonEncode(widget.initialCode)};
  var ta = document.querySelector('textarea[name=sourceCode]');
  if (ta) {
    ta.value = code;
    ta.dispatchEvent(new Event('input', { bubbles: true }));
  }
  if (window.ace && document.querySelector('.ace_editor')) {
    var ed = ace.edit(document.querySelector('.ace_editor'));
    ed.setValue(code, -1);
    ed.clearSelection();
  }
})();'''
          );
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('提出画面')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
