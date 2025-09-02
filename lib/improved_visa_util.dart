// visa_mrz_parser.dart
import 'dart:convert';
import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/doc_code_validator.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart'; // for MrzFormat (MRV_A / MRV_B)
import 'package:ocr_mrz/name_validation_data_class.dart';

import 'ocr_mrz_settings_class.dart';
import 'orc_mrz_log_class.dart';
import 'travel_doc_util.dart'; // isValidMrzCountry(...)

// =====================================================
// Typed result (parallel to passport parser)
// =====================================================

sealed class VisaMrzParseResult {
  const VisaMrzParseResult();
}

class VisaMrzSuccess extends VisaMrzParseResult {
  final MrzFormat format;                 // MRV_A or MRV_B
  final OcrMrzValidation validation;
  final Map<String, dynamic> data;        // legacy-compatible map
  const VisaMrzSuccess(this.format, this.validation, this.data);
}

class VisaMrzFailure extends VisaMrzParseResult {
  final String reason;
  final List<String> rawLines;
  const VisaMrzFailure(this.reason, this.rawLines);
}

// =====================================================
// Public API (legacy-compatible wrapper)
// =====================================================

/// Legacy wrapper: returns Map (null on failure).
Map<String, dynamic>? tryParseVisaMrzFromOcrLines(
    OcrData ocrData,
    OcrMrzSetting? setting,
    List<NameValidationData>? nameValidations,
    void Function(OcrMrzLog log)? mrzLogger,
    ) {
  final res = tryParseVisaMrzFromOcrLinesModern(
    ocrData: ocrData,
    setting: setting,
    nameValidations: nameValidations,
    mrzLogger: mrzLogger,
  );
  if (res is VisaMrzSuccess) return res.data;
  return null;
}

/// Modern typed entry point. Tries MRV-A (44) then MRV-B (36).
VisaMrzParseResult tryParseVisaMrzFromOcrLinesModern({
  required OcrData ocrData,
  OcrMrzSetting? setting,
  List<NameValidationData>? nameValidations,
  void Function(OcrMrzLog log)? mrzLogger,
}) {
  final s = setting ?? OcrMrzSetting();

  final rawAll = ocrData.lines.map((e) => e.text).toList();
  final normalized = rawAll.map(_normalizeVisaLine).toList();

  final first = _findVisaPairAndParse(
    normalized: normalized,
    rawAllLines: rawAll,
    targetLen: 44,
    validateSettings: s,
    nameValidations: nameValidations,
    ocr: ocrData,
    mrzLogger: mrzLogger,
  );
  if (first is VisaMrzSuccess || first is VisaMrzFailure) return first!;

  final second = _findVisaPairAndParse(
    normalized: normalized,
    rawAllLines: rawAll,
    targetLen: 36,
    validateSettings: s,
    nameValidations: nameValidations,
    ocr: ocrData,
    mrzLogger: mrzLogger,
  );
  if (second is VisaMrzSuccess || second is VisaMrzFailure) return second!;

  final mrzLike = rawAll.where((a) => a.contains('<') && a.length > 30).toList();
  mrzLogger?.call(OcrMrzLog(
    rawText: ocrData.text,
    rawMrzLines: mrzLike,
    fixedMrzLines: const [],
    validation: OcrMrzValidation(),
    extractedData: {'error': 'No MRV-A/B pair recognized'},
  ));
  return VisaMrzFailure('No valid MRV-A (44) or MRV-B (36) pair recognized', mrzLike);
}

// =====================================================
// Pair finding & parsing pipeline
// =====================================================

VisaMrzParseResult? _findVisaPairAndParse({
  required List<String> normalized,
  required List<String> rawAllLines,
  required int targetLen,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
  required void Function(OcrMrzLog log)? mrzLogger,
}) {
  final enforced = <int, String>{};
  for (var i = 0; i < normalized.length; i++) {
    final line = _enforceLen(normalized[i], targetLen);
    if (line.length == targetLen) enforced[i] = line;
  }
  if (enforced.isEmpty) return null;

  final l1Candidates = enforced.entries
           .where((e) {
               final l = e.value;
               if (l.isEmpty || l[0] != 'V') return false;
               // MRV line 1 must have name separator '<<'
               if (!l.contains('<<')) return false;
               // Optional: require at least one filler run (e.g., '<<<') to avoid plain words
               if (!RegExp(r'<<|<{2,}').hasMatch(l)) return false;
               return true;
             })
          .toList();
  if (l1Candidates.isEmpty) return null;

  const window = 3;
  for (final c in l1Candidates) {
    final i = c.key;
    final line1 = _repairVisaLine1(c.value, targetLen);

    // forward neighbors
    for (var j = i + 1; j <= i + window; j++) {
      final res = _tryVisaPairIndices(
        i: i,
        j: j,
        enforced: enforced,
        line1: line1,
        targetLen: targetLen,
        rawAllLines: rawAllLines,
        validateSettings: validateSettings,
        nameValidations: nameValidations,
        ocr: ocr,
        mrzLogger: mrzLogger,
      );
      if (res is VisaMrzSuccess) return res;
    }

    // backward neighbors
    for (var j = i - 1; j >= i - window; j--) {
      final res = _tryVisaPairIndices(
        i: i,
        j: j,
        enforced: enforced,
        line1: line1,
        targetLen: targetLen,
        rawAllLines: rawAllLines,
        validateSettings: validateSettings,
        nameValidations: nameValidations,
        ocr: ocr,
        mrzLogger: mrzLogger,
      );
      if (res is VisaMrzSuccess) return res;
    }
  }

  return null;
}

VisaMrzParseResult? _tryVisaPairIndices({
  required int i,
  required int j,
  required Map<int, String> enforced,
  required String line1,
  required int targetLen,
  required List<String> rawAllLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
  required void Function(OcrMrzLog log)? mrzLogger,
}) {
  if (!enforced.containsKey(j)) {
    final mrzLike = rawAllLines.where((a) => a.length > 30 && a.contains('<')).toList();
    mrzLogger?.call(OcrMrzLog(
      rawText: ocr.text,
      rawMrzLines: mrzLike,
      fixedMrzLines: [line1],
      validation: OcrMrzValidation(),
      extractedData: const {'error': 'L2 index missing in enforced map'},
    ));
    return null;
  }

  final candidateL2 = enforced[j]!;
  // L2 must not start with 'V'
  if (candidateL2.startsWith('V')) {
    final mrzLike = rawAllLines.where((a) => a.length > 30 && a.contains('<')).toList();
    mrzLogger?.call(OcrMrzLog(
      rawText: ocr.text,
      rawMrzLines: mrzLike,
      fixedMrzLines: [line1],
      validation: OcrMrzValidation(),
      extractedData: const {'error': 'L2 starts with V'},
    ));
    return null;
  }

  final line2 = _repairVisaLine2(candidateL2, targetLen);
  if (!_looksLikeVisaLine2(line2)) {
    final mrzLike = rawAllLines.where((a) => a.length > 30 && a.contains('<')).toList();
    mrzLogger?.call(OcrMrzLog(
      rawText: ocr.text,
      rawMrzLines: mrzLike,
      fixedMrzLines: [line1, line2],
      validation: OcrMrzValidation(),
      extractedData: const {'error': 'L2 does not pass coarse checks'},
    ));
    return null;
  }

  // Build otherLines excluding i and j
  final otherLines = <String>[];
  for (var k = 0; k < rawAllLines.length; k++) {
    if (k != i && k != j) otherLines.add(rawAllLines[k]);
  }

  // Parse/validate (typed)
  final parsed = _parseVisaCommon(
    line1: line1,
    line2: line2,
    len: targetLen,
    otherLines: otherLines,
    validateSettings: validateSettings,
    nameValidations: nameValidations,
    ocr: ocr,
    mrzLogger: mrzLogger,
  );

  // _parseVisaCommon returns VisaMrzParseResult (success OR failure).
  if (parsed is VisaMrzSuccess) {
    return parsed;
  } else if (parsed is VisaMrzFailure) {
    // Optional: log the failure reason to your logger for diagnostics
    final mrzLike = rawAllLines.where((a) => a.length > 30 && a.contains('<')).toList();
    mrzLogger?.call(OcrMrzLog(
      rawText: ocr.text,
      rawMrzLines: mrzLike,
      fixedMrzLines: [line1, line2],
      validation: OcrMrzValidation(),
      extractedData: {'error': parsed.reason},
    ));
    return null;
  }

  // Should never happen, but keep null for safety.
  return null;
}

// =====================================================
// Normalization & Repairs
// =====================================================

/// Single-pass normalization; uppercase, keep [A-Z0-9<], map common junk to '<'.
String _normalizeVisaLine(String line) {
  const map = {
    '«': '<', '|': '<', '\\': '<', '/': '<',
    '“': '<', '”': '<', '’': '<', '‘': '<',
    ' ': '<',
  };
  final b = StringBuffer();
  for (final rune in line.toUpperCase().runes) {
    var ch = String.fromCharCode(rune);
    ch = map[ch] ?? ch;
    final cu = ch.codeUnitAt(0);
    final isAZ = cu >= 65 && cu <= 90;
    final is09 = cu >= 48 && cu <= 57;
    if (isAZ || is09 || cu == 60) b.writeCharCode(cu);
  }
  // collapse <KKK< or <XXX< => <<<
  return b.toString().replaceAll(RegExp(r'(<)[KX]{2,}(<)'), '<<<');
}

String _enforceLen(String s, int len) {
  if (s.length == len) return s;
  if (s.length > len) return s.substring(0, len);
  return s.padRight(len, '<');
}

String _repairVisaLine1(String line1, int len) {
  var l = _enforceLen(line1, len);
  if (l[0] != 'V') l = 'V${l.substring(1)}';

  // positions 2..4 (issuing state): letters only
  final issuing = l.substring(2, 5).split('').map((c) {
    switch (c) {
      case '0': return 'O';
      case '1': return 'I';
      case '5': return 'S';
      case '8': return 'B';
      case '6': return 'G';
      default:  return c;
    }
  }).join();

  return l.substring(0, 2) + issuing + l.substring(5);
}

String _repairVisaLine2(String line2, int len) {
  var l = _normalizeVisaLine(line2);
  l = _enforceLen(l, len);

  final buf = l.split('');

  String asDigit(String c) {
    switch (c) {
      case 'O':
      case 'Q':
        return '0';
      case 'I':
      case 'L':
        return '1';
      case 'Z':
        return '2';
      case 'S':
        return '5';
      case 'B':
        return '8';
      case 'G':
        return '6';
      default:
        return c;
    }
  }

  // numeric-only positions relative to MRV-A/B layout
  final numericPositions = <int>[
    9,                              // doc check
    13,14,15,16,17,18,              // birth YYMMDD
    19,                             // birth check
    21,22,23,24,25,26,              // expiry YYMMDD
    27,                             // expiry check
  ];
  for (final p in numericPositions) {
    if (p >= 0 && p < buf.length) buf[p] = asDigit(buf[p]);
  }

  // sex at pos 20 => M/F/< only
  if (buf.length > 20) {
    final sx = buf[20];
    buf[20] = (sx == 'M' || sx == 'F' || sx == '<') ? sx : '<';
  }

  return buf.join();
}

bool _looksLikeVisaLine2(String l2) {
  if (l2.length < 28) return false;
  final birth = l2.substring(13, 19);
  final birthCheck = l2[19];
  final sex = l2[20];
  final expiry = l2.substring(21, 27);
  final expiryCheck = l2[27];

  if (!_isYYYYMMDD6(birth) || !_isYYYYMMDD6(expiry)) return false;
  if (!(sex == 'M' || sex == 'F' || sex == '<')) return false;

  final birthOk = _checkDigitFast(birth) == birthCheck;
  final expiryOk = _checkDigitFast(expiry) == expiryCheck;
  return birthOk && expiryOk;
}

// =====================================================
// Parsing & Validation
// =====================================================

VisaMrzParseResult _parseVisaCommon({
  required String line1,
  required String line2,
  required int len, // 44: MRV-A, 36: MRV-B
  required List<String> otherLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
  required void Function(OcrMrzLog log)? mrzLogger,
}) {
  try {
    // --- Line 1 ---
    final documentType = line1.substring(0, 1);     // 'V'
    final documentCode = line1.substring(0, 2);     // 'Vx'
    final issuingState = fixAlphaOnlyField(line1.substring(2, 5));
    final nameField = line1.substring(5);
    final nameParts = nameField.split('<<');
    var lastName  = (nameParts.isNotEmpty ? nameParts[0] : '').replaceAll('<', ' ').trim();
    var firstName = (nameParts.length > 1 ? nameParts[1] : '').replaceAll('<', ' ').trim();
    lastName  = _cleanMrzVisaName(lastName);
    firstName = _cleanMrzVisaName(firstName);

    // --- Line 2 ---
    final docNumber   = line2.substring(0, 9);
    final docCheck    = line2.substring(9, 10);
    final nationality = fixAlphaOnlyField(line2.substring(10, 13));
    final birthRaw    = line2.substring(13, 19);
    final birthCheck  = line2.substring(19, 20);
    final sex         = line2.substring(20, 21);
    final expiryRaw   = line2.substring(21, 27);
    final expiryCheck = line2.substring(27, 28);
    final optional    = (28 < len) ? line2.substring(28, len) : '';

    final validDoc    = _checkDigitFast(docNumber) == docCheck;
    final validBirth  = RegExp(r'^\d{6}$').hasMatch(birthRaw)  && _checkDigitFast(birthRaw)  == birthCheck;
    final validExpiry = RegExp(r'^\d{6}$').hasMatch(expiryRaw) && _checkDigitFast(expiryRaw) == expiryCheck;

    final validation = validateMrzLineVisa(
      line1: line1,
      line2: line2,
      setting: validateSettings,
      otherLines: otherLines,
      firstName: firstName,
      lastName: lastName,
      country: issuingState,
      nationality: nationality,
      issuing: issuingState,
      personalNumber: optional,
      nameValidations: nameValidations,
    );

    final birthDt  = _parseMrzVisaDateSmart(birthRaw,  isExpiry: false)?.toIso8601String();
    final expiryDt = _parseMrzVisaDateSmart(expiryRaw, isExpiry: true )?.toIso8601String();

    final format = (len == 44) ? MrzFormat.MRV_A : MrzFormat.MRV_B;

    bool _require(bool enabled, bool ok) => !enabled || ok;
    final accepts = _require(validateSettings.validateNames,           validation.nameValid) &&
        _require(validateSettings.validateDocNumberValid,  validation.docNumberValid) &&
        _require(validateSettings.validateBirthDateValid,  validation.birthDateValid) &&
        _require(validateSettings.validateExpiryDateValid, validation.expiryDateValid) &&
        _require(validateSettings.validateLinesLength,     validation.linesLengthValid) &&
        _require(validateSettings.validateCountry,         validation.countryValid) &&
        _require(validateSettings.validateNationality,     validation.nationalityValid);

    final resultMap = <String, dynamic>{
      'line1': line1,
      'line2': line2,
      'documentCode': documentCode,
      'documentType': documentType,
      'mrzFormat': len == 44 ? 'MRV-A' : 'MRV-B',
      'issuingState': issuingState,
      'countryCode': issuingState,
      'lastName': lastName,
      'firstName': firstName,
      'documentNumber': docNumber,
      'passportNumber': docNumber,
      'nationality': nationality,
      'birthDate': birthDt,
      'expiryDate': expiryDt,
      'sex': sex,
      'optionalData': optional,
      'personalNumber': optional,
      'valid': {
        'docNumberValid':     validDoc,
        'docCodeValid':       DocumentCodeHelper.isValid(documentCode),
        'birthDateValid':     validBirth,
        'expiryDateValid':    validExpiry,
        'personalNumberValid': true,
        'finalCheckValid':    true,
        'hasFinalCheck':      false,
        'nameValid':          validation.nameValid,
        'linesLengthValid':   validation.linesLengthValid,
        'countryValid':       validation.countryValid,
        'nationalityValid':   validation.nationalityValid,
      },
      'checkDigits': {
        'document': validDoc,
        'passport': validDoc,
        'birth':    validBirth,
        'expiry':   validExpiry,
        'optional': true,
      },
      'format': format.toString().split('.').last,
      'ocrData': ocr.toJson(),
    };

    final mrzLike = ocr.lines.map((e) => e.text).where((a) => a.contains('<') && a.length > 30).toList();
    mrzLogger?.call(OcrMrzLog(
      rawText: ocr.text,
      rawMrzLines: mrzLike,
      fixedMrzLines: [line1, line2],
      validation: validation,
      extractedData: resultMap,
    ));

    if (firstName.isEmpty || lastName.isEmpty) {
      return VisaMrzFailure('Empty first/last name after normalization', [line1, line2]);
    }
    if (!accepts) {
      final failures = <String>[
        if (validateSettings.validateNames && !validation.nameValid) 'name',
        if (validateSettings.validateDocNumberValid && !validation.docNumberValid) 'docNumber',
        if (validateSettings.validateBirthDateValid && !validation.birthDateValid) 'birthDate',
        if (validateSettings.validateExpiryDateValid && !validation.expiryDateValid) 'expiryDate',
        if (validateSettings.validateLinesLength && !validation.linesLengthValid) 'linesLength',
        if (validateSettings.validateCountry && !validation.countryValid) 'country',
        if (validateSettings.validateNationality && !validation.nationalityValid) 'nationality',
      ].join(', ');
      return VisaMrzFailure('Validation failed: $failures', [line1, line2]);
    }


    return VisaMrzSuccess(format, validation, resultMap);
  } catch (e, st) {
    log('Visa MRZ parse exception: $e\n$st');

    final mrzLike = ocr.lines.map((e) => e.text).where((a) => a.contains('<') && a.length > 30).toList();
    mrzLogger?.call(OcrMrzLog(
      rawText: ocr.text,
      rawMrzLines: mrzLike,
      fixedMrzLines: [line1, line2],
      validation: OcrMrzValidation(),
      extractedData: {'error': e.toString()},
    ));
    return VisaMrzFailure('Exception: $e', [line1, line2]);
  }
}


OcrMrzValidation validateMrzLineVisa({
  required String line1,
  required String line2,
  required OcrMrzSetting setting,
  required List<String> otherLines,
  required String firstName,
  required String lastName,
  required String country,         // issuing state
  required String nationality,
  required String issuing,
  required String personalNumber,  // optional tail
  required List<NameValidationData>? nameValidations,
}) {
  final validation = OcrMrzValidation();
  try {
    validation.linesLengthValid = (line1.length == 44 || line1.length == 36) &&
        (line2.length == 44 || line2.length == 36);

    final docCode   = line1.substring(0, 2);
    final docNumber = line2.substring(0, 9);
    final docCheck  = line2[9];

    validation.docCodeValid    = DocumentCodeHelper.isValid(docCode);
    validation.docNumberValid  = _checkDigitFast(docNumber) == docCheck;

    final birth       = line2.substring(13, 19);
    final birthCheck  = line2[19];
    final expiry      = line2.substring(21, 27);
    final expiryCheck = line2[27];

    validation.birthDateValid  = _isYYYYMMDD6(birth)  && _checkDigitFast(birth)  == birthCheck;
    validation.expiryDateValid = _isYYYYMMDD6(expiry) && _checkDigitFast(expiry) == expiryCheck;

    // MRV tail has no dedicated check-digit
    validation.personalNumberValid = true;

    // No composite final in visas
    validation.finalCheckValid = true;

    var namesOk = validateNames(firstName, lastName, otherLines);
    if (!namesOk && nameValidations != null) {
      namesOk = nameValidations.any((a) =>
      a.firstName.toLowerCase() == firstName.toLowerCase() &&
          a.lastName.toLowerCase()  == lastName.toLowerCase());
    }
    validation.nameValid = namesOk;

    validation.countryValid     = isValidMrzCountry(issuing);
    validation.nationalityValid = isValidMrzCountry(nationality);

    return validation;
  } catch (_) {
    return validation;
  }
}

// =====================================================
// Name, date, and performance helpers
// =====================================================

final _wordRe = RegExp(r'\b\w+\b');

bool validateNames(String firstName, String lastName, Iterable<String> lines) {
  final set = <String>{};
  for (final l in lines) {
    for (final m in _wordRe.allMatches(l)) {
      set.add(m.group(0)!.toLowerCase());
    }
  }
  bool containsAll(String s) {
    final parts = s.toLowerCase().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    for (final p in parts) {
      if (!set.contains(p)) return false;
    }
    return true;
  }
  return containsAll(firstName) && containsAll(lastName);
}

String _cleanMrzVisaName(String input) => input
    .replaceAll('0', 'O')
    .replaceAll('1', 'I')
    .replaceAll('5', 'S')
    .replaceAll(RegExp(r'[2-9]'), '')
    .replaceAll('<', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _isYYYYMMDD6(String s) => RegExp(r'^\d{6}$').hasMatch(s);

DateTime? _parseMrzVisaDateSmart(String yymmdd, {required bool isExpiry}) {
  if (!_isYYYYMMDD6(yymmdd)) return null;
  final y = int.parse(yymmdd.substring(0, 2));
  final m = int.parse(yymmdd.substring(2, 4));
  final d = int.parse(yymmdd.substring(4, 6));
  final now = DateTime.now();

  DateTime candidate(int century) => DateTime(century + y, m, d);

  try {
    if (isExpiry) {
      final c2000 = candidate(2000);
      final c1900 = candidate(1900);
      // prefer future or near-past (≈10y)
      return (c2000.isAfter(now.subtract(const Duration(days: 3650)))) ? c2000 : c1900;
    } else {
      final c2000 = candidate(2000);
      final c1900 = candidate(1900);
      final age2000 = now.difference(c2000).inDays ~/ 365;
      final age1900 = now.difference(c1900).inDays ~/ 365;

      if (c2000.isAfter(now) || age2000 > 120) return c1900;
      if (!c1900.isAfter(now) && age1900 <= 120) return c1900;
      return c2000;
    }
  } catch (_) {
    return null;
  }
}

// =====================================================
// Fast check-digit implementation
// =====================================================

final _weights = [7, 3, 1];
final List<int> _valTable = _buildValTable();

List<int> _buildValTable() {
  final t = List<int>.filled(128, 0);
  for (var d = 0; d <= 9; d++) t['0'.codeUnitAt(0) + d] = d;
  for (var i = 0; i < 26; i++) t['A'.codeUnitAt(0) + i] = 10 + i;
  t['<'.codeUnitAt(0)] = 0;
  return t;
}

String _checkDigitFast(String s) {
  var sum = 0;
  for (var i = 0; i < s.length; i++) {
    final cu = s.codeUnitAt(i);
    final v = cu < 128 ? _valTable[cu] : 0;
    sum += v * _weights[i % 3];
  }
  return (sum % 10).toString();
}

// =====================================================
// Tiny util (optional, used above)
// =====================================================

extension LetExt<T> on T {
  R? let<R>(R Function(T it) block) => block(this);
}
