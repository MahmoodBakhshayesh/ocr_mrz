import 'dart:convert';
import 'dart:developer';

import 'package:ocr_mrz/my_ocr_handler.dart';
import 'package:ocr_mrz/my_ocr_handler_new.dart';
import 'package:ocr_mrz/ocr_setting_dialog.dart';
import 'package:flutter/material.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';
import 'package:ocr_mrz/ocr_mrz.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/orc_mrz_log_class.dart';
import 'package:ocr_mrz/passport_dialog.dart';
import 'package:ocr_mrz/session_status_class.dart';

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
  OcrMrzController controller = OcrMrzController();
  bool scanning = true;
  OcrMrzSetting setting = OcrMrzSetting(
    validateBirthDateValid: true,
    validatePersonalNumberValid: false,
    validateLinesLength: false,
    validateFinalCheckValid: false,
    validateExpiryDateValid: true,
    validateDocNumberValid: false,
    validateNames: false,
    algorithm: ParseAlgorithm.method2,
  );
  int logCount = 0;
  OcrMrzLog? lastLog;
  List<String> fixed = [];
  List<SessionStatus> sessionList = [];

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
      controller.resetSession();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // log(lastLog!.fixedMrzLines.join("\n"));
    // log(lastLog!.rawMrzLines.join("\n"));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: GestureDetector(
          onLongPress: (){
            controller.resetSession();
            log("reset sesson");
          },
          onTap: () {
            // MyOcrHandler.debug("PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<<\nC038641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ");
            // final res = MyOcrHandler.debug("PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<««««K<<\nCO38641541AZE98062 72 F33080842 E6HK4A<<<<«<<58 ");
            // if(res !=null) {
            //   log(jsonEncode(res.toJson()));
            // }
            // final dataList = [
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<<\nC038641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<««««K<<\nCO38641541AZE98062 72 F33080842 E6HK4A<<<<«<<58 ",
            //   "PCAZERAHIMLI <MURAD LI<<AYTAKIN<<<<<<<<<<<<«<<\nCO3864 1541 AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURAD LI<<AYTAKIN<<<<<<<<<<<<<<< \nCO3864 1541 AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541 AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<«<<<<<<<<< \nCO3864 1541 AZE9806272 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<««<<<<«<««<< \nCO38641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nC038641541 AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541 AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<«<<<<<<<<< \nCO3864 1541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nCO3864 1541AZE98062 72 F33080842 E6MK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI <<AYTAKIN<<<<<««<<<<<<<< \nCO38641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKI N<<<<<<<<<<<<«<< \nCO38641 541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \ncO38641541AZE98062 72 F33080842 E6HK4A<<<<<<<S8 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<«<<<<<<<<<<< \nCO38641541AZE9806272 F33080842 E6 HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541 AZ E9806272 F33080842 E6 HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541 AZE9806272 F33080842 E6 HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAK IN<<<<<<<<<<<<<<< \nCO38641541AZE98062 72 F33080842 E6 HK4A<<<<<<«58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKI N<<<<<<<<<<<<<<« \nCO38641541AZE9806272 F33080842 E6 HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAK IN<<<<<<<<<<<<<<< \nCO38641541AZE98062 72 F33080842 E6 HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI<MURADLI<<AYTAKIN<<<<<<<<<<«<<<« \nCO38641541 AZE98062 72 F33080842 E6 HK4 A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541AZE9806272 F33080842 E6 HK4 A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541AZE98062 72 F33080842 E6 HK4 A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<«<<«< \nCO38641541AZE9806272 F33080842 E6 HK4 A<<<<<<<S8 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<«<<<<<<<< \nCO38641541AZE9806272 F33080842 E6 HK4 A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAK IN<<<<<<<<<<<<<<< \nCO38641541AZE98062 72 F33080842 E6 HK 4 A<<<<<<<58 ",
            //   "PCAZERAH IMLI <MURADLI <<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541AZE9806272 F33080842 E6 HK4A<<<<<<«58 ",
            //   "PCAZERAH IMLI <MURADLI <<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541AZE9806272 F33080842 E6 HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKI N<<<<<<<<<<<<<<< \nCO38641541AZE98062 72 F33080842 E6 HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURAD LI <<AYTAK I N<<<<<<<<<<<<<<< \nC038641541AZ E9806272 F33080842 E 6 HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<c< \nCO38641541AZE9806272 F55080842E6HK4AK<<K<<<8 ",
            //   "PCAZERAMIMLI <MURADLI<<AYTAKIN<<<<<<<<<<Kc<< ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZE%AMIMLL <MURADLI<AY TAKINCK<<KK<<c<<<cc< \nC618661541AZE9806272FS508084266HK&AKK<KKK<S8 ",
            //   "PCAZERAHIML1<MURADLI<<AYTAKIN<<K<<<<««<cc« \nCO38641541AZE 98062 72F53080842 E6HK4 AC<<<<K<SB ",
            //   "PCAZERAMIMLI <MURADLI<<AYT AK INK<<<e<««<<<eKe« \nCO38641541AZE98062 72 F33080842E6HK4AKK<KKe<s8 ",
            //   "PCAZERAHIMLI <MURAD LI<<AYTAKIN<<<<<<<«K<<«<KK \nCO38641541AZE9806272 F33080842 E6NK4AK<<<<<<S8 ",
            //   "PCAZERAHIMLI<MURADLI<<AYTAK IN<<<<<<<«<<<<<«« \nCO38641541 AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI <<AY TAKIN<<<<<<<<<<<<<<< \nCO38641541 AZE98062 72 F33080842 E 6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<«<< \nCO38641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<«<<<<<<<<< \ncO38641541 AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<«<<<< \nCO38641541 AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<««<<<<<<<«« \nCO3864 1541AZE98062 72 F33080842 E6 HK4 A<<<<<<<58 ",
            //   "PCAZERAHIML I <MURADLI<<AYTAKIN<<<<«««<<<<<««« \nCO38641541AZE9806272 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAK IN<<<<<<<<«<<<<«< \nCO38641541 AZE98062 72 F33080842 E6HK4A<<<<<<<8 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<<<<<«<< \nCO3864154 1 AZE98062 72 F33080842 E6HK4 A<<<<<<<8 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<««<<<<<<««< \n\nCO38641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<«<<<<<<<< \nCO38641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI <<AYTAKIN<<<<<<<<<<<<<<< \nCO38641541AZE98062 72 F33080842 E 6HK4 A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<«<<<<<<<<<< \nC038641541 AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURAD LI<<AYT AKIN<<<<<<<««<<<««K \nCO3864 1541AZE98062 72 F33080842 E6HK4 A<««««K«s8 ",
            //   "PCAZER AHIMLI<MURADLI<<AYTAK IN<<<<<<<<««<<««« ",
            //   "PCAZERAHIMLI<MURADLI<<AYTAKIN<<<<<<<««««<<KK \nCO3864 1541AZE98062 72 F33080842E6HKAA<<<<KKcS8 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<«««<<«««« \nCO38641541AZE98062 72 F33080842E6MK4 A<<<CKK<S8 ",
            //   "PCAZERAHIMLI <MURADLI<<AYT AKIN<<<<<<<«<<<«««« \nCO3864154 1AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AY TAK IN<<<<<<«««<<<««« \nCO38641541AZE98062 72 F33080842 E6HK4A<<<<««<s8 ",
            //   "PCAZERAHIMLI <MURAD LI<<AYTAK IN<<<<<<«<<<<<««< \nCO38641541AZE9806272 F33080842 E 6HK4A<<<<««<58 ",
            //   "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<««<<<«« \nCO38641541AZE98062 72 F33080842 E6HK4A<<<<<<<58 ",
            // ];
            // final dataList2 = [
            //   "PEROUMIHALI<KGEORGE<ALEXD<<<<<<K<KKKK<\n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<<<\n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<<KKKK<«K< t\n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<<K<<K<<«K |\n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALIKKGEORGE<AIEXD<<<<<K<<<KK< \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<< \n0613771131ROUO 403036M3201040303245033<86 <K<<s ",
            //   "PEROUMIHALI<KGEORGE<ALEXDK<<<KKKKKK<<KKK \n0613771131ROU040303 6M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<KKK<KKKKK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMI HALI<<GEORGEKALEXD<<<<<<<<K<<KK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<< \n0613771131ROU0403036M3201040303245033<86 K<<<KKK ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<«<<KKKKKKKK< \n0613771131ROUO403036M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<KKKKK<KKK<<K \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMTHALI<<GEORGE<ALEXDK<<<<<KK<KKKKK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGEKALEXD<<<<<<K<<<<<<<< \n0613771131ROU0 403036M3201040303245033<86 ",
            //   "<K<K<<<<K PEROUMIHALI<<GEORGE<ALEXD<«KK \n0613771131ROU040303 6M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<<KK<K \n0613771131ROUO403036M3201040303245033<86 <<<<KK ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<K<«KKK<<<<<K \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<AILEXD<<<<<K K<<<<K<<< \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGEKALEXD<<<<KKKKKKKKKK< \nD613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<<K<< <<<<<K \n613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALIKKGEORGE<ALEXD<<<K<<<<<<«KK< \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGEKALEXD<<<<K<<KK<<<K< \n0613771131ROU0 40303 6M3201040303245033<86 ",
            //   "PEROUMIHALI<GEORGE<ALEXD<<<K<<<<<KK<< \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<«K<KKKKK<<KK \n0613771131ROUO 4 0303 6M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGEKALEXD<<<K<K \n0613771131ROU0403036M3201040303245033<86 <<K<KK< ",
            //   "PEROUMIHALI<<GEORGE<ALEXDK<< \n0613771131ROU0403036M3201040303245033<86 <<<KKK< ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<<<<<K<<<< \n0613771131ROUO403036M3201040303245033<86 ",
            //   "PEROUMIHAL<<GEORGE<ALEXD<<<<<<KK<<KK<K< \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<<<<<<<<KK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMI HALIK<GEORGEKALEXD<<<K<KK<<<KKK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<<<<KKK<<<KKK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<K<KKKKKKK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMTHALI<<GEORGE<ALEXD<<«<KKK<<KKKKK< \n0613771131ROU0 403036M3 201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<<<<KKK<<KKKK \n613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<<<KKK<<KKKKK \n0613771131ROU0 403036M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGEKALEXD<<<<<<<<KKKKK<< \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<<K<<<KKKK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<<KK<<<<KK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE <ALEXD<<<K<<<KKKK<KK |\n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGEKALEXD<<<<<KKK<KKKKK \n|l0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<<KKK<KKKKKK< \n|0613771131ROT0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<<KKKK<<<K \n0613771131ROU0 403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<K<KK<KK<<KKKKK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGEKALEXD<<<< \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<KGEORGE<ALEXD<<<KKKKKKKKKKKK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGEKAIEXD<<K<KKS<<K<K \nl0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<K<<<KKKK<K \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<KKKK<KKKKKK< \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGE<ALEXD<<<<<<<<<<KKKKK \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<<KKKKK<KK \n0613771131ROUO 403036M3201040303245033<86 ",
            //   "PEROUMIHALIKKGEORGE<ALEXD<<<<<<K<<KKKK \n0613771131ROUO403036M3201040303245033<86 ",
            //   "PEROUMIHALIK<GEORGEKALEXD<<<<<<KK<<<KKK \n0613771131ROUO403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<KKK<<<<<K \n0613771131ROU0403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<KKK \n0613771131ROU0403036M3201040303245033<86 <<K<< ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<<<<<<<<<< \n0613771131ROUO403036M3201040303245033<86 ",
            //   "PEROUMI HALI<<GEORGE<ALEXD<«<<<<«<<<<K \n|0613771131ROUO403036M3201040303245033<86 ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<< K<KKK \n|0613771131ROU0403036M3201040303245033<86 << ",
            //   "PEROUMIHALI<<GEORGE<ALEXD<<<<<<<<<KK<<- \n0613771131ROU0 4 03036M3201040303245033<8 ",
            //   "PEROUMI HALI<<GEORGE<ALEXDK<<<<«<«<<<<K \nl0613771131ROU0403036M3201040303245033<8 ",
            //   "3 PEROUMIHALI<<GEORGE<ALEXD<<<K<<<K<K<K<e \n0613771131ROU0403036M3201040303245033<E ",
            // ];
            // // String s = "PCAZERAHIMLI <MURADLI<<AYTAKIN<<<<<<<<««««K<<\nCO38641541AZE98062 72 F33080842 E6HK4A<<<<«<<58 ";
            // dataList2.forEach((d) {
            //   controller.debug(d, ParseAlgorithm.method1, (a) {
            //     log(a.valid.toString());
            //   });
            // });
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return SessionLogHistoryListDialog(historyList: controller.getSessionHistory.value);
              },
            );
          },
          child: ValueListenableBuilder<List<SessionStatus>>(
            valueListenable: controller.getSessionHistory,
            builder: (context, value, child) {
              return Text("Passport Reader ${sessionList.length}");
            },
          ),
        ),
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
                  setting = OcrMrzSetting.fromJson(a.toJson());
                  setState(() {});
                }
              });
              // controller.flashOn();
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(onPressed: () async {
      //   final path = await controller.takePicture();
      //   log("path :$path");
      //
      // }),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Stack(
                children: [
                  OcrMrzReader(
                    onSessionChange: (List<SessionStatus> sl) {
                      if (sl.length > 1) {
                        sessionList = sl;
                        setState(() {});
                      }
                    },
                    controller: controller,
                    showFrame: false,
                    setting: setting,
                    onFoundMrz: (a) {
                      // log(a.valid.toString());
                      // log(a.nationality);
                      if (scanning) {
                        if (a.matchSetting(setting)) {
                          showFoundPassport(a);
                        } else {
                          // log("res does not match setting");
                          // log(jsonEncode(a.valid.toJson()));
                        }
                      }
                      // log("✅ ${a.documentType} matched:");
                    },
                    mrzLogger: (l) {
                      if (l.rawMrzLines.isNotEmpty && l.fixedMrzLines.join().trim().isNotEmpty) {
                        logCount++;
                        lastLog = l;
                        fixed = l.fixedMrzLines;
                        setState(() {});

                        // log("log recieved\n${l.fixedMrzLines.join("\n")}");
                        // log("log setted\n${lastLog!.fixedMrzLines.join("\n")}");
                        // log(jsonEncode(l.toJson()));
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
                                  Row(children: [Expanded(child: FittedBox(child: Text(fixed.join("\n"))))]),
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
