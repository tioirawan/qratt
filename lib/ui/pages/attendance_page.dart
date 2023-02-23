import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class AttendancePage extends StatefulWidget {
  final String attendanceId;

  const AttendancePage({Key? key, required this.attendanceId})
      : super(key: key);

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late Timer _timer;
  Map<String, dynamic> _attendance = {};

  final int refreshInterval = 10;

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

  Future<void> _refreshData() async {
    final data = await docRef.get();

    setState(() {
      _attendance = data.data() ?? {};
    });
  }

  void _initRefreshTimer() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final newSecret = const Uuid().v4();

      await docRef.update({
        'secret': newSecret,
      });

      _refreshData();
      _timerStreamController.add(refreshInterval);
    });
  }

  void _initDisplayTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining =
          (refreshInterval - (timer.tick % refreshInterval)).abs();
      _timerStreamController.add(remaining);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _timerStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            // Wide screen layout
            return Row(
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
            );
          } else {
            // Narrow screen layout
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
          QrImage(
            data: '${widget.attendanceId}#${_attendance['secret']}',
            size: 400,
          ),
          const SizedBox(height: 16),
          // listen to timer stream
          StreamBuilder(
            stream: _timerStreamController.stream,
            builder: (context, snapshot) {
              return Text(snapshot.data == null
                  ? 'Refreshing in ${refreshInterval}s'
                  : 'Refreshing in ${snapshot.data}s');
            },
          ),
          const SizedBox(height: 16),
          const Text(
            "Open qrattendance-proto.web.app on you phone and scan the QR code above to submit your attendance.",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
    print("rebuilding");
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

        return ListView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: snapshot.data?.docs.length ?? 0,
          itemBuilder: (BuildContext context, int index) {
            final response = snapshot.data!.docs[index];

            return ListTile(
              title: Text(response['name']),
              subtitle: Text(response['nim'] + ' - ' + response['classroom']),
              trailing: Text(
                DateFormat('dd MMMM yyyy, hh:mm a')
                    .format(response['timestamp'].toDate()),
              ),
            );
          },
        );
      },
    );
  }
}
