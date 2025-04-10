import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/template_provider.dart';

class TemplateEditScreen extends StatefulWidget {
  final String language;

  const TemplateEditScreen({super.key, required this.language});

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  late TextEditingController _controller;
  bool _isEdited = false;
  late TemplateProvider _templateProvider;

  @override
  void initState() {
    super.initState();
    _templateProvider = Provider.of<TemplateProvider>(context, listen: false);
    // 現在のテンプレート（カスタムまたはデフォルト）を取得
    String currentTemplate = _templateProvider.getTemplate(widget.language);
    _controller = TextEditingController(text: currentTemplate);
    
    // テキスト変更を監視
    _controller.addListener(() {
      if (!_isEdited) {
        setState(() {
          _isEdited = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // テンプレートを保存する
  void _saveTemplate() {
    _templateProvider.setTemplate(widget.language, _controller.text);
    setState(() {
      _isEdited = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.language}のテンプレートを保存しました')),
    );
  }
  
  // テンプレートをリセットする
  void _resetTemplate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレートをリセット'),
        content: Text('${widget.language}のテンプレートをデフォルトに戻しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              _controller.text = _templateProvider.getDefaultTemplate(widget.language);
              _templateProvider.resetTemplate(widget.language);
              Navigator.of(context).pop();
              setState(() {
                _isEdited = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${widget.language}のテンプレートをリセットしました')),
              );
            },
            child: const Text('リセット'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.language}のテンプレート編集'),
        actions: [
          IconButton(
            onPressed: _resetTemplate,
            icon: const Icon(Icons.refresh),
            tooltip: 'デフォルトに戻す',
          ),
          TextButton(
            onPressed: _isEdited ? _saveTemplate : null,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(8.0),
                    border: InputBorder.none,
                    hintText: '// テンプレートを編集',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
