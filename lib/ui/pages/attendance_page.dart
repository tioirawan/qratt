import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:entry/entry.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
          const SizedBox(height: 16),
          // listen to timer stream
          // StreamBuilder(
          //   stream: _timerStreamController.stream,
          //   builder: (context, snapshot) {
          //     return Text(snapshot.data == null
          //         ? 'Refreshing in ${refreshInterval}s'
          //         : 'Refreshing in ${snapshot.data}s');
          //   },
          // ),
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
                    text:
                        " and scan the QR code above to submit your attendance.",
                  )
                ],
              ),
            ),
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

            return Entry.offset(
              key: ValueKey(response.id),
              xOffset: 100,
              delay: Duration(milliseconds: 100 * index),
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
