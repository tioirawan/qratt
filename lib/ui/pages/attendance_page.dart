import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:entry/entry.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'package:uuid/uuid.dart';

import '../widgets/square_progress_painter.dart';

class AttendancePage extends StatefulWidget {
  final String attendanceId;

  const AttendancePage({Key? key, required this.attendanceId})
      : super(key: key);

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late Timer _timer;
  late Timer _counterTimer;
  Map<String, dynamic> _attendance = {};

  final int refreshInterval = 15;

  // stream controller for timer
  final StreamController<int> _timerStreamController =
      StreamController<int>.broadcast();

  late final docRef = FirebaseFirestore.instance
      .collection('attendances')
      .doc(widget.attendanceId);

  late final attendanceList = AttendanceResponseList(
    attendanceId: widget.attendanceId,
  );
  late final mobileAttendanceList = AttendanceResponseList(
    attendanceId: widget.attendanceId,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshData();
      _initRefreshTimer();
      _initDisplayTimer();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _counterTimer.cancel();
    _timerStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            // Wide screen layout
            return Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildQrCode(),
                    ),
                    Expanded(
                      flex: 3,
                      child: attendanceList,
                    ),
                  ],
                ),
                Positioned(
                  top: 32,
                  left: 32,
                  child: IconButton(
                    color: Theme.of(context).colorScheme.primary,
                    iconSize: 32,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            );
          } else {
            // Narrow screen layout
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppBar(),
                  _buildQrCode(),
                  mobileAttendanceList,
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildQrCode() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: AspectRatio(
              aspectRatio: 1,
              child: StreamBuilder(
                stream: _timerStreamController.stream,
                builder: (context, snapshot) => TweenAnimationBuilder(
                  duration: const Duration(seconds: 1),
                  tween: Tween<double>(
                    begin: 0,
                    end: snapshot.data == null
                        ? 0
                        : (snapshot.data! - 1) / refreshInterval,
                  ),
                  builder: (context, value, child) => CustomPaint(
                    painter: SquareProgressPainter(
                      color: ColorTween(
                            begin: const Color.fromARGB(255, 244, 54, 54),
                            end: const Color.fromARGB(255, 26, 255, 34),
                          ).lerp(value) ??
                          Colors.blue,
                      percentage: value,
                    ),
                    child: child,
                  ),
                  child: QrImage(
                    data: '${widget.attendanceId}#${_attendance['secret']}',
                    size: double.infinity,
                    embeddedImage: const AssetImage(
                      'assets/images/logo_white_bg.png',
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  const TextSpan(text: "Open "),
                  TextSpan(
                    text: "qrattendance-proto.web.app",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(
                    text: " to submit your attendance.",
                  )
                ],
              ),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _exportCollectionToExcel,
              icon: const Icon(Icons.download_rounded),
              label: const Text("Export to Excel"),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    final data = await docRef.get();

    setState(() {
      _attendance = data.data() ?? {};
    });
  }

  void _initRefreshTimer() {
    _timer = Timer.periodic(Duration(seconds: refreshInterval), (timer) async {
      final newSecret = const Uuid().v4();

      await docRef.update({
        'secret': newSecret,
      });

      _refreshData();
      _timerStreamController.add(refreshInterval);
    });
  }

  void _initDisplayTimer() {
    _counterTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining =
          (refreshInterval - (timer.tick % refreshInterval)).abs();
      _timerStreamController.add(remaining);
    });
  }

  Future<void> _exportCollectionToExcel() async {
    // Get the Firestore collection reference
    final collectionRef = FirebaseFirestore.instance
        .collection('attendances')
        .doc(widget.attendanceId)
        .collection('responses');

    final snapshot = await collectionRef.get();

    if (snapshot.docs.isEmpty) return;

    final excel = Excel.createExcel();
    final sheetObject = excel['Sheet1'];

    const fieldNames = ["nim", "name", "classroom", "timestamp"];
    const header = ["NIM", "Nama", "Kelas", "Waktu"];

    // Add the header row to the sheet
    sheetObject.appendRow(header);

    // Add the data rows to the sheet
    for (final doc in snapshot.docs) {
      sheetObject.appendRow(
        fieldNames.map((fieldName) {
          final fieldValue = doc[fieldName];

          if (fieldValue is Timestamp) {
            return DateFormat('dd MMM yyyy h:mm a').format(fieldValue.toDate());
          }

          return fieldValue.toString();
        }).toList(),
      );
    }

    // Save the Excel file
    final attendance = await docRef.get();
    final filename = DateFormat('dd MMM yyyy h.mm a')
        .format((attendance['createdAt'] as Timestamp).toDate());
    final bytes = excel.encode();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final link = html.AnchorElement(href: url)
      ..download = 'qr-attendance-$filename.xlsx'
      ..style.display = 'none';

    html.document.body!.append(link);
    link.click();

    link.remove();
    html.Url.revokeObjectUrl(url);
  }
}

class AttendanceResponseList extends StatelessWidget {
  const AttendanceResponseList({
    super.key,
    required this.attendanceId,
    this.shrinkWrap = false,
    this.physics,
  });

  final String attendanceId;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  get docRef =>
      FirebaseFirestore.instance.collection('attendances').doc(attendanceId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: docRef
          .collection('responses')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No attendance response yet.'));
        }

        return ListView.separated(
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: (snapshot.data?.docs.length ?? 0),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
          itemBuilder: (BuildContext context, int index) {
            final response = snapshot.data!.docs[index];

            return Entry.opacity(
              key: ValueKey(response.id),
              // xOffset: 100,
              // delay: Duration(milliseconds: 100 * index),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.grey[200],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          response['name'],
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('hh:mm a').format(
                            response['timestamp'].toDate(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      response['nim'] + ' - ' + response['classroom'],
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (BuildContext context, int index) => const SizedBox(
            height: 12,
          ),
        );
      },
    );
  }
}
