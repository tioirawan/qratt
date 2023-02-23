import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'form_page.dart';

// LoadingPage statefull widget, loading when user is not logged in, auto login using firebase auth anonymous
class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCurrentUser());
  }

  Future<void> _checkCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;

    user ??= await FirebaseAuth.instance
        .signInAnonymously()
        .then((result) => result.user);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FormPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
