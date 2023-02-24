import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/drawer.dart';
import 'scanner_page.dart';

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _form = FormGroup({
    'name': FormControl<String>(validators: [Validators.required]),
    'nim': FormControl<String>(validators: [Validators.required]),
    'classroom': FormControl<String>(validators: [Validators.required]),
  });

  SharedPreferences? _prefs;
  bool _formFilled = false;

  @override
  void initState() {
    super.initState();
    _loadDataFromLocalStorage();
  }

  void _loadDataFromLocalStorage() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _form.control('name').value = _prefs?.getString('name') ?? '';
      _form.control('nim').value = _prefs?.getString('nim') ?? '';
      _form.control('classroom').value = _prefs?.getString('classroom') ?? '';

      _checkFormFilled();
    });
  }

  void _saveDataToLocalStorage() async {
    _prefs = await SharedPreferences.getInstance();

    _prefs?.setString('name', _form.control('name').value);
    _prefs?.setString('nim', _form.control('nim').value);
    _prefs?.setString('classroom', _form.control('classroom').value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi QR'),
        centerTitle: true,
      ),
      drawer: const AppDrawer(),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _buildFormWidget()),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text("Built with ❤️ by @WRI"),
          ),
        ),
      ]),
    );
  }

  Widget _buildFormWidget() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ReactiveForm(
        formGroup: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: AspectRatio(
                aspectRatio: 1 / 1,
                child: Image.asset('assets/images/logo.png'),
              ),
            ),
            const SizedBox(height: 32),
            ReactiveTextField(
              formControlName: 'name',
              decoration: const InputDecoration(
                labelText: 'Name',
              ),
              onChanged: _checkFormFilled,
            ),
            const SizedBox(height: 16),
            ReactiveTextField(
              formControlName: 'nim',
              decoration: const InputDecoration(labelText: 'NIM'),
              onChanged: _checkFormFilled,
            ),
            const SizedBox(height: 16),
            ReactiveTextField(
              formControlName: 'classroom',
              decoration: const InputDecoration(labelText: 'Classroom'),
              onChanged: _checkFormFilled,
            ),
            const SizedBox(height: 24),
            ReactiveFormBuilder(
              form: () => _form,
              builder: (context, form, child) => ElevatedButton(
                onPressed:
                    form.valid ? () => _openScanner(context, form) : null,
                child: const Text(
                  "Open QR Scanner",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkFormFilled([FormControl? control]) {
    _saveDataToLocalStorage();

    if (_form.valid && !_formFilled) {
      setState(() {
        _formFilled = true;
      });

      return;
    }

    if (_formFilled) {
      setState(() {
        _formFilled = false;
      });
    }
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  _openScanner(BuildContext context, FormGroup form) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScannerPage(
          uid: FirebaseAuth.instance.currentUser!.uid,
          name: form.control('name').value,
          nim: form.control('nim').value,
          classroom: form.control('classroom').value,
        ),
      ),
    );
  }
}
