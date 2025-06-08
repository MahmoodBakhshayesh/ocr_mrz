import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:ocr_mrz/mrz_result_class.dart';

import 'mrz_util.dart';
class OcrMrzReader extends StatelessWidget {
  final void Function(OcrMrzResult res) onFoundMrz;
  const OcrMrzReader({super.key, required this.onFoundMrz});

  @override
  Widget build(BuildContext context) {
    return CameraKitOcrPlusView(onTextRead: (c){
      processFrameLines(c,onFoundMrz);
    });
  }
}
