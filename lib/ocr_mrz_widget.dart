import 'dart:convert';
import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_plus_controller.dart';
import 'package:camera_kit_plus/enums.dart';
import 'package:flutter/material.dart';
import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:ocr_mrz/mrz_result_class.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/orc_mrz_log_class.dart';
import 'package:ocr_mrz/passport_util.dart';

import 'mrz_result_class_fix.dart';
import 'mrz_util.dart';
import 'name_validation_data_class.dart';
import 'travel_doc_util.dart';
import 'visa_util.dart';

class OcrMrzController extends CameraKitPlusController {
    flashOn(){
      changeFlashMode(CameraKitPlusFlashMode.on);
    }
}

class OcrMrzReader extends StatefulWidget {
  final void Function(OcrMrzResult res) onFoundMrz;
  final void Function(OcrMrzLog log)? mrzLogger;
  final List<DocumentType> filterTypes;
  final OcrMrzSetting? setting;
  final OcrMrzController? controller;
  final List<NameValidationData>? nameValidations;

  const OcrMrzReader({super.key, required this.onFoundMrz, this.setting, this.nameValidations, this.mrzLogger, this.filterTypes = const [],this.controller});

  @override
  State<OcrMrzReader> createState() => _OcrMrzReaderState();
}

class _OcrMrzReaderState extends State<OcrMrzReader> {
  late OcrMrzController cameraKitPlusController = widget.controller??OcrMrzController();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 400),(){
        cameraKitPlusController.setOcrRotation(widget.setting?.rotation??0);
        cameraKitPlusController.setMacro(widget.setting?.macro??false);
      });
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant OcrMrzReader oldWidget) {
    // log(jsonEncode(widget.setting?.toJson()) );
    // log(jsonEncode(oldWidget.setting?.toJson()) );
    super.didUpdateWidget(oldWidget);

    if(oldWidget.setting?.macro != widget.setting?.macro){
      log("should change macro");
      cameraKitPlusController.setMacro(widget.setting?.macro??false);
    }
    if(oldWidget.setting?.rotation != widget.setting?.rotation){
      log("should change rotation");
      cameraKitPlusController.setOcrRotation(widget.setting?.rotation??0);

    }
    // if(mounted ) {
    //   cameraKitPlusController.setOcrRotation(widget.setting?.rotation??0);
    //   cameraKitPlusController.setMacro(widget.setting?.macro??false);
    //   log("setting macro ${widget.setting?.macro}");
    // }

  }

  @override
  Widget build(BuildContext context) {
    return CameraKitOcrPlusView(
      controller: cameraKitPlusController,
      onTextRead: (c) {
        // log(c.text);
        // processFrameLines(c,onFoundMrz);
        handleOcr(c, widget.onFoundMrz, widget.setting, widget.nameValidations, widget.mrzLogger, widget.filterTypes);
      },
    );
  }
}

/// General MRZ handler: tries passport (TD3) and visa (MRV-A/MRV-B),
/// picks the better-scoring parse, and calls [onFoundMrz] with OcrMrzResult.
/// General MRZ handler: tries ONE parser, and only if it fails, tries the other.
/// Set [tryPassportFirst] to control the order.
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

    // if (tryPassportFirst) {
    //
    //   result ??= tryParseVisaMrzFromOcrLines(ocr, s, nameValidations,mrzLogger);
    //   // result ??= tryParseTD1FromOcrLines(ocr, s, nameValidations,mrzLogger);
    //   // result ??= tryParseTD2FromOcrLines(ocr, s, nameValidations,mrzLogger);
    // } else {
    //   result = tryParseVisaMrzFromOcrLines(ocr, s, nameValidations,mrzLogger);
    //   result ??= tryParseMrzFromOcrLines(ocr, s, nameValidations,mrzLogger);
    //   // result ??= tryParseTD1FromOcrLines(ocr, s, nameValidations,mrzLogger);
    //   // result ??= tryParseTD2FromOcrLines(ocr, s, nameValidations,mrzLogger);
    // }

    if (result == null) return; // nothing parsed

    final parsed = OcrMrzResult.fromJson(result);
    // log("✅ Valid ${parsed.isVisa ? 'Visa' : 'Passport'} MRZ (${parsed.mrzFormat.name}):");
    // log("\n${parsed.mrzLines.join("\n")}");
    onFoundMrz(parsed);
  } catch (e, st) {
    log(e.toString());
    log(st.toString());
  }
}
