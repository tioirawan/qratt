import 'package:entry/entry.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class SuccessPage extends StatefulWidget {
  const SuccessPage({super.key});

  @override
  State<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage> {
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _setupAudioPlayer();
  }

  Future<void> _setupAudioPlayer() async {
    await _audioPlayer.setAsset('assets/audio/notif.mp3');
    await _audioPlayer.play();
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00AA13),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Entry.scale(
              scale: 500,
              duration: Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              child: Icon(
                Icons.check_circle_rounded,
                size: 128,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Absensi berhasil',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
