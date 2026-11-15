import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/socket_service.dart';

class DevicePairingScannerScreen extends StatefulWidget {
  const DevicePairingScannerScreen({super.key});

  @override
  State<DevicePairingScannerScreen> createState() =>
      _DevicePairingScannerScreenState();
}

class _DevicePairingScannerScreenState
    extends State<DevicePairingScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _processing = false;
  bool _completed = false;
  String? _message;

  bool _isValidPublicKey(dynamic value) {
    if (value is! Map) return false;
    if (value['kty'] != 'EC' ||
        value['crv'] != 'P-256' ||
        value.containsKey('d')) {
      return false;
    }
    final x = value['x'];
    final y = value['y'];
    return x is String &&
        y is String &&
        RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(x) &&
        RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(y);
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_processing || _completed) return;
    final rawValues = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .toList(growable: false);
    final raw = rawValues.isEmpty ? null : rawValues.first;
    if (raw == null || raw.isEmpty) return;

    Map<String, dynamic> pairing;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException();
      pairing = Map<String, dynamic>.from(decoded);
      final sessionId = pairing['sessionId']?.toString() ?? '';
      final username = pairing['username']?.toString().trim() ?? '';
      if (pairing['type'] != 'novyn-device-pairing' ||
          pairing['version'] != 1 ||
          !RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(sessionId) ||
          !RegExp(r'^[A-Za-z0-9_.-]{1,30}$').hasMatch(username) ||
          !_isValidPublicKey(pairing['browserPublicKey'])) {
        throw const FormatException();
      }
    } catch (_) {
      setState(() => _message = 'This is not a valid Novyn device-pairing QR.');
      return;
    }

    setState(() {
      _processing = true;
      _message = null;
    });
    await _controller.stop();
    if (!mounted) return;

    final auth = context.read<AuthService>();
    final activeUsername = auth.user?.username.trim() ?? '';
    final qrUsername = pairing['username'].toString().trim();
    if (activeUsername.isEmpty ||
        activeUsername.toLowerCase() != qrUsername.toLowerCase()) {
      setState(() {
        _processing = false;
        _message =
            'This QR belongs to @$qrUsername. Sign in to that same account on this Android phone.';
      });
      await _controller.start();
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Link this browser?'),
        content: Text(
          'Allow this browser to use the Novyn encryption identity for @$activeUsername? '
          'The private key is sent only inside an encrypted, one-time pairing message.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Approve & link'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (approved != true) {
      setState(() => _processing = false);
      await _controller.start();
      return;
    }

    try {
      final browserPublicKey =
          jsonEncode(pairing['browserPublicKey']);
      final encryptedPayload = await context
          .read<SocketService>()
          .encryption
          .encryptDevicePairingPayload(
            activeUsername,
            browserPublicKey,
            pairing['sessionId'].toString(),
          );
      await ApiService.approveDevicePairing(
        pairing['sessionId'].toString(),
        encryptedPayload,
      );
      if (!mounted) return;
      setState(() {
        _completed = true;
        _processing = false;
        _message =
            'Approved. Return to Novyn Web; it will finish verifying and linking this device.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Browser pairing approved securely.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _message = error.toString().replaceFirst('Bad state: ', '');
      });
      await _controller.start();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final username = context.watch<AuthService>().user?.username ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link a web device'),
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code_scanner_rounded,
                      size: 34, color: colors.primary),
                  const SizedBox(height: 10),
                  Text(
                    'Scan the QR shown on Novyn Web',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'You are linking as @$username. Check the account before approving.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _handleCapture,
                      errorBuilder: (context, error, child) => Container(
                        color: colors.surfaceContainerHighest,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Camera unavailable: ${error.errorCode.name}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 236,
                          height: 236,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: colors.primary, width: 3),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                    if (_processing)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _completed ? colors.primary : colors.error,
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _completed || _processing
                  ? null
                  : () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel'),
            ),
            const SizedBox(height: 8),
            Text(
              'Your private key never appears in the QR code. Android encrypts it to this browser’s temporary public key after your approval.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
