import 'dart:developer';

import 'package:ocr_mrz/ocr_setting_dialog.dart';
import 'package:flutter/material.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';
import 'package:ocr_mrz/ocr_mrz.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/passport_dialog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Flutter Demo', theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)), home: const MyHomePage(title: 'Flutter Demo Home Page'));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool scanning = true;
  OcrMrzSetting setting = OcrMrzSetting(
    validateBirthDateValid: true,
    validatePersonalNumberValid: false,
    validateLinesLength: true,
    validateFinalCheckValid: false,
    validateExpiryDateValid: true,
    validateDocNumberValid: false,
    validateNames: true,
  );

  showFoundPassport(OcrMrzResult res) {
    scanning = false;
    setState(() {});
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PassportDialog(result: res);
      },
    ).then((a) {
      scanning = true;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Passport Reader"),

        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return OcrSettingDialog(current: setting);
                },
              ).then((a) {
                if (a is OcrMrzSetting) {
                  setting = a;
                  setState(() {});
                }
              });
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: OcrMrzReader(
                setting: setting,
                onFoundMrz: (a) {
                  if (scanning) {
                    showFoundPassport(a);
                  }
                  log("✅ ${a.documentType} matched:");
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
