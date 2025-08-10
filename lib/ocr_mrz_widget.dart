import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:ocr_mrz/mrz_result_class.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/passport_util.dart';

import 'mrz_result_class_fix.dart';
import 'mrz_util.dart';
import 'name_validation_data_class.dart';
import 'travel_doc_util.dart';
import 'visa_util.dart';

class OcrMrzReader extends StatelessWidget {
  final void Function(OcrMrzResult res) onFoundMrz;
  final OcrMrzSetting? setting;
  final List<NameValidationData>? nameValidations;

  const OcrMrzReader({super.key, required this.onFoundMrz, this.setting, this.nameValidations});

  @override
  Widget build(BuildContext context) {
    return CameraKitOcrPlusView(
      onTextRead: (c) {
        // processFrameLines(c,onFoundMrz);
        handleOcr(c, onFoundMrz, setting, nameValidations);
      },
    );
  }
}

/// General MRZ handler: tries passport (TD3) and visa (MRV-A/MRV-B),
/// picks the better-scoring parse, and calls [onFoundMrz] with OcrMrzResult.
/// General MRZ handler: tries ONE parser, and only if it fails, tries the other.
/// Set [tryPassportFirst] to control the order.
void handleOcr(OcrData ocr, void Function(OcrMrzResult res) onFoundMrz, OcrMrzSetting? setting, List<NameValidationData>? nameValidations, {bool tryPassportFirst = true}) {
  try {
    final s = setting ?? OcrMrzSetting();

    Map<String, dynamic>? result;

    if (tryPassportFirst) {
      result = tryParseMrzFromOcrLines(ocr, s, nameValidations);
      result ??= tryParseVisaMrzFromOcrLines(ocr, s, nameValidations);
      result ??= tryParseTD1FromOcrLines(ocr, s, nameValidations);
      result ??= tryParseTD2FromOcrLines(ocr, s, nameValidations);
    } else {
      result = tryParseVisaMrzFromOcrLines(ocr, s, nameValidations);
      result ??= tryParseMrzFromOcrLines(ocr, s, nameValidations);
      result ??= tryParseTD1FromOcrLines(ocr, s, nameValidations);
      result ??= tryParseTD2FromOcrLines(ocr, s, nameValidations);
    }

    if (result == null) return; // nothing parsed

    final parsed = OcrMrzResult.fromJson(result);
    log("✅ Valid ${parsed.isVisa ? 'Visa' : 'Passport'} MRZ (${parsed.mrzFormat.name}):");
    log("\n${parsed.mrzLines.join("\n")}");
    onFoundMrz(parsed);
  } catch (e, st) {
    log(e.toString());
    log(st.toString());
  }
}
