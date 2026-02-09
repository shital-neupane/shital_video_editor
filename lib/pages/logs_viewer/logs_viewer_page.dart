import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shital_video_editor/shared/logger_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LogsViewerPage extends StatelessWidget {
  const LogsViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Get.forceAppUpdate();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (String choice) {
              if (choice == 'clear') {
                _clearLogs();
              } else if (choice == 'share') {
                _shareLogs();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'clear',
                  child: Text('Clear Logs'),
                ),
                const PopupMenuItem<String>(
                  value: 'share',
                  child: Text('Share Logs'),
                ),
              ];
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: logger.getLogContent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final logs = snapshot.data ?? '';
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Log File Info:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      FutureBuilder<String>(
                        future: logger.getLogFilePath(),
                        builder: (context, pathSnapshot) {
                          if (pathSnapshot.hasData) {
                            return Expanded(
                              child: Text(
                                pathSnapshot.data!,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SelectableText(
                        logs,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  void _clearLogs() {
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await logger.clearLogs();
              Get.snackbar('Success', 'Logs cleared successfully');
              Navigator.of(context).pop();
              Get.forceAppUpdate();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _shareLogs() async {
    final logs = await logger.getLogContent();
    final path = await logger.getLogFilePath();
    
    try {
      // On mobile platforms, we can share the logs using url_launcher
      // For now, we'll just show the logs in a dialog
      await showDialog(
        context: Get.context!,
        builder: (context) => AlertDialog(
          title: const Text('Share Logs'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Log file path:'),
                SelectableText(path),
                const SizedBox(height: 10),
                const Text('Would you like to share the logs?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Copy logs to clipboard
                await Clipboard.setData(ClipboardData(text: logs));
                Get.snackbar('Copied', 'Logs copied to clipboard');
                Navigator.of(context).pop();
              },
              child: const Text('Copy to Clipboard'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not share logs: $e');
    }
  }
}
