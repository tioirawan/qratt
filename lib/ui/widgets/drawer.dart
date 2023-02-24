import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../pages/attendance_page.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final attendancesRef = FirebaseFirestore.instance.collection('attendances');

  @override
  Widget build(BuildContext context) {
    final userStream = FirebaseAuth.instance.userChanges();

    return Drawer(
      child: Column(
        children: [
          StreamBuilder(
            stream: userStream,
            builder: (context, snapshot) => UserAccountsDrawerHeader(
              accountName: Text(snapshot.data?.displayName ?? 'Guest'),
              accountEmail:
                  Text(snapshot.data?.email ?? 'Prototype QR Attendance'),
              currentAccountPicture: CircleAvatar(
                backgroundImage: NetworkImage(
                  snapshot.data?.photoURL?.isNotEmpty == true
                      ? snapshot.data!.photoURL!
                      : 'https://www.pngitem.com/pimgs/m/146-1468479_my-profile-icon-blank-profile-picture-circle-hd.png',
                ),
              ),
            ),
          ),
          StreamBuilder(
            stream: userStream,
            builder: (context, snapshot) => snapshot.data?.providerData
                        .where(
                          (provider) => provider.providerId == 'google.com',
                        )
                        .isNotEmpty ==
                    true
                ? const SizedBox.shrink()
                : ListTile(
                    title: const Text('Connect to Google'),
                    leading: const Icon(Icons.account_circle),
                    onTap: _connectAccountToGoogle,
                  ),
          ),
          ListTile(
            title: const Text('Create Attendance'),
            leading: const Icon(Icons.add),
            onTap: () async {
              final secret = const Uuid().v4();

              final currentUser = FirebaseAuth.instance.currentUser!;

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
            child: StreamBuilder(
                stream: userStream,
                builder: (context, snapshot) {
                  final currentUser = snapshot.data;

                  if (currentUser == null) {
                    return const Center(
                      child: Text('Please sign in to view your attendances'),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
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
                                (attendance['createdAt'] as Timestamp?)
                                        ?.toDate() ??
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
                  );
                }),
          ),
        ],
      ),
    );
  }

  Future<void> _connectAccountToGoogle() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;

      final googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credentials = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      try {
        await currentUser.linkWithCredential(credentials);

        currentUser
          ..updateDisplayName(googleUser.displayName)
          ..updatePhotoURL(googleUser.photoUrl)
          ..updateEmail(googleUser.email);

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account connected to Google'),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          await FirebaseAuth.instance.signInWithCredential(credentials);

          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Signed in with Google'),
              ),
            );
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint(e.toString());
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to Google'),
          ),
        );
      }
    }
  }
}
