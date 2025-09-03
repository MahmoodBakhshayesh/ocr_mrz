// import 'dart:developer';
//
// import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
// import 'package:ocr_mrz/name_validation_data_class.dart';
//
// import 'ocr_mrz_settings_class.dart';
// import 'orc_mrz_log_class.dart';
// import 'mrz_result_class_fix.dart';
//
// // Legacy (passport) – returns Map<String, dynamic>?
// import 'improved_passport_util.dart' show tryParseMrzFromOcrLines;
//
// // Typed MRV + legacy wrapper exist, but we’ll use the typed API:
// import 'improved_visa_util.dart'
//     show tryParseVisaMrzFromOcrLinesModern, VisaMrzSuccess, VisaMrzFailure;
//
// // Typed TD1/TD2 API:
// import 'improved_td_util.dart'
//     show
//     tryParseTD1FromOcrLinesModern,
//     tryParseTD2FromOcrLinesModern,
//     IdMrzSuccess,
//     IdMrzFailure;
//
// enum DocumentType { passport, visa, travelDocument1, travelDocument2 }
//
// void handleOcr(
//     OcrData ocr,
//     void Function(OcrMrzResult res) onFoundMrz,
//     OcrMrzSetting? setting,
//     List<NameValidationData>? nameValidations,
//     void Function(OcrMrzLog log)? mrzLogger,
//     List<DocumentType> filterTypes, {
//       bool tryPassportFirst = true,
//     }) {
//   try {
//     final s = setting ?? OcrMrzSetting();
//
//     // Build parse order
//     final List<DocumentType> all = [
//       DocumentType.passport,
//       DocumentType.visa,
//       DocumentType.travelDocument1,
//       DocumentType.travelDocument2,
//     ];
//     final allow = filterTypes.isEmpty ? all.toSet() : filterTypes.toSet();
//
//     List<DocumentType> order;
//     if (tryPassportFirst) {
//       order = [
//         DocumentType.passport,
//         DocumentType.visa,
//         DocumentType.travelDocument1,
//         DocumentType.travelDocument2,
//       ];
//     } else {
//       order = [
//         DocumentType.visa,
//         DocumentType.travelDocument1,
//         DocumentType.travelDocument2,
//         DocumentType.passport,
//       ];
//     }
//     order = order.where(allow.contains).toList();
//
//     Map<String, dynamic>? asMap;
//
//     for (final kind in order) {
//       switch (kind) {
//         case DocumentType.passport:
//         // Legacy passport parser returns Map? already compatible with OcrMrzResult
//           asMap = tryParseMrzFromOcrLines(ocr, s, nameValidations, mrzLogger);
//           if (asMap != null) {
//             onFoundMrz(OcrMrzResult.fromJson(asMap));
//             log("passport success");
//             return;
//           }
//           break;
//
//         case DocumentType.visa:
//           final visaRes = tryParseVisaMrzFromOcrLinesModern(
//             ocrData: ocr,
//             setting: s,
//             nameValidations: nameValidations,
//             mrzLogger: mrzLogger,
//           );
//           if (visaRes is VisaMrzSuccess) {
//             onFoundMrz(OcrMrzResult.fromJson(visaRes.data));
//             return;
//           } else if (visaRes is VisaMrzFailure) {
//             // Optional: log reason for telemetry/debug
//             // log('Visa parse failed: ${visaRes.reason}');
//           }
//           break;
//
//         case DocumentType.travelDocument1:
//           final td1Res = tryParseTD1FromOcrLinesModern(
//             ocrData: ocr,
//             setting: s,
//             nameValidations: nameValidations,
//             mrzLogger: mrzLogger,
//           );
//           if (td1Res is IdMrzSuccess) {
//             onFoundMrz(OcrMrzResult.fromJson(td1Res.data));
//             return;
//           } else if (td1Res is IdMrzFailure) {
//             // log('TD1 parse failed: ${td1Res.reason}');
//           }
//           break;
//
//         case DocumentType.travelDocument2:
//           final td2Res = tryParseTD2FromOcrLinesModern(
//             ocrData: ocr,
//             setting: s,
//             nameValidations: nameValidations,
//             mrzLogger: mrzLogger,
//           );
//           if (td2Res is IdMrzSuccess) {
//             onFoundMrz(OcrMrzResult.fromJson(td2Res.data));
//             return;
//           } else if (td2Res is IdMrzFailure) {
//             // log('TD2 parse failed: ${td2Res.reason}');
//           }
//           break;
//       }
//     }
//
//     // Nothing parsed – just return quietly (like before)
//     return;
//   } catch (e, st) {
//     log(e.toString());
//     log(st.toString());
//   }
// }
