import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:flutter/material.dart';
import 'package:ocr_mrz/mrz_parser/mrz_parser.dart';
import 'package:ocr_mrz/mrz_parser/mrz_result.dart';
import 'package:ocr_mrz/ocr_mrz_widget.dart';

import 'ocr_mrz_new_controller.dart'; // We'll still need the controller

class OcrMrzReaderNew extends StatefulWidget {
  final void Function(MrzResult result) onFoundMrz;
  final void Function(Map<String, dynamic> progress)? onProgress;
  final OcrMrzControllerNew controller;
  final bool isActive;
  final int confidence;
  final bool showFrame;
  final bool showZoom;

  OcrMrzReaderNew({
    super.key,
    required this.onFoundMrz,
    required this.controller,
    this.onProgress,
    this.isActive = true,
    this.confidence = 3,
    this.showFrame = true,
    this.showZoom = true,
  });

  @override
  State<OcrMrzReaderNew> createState() => _OcrMrzReaderNewState();
}

class _OcrMrzReaderNewState extends State<OcrMrzReaderNew> {
  late final MrzParser _mrzParser;

  @override
  void initState() {
    super.initState();
    _mrzParser = MrzParser(confidence: widget.confidence);
  }

  @override
  Widget build(BuildContext context) {
    return CameraKitOcrPlusView(
      showFrame: widget.showFrame,
      showZoomSlider: widget.showZoom,
      controller: widget.controller,
      onTextRead: (ocrData) {
        if (!widget.isActive) {
          return;
        }

        try {
          final MrzResult? result = _mrzParser.parse(ocrData);
          
          widget.onProgress?.call(_mrzParser.getProgress(ocrData));

          if (result != null) {
            log('--- MRZ Found! ---');
            log(result.toString());
            
            widget.onFoundMrz(result);
            widget.controller.resetSession(); 
            _mrzParser.reset();
          }
        } catch (e) {
          log('Error during MRZ parsing: $e');
        }
      },
    );
  }
}
