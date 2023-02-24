import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'success_page.dart';

class ScannerPage extends StatefulWidget {
  final String uid;
  final String name;
  final String nim;
  final String classroom;

  const ScannerPage({
    super.key,
    required this.uid,
    required this.name,
    required this.nim,
    required this.classroom,
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final qrKey = MobileScannerController(facing: CameraFacing.back);

  String? qrResult;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildQRScannerWidget(),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.all(16) +
                      const EdgeInsets.only(right: 4),
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
            ),
          ),
          if (_isSubmitting)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildQRScannerWidget() {
    return MobileScanner(
      // fit: BoxFit.contain,
      controller: qrKey,

      onDetect: _onQrDetect,
    );
  }

  void _onQrDetect(capture) {
    final Barcode barcodes = capture.barcodes.first;
    final List<String> data = barcodes.rawValue?.split('#') ?? [];

    if (data.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR Code'),
        ),
      );
      return;
    }

    final docId = data[0];
    final secret = data[1];

    _submitAttendanceToFirestore(docId, secret);
  }

  void _submitAttendanceToFirestore(String docId, String secret) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection("attendances").doc(docId);

      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['secret'] == secret) {
          final attendance = await docRef
              .collection("responses")
              .where('uid', isEqualTo: widget.uid)
              .get();

          if (attendance.docs.isEmpty) {
            final data = {
              'uid': widget.uid,
              'name': widget.name,
              'nim': widget.nim,
              'classroom': widget.classroom,
              'timestamp': Timestamp.now(),
            };

            await docRef.collection("responses").add(data);

            if (mounted && context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const SuccessPage(),
                ),
              );
              return;
            }
          } else {
            alert('Attendance already submitted');
          }
        } else {
          alert('Invalid QR Code');
        }
      }
    } on Exception {
      alert('Something went wrong');
    } finally {
      if (mounted && context.mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void alert(String text) {
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    qrKey.dispose();
    super.dispose();
  }
}
