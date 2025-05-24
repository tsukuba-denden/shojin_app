import 'dart:convert'; // for auto-paste code
import 'dart:developer'; // for JS debug messages
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SubmitScreen extends StatefulWidget {
  final String url;
  final String initialCode;
  final String initialLanguage;
  const SubmitScreen({Key? key, required this.url, required this.initialCode, required this.initialLanguage}) : super(key: key);

  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // JavaScript チャンネル追加（デバッグ用）
    _controller = WebViewController()
      ..addJavaScriptChannel('Debug', onMessageReceived: (message) {
        log('JS> ' + message.message, name: 'SubmitScreen');
      })
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          _controller.runJavaScript(
            '''(function() {
  // debug: select[name="language_id"] presence
  var sel = document.querySelector('select[name="language_id"]');
  window.Debug.postMessage('select[name="language_id"] found: ' + (sel !== null));
  if (sel) window.Debug.postMessage('selector name=' + sel.name + ', options=' + sel.options.length);
  // debug: list all select2 containers
  var sp = document.querySelectorAll('.select2-selection');
  window.Debug.postMessage('.select2-selection count: ' + sp.length);
            var desired = "Python (PyPy 3.10-v7.3.12)";
            var sel = document.getElementById('language_id');
            if (sel) {
    window.Debug.postMessage('options count: ' + sel.options.length);
              for (var i = 0; i < sel.options.length; i++) {
      window.Debug.postMessage('option['+i+'] text=' + sel.options[i].text);
                var opt = sel.options[i];
                if (opt.text.indexOf(desired) !== -1) {
        window.Debug.postMessage('matching option[' + i + ']= ' + opt.text);
                  sel.value = opt.value;
        window.Debug.postMessage('sel.value set to=' + sel.value);
                  sel.dispatchEvent(new Event('change', { bubbles: true }));
                  if (window.jQuery) {
                    jQuery(sel).val(opt.value).trigger('change');
                  }
                  var disp = document.querySelector('.select2-selection__rendered');
        window.Debug.postMessage('select2 display element: ' + (disp !== null));
                  if (disp) disp.textContent = opt.text;
                  break;
                }
              }
            }
  window.Debug.postMessage('language selection script finished');
            var code = ${jsonEncode(widget.initialCode)};
            var ta = document.querySelector('textarea[name=sourceCode]');
            if (ta) {
    window.Debug.postMessage('textarea found');
              ta.value = code;
              ta.dispatchEvent(new Event('input', { bubbles: true }));
            }
            if (window.ace && document.querySelector('.ace_editor')) {
    window.Debug.postMessage('ace editor found');
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
