import 'dart:convert';
import 'dart:developer';
import 'package:camera_kit_plus/camera_kit_plus_controller.dart';
import 'package:camera_kit_plus/enums.dart';
import 'package:flutter/material.dart';
import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:ocr_mrz/mrz_result_class.dart';
import 'package:ocr_mrz/my_ocr_handler.dart';
import 'package:ocr_mrz/my_ocr_handler_new.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/orc_mrz_log_class.dart';
import 'package:ocr_mrz/passport_util.dart';
import 'package:ocr_mrz/session_ocr_handler.dart';
import 'package:ocr_mrz/session_ocr_handler_consensus.dart';
import 'package:ocr_mrz/session_status_class.dart';

import 'aggregator.dart';
import 'improved_ocr_handler.dart';
import 'mrz_result_class_fix.dart';
import 'mrz_util.dart';
import 'name_validation_data_class.dart';

import 'travel_doc_util.dart';
import 'visa_util.dart';
export 'session_log_history_list_dialog.dart';

class OcrMrzController extends CameraKitPlusController {
  ValueNotifier<List<SessionStatus>> _sessionHistory = ValueNotifier<List<SessionStatus>>([SessionStatus.start()]);
  ValueNotifier<OcrMrzAggregator> _aggregator = ValueNotifier<OcrMrzAggregator>(OcrMrzAggregator());

  // List<SessionStatus> _sessionHistory = [SessionStatus.start()];

  flashOn() {
    changeFlashMode(CameraKitPlusFlashMode.on);
  }

  resetSession() {
    _sessionHistory.value = [SessionStatus.start()];
    _aggregator.value.reset();
  }

  OcrMrzAggregator get getAggregator => _aggregator.value;

  ValueNotifier<List<SessionStatus>> get getSessionHistory => _sessionHistory;

  void setSessionHistory(List<SessionStatus> sh) {
    _sessionHistory.value = [...sh];
  }

  void addSessionHistory(SessionStatus s) {
    _sessionHistory.value = [..._sessionHistory.value, s];
  }

  debug(String s, ParseAlgorithm alg, void Function(OcrMrzResult res) onFoundMrz) {
    final ocr = OcrData(text: s, lines: s.split("\n").map((oc) => OcrLine(text: oc, cornerPoints: [])).toList());
    switch (alg) {
      case ParseAlgorithm.method1:
        handleOcrNew(ocr, onFoundMrz, OcrMrzSetting(), [], null, []);
        return;
      case ParseAlgorithm.method2:
        // log("hande ocr");
        handleOcr(ocr, onFoundMrz, OcrMrzSetting(), [], null, []);
      case ParseAlgorithm.method3:
        // log("hande ocr");
        handleOcr3(ocr, onFoundMrz, OcrMrzSetting(), [], null, []);
    }
  }
}

class OcrMrzReader extends StatefulWidget {
  final void Function(OcrMrzResult res) onFoundMrz;
  final void Function(OcrMrzLog log)? mrzLogger;
  final void Function(List<SessionStatus> sessionList)? onSessionChange;
  final void Function(OcrMrzConsensus sessionList)? onConsensusChanged;
  final List<DocumentType> filterTypes;
  final OcrMrzSetting? setting;
  final OcrMrzCountValidation? countValidation;
  final OcrMrzController? controller;
  final List<NameValidationData>? nameValidations;
  final bool showFrame;
  final bool showZoom;
  final OcrMrzAggregator aggregator = OcrMrzAggregator();

  OcrMrzReader({
    super.key,
    required this.onFoundMrz,
    this.setting,
    this.nameValidations,
    this.mrzLogger,
    this.filterTypes = const [],
    this.controller,
    this.showFrame = true,
    this.showZoom = true,
    this.onSessionChange,
    this.countValidation,
    this.onConsensusChanged,
  });

  @override
  State<OcrMrzReader> createState() => _OcrMrzReaderState();
}

class _OcrMrzReaderState extends State<OcrMrzReader> {
  late OcrMrzController cameraKitPlusController = widget.controller ?? OcrMrzController();

  // late OcrMrzSetting setting = widget.setting ?? OcrMrzSetting();
  double zoom = 1.0;

  SessionStatus session = SessionStatus.start();
  OcrMrzConsensus? improving;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 400), () {
        cameraKitPlusController.setOcrRotation(widget.setting?.rotation ?? 0);
        cameraKitPlusController.setMacro(widget.setting?.macro ?? false);
      });
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant OcrMrzReader oldWidget) {
    // log(jsonEncode(widget.setting?.toJson()) );
    // log(jsonEncode(oldWidget.setting?.toJson()) );
    super.didUpdateWidget(oldWidget);

    if (oldWidget.setting?.macro != widget.setting?.macro) {
      log("should change macro");
      cameraKitPlusController.setMacro(widget.setting?.macro ?? false);
    }
    if (oldWidget.setting?.rotation != widget.setting?.rotation) {
      log("should change rotation");
      cameraKitPlusController.setOcrRotation(widget.setting?.rotation ?? 0);
    }
    // if(mounted ) {
    //   cameraKitPlusController.setOcrRotation(widget.setting?.rotation??0);
    //   cameraKitPlusController.setMacro(widget.setting?.macro??false);
    //   log("setting macro ${widget.setting?.macro}");
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CameraKitOcrPlusView(
          showFrame: widget.showFrame,
          showZoomSlider: widget.showZoom,
          controller: cameraKitPlusController,
          onTextRead: (c) {
            if (widget.setting?.algorithm == ParseAlgorithm.method3) {
              OcrMrzLog log = OcrMrzLog(rawText: c.text, rawMrzLines: c.lines.where((a) => a.text.contains("<")).map((a) => a.text).toList(), fixedMrzLines: [], validation: OcrMrzValidation(), extractedData: {});
              widget.mrzLogger?.call(log);
            } else {
              final newCon = SessionOcrHandlerConsensus().handleSession(cameraKitPlusController._aggregator.value, c,widget.setting ?? OcrMrzSetting(),widget.nameValidations??[]);
              improving = newCon;
              widget.onConsensusChanged?.call(newCon);
              if(cameraKitPlusController._aggregator.value.matchValidationCount(widget.countValidation,widget.setting ?? OcrMrzSetting())) {
                if (newCon.toResult().matchSetting(widget.setting ?? OcrMrzSetting())) {
                  final result = newCon.toResult();
                  result.line1 = cameraKitPlusController.getAggregator.buildMrz()[0];
                  result.line2 = cameraKitPlusController.getAggregator.buildMrz()[1];
                  result.line3 =cameraKitPlusController.getAggregator.buildMrz().length>2? cameraKitPlusController.getAggregator.buildMrz()[2]:null;
                  widget.onFoundMrz(result);
                  widget.controller?.resetSession();
                }
              }
              setState(() {});
            }
            //   if(widget.setting?.algorithm == ParseAlgorithm.method1){
            //     handleOcrNew(c, widget.onFoundMrz, widget.setting, widget.nameValidations, widget.mrzLogger, widget.filterTypes);
            //   }else if(widget.setting?.algorithm == ParseAlgorithm.method2){
            //
            //     final newSess = SessionOcrHandler().handleSession(cameraKitPlusController.getSessionHistory.value.last, c);
            //     widget.mrzLogger?.call(newSess.getLog);
            //     // log(newSess.nationality??'-');
            //
            //     session = newSess;
            //     if (newSess.logDetails != cameraKitPlusController.getSessionHistory.value.last.logDetails && !cameraKitPlusController.getSessionHistory.value.last.getOcrResult.matchSetting(widget.setting ?? OcrMrzSetting())) {
            //       // if (!cameraKitPlusController.getSessionHistory.last.getOcrResult.matchSetting(widget.setting ?? OcrMrzSetting())) {
            //       // log("should add new session");
            //
            //       // cameraKitPlusController.sessionHistory.add(newSess);
            //       cameraKitPlusController.addSessionHistory(newSess);
            //       widget.onSessionChange?.call(cameraKitPlusController.getSessionHistory.value);
            //       // if (newSess.getOcrResult.matchSetting(widget.setting ?? OcrMrzSetting())) {
            //       widget.onFoundMrz(newSess.getOcrResult);
            //       // }
            //     }else{
            //       widget.onFoundMrz(newSess.getOcrResult);
            //     }
            //     setState(() {});
            //   }else if(widget.setting?.algorithm == ParseAlgorithm.method3){
            //     OcrMrzLog log = OcrMrzLog(rawText: c.text, rawMrzLines: c.lines.where((a)=>a.text.contains("<")).map((a)=>a.text).toList(), fixedMrzLines: [], validation: OcrMrzValidation(), extractedData: {});
            //     widget.mrzLogger?.call(log);
            //   }
            //
            //
          },
        ),
      ],
    );
  }
}

//
// /// General MRZ handler: tries passport (TD3) and visa (MRV-A/MRV-B),
// /// picks the better-scoring parse, and calls [onFoundMrz] with OcrMrzResult.
// /// General MRZ handler: tries ONE parser, and only if it fails, tries the other.
// /// Set [tryPassportFirst] to control the order.
void handleOcr(
  OcrData ocr,
  void Function(OcrMrzResult res) onFoundMrz,
  OcrMrzSetting? setting,
  List<NameValidationData>? nameValidations,
  void Function(OcrMrzLog log)? mrzLogger,
  List<DocumentType> filterTypes, {
  bool tryPassportFirst = true,
}) {
  try {
    final s = setting ?? OcrMrzSetting();
    // log(ocr.text);
    Map<String, dynamic>? result;
    if (filterTypes.isEmpty || filterTypes.contains(DocumentType.passport)) {
      result = tryParseMrzFromOcrLines(ocr, s, nameValidations, mrzLogger);
    }
    if (filterTypes.isEmpty || filterTypes.contains(DocumentType.visa)) {
      result ??= tryParseVisaMrzFromOcrLines(ocr, s, nameValidations, mrzLogger);
    }
    if (filterTypes.isEmpty || filterTypes.contains(DocumentType.travelDocument1)) {
      result ??= tryParseTD1FromOcrLines(ocr, s, nameValidations, mrzLogger);
    }
    if (filterTypes.isEmpty || filterTypes.contains(DocumentType.travelDocument2)) {
      result ??= tryParseTD2FromOcrLines(ocr, s, nameValidations, mrzLogger);
    }

    if (result == null) {
      // log("no result");
      return; // nothing parsed
    }

    final parsed = OcrMrzResult.fromJson(result);
    // log("✅ Valid ${parsed.isVisa ? 'Visa' : 'Passport'} MRZ (${parsed.mrzFormat.name}):");
    // log("\n${parsed.mrzLines.join("\n")}");
    onFoundMrz(parsed);
  } catch (e, st) {
    log(e.toString());
    log(st.toString());
  }
}

void handleOcrNew(
  OcrData ocr,
  void Function(OcrMrzResult res) onFoundMrz,
  OcrMrzSetting? setting,
  List<NameValidationData>? nameValidations,
  void Function(OcrMrzLog log)? mrzLogger,
  List<DocumentType> filterTypes, {
  bool tryPassportFirst = true,
}) {
  try {
    final s = setting ?? OcrMrzSetting();
    var result = MyOcrHandler.handle(ocr, mrzLogger);
    if (result != null) {
      onFoundMrz(result);
    }
  } catch (e, st) {
    log(e.toString());
    log(st.toString());
  }
}

void handleOcr3(
  OcrData ocr,
  void Function(OcrMrzResult res) onFoundMrz,
  OcrMrzSetting? setting,
  List<NameValidationData>? nameValidations,
  void Function(OcrMrzLog log)? mrzLogger,
  List<DocumentType> filterTypes, {
  bool tryPassportFirst = true,
}) {
  try {
    final s = setting ?? OcrMrzSetting();
    var result = MyOcrHandlerNew.handle(ocr, mrzLogger);
    if (result != null) {
      onFoundMrz(result);
    }
  } catch (e, st) {
    log(e.toString());
    log(st.toString());
  }
}
