import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../services/socket_service.dart';

class PairWebDeviceScreen extends StatefulWidget {
  const PairWebDeviceScreen({super.key});

  @override
  State<PairWebDeviceScreen> createState() => _PairWebDeviceScreenState();
}

class _PairWebDeviceScreenState extends State<PairWebDeviceScreen> {
  bool _working = false;
  String? _error;

  Future<void> _handleCode(String raw) async {
    if (_working) return;
    setState(() => _working = true);
    Map<String, dynamic> data;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) throw const FormatException();
      data = Map<String, dynamic>.from(parsed);
    } catch (_) {
      setState(() { _working = false; _error = 'This QR code is not a Novyn device-pairing code.'; });
      return;
    }
    if (data['type'] != 'novyn-device-pair-v1' ||
        data['id'] is! String || data['secret'] is! String ||
        data['publicKey'] is! String || data['origin'] is! String) {
      setState(() { _working = false; _error = 'This QR code is not a Novyn device-pairing code.'; });
      return;
    }
    final origin = Uri.tryParse(data['origin'] as String);
    final originLabel = origin == null || !origin.hasAuthority
        ? 'Unknown website'
        : origin.host;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Link this web browser?'),
        content: Text(
          'Website: $originLabel\n\nThis browser will be able to read your synced chats. Only approve if you opened Novyn Web yourself. You can sign it out later from Active Sessions.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Approve')),
        ],
      ),
    );
    if (approved != true || !mounted) {
      if (mounted) setState(() => _working = false);
      return;
    }
    setState(() => _error = null);
    try {
      final result = await context.read<SocketService>().approveWebDevicePairing(
        id: data['id'] as String,
        secret: data['secret'] as String,
        browserPublicKey: data['publicKey'] as String,
      );
      if (!mounted) return;
      if (result['ok'] == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() { _working = false; _error = result['message']?.toString() ?? 'Could not link this browser.'; });
      }
    } catch (error) {
      if (mounted) setState(() { _working = false; _error = error.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Link a web device')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.devices_rounded, size: 42),
              const SizedBox(height: 10),
              Text('Scan the QR code on Novyn Web', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Your phone stays the primary device. Chat keys are encrypted for the browser during pairing.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(onDetect: (capture) {
                        if (_working) return;
                        final value = capture.barcodes.isEmpty
                            ? null
                            : capture.barcodes.first.rawValue;
                        if (value != null) _handleCode(value);
                      }),
                      Center(child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(24)),
                      )),
                      if (_working) const ColoredBox(color: Color(0x99000000), child: Center(child: CircularProgressIndicator(color: Colors.white))),
                    ],
                  ),
                ),
              ),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
