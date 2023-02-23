import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../pages/attendance_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final attendancesRef = FirebaseFirestore.instance.collection('attendances');

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(currentUser.displayName ?? 'Guest'),
            accountEmail: Text(currentUser.email ?? 'Prototype QR Attendance'),
          ),
          ListTile(
            title: const Text('Create Attendance'),
            leading: const Icon(Icons.add),
            onTap: () async {
              final secret = const Uuid().v4();

              final attendanceDoc = await attendancesRef.add({
                'owner': currentUser.uid,
                'secret': secret,
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendancePage(
                      attendanceId: attendanceDoc.id,
                    ),
                  ),
                );
              }
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: attendancesRef
                  .where('owner', isEqualTo: currentUser.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                final attendanceDocs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: attendanceDocs.length,
                  itemBuilder: (context, index) {
                    final attendance = attendanceDocs[index];
                    return ListTile(
                      title: Text(
                        DateFormat('dd MMM yyyy h:mm a').format(
                          (attendance['createdAt'] as Timestamp?)?.toDate() ??
                              DateTime.now(),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AttendancePage(
                              attendanceId: attendance.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
