import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/drawer.dart';

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final qrKey = MobileScannerController(facing: CameraFacing.back);

  TextEditingController nameController = TextEditingController();
  TextEditingController nimController = TextEditingController();
  TextEditingController classroomController = TextEditingController();

  String? qrResult;
  SharedPreferences? _prefs;
  bool _formFilled = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDataFromLocalStorage();
  }

  void _loadDataFromLocalStorage() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      nameController.text = _prefs?.getString('name') ?? '';
      nimController.text = _prefs?.getString('nim') ?? '';
      classroomController.text = _prefs?.getString('classroom') ?? '';

      _checkFormFilled('');
    });
  }

  void _saveDataToLocalStorage() async {
    _prefs = await SharedPreferences.getInstance();
    _prefs?.setString('name', nameController.text);
    _prefs?.setString('nim', nimController.text);
    _prefs?.setString('classroom', classroomController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi QR'),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: AspectRatio(
                aspectRatio: 1 / 1,
                child: _formFilled
                    ? _buildQRScannerWidget()
                    : Container(
                        color: Colors.grey,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: const Text(
                          'Please fill the form to submit attendance or open the drawer to create a new attendance activity',
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            _buildFormWidget()
          ],
        ),
      ),
    );
  }

  Widget _buildFormWidget() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: _checkFormFilled,
          ),
          TextField(
            controller: nimController,
            decoration: const InputDecoration(labelText: 'NIM'),
            onChanged: _checkFormFilled,
          ),
          TextField(
            controller: classroomController,
            decoration: const InputDecoration(labelText: 'Classroom'),
            onChanged: _checkFormFilled,
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

  void _checkFormFilled(String _) {
    _saveDataToLocalStorage();

    if (nameController.text.isNotEmpty &&
        nimController.text.isNotEmpty &&
        classroomController.text.isNotEmpty) {
      if (!_formFilled) {
        setState(() {
          _formFilled = true;
        });
      }

      return;
    }

    if (_formFilled) {
      setState(() {
        _formFilled = false;
      });
    }
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
              .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
              .get();

          if (attendance.docs.isEmpty) {
            final data = {
              'uid': FirebaseAuth.instance.currentUser!.uid,
              'name': nameController.text,
              'nim': nimController.text,
              'classroom': classroomController.text,
              'timestamp': Timestamp.now(),
            };

            await docRef.collection("responses").add(data);

            if (context.mounted) {
              alert('Attendance submitted');
            }
          } else {
            if (context.mounted) {
              alert('Attendance already submitted');
            }
          }
        } else {
          if (context.mounted) {
            alert('Invalid QR Code');
          }
        }
      }
    } on Exception {
      if (context.mounted) {
        alert('Something went wrong');
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void alert(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    nimController.dispose();
    classroomController.dispose();
    qrKey.dispose();
    super.dispose();
  }
}
