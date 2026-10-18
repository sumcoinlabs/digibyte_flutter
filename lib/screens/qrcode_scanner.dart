import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScanner extends StatefulWidget {
  const QRScanner({
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  QRViewController? _controller;
  StreamSubscription<Barcode>? _scanSubscription;
  bool _handledScan = false;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _controller?.pauseCamera();
      _controller?.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(ModalRoute.of(context)!.settings.arguments as String),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: [
                _buildQrView(context),
                Positioned(
                  bottom: 25,
                  right: 25,
                  child: FloatingActionButton(
                    backgroundColor: Theme.of(context).primaryColor,
                    onPressed: () async => await _controller?.toggleFlash(),
                    child: const Icon(
                      Icons.lightbulb,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Theme.of(context).primaryColor,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: scanArea,
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) async {
    if (!mounted) {
      controller.dispose();
      return;
    }
    _controller = controller;
    _handledScan = false;
    if (Platform.isAndroid) {
      await controller.pauseCamera();
      if (!mounted) return;
      await controller.resumeCamera();
      if (!mounted) return;
    }

    _scanSubscription?.cancel();
    _scanSubscription = controller.scannedDataStream.listen((scanData) {
      final value = scanData.code?.trim();
      if (_handledScan || !mounted || value == null || value.isEmpty) return;
      // The scanner can emit several frames of the same QR in milliseconds.
      // Pop exactly ONCE; otherwise subsequent events can pop the Send route.
      _handledScan = true;
      _scanSubscription?.cancel();
      Navigator.of(context).pop(value);
    });
  }

  @override
  void dispose() {
    _handledScan = true;
    _scanSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
