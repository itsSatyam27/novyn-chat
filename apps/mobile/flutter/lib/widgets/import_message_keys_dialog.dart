import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';

Future<void> showImportMessageKeys(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const ImportMessageKeysDialog(),
    );

class ImportMessageKeysDialog extends StatefulWidget {
  const ImportMessageKeysDialog({super.key});
  @override
  State<ImportMessageKeysDialog> createState() =>
      _ImportMessageKeysDialogState();
}

class _ImportMessageKeysDialogState extends State<ImportMessageKeysDialog> {
  final _password = TextEditingController();
  String? _file;
  String? _name;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    try {
      final selection = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (selection == null) return;
      final file = selection.files.single;
      if (file.size > 2 * 1024 * 1024) {
        throw const FormatException('Key file is too large.');
      }
      final content = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();
      if (mounted) {
        setState(() {
          _file = content;
          _name = file.name;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not read the selected key file.');
      }
    }
  }

  Future<void> _import() async {
    if (_busy || _file == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await context
          .read<SocketService>()
          .importMessageKeys(_file!, _password.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text('Message keys imported for $count conversations.')));
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is FormatException
              ? error.message
              : 'Could not import message keys. Please try again.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: const Text('Import message keys'),
          content: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text(
                    'On the web browser where messages are readable, open Settings → Security & Privacy → Sync Message Keys. Download the protected file and transfer it to this phone.'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                    onPressed: _busy ? null : _choose,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(_name ?? 'Choose key file',
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 12),
                TextField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    decoration:
                        const InputDecoration(labelText: 'Transfer password')),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
              ])),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _busy || _file == null ? null : _import,
                child: Text(_busy ? 'Importing…' : 'Import')),
          ],
        ),
      );
}
