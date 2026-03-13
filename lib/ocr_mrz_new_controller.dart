import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera_kit_plus/camera_kit_plus_controller.dart';
import 'package:camera_kit_plus/enums.dart';
import 'package:flutter/material.dart';
import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:ocr_mrz/mrz_parser/mrz_parser.dart'; // Import the new parser
import 'package:ocr_mrz/mrz_result_class.dart';
import 'package:ocr_mrz/my_ocr_handler.dart';
import 'package:ocr_mrz/my_ocr_handler_new.dart';
import 'package:ocr_mrz/ocr_mrz_api_config.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/online_parse_class.dart';
import 'package:ocr_mrz/orc_mrz_log_class.dart';
import 'package:ocr_mrz/passport_util.dart';
import 'package:ocr_mrz/session_logger.dart';
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

class OcrMrzControllerNew extends CameraKitPlusController {
  final ValueNotifier<List<SessionStatus>> _sessionHistory = ValueNotifier<List<SessionStatus>>([SessionStatus.start()]);
  final OcrMrzAggregator aggregator = OcrMrzAggregator(); // Legacy aggregator
  late final SessionLogger logger;
  late DateTime _sessionStartTime;
  
  late final ValueNotifier<OcrMrzApiConfig?> _apiConfigNotifier;
  OcrMrzApiConfig? get apiConfig => _apiConfigNotifier.value;
  set apiConfig(OcrMrzApiConfig? newConfig) => _apiConfigNotifier.value = newConfig;
  ValueNotifier<OcrMrzApiConfig?> get apiConfigNotifier => _apiConfigNotifier;

  // New, unified parser instance
  late final MrzParser mrzParser;

  OcrMrzControllerNew({SessionLogger? sessionLogger, OcrMrzApiConfig? apiConfig, int confidence = 3}) {
    logger = sessionLogger ?? SessionLogger();
    _sessionStartTime = DateTime.now();
    _apiConfigNotifier = ValueNotifier(apiConfig);
    mrzParser = MrzParser(confidence: confidence);
  }

  void changeApiConfig(OcrMrzApiConfig? newConfig) {
    apiConfig = newConfig;
  }

  flashOn() {
    changeFlashMode(CameraKitPlusFlashMode.on);
  }

  /// Resets the entire scanning session, including the parser's internal state.
  void resetSession() {
    // Legacy state reset
    _sessionHistory.value = [SessionStatus.start()];
    aggregator.reset();
    
    // New system reset
    mrzParser.reset();
    
    // Common state reset
    logger.clear();
    _sessionStartTime = DateTime.now();
  }

  ValueNotifier<List<SessionStatus>> get getSessionHistory => _sessionHistory;

  void setSessionHistory(List<SessionStatus> sh) {

    _sessionHistory.value = [...sh];
  }

  void addSessionHistory(SessionStatus s) {
    _sessionHistory.value = [..._sessionHistory.value, s];
  }

  void dispose() {
    logger.dispose();
    _apiConfigNotifier.dispose();
  }

  debug(String s, ParseAlgorithm alg, void Function(OcrMrzResult res) onFoundMrz) {
    final ocr = OcrData(text: s, lines: s.split("\n").map((oc) => OcrLine(text: oc, cornerPoints: [])).toList());
    switch (alg) {
      case ParseAlgorithm.method1:
        handleOcrNew(ocr, onFoundMrz, OcrMrzSetting(), [], null, []);
        return;
      case ParseAlgorithm.method2:
        handleOcr(ocr, onFoundMrz, OcrMrzSetting(), [], null, []);
      case ParseAlgorithm.method3:
        handleOcr3(ocr, onFoundMrz, OcrMrzSetting(), [], null, []);
    }
  }
}

// Re-introducing the legacy handler methods for the debug function
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
    Map<String, dynamic>? result;
    if (filterTypes.isEmpty || filterTypes.contains(DocumentType.passport)) {
      result = tryParseMrzFromOcrLines(ocr, setting ?? OcrMrzSetting(), nameValidations, mrzLogger);
    }
    if (filterTypes.isEmpty || filterTypes.contains(DocumentType.visa)) {
      result ??= tryParseVisaMrzFromOcrLines(ocr, setting ?? OcrMrzSetting(), nameValidations, mrzLogger);
    }
    if (filterTypes.isEmpty || filterTypes.contains(DocumentType.travelDocument1)) {
      result ??= tryParseTD1FromOcrLines(ocr, setting ?? OcrMrzSetting(), nameValidations, mrzLogger);
    }
    if (filterTypes.isEmpty || filterTypes.contains(DocumentType.travelDocument2)) {
      result ??= tryParseTD2FromOcrLines(ocr, setting ?? OcrMrzSetting(), nameValidations, mrzLogger);
    }

    if (result == null) {
      return;
    }

    final parsed = OcrMrzResult.fromJson(result);
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
    var result = MyOcrHandlerNew.handle(ocr, mrzLogger);
    if (result != null) {
      onFoundMrz(result);
    }
  } catch (e, st) {
    log(e.toString());
    log(st.toString());
  }
}
