import 'dart:convert';
import 'dart:developer';

import 'package:ocr_mrz/ocr_setting_dialog.dart';
import 'package:flutter/material.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';
import 'package:ocr_mrz/ocr_mrz.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/orc_mrz_log_class.dart';
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
  int logCount = 0;
  OcrMrzLog? lastLog;

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
        title: Text("Passport Reader ${logCount}"),

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
              child: Stack(
                children: [
                  OcrMrzReader(
                    setting: setting,
                    onFoundMrz: (a) {
                      if (scanning) {
                        showFoundPassport(a);
                      }
                      log("✅ ${a.documentType} matched:");
                    },
                    mrzLogger: (l) {
                      if (l.rawMrzLines.isNotEmpty) {
                        logCount++;
                        lastLog = l;
                        setState(() {});

                        log("log recieved");
                        log(jsonEncode(l.toJson()));
                      }
                    },
                  ),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child:
                        lastLog == null
                            ? SizedBox()
                            : Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              color: Colors.white,
                              child: Column(
                                children: [
                                  Row(children: [Expanded(child: FittedBox(child: Text(lastLog!.rawMrzLines.join("\n"))))]),
                                  Divider(),
                                  Row(children: [Expanded(child: FittedBox(child: Text(lastLog!.fixedMrzLines.join("\n"))))]),
                                  Divider(),
                                  Row(children: [Expanded(child: FittedBox(child: Text(lastLog!.validation.toString())))]),
                                ],
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
