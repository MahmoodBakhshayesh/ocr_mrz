// // mrz_parser.dart
// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
// import 'package:ocr_mrz/doc_code_validator.dart';
// import 'package:ocr_mrz/mrz_result_class_fix.dart'; // assumes MrzFormat enum, etc.
// import 'package:ocr_mrz/name_validation_data_class.dart';
// import 'package:ocr_mrz/orc_mrz_log_class.dart';
//
// import 'ocr_mrz_settings_class.dart';
// import 'travel_doc_util.dart';
//
// /// ----------------------------
// /// Typed parse result
// /// ----------------------------
// sealed class MrzParseResult {
//   const MrzParseResult();
// }
//
// class MrzSuccess extends MrzParseResult {
//   final MrzFormat format;
//   final OcrMrzValidation validation;
//   final Map<String, dynamic> data; // keep compatibility with existing code
//   const MrzSuccess(this.format, this.validation, this.data);
// }
//
// class MrzFailure extends MrzParseResult {
//   final String reason;
//   final List<String> rawLines;
//   const MrzFailure(this.reason, this.rawLines);
// }
//
// /// ----------------------------
// /// Public API (legacy-compatible)
// /// ----------------------------
//
// /// Legacy wrapper to keep your previous call sites working:
// /// returns `Map<String, dynamic>?` (null when parsing fails),
// /// but internally uses the typed result.
// Map<String, dynamic>? tryParseMrzFromOcrLines(
//     OcrData ocrData,
//     OcrMrzSetting? setting,
//     List<NameValidationData>? nameValidations,
//     void Function(OcrMrzLog log)? mrzLogger,
//     ) {
//   final res = tryParseMrzFromOcrLinesModern(
//     ocrData: ocrData,
//     setting: setting,
//     nameValidations: nameValidations,
//     mrzLogger: mrzLogger,
//   );
//
//   if (res is MrzSuccess) return res.data;
//   return null;
// }
//
// /// New typed entry point with better errors.
// MrzParseResult tryParseMrzFromOcrLinesModern({
//   required OcrData ocrData,
//   OcrMrzSetting? setting,
//   List<NameValidationData>? nameValidations,
//   void Function(OcrMrzLog log)? mrzLogger,
// }) {
//   final s = setting ?? OcrMrzSetting();
//
//   // Extract OCR lines (raw)
//   final ocrLines = ocrData.lines.map((a) => a.text).toList();
//
//   // Candidate MRZ lines: length heuristic + contains '<'
//   final rawCandidates = ocrLines.where((a) => a.length > 35 && a.contains('<')).toList();
//   final normalizedCandidates = rawCandidates.map(normalize44).where((l) => l.length == 44).toList();
//
//   if (normalizedCandidates.length < 2) {
//     mrzLogger?.call(OcrMrzLog(
//       rawText: ocrData.text,
//       rawMrzLines: rawCandidates,
//       fixedMrzLines: normalizedCandidates,
//       validation: OcrMrzValidation(),
//       extractedData: {},
//     ));
//     return MrzFailure('Less than 2 MRZ candidate lines after normalization', rawCandidates);
//     // Note: We currently assume TD3. TD1/TD2 support can be added later if needed.
//   }
//
//   // Choose last two lines as MRZ lines (TD3 order)
//   String line1 = normalizedCandidates[normalizedCandidates.length - 2];
//   String line2 = normalizedCandidates[normalizedCandidates.length - 1];
//
//   final oldLine1 = line1;
//   final oldLine2 = line2;
//
//   // "Other lines" for name validation (exclude MRZ-like lines and those with '<')
//   final otherLines = ocrLines.where((a) => !rawCandidates.contains(a) && !a.contains('<')).toList();
//
//   // Repairs
//   line1 = normalizeMrzLine1(line1); // names-friendly O/0, I/1, S/5 swaps
//   line2 = runRepairs(line2, _td3Repairs);
//
//   try {
//     // Guard: ensure 44 chars before substring
//     if (line1.length != 44 || line2.length != 44) {
//       return MrzFailure('Line lengths are not 44 after repair', [oldLine1, oldLine2, line1, line2]);
//     }
//
//     // Line 1 fields
//     final documentType = line1.substring(0, 1);
//     final documentCode = line1.substring(0, 2);
//     final countryCode = fixAlphaOnlyField(line1.substring(2, 5));
//     final nameParts = line1.substring(5).split('<<');
//     var lastName = nameParts[0].replaceAll('<', ' ').trim();
//     var firstName = (nameParts.length > 1 ? nameParts[1] : '').replaceAll('<', ' ').trim();
//     firstName = _cleanMrzName(firstName);
//     lastName = _cleanMrzName(lastName);
//
//     // Line 2 fields
//     final passportNumber = line2.substring(0, 9).replaceAll('<', '');
//     final passportCheck = line2.substring(9, 10);
//     final nationality = fixAlphaOnlyField(line2.substring(10, 13));
//     final birthDateRaw = line2.substring(13, 19);
//     final birthCheck = line2.substring(19, 20);
//     final sex = line2.substring(20, 21);
//     final expiryDateRaw = line2.substring(21, 27);
//     final expiryCheck = line2.substring(27, 28);
//     final personalNumber = line2.substring(28, 42);
//     final personalCheck = line2.substring(42, 43);
//     final finalCheck = line2.substring(43, 44);
//
//     // Check digits (fast)
//     final validPassport = _checkDigitFast(line2.substring(0, 9)) == passportCheck;
//     final validBirth = _checkDigitFast(birthDateRaw) == birthCheck && _isYYYYMMDD6(birthDateRaw);
//     final validExpiry = _checkDigitFast(expiryDateRaw) == expiryCheck && _isYYYYMMDD6(expiryDateRaw);
//
//     final isPersonalEmpty = personalNumber.replaceAll('<', '').isEmpty;
//     final validOptional = isPersonalEmpty
//         ? (personalCheck == '0' || personalCheck == '<')
//         : (_checkDigitFast(personalNumber) == personalCheck);
//
//     final composite = line2.substring(0, 10) +
//         birthDateRaw +
//         birthCheck +
//         expiryDateRaw +
//         expiryCheck +
//         personalNumber +
//         personalCheck;
//     final validFinal = _checkDigitFast(composite) == finalCheck;
//
//     // Validation bundle (uses country/nationality/name checks)
//     final validation = validateMrzLine(
//       line1: line1,
//       line2: line2,
//       code: documentCode,
//       setting: s,
//       otherLines: otherLines,
//       firstName: firstName,
//       lastName: lastName,
//       country: countryCode,
//       nationality: nationality,
//       personalNumber: personalNumber,
//       nameValidations: nameValidations,
//     );
//
//     // log(validation.toString());
//
//     // Date parsing with century logic
//     final birthDt = parseMrzDate(birthDateRaw, isExpiry: false)?.toIso8601String();
//     final expiryDt = parseMrzDate(expiryDateRaw, isExpiry: true)?.toIso8601String();
//
//
//
//     // Construct result map (keeps your current shape)
//     final resultMap = <String, dynamic>{
//       'line1': line1,
//       'line2': line2,
//       'documentCode': documentCode,
//       'documentType': documentType,
//       'countryCode': countryCode,
//       'lastName': lastName,
//       'firstName': firstName,
//       'passportNumber': passportNumber,
//       'nationality': nationality,
//       'birthDate': birthDt,
//       'expiryDate': expiryDt,
//       'sex': sex,
//       'personalNumber': personalNumber,
//       'valid': validation.toJson(),
//       'checkDigits': {
//         'passport': validPassport,
//         'birth': validBirth,
//         'expiry': validExpiry,
//         'optional': validOptional,
//         'final': validFinal,
//       },
//       'ocrData': ocrData.toJson(),
//       'format': MrzFormat.TD3.toString().split('.').last, // current implementation targets TD3
//     };
//
//
//     // Log
//     mrzLogger?.call(OcrMrzLog(
//       rawText: ocrData.text,
//       rawMrzLines: rawCandidates,
//       fixedMrzLines: [line1, line2],
//       validation: validation,
//       extractedData: resultMap,
//     ));
//     // log(jsonEncode(validation.toJson()));
//
//
//     // Quick sanity: non-empty names
//     if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
//       return MrzFailure('Empty first/last name after normalization', [line1, line2]);
//     }
//
//     // Settings-driven acceptance gate
//     bool _require(bool enabled, bool ok) => !enabled || ok;
//
//     final accepts = _require(s.validateNames, validation.nameValid) &&
//         _require(s.validateBirthDateValid, validation.birthDateValid) &&
//         _require(s.validateDocNumberValid, validation.docNumberValid) &&
//         _require(s.validateExpiryDateValid, validation.expiryDateValid) &&
//         _require(s.validateFinalCheckValid, validation.finalCheckValid) &&
//         _require(s.validateLinesLength, validation.linesLengthValid) &&
//         _require(s.validatePersonalNumberValid, validation.personalNumberValid) &&
//         _require(s.validateCountry, validation.countryValid) &&
//         _require(s.validateNationality, validation.nationalityValid);
//
//     if (!accepts) {
//       final failures = <String>[
//         if (s.validateNames && !validation.nameValid) 'name',
//         if (s.validateBirthDateValid && !validation.birthDateValid) 'birthDate',
//         if (s.validateDocNumberValid && !validation.docNumberValid) 'docNumber',
//         if (s.validateExpiryDateValid && !validation.expiryDateValid) 'expiryDate',
//         if (s.validateFinalCheckValid && !validation.finalCheckValid) 'finalCheck',
//         if (s.validateLinesLength && !validation.linesLengthValid) 'linesLength',
//         if (s.validatePersonalNumberValid && !validation.personalNumberValid) 'personalNumber',
//         if (s.validateCountry && !validation.countryValid) 'country',
//         if (s.validateNationality && !validation.nationalityValid) 'nationality',
//       ].join(', ');
//       return MrzFailure('Validation failed: $failures', [line1, line2]);
//     }
//     log("Success passport");
//     // log(jsonEncode(resultMap));
//
//     return MrzSuccess(MrzFormat.TD3, validation, resultMap);
//   } catch (e, st) {
//     log('MRZ parse exception: $e\n$st');
//     mrzLogger?.call(OcrMrzLog(
//       rawText: ocrData.text,
//       rawMrzLines: rawCandidates,
//       fixedMrzLines: [line1, line2],
//       validation: OcrMrzValidation(),
//       extractedData: {'error': e.toString()},
//     ));
//     return MrzFailure('Exception: $e', [line1, line2]);
//   }
// }
//
// /// ----------------------------
// /// Performance helpers
// /// ----------------------------
//
// final _weights = [7, 3, 1];
// final List<int> _valTable = _buildValTable();
//
// List<int> _buildValTable() {
//   final t = List<int>.filled(128, 0);
//   // digits
//   for (var d = 0; d <= 9; d++) t['0'.codeUnitAt(0) + d] = d;
//   // letters
//   for (var i = 0; i < 26; i++) t['A'.codeUnitAt(0) + i] = 10 + i;
//   // '<'
//   t['<'.codeUnitAt(0)] = 0;
//   return t;
// }
//
// String _checkDigitFast(String s) {
//   var sum = 0;
//   for (var i = 0; i < s.length; i++) {
//     final cu = s.codeUnitAt(i);
//     final v = cu < 128 ? _valTable[cu] : 0;
//     sum += v * _weights[i % 3];
//   }
//   return (sum % 10).toString();
// }
//
// /// ----------------------------
// /// Normalization & repairs
// /// ----------------------------
//
// const _normMap = {
//   '«': '<',
//   '|': '<',
//   '\\': '<',
//   '/': '<',
//   '“': '<',
//   '”': '<',
//   '’': '<',
//   '‘': '<',
//   ' ': '<',
//   '—': '-', // rarely present; we strip to '-' then filtered out
//   '–': '-',
// };
//
// /// Normalize a line into exactly 44 chars: uppercase, keep [A-Z0-9<], pad with '<'.
// String normalize44(String line) {
//   final b = StringBuffer();
//   for (final rune in line.toUpperCase().runes) {
//     var ch = String.fromCharCode(rune);
//     ch = _normMap[ch] ?? ch;
//     final cu = ch.codeUnitAt(0);
//     final isAZ = cu >= 65 && cu <= 90;
//     final is09 = cu >= 48 && cu <= 57;
//     if (isAZ || is09 || cu == 60) {
//       b.writeCharCode(cu);
//       if (b.length == 44) break;
//     }
//   }
//   while (b.length < 44) b.write('<');
//   return b.toString();
// }
//
// /// Names-only normalization (line 1, surname/given names).
// String normalizeMrzLine1(String line) {
//   // names fields may be mis-OCRed as digits, fix only name-friendly confusions
//   return line.replaceAll('0', 'O').replaceAll('1', 'I').replaceAll('5', 'S');
// }
//
// /// TD3 repair pipeline
// typedef RepairFn = String Function(String);
// final List<RepairFn> _td3Repairs = [
//   // Already normalized before calling; keep strict and field-aware repairs here:
//   repairMrzLine2Strict,
//   repairSpecificFields,
// ];
//
// String runRepairs(String line, List<RepairFn> steps) {
//   for (final fn in steps) {
//     line = fn(line);
//   }
//   return line;
// }
//
// /// Strict repair: preserves structure and validates candidate variants by check digits.
// String repairMrzLine2Strict(String rawLine) {
//   final Map<String, String> replacements = {
//     '«': '<<',
//     '|': '<',
//     '\\': '<',
//     '/': '<',
//     '“': '<',
//     '”': '<',
//     '’': '<',
//     '‘': '<',
//     ' ': '',
//     'O': '0',
//     // Avoid global Q/I/L/Z/S/B/G swaps in line 2 (can corrupt digits).
//   };
//
//   String cleaned = rawLine
//       .toUpperCase()
//       .split('')
//       .map((c) => replacements[c] ?? c)
//       .where((c) {
//     final cu = c.codeUnitAt(0);
//     final isAZ = cu >= 65 && cu <= 90;
//     final is09 = cu >= 48 && cu <= 57;
//     return isAZ || is09 || cu == 60;
//   })
//       .join();
//
//   if (cleaned.length < 44) cleaned = cleaned.padRight(44, '<');
//   if (cleaned.length > 44) cleaned = cleaned.substring(0, 44);
//
//   List<String> generateCandidates(String line) {
//     final results = <String>[line];
//
//     // Remove a single '<' at various positions
//     for (int i = 0; i < line.length; i++) {
//       if (line[i] == '<') {
//         results.add(line.substring(0, i) + line.substring(i + 1));
//       }
//     }
//     // Remove two '<'s (coarse)
//     for (int i = 0; i < line.length; i++) {
//       if (line[i] != '<') continue;
//       for (int j = i + 1; j < line.length; j++) {
//         if (line[j] != '<') continue;
//         final removed = line.substring(0, i) + line.substring(i + 1, j) + line.substring(j + 1);
//         results.add(removed);
//       }
//     }
//     return results;
//   }
//
//   bool _validCandidate(String line) {
//     if (line.length != 44) return false;
//
//     final birth = line.substring(13, 19);
//     final birthCheck = line[19];
//     final expiry = line.substring(21, 27);
//     final expiryCheck = line[27];
//
//     final personalNum = line.substring(28, 42);
//     final personalCheck = line[42];
//     final finalCheck = line[43];
//
//     final isBirthValid = _isYYYYMMDD6(birth) && _checkDigitFast(birth) == birthCheck;
//     final isExpiryValid = _isYYYYMMDD6(expiry) && _checkDigitFast(expiry) == expiryCheck;
//
//     final isPersonalValid = personalNum.replaceAll('<', '').isEmpty
//         ? (personalCheck == '0' || personalCheck == '<')
//         : (_checkDigitFast(personalNum) == personalCheck);
//
//     final finalCheckInput = line.substring(0, 10) + line.substring(13, 20) + line.substring(21, 43);
//     final isFinalValid = _checkDigitFast(finalCheckInput) == finalCheck;
//
//     final sex = line[20];
//     final validSex = sex == 'M' || sex == 'F' || sex == '<';
//
//     return isBirthValid && isExpiryValid && isPersonalValid && isFinalValid && validSex;
//   }
//
//   for (final candidate in generateCandidates(cleaned)) {
//     String line = candidate;
//     if (line.length < 44) line = line.padRight(44, '<');
//     if (line.length > 44) line = line.substring(0, 44);
//     if (_validCandidate(line)) return line;
//   }
//
//   // fallback
//   return cleaned;
// }
//
// /// Field-specific corrections (alpha-only nationality; tighten personal number shape)
// String repairSpecificFields(String line) {
//   if (line.length != 44) return line;
//
//   // Nationality (10..12) — alpha only; fix common digit-as-letter OCR
//   final nat = line.substring(10, 13).split('').map((c) {
//     switch (c) {
//       case '0':
//         return 'O';
//       case '1':
//         return 'I';
//       case '5':
//         return 'S';
//       case '8':
//         return 'B';
//       case '6':
//         return 'G';
//       default:
//         return c;
//     }
//   }).join();
//
//   // Personal number (28..41) — drop '<' between digits only, then pad
//   final personalRaw = line.substring(28, 42);
//   final digits = personalRaw.replaceAll(RegExp(r'(?<=\d)<(?=\d)'), '');
//   final padded = digits.padRight(14, '<').substring(0, 14);
//
//   return line.substring(0, 10) + nat + line.substring(13, 28) + padded + line.substring(42);
// }
//
// /// ----------------------------
// /// Validation helpers
// /// ----------------------------
//
// OcrMrzValidation validateMrzLine({
//   required String line1,
//   required String line2,
//   required String code,
//   required OcrMrzSetting setting,
//   required List<String> otherLines,
//   required String firstName,
//   required String lastName,
//   required String country,
//   required String nationality,
//   required String personalNumber,
//   required List<NameValidationData>? nameValidations,
// }) {
//   final validation = OcrMrzValidation();
//   try {
//     validation.linesLengthValid = (line2.length == 44 && line1.length == 44);
//
//     final isDocCodeValid = DocumentCodeHelper.isValid(code);
//     validation.docCodeValid = isDocCodeValid;
//
//     final docNumber = line2.substring(0, 9);
//     final docCheck = line2[9];
//     validation.docNumberValid = _checkDigitFast(docNumber) == docCheck;
//
//     final birthDate = line2.substring(13, 19);
//     final birthCheck = line2[19];
//     validation.birthDateValid = _isYYYYMMDD6(birthDate) && _checkDigitFast(birthDate) == birthCheck;
//
//     final expiryDate = line2.substring(21, 27);
//     final expiryCheck = line2[27];
//     validation.expiryDateValid = _isYYYYMMDD6(expiryDate) && _checkDigitFast(expiryDate) == expiryCheck;
//
//     final personalCheck = line2[42];
//     final isPersonalEmpty = personalNumber.replaceAll('<', '').isEmpty;
//     final isPersonalValid = isPersonalEmpty
//         ? (personalCheck == '0' || personalCheck == '<')
//         : (_checkDigitFast(personalNumber) == personalCheck);
//     validation.personalNumberValid = isPersonalValid;
//
//     final finalCheck = line2[43];
//     validation.finalCheckValid = _checkDigitFast(
//       docNumber +
//           docCheck +
//           birthDate +
//           birthCheck +
//           expiryDate +
//           expiryCheck +
//           personalNumber +
//           personalCheck,
//     ) ==
//         finalCheck;
//
//     var namesOk = validateNames(firstName, lastName, otherLines);
//     if (!namesOk && nameValidations != null) {
//       // Allow list override
//       namesOk = nameValidations.any((a) =>
//       a.firstName.toLowerCase() == firstName.toLowerCase() &&
//           a.lastName.toLowerCase() == lastName.toLowerCase());
//     }
//     validation.nameValid = namesOk;
//
//     validation.countryValid = isValidMrzCountry(country);
//     validation.nationalityValid = isValidMrzCountry(nationality);
//
//     log("$docNumber - $code - $country - $nationality - $code - $expiryDate");
//     log(validation.toString());
//     return validation;
//   } catch (_) {
//     return validation;
//   }
// }
//
// bool _isYYYYMMDD6(String s) => RegExp(r'^\d{6}$').hasMatch(s);
//
// /// Optimize: build a lowercased bag-of-words once.
// bool validateNames(String firstName, String lastName, Iterable<String> lines) {
//   final set = <String>{};
//   for (final l in lines) {
//     for (final m in _wordRe.allMatches(l)) {
//       set.add(m.group(0)!.toLowerCase());
//     }
//   }
//
//   bool containsAllWords(String s) {
//     final parts = s.toLowerCase().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
//     for (final p in parts) {
//       if (!set.contains(p)) return false;
//     }
//     return true;
//   }
//
//   return containsAllWords(firstName) && containsAllWords(lastName);
// }
//
// final _wordRe = RegExp(r'\b\w+\b');
//
// String _cleanMrzName(String input) {
//   return input
//       .replaceAll('0', 'O')
//       .replaceAll('1', 'I')
//       .replaceAll('5', 'S')
//       .replaceAll(RegExp(r'[2-9]'), '') // remove other digits
//       .replaceAll('<', ' ')
//       .replaceAll(RegExp(r'\s+'), ' ')
//       .trim();
// }
//
// /// ----------------------------
// /// Date parsing with century logic
// /// ----------------------------
//
// DateTime? parseMrzDate(String yymmdd, {required bool isExpiry}) {
//   if (!_isYYYYMMDD6(yymmdd)) return null;
//
//   final y = int.parse(yymmdd.substring(0, 2));
//   final m = int.parse(yymmdd.substring(2, 4));
//   final d = int.parse(yymmdd.substring(4, 6));
//   final now = DateTime.now();
//
//   DateTime candidate(int century) => DateTime(century + y, m, d);
//
//   try {
//     if (isExpiry) {
//       final c2000 = candidate(2000);
//       final c1900 = candidate(1900);
//       // Prefer future or near-past (within ~10 years) expiry
//       final chosen = (c2000.isAfter(now.subtract(const Duration(days: 3650)))) ? c2000 : c1900;
//       return chosen;
//     } else {
//       final c2000 = candidate(2000);
//       final c1900 = candidate(1900);
//       final age2000 = now.difference(c2000).inDays ~/ 365;
//       final age1900 = now.difference(c1900).inDays ~/ 365;
//
//       DateTime chosen;
//       if (c2000.isAfter(now) || age2000 > 120) {
//         chosen = c1900;
//       } else if (!c1900.isAfter(now) && age1900 <= 120) {
//         // Both feasible: pick the one that is not in future and age <= 120, prefer older if both valid
//         chosen = c1900;
//       } else {
//         chosen = c2000;
//       }
//       return chosen;
//     }
//   } catch (_) {
//     return null;
//   }
// }
//
// /// ----------------------------
// /// (Optional) Format detection (kept minimal; we target TD3 right now)
// /// ----------------------------
//
// MrzFormat detectFormat(List<String> lines) {
//   final fixed = lines.map(normalize44).toList();
//   if (fixed.length >= 2 && fixed[0].length == 44 && fixed[1].length == 44) return MrzFormat.TD3;
//   // TD2: 2x36, TD1: 3x30 (add if needed)
//   return MrzFormat.TD3; // default to TD3 for current pipeline
// }
