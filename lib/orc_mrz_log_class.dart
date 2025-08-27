import 'package:ocr_mrz/mrz_result_class_fix.dart';

class OcrMrzLog {
  final OcrMrzValidation validation;
  final String rawText;
  final List<String> rawMrzLines;
  final List<String> fixedMrzLines;
  final Map<String, dynamic> extractedData;
  late DateTime time;

  OcrMrzLog({required this.rawText, required this.rawMrzLines, required this.fixedMrzLines, required this.validation, required this.extractedData}) {
    time = DateTime.now();
  }
}
