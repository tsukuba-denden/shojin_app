import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/code_history.dart';
import '../services/code_history_service.dart';

class CodeHistoryScreen extends StatefulWidget {
  final String problemId;

  const CodeHistoryScreen({super.key, required this.problemId});

  @override
  _CodeHistoryScreenState createState() => _CodeHistoryScreenState();
}

class _CodeHistoryScreenState extends State<CodeHistoryScreen> {
  final CodeHistoryService _codeHistoryService = CodeHistoryService();
  late Future<List<CodeHistory>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _codeHistoryService.getHistory(widget.problemId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Code History'),
      ),
      body: FutureBuilder<List<CodeHistory>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No history found.'));
          } else {
            final historyList = snapshot.data!;
            return ListView.builder(
              itemCount: historyList.length,
              itemBuilder: (context, index) {
                final history = historyList[index];
                return ListTile(
                  title: Text(DateFormat.yMMMd().add_jms().format(history.timestamp)),
                  subtitle: Text(
                    history.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _showHistoryDetailDialog(history),
                );
              },
            );
          }
        },
      ),
    );
  }

  void _showHistoryDetailDialog(CodeHistory history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DateFormat.yMMMd().add_jms().format(history.timestamp)),
        content: SingleChildScrollView(
          child: SelectableText(history.content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              Navigator.of(context).pop(history.content); // Pop the screen and return the code
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
