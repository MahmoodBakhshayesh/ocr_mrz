// id_mrz_parser.dart
import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/doc_code_validator.dart';
import 'package:ocr_mrz/name_validation_data_class.dart';
import 'package:ocr_mrz/passport_util.dart'; // if you keep shared utils here
import 'country_validator.dart'; // isValidMrzCountry(...)
import 'mrz_result_class_fix.dart'; // MrzFormat enum
import 'ocr_mrz_settings_class.dart';
import 'orc_mrz_log_class.dart';
import 'travel_doc_util.dart';

/// =====================================================
/// Typed results (parallel with your other parsers)
/// =====================================================
sealed class IdMrzParseResult {
  const IdMrzParseResult();
}

class IdMrzSuccess extends IdMrzParseResult {
  final MrzFormat format; // TD1 or TD2
  final OcrMrzValidation validation;
  final Map<String, dynamic> data; // legacy/compat map
  const IdMrzSuccess(this.format, this.validation, this.data);
}

class IdMrzFailure extends IdMrzParseResult {
  final String reason;
  final List<String> rawLines;
  const IdMrzFailure(this.reason, this.rawLines);
}

/// =====================================================
/// Public API — LEGACY wrappers (return Map? like before)
/// =====================================================

Map<String, dynamic>? tryParseTD1FromOcrLines(
    OcrData ocrData,
    OcrMrzSetting? setting,
    List<NameValidationData>? nameValidations,
    void Function(OcrMrzLog log)? mrzLogger,
    ) {
  final res = tryParseTD1FromOcrLinesModern(
    ocrData: ocrData,
    setting: setting,
    nameValidations: nameValidations,
    mrzLogger: mrzLogger,
  );
  return res is IdMrzSuccess ? res.data : null;
}

Map<String, dynamic>? tryParseTD2FromOcrLines(
    OcrData ocrData,
    OcrMrzSetting? setting,
    List<NameValidationData>? nameValidations,
    void Function(OcrMrzLog log)? mrzLogger,
    ) {
  final res = tryParseTD2FromOcrLinesModern(
    ocrData: ocrData,
    setting: setting,
    nameValidations: nameValidations,
    mrzLogger: mrzLogger,
  );
  return res is IdMrzSuccess ? res.data : null;
}

/// =====================================================
/// Public API — TYPED entry points
/// =====================================================

IdMrzParseResult tryParseTD1FromOcrLinesModern({
  required OcrData ocrData,
  OcrMrzSetting? setting,
  List<NameValidationData>? nameValidations,
  void Function(OcrMrzLog log)? mrzLogger,
}) {
  final s = setting ?? OcrMrzSetting();
  final raw = ocrData.lines.map((e) => e.text).toList();
  final normalized = raw.map(_normalizeIdLine).toList();

  final res = _findTd1TripletAndParse(
    normalized: normalized,
    rawAllLines: raw,
    validateSettings: s,
    nameValidations: nameValidations,
    ocr: ocrData,
    mrzLogger: mrzLogger,
  );
  if (res is IdMrzSuccess) return res;

  final mrzLike = raw.where((a) => a.contains('<') && a.length >= 25).toList();
  mrzLogger?.call(OcrMrzLog(
    rawText: ocrData.text,
    rawMrzLines: mrzLike,
    fixedMrzLines: const [],
    validation: OcrMrzValidation(),
    extractedData: {'error': 'No TD1 triplet recognized'},
  ));
  return IdMrzFailure('No valid TD1 (3×30) triplet recognized', mrzLike);
}

IdMrzParseResult tryParseTD2FromOcrLinesModern({
  required OcrData ocrData,
  OcrMrzSetting? setting,
  List<NameValidationData>? nameValidations,
  void Function(OcrMrzLog log)? mrzLogger,
}) {
  final s = setting ?? OcrMrzSetting();
  final raw = ocrData.lines.map((e) => e.text).toList();
  final normalized = raw
      .where((a) => a.contains('<'))
      .map(_normalizeIdLine)
      .toList();

  final res = _findTd2PairAndParse(
    normalized: normalized,
    rawAllLines: raw,
    validateSettings: s,
    nameValidations: nameValidations,
    ocr: ocrData,
    mrzLogger: mrzLogger,
  );
  if (res is IdMrzSuccess) return res;

  final mrzLike = raw.where((a) => a.contains('<') && a.length >= 30).toList();
  mrzLogger?.call(OcrMrzLog(
    rawText: ocrData.text,
    rawMrzLines: mrzLike,
    fixedMrzLines: const [],
    validation: OcrMrzValidation(),
    extractedData: {'error': 'No TD2 pair recognized'},
  ));
  return IdMrzFailure('No valid TD2 (2×36) pair recognized', mrzLike);
}

/// =====================================================
/// Normalization & fast check digit
/// =====================================================

/// Single-pass normalization: uppercase, keep [A-Z0-9<], map common junk to '<'.
String _normalizeIdLine(String line) {
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
  return b.toString();
}

String _enforceLen(String s, int len) =>
    s.length == len ? s : (s.length > len ? s.substring(0, len) : s.padRight(len, '<'));

final _weights = [7, 3, 1];
final List<int> _valTable = _buildValTable();
List<int> _buildValTable() {
  final t = List<int>.filled(128, 0);
  for (var d = 0; d <= 9; d++) {
    t['0'.codeUnitAt(0) + d] = d;
  }
  for (var i = 0; i < 26; i++) {
    t['A'.codeUnitAt(0) + i] = 10 + i;
  }
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

/// =====================================================
/// Shared field cleaners
/// =====================================================

String _cleanName(String input) => input
    .replaceAll('0', 'O')
    .replaceAll('1', 'I')
    .replaceAll('5', 'S')
    .replaceAll(RegExp(r'[2-9]'), '')
    .replaceAll('<', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Alpha-only field fixer (country/nationality)
String fixAlphaOnlyField(String value) {
  const map = {'0': 'O', '1': 'I', '5': 'S', '8': 'B', '6': 'G'};
  return value.toUpperCase().split('').map((c) => map[c] ?? c).join();
}

bool _isYYYYMMDD6(String s) => RegExp(r'^\d{6}$').hasMatch(s);

DateTime? _parseYYMMDDSmart(String yymmdd, {required bool isExpiry}) {
  if (!_isYYYYMMDD6(yymmdd)) return null;
  final y = int.parse(yymmdd.substring(0, 2));
  final m = int.parse(yymmdd.substring(2, 4));
  final d = int.parse(yymmdd.substring(4, 6));
  final now = DateTime.now();
  DateTime candidate(int c) => DateTime(c + y, m, d);
  try {
    if (isExpiry) {
      final c2000 = candidate(2000);
      final c1900 = candidate(1900);
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

/// Alnum with preference to digits for ambiguous OCR (doc numbers)
String _fixAlnumPrefDigits(String c) {
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

String _toDigit(String c) => _fixAlnumPrefDigits(c);
String _fixAlpha(String c) {
  switch (c) {
    case '0':
      return 'O';
    case '1':
      return 'I';
    case '5':
      return 'S';
    case '8':
      return 'B';
    case '6':
      return 'G';
    default:
      return c;
  }
}

/// =====================================================
/// TD1 (3 × 30) — find & parse
/// =====================================================

IdMrzParseResult? _findTd1TripletAndParse({
  required List<String> normalized,
  required List<String> rawAllLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
  void Function(OcrMrzLog log)? mrzLogger,
}) {
  final idxToLine = <int, String>{};
  for (int i = 0; i < normalized.length; i++) {
    final l = _enforceLen(normalized[i], 30);
    if (l.length == 30) idxToLine[i] = l;
  }
  if (idxToLine.length < 3) return null;

  const window = 3;
  final indices = idxToLine.keys.toList()..sort();

  for (final i in indices) {
    final l1cand = idxToLine[i]!;
    if (!RegExp(r'^[A-Z][A-Z<]').hasMatch(l1cand)) continue;

    for (int j = i + 1; j <= i + window; j++) {
      for (int k = j + 1; k <= i + window + 1; k++) {
        if (!idxToLine.containsKey(j) || !idxToLine.containsKey(k)) continue;

        final l2cand = idxToLine[j]!;
        final l3cand = idxToLine[k]!;
        if (!l3cand.contains('<<')) continue;

        final line1 = _repairTd1Line1(l1cand);
        final line2 = _repairTd1Line2(l2cand);
        final line3 = _repairTd1Line3(l3cand);

        if (!_looksLikeTd1Line1(line1)) continue;
        if (!_looksLikeTd1Line2(line2)) continue;

        final other = <String>[];
        for (int t = 0; t < rawAllLines.length; t++) {
          if (t != i && t != j && t != k) other.add(rawAllLines[t]);
        }

        final parsed = _parseTd1(
          l1: line1,
          l2: line2,
          l3: line3,
          otherLines: other,
          validateSettings: validateSettings,
          nameValidations: nameValidations,
          ocr: ocr,
          mrzLogger: mrzLogger,
        );
        if (parsed is IdMrzSuccess) return parsed;
      }
    }
  }
  return null;
}

String _repairTd1Line1(String l1) {
  var s = _enforceLen(l1, 30);
  final buf = s.split('');

  // Doc code
  if (buf.isEmpty || !RegExp(r'^[A-Z]$').hasMatch(buf[0])) {
    if (buf.isEmpty) return 'I<${''.padRight(28, '<')}';
    buf[0] = 'I';
  }
  if (buf[0] == 'T') buf[0] = 'I'; // common OCR confusion

  // Second char A–Z or '<'
  if (buf.length >= 2 && !RegExp(r'^[A-Z<]$').hasMatch(buf[1])) {
    const m = {'1': 'I', '0': 'O', '|': 'I', '/': '<', '\\': '<', '«': '<', '»': '<'};
    buf[1] = m[buf[1]] ?? '<';
  }

  // Issuing state letters only
  if (buf.length >= 5) {
    final issuing = fixAlphaOnlyField(buf.sublist(2, 5).join());
    for (int i = 0; i < 3; i++) {
      buf[2 + i] = issuing[i];
    }
  }

  // Doc number alnum (prefer digits)
  for (int i = 5; i < 14 && i < buf.length; i++) {
    buf[i] = _fixAlnumPrefDigits(buf[i]);
  }

  // Recompute doc check at [14]
  if (buf.length > 14) {
    final docNo = buf.sublist(5, 14).join();
    buf[14] = _checkDigitFast(docNo);
  }

  return _enforceLen(buf.join(), 30);
}

String _repairTd1Line2(String l2) {
  final buf = _enforceLen(l2, 30).split('');
  // birth [0..5], chk [6], sex [7], expiry [8..13], chk [14], nationality [15..17]
  for (int i = 0; i < 6 && i < buf.length; i++) {
    buf[i] = _toDigit(buf[i]);
  }
  if (buf.length > 6) buf[6] = _toDigit(buf[6]);
  if (buf.length > 7) buf[7] = (buf[7] == 'M' || buf[7] == 'F' || buf[7] == '<') ? buf[7] : '<';
  for (int i = 8; i < 14 && i < buf.length; i++) {
    buf[i] = _toDigit(buf[i]);
  }
  if (buf.length > 14) buf[14] = _toDigit(buf[14]);
  for (int i = 15; i < 18 && i < buf.length; i++) {
    buf[i] = _fixAlpha(buf[i]);
  }
  return buf.join();
}

String _repairTd1Line3(String l3) => _enforceLen(
  l3.replaceAll(RegExp(r'[^\w<]'), '<'),
  30,
);

bool _looksLikeTd1Line1(String l1) {
  if (l1.length != 30) return false;
  if (!RegExp(r'^[A-Z][A-Z<]').hasMatch(l1)) return false;
  final issuing = fixAlphaOnlyField(l1.substring(2, 5));
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(issuing)) return false;
  final docNo = l1.substring(5, 14);
  if (docNo.replaceAll('<', '').length < 5) return false;
  return _checkDigitFast(docNo) == l1[14];
}

bool _looksLikeTd1Line2(String l2) {
  if (l2.length != 30) return false;
  final birth = l2.substring(0, 6);
  final birthChk = l2[6];
  final sex = l2[7];
  final expiry = l2.substring(8, 14);
  final expiryChk = l2[14];
  final birthOk = _isYYYYMMDD6(birth) && _checkDigitFast(birth) == birthChk;
  final expiryOk = _isYYYYMMDD6(expiry) && _checkDigitFast(expiry) == expiryChk;
  final sexOk = (sex == 'M' || sex == 'F' || sex == '<');
  return birthOk && expiryOk && sexOk;
}

IdMrzParseResult _parseTd1({
  required String l1,
  required String l2,
  required String l3,
  required List<String> otherLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
  void Function(OcrMrzLog log)? mrzLogger,
}) {
  try {
    // L1
    final documentType = l1.substring(0, 1);
    final documentCode = l1.substring(0, 2);
    final issuingState = fixAlphaOnlyField(l1.substring(2, 5));
    final docNo = l1.substring(5, 14);
    final docChk = l1[14];
    final opt1 = l1.substring(15, 30);

    // L2
    final birthRaw = l2.substring(0, 6);
    final birthChk = l2[6];
    final sex = l2[7];
    final expiryRaw = l2.substring(8, 14);
    final expiryChk = l2[14];
    final nationality = fixAlphaOnlyField(l2.substring(15, 18));
    final opt2 = l2.substring(18, 29);
    final finalComposite = l2[29];

    // L3 — names
    final nameParts = l3.split('<<');
    var lastName = (nameParts.isNotEmpty ? nameParts[0] : '').replaceAll('<', ' ').trim();
    var firstName = (nameParts.length > 1 ? nameParts[1] : '').replaceAll('<', ' ').trim();
    lastName = _cleanName(lastName);
    firstName = _cleanName(firstName);
    if (firstName.isEmpty || lastName.isEmpty) {
      return IdMrzFailure('Empty first/last name after normalization', [l1, l2, l3]);
    }

    // Checks
    final vDoc = _checkDigitFast(docNo) == docChk;
    final vBirth = _isYYYYMMDD6(birthRaw) && _checkDigitFast(birthRaw) == birthChk;
    final vExpiry = _isYYYYMMDD6(expiryRaw) && _checkDigitFast(expiryRaw) == expiryChk;

    // Composite per ICAO (TD1 final is last char of L2; input includes opt2)
    final compositeInput = docNo + docChk + birthRaw + birthChk + expiryRaw + expiryChk + opt2;
    final vFinal = _checkDigitFast(compositeInput) == finalComposite;

    // Validation struct
    final validation = validateMrzLineTd1(
      l1: l1,
      l2: l2,
      l3: l3,
      otherLines: otherLines,
      firstName: firstName,
      lastName: lastName,
      setting: validateSettings,
      country: issuingState,
      nationality: nationality,
      personalNumber: opt2,
      nameValidations: nameValidations,
    );

    // Acceptance gates
    bool _require(bool enabled, bool ok) => !enabled || ok;
    final docCodeValid = DocumentCodeHelper.isValid(documentCode);
    final namesOk = validation.nameValid;
    final accepts = _require(validateSettings.validateNames, namesOk) &&
        _require(validateSettings.validateDocNumberValid, vDoc) &&
        _require(validateSettings.validateBirthDateValid, vBirth) &&
        _require(validateSettings.validateExpiryDateValid, vExpiry) &&
        _require(validateSettings.validateFinalCheckValid, vFinal) &&
        _require(validateSettings.validateLinesLength, true) &&
        _require(validateSettings.validateCountry, validation.countryValid) &&
        _require(validateSettings.validateNationality, validation.nationalityValid) &&
        _require(true, docCodeValid);

    final birthDt = _parseYYMMDDSmart(birthRaw, isExpiry: false)?.toIso8601String();
    final expiryDt = _parseYYMMDDSmart(expiryRaw, isExpiry: true)?.toIso8601String();

    final resultMap = <String, dynamic>{
      'line1': l1,
      'line2': l2,
      'line3': l3,
      'documentCode': documentCode,
      'documentType': documentType,
      'mrzFormat': 'TD1',
      'issuingState': issuingState,
      'countryCode': issuingState,
      'lastName': lastName,
      'firstName': firstName,
      'documentNumber': docNo,
      'passportNumber': docNo, // mirror for legacy
      'nationality': nationality,
      'birthDate': birthDt,
      'expiryDate': expiryDt,
      'sex': sex,
      'optionalData': opt2.isNotEmpty ? opt2 : opt1,
      'personalNumber': opt2.isNotEmpty ? opt2 : opt1,
      'valid': {
        'docNumberValid': vDoc,
        'docCodeValid': docCodeValid,
        'birthDateValid': vBirth,
        'expiryDateValid': vExpiry,
        'personalNumberValid': true,
        'finalCheckValid': vFinal,
        'hasFinalCheck': true,
        'nameValid': namesOk,
        'linesLengthValid': true,
        'countryValid': validation.countryValid,
        'nationalityValid': validation.nationalityValid,
      },
      'checkDigits': {
        'document': vDoc,
        'passport': vDoc,
        'birth': vBirth,
        'expiry': vExpiry,
        'optional': true,
        'final': vFinal,
        'finalComposite': vFinal,
      },
      'format': MrzFormat.TD1.toString().split('.').last,
      'ocrData': ocr.toJson(),
    };

    final mrzLike = ocr.lines.map((e) => e.text).where((a) => a.contains('<')).toList();
    mrzLogger?.call(OcrMrzLog(
      rawText: ocr.text,
      rawMrzLines: mrzLike,
      fixedMrzLines: [l1, l2, l3],
      validation: validation,
      extractedData: resultMap,
    ));

    if (!accepts) {
      final failures = <String>[
        if (validateSettings.validateNames && !namesOk) 'name',
        if (validateSettings.validateDocNumberValid && !vDoc) 'docNumber',
        if (validateSettings.validateBirthDateValid && !vBirth) 'birthDate',
        if (validateSettings.validateExpiryDateValid && !vExpiry) 'expiryDate',
        if (validateSettings.validateFinalCheckValid && !vFinal) 'finalCheck',
        if (validateSettings.validateCountry && !validation.countryValid) 'country',
        if (validateSettings.validateNationality && !validation.nationalityValid) 'nationality',
        if (!docCodeValid) 'docCode',
      ].join(', ');
      return IdMrzFailure('TD1 validation failed: $failures', [l1, l2, l3]);
    }

    return IdMrzSuccess(MrzFormat.TD1, validation, resultMap);
  } catch (e, st) {
    log('TD1 parse exception: $e\n$st');
    return IdMrzFailure('Exception: $e', [l1, l2, l3]);
  }
}

OcrMrzValidation validateMrzLineTd1({
  required String l1,
  required String l2,
  required String l3,
  required List<String> otherLines,
  required String firstName,
  required String lastName,
  required OcrMrzSetting setting,
  required String country,
  required String nationality,
  required String personalNumber,
  List<NameValidationData>? nameValidations,
}) {
  final v = OcrMrzValidation();
  try {
    v.linesLengthValid = (l1.length == 30 && l2.length == 30 && l3.length == 30);

    final documentCode = l1.substring(0, 2);
    v.docCodeValid = DocumentCodeHelper.isValid(documentCode);

    final docNo = l1.substring(5, 14);
    final docChk = l1[14];
    v.docNumberValid = _checkDigitFast(docNo) == docChk;

    final birth = l2.substring(0, 6);
    final birthChk = l2[6];
    v.birthDateValid = _isYYYYMMDD6(birth) && _checkDigitFast(birth) == birthChk;

    final expiry = l2.substring(8, 14);
    final expiryChk = l2[14];
    v.expiryDateValid = _isYYYYMMDD6(expiry) && _checkDigitFast(expiry) == expiryChk;

    // Composite final
    final opt2 = l2.substring(18, 29);
    final finalComposite = l2[29];
    final composite = docNo + docChk + birth + birthChk + expiry + expiryChk + opt2;
    v.finalCheckValid = _checkDigitFast(composite) == finalComposite;

    // Optional/personal number — no dedicated check digit in TD1
    v.personalNumberValid = true;

    var namesOk = validateNames(firstName, lastName, otherLines);
    if (!namesOk && nameValidations != null) {
      namesOk = nameValidations.any((a) =>
      a.firstName.toLowerCase() == firstName.toLowerCase() &&
          a.lastName.toLowerCase() == lastName.toLowerCase());
    }
    v.nameValid = namesOk;

    v.countryValid = isValidMrzCountry(country);
    v.nationalityValid = isValidMrzCountry(nationality);

    return v;
  } catch (_) {
    return v;
  }
}

/// =====================================================
/// TD2 (2 × 36) — find & parse
/// =====================================================

IdMrzParseResult? _findTd2PairAndParse({
  required List<String> normalized,
  required List<String> rawAllLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
  void Function(OcrMrzLog log)? mrzLogger,
}) {
  final idxToLine = <int, String>{};
  for (int i = 0; i < normalized.length; i++) {
    final l = _enforceLen(normalized[i], 36);
    if (l.length == 36) idxToLine[i] = l;
  }
  if (idxToLine.length < 2) return null;

  const window = 3;
  final indices = idxToLine.keys.toList()..sort();

  for (final i in indices) {
    final l1cand = idxToLine[i]!;
    if (!RegExp(r'^[A-Z]').hasMatch(l1cand)) continue;

    for (int j = i + 1; j <= i + window; j++) {
      if (!idxToLine.containsKey(j)) continue;

      final line1 = _repairTd2Line1(l1cand);
      final line2 = _repairTd2Line2(idxToLine[j]!);

      if (!_looksLikeTd2Line2(line2)) continue;

      final other = <String>[];
      for (int t = 0; t < rawAllLines.length; t++) {
        if (t != i && t != j) other.add(rawAllLines[t]);
      }

      final parsed = _parseTd2(
        l1: line1,
        l2: line2,
        otherLines: other,
        validateSettings: validateSettings,
        nameValidations: nameValidations,
        ocr: ocr,
        mrzLogger: mrzLogger,
      );
      if (parsed is IdMrzSuccess) return parsed;
    }
  }

  return null;
}

String _repairTd2Line1(String l1) {
  final buf = _enforceLen(l1, 36).split('');
  for (int i = 2; i < 5 && i < buf.length; i++) {
    buf[i] = _fixAlpha(buf[i]); // issuing state
  }
  return buf.join();
}

String _repairTd2Line2(String l2) {
  final buf = _enforceLen(l2, 36).split('');
  // [0..9) docNo, [9] chk, [10..13) nationality, [13..19) birth, [19] chk,
  // [20] sex, [21..27) expiry, [27] chk, [28..35) optional, [35] final
  for (int i = 13; i < 19 && i < buf.length; i++) {
    buf[i] = _toDigit(buf[i]); // birth
  }
  if (buf.length > 19) buf[19] = _toDigit(buf[19]);
  if (buf.length > 20) buf[20] = (buf[20] == 'M' || buf[20] == 'F' || buf[20] == '<') ? buf[20] : '<';
  for (int i = 21; i < 27 && i < buf.length; i++) {
    buf[i] = _toDigit(buf[i]); // expiry
  }
  if (buf.length > 27) buf[27] = _toDigit(buf[27]);
  for (int i = 10; i < 13 && i < buf.length; i++) {
    buf[i] = _fixAlpha(buf[i]); // nationality
  }
  return buf.join();
}

bool _looksLikeTd2Line2(String l2) {
  if (l2.length != 36) return false;
  final docNo = l2.substring(0, 9);
  final docChk = l2[9];
  final nationality = l2.substring(10, 13);
  final birth = l2.substring(13, 19);
  final birthChk = l2[19];
  final sex = l2[20];
  final expiry = l2.substring(21, 27);
  final expiryChk = l2[27];

  final vDoc = _checkDigitFast(docNo) == docChk;
  final vBirth = _isYYYYMMDD6(birth) && _checkDigitFast(birth) == birthChk;
  final vExpiry = _isYYYYMMDD6(expiry) && _checkDigitFast(expiry) == expiryChk;
  final vNat = isValidMrzCountry(fixAlphaOnlyField(nationality));
  final vSex = (sex == 'M' || sex == 'F' || sex == '<');
  return vDoc && vBirth && vExpiry && vNat && vSex;
}

IdMrzParseResult _parseTd2({
  required String l1,
  required String l2,
  required List<String> otherLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
  void Function(OcrMrzLog log)? mrzLogger,
}) {
  try {
    // L1: doc code, issuing, names
    final documentType = l1.substring(0, 1);
    final documentCode = l1.substring(0, 2);
    final issuingState = fixAlphaOnlyField(l1.substring(2, 5));
    final nameField = l1.substring(5);
    final nameParts = nameField.split('<<');
    var lastName = (nameParts.isNotEmpty ? nameParts[0] : '').replaceAll('<', ' ').trim();
    var firstName = (nameParts.length > 1 ? nameParts[1] : '').replaceAll('<', ' ').trim();
    lastName = _cleanName(lastName);
    firstName = _cleanName(firstName);
    if (firstName.isEmpty || lastName.isEmpty) {
      return IdMrzFailure('Empty first/last name after normalization', [l1, l2]);
    }

    // L2 fields
    final docNo = l2.substring(0, 9);
    final docChk = l2[9];
    final nationality = fixAlphaOnlyField(l2.substring(10, 13));
    final birthRaw = l2.substring(13, 19);
    final birthChk = l2[19];
    final sex = l2[20];
    final expiryRaw = l2.substring(21, 27);
    final expiryChk = l2[27];
    final optional = l2.substring(28, 35);
    final finalComposite = l2[35];

    final vDoc = _checkDigitFast(docNo) == docChk;
    final vBirth = _isYYYYMMDD6(birthRaw) && _checkDigitFast(birthRaw) == birthChk;
    final vExpiry = _isYYYYMMDD6(expiryRaw) && _checkDigitFast(expiryRaw) == expiryChk;

    // Composite input per ICAO (TD2: optional in composite)
    final composite = docNo + docChk + birthRaw + birthChk + expiryRaw + expiryChk + optional;
    final vFinal = _checkDigitFast(composite) == finalComposite;

    final docCodeValid = DocumentCodeHelper.isValid(documentCode);

    // Build validation (reuse OcrMrzValidation for consistent shape)
    final validation = OcrMrzValidation()
      ..linesLengthValid = (l1.length == 36 && l2.length == 36)
      ..docCodeValid = docCodeValid
      ..docNumberValid = vDoc
      ..birthDateValid = vBirth
      ..expiryDateValid = vExpiry
      ..personalNumberValid = true
      ..finalCheckValid = vFinal
      ..countryValid = isValidMrzCountry(issuingState)
      ..nationalityValid = isValidMrzCountry(nationality);

    var namesOk = validateNames(firstName, lastName, otherLines);
    if (!namesOk && nameValidations != null) {
      namesOk = nameValidations.any((a) =>
      a.firstName.toLowerCase() == firstName.toLowerCase() &&
          a.lastName.toLowerCase() == lastName.toLowerCase());
    }
    validation.nameValid = namesOk;

    // Acceptance gates
    bool _require(bool enabled, bool ok) => !enabled || ok;
    final accepts = _require(validateSettings.validateNames, namesOk) &&
        _require(validateSettings.validateDocNumberValid, vDoc) &&
        _require(validateSettings.validateBirthDateValid, vBirth) &&
        _require(validateSettings.validateExpiryDateValid, vExpiry) &&
        _require(validateSettings.validateFinalCheckValid, vFinal) &&
        _require(validateSettings.validateLinesLength, true) &&
        _require(validateSettings.validateCountry, validation.countryValid) &&
        _require(validateSettings.validateNationality, validation.nationalityValid) &&
        _require(true, docCodeValid);

    final birthDt = _parseYYMMDDSmart(birthRaw, isExpiry: false)?.toIso8601String();
    final expiryDt = _parseYYMMDDSmart(expiryRaw, isExpiry: true)?.toIso8601String();

    final resultMap = <String, dynamic>{
      'line1': l1,
      'line2': l2,
      'documentCode': documentCode,
      'documentType': documentType,
      'mrzFormat': 'TD2',
      'issuingState': issuingState,
      'countryCode': issuingState,
      'lastName': lastName,
      'firstName': firstName,
      'documentNumber': docNo,
      'passportNumber': docNo,
      'nationality': nationality,
      'birthDate': birthDt,
      'expiryDate': expiryDt,
      'sex': sex,
      'optionalData': optional,
      'personalNumber': optional,
      'valid': {
        'docNumberValid': vDoc,
        'docCodeValid': docCodeValid,
        'birthDateValid': vBirth,
        'expiryDateValid': vExpiry,
        'personalNumberValid': true,
        'finalCheckValid': vFinal,
        'hasFinalCheck': true,
        'nameValid': namesOk,
        'linesLengthValid': true,
        'countryValid': validation.countryValid,
        'nationalityValid': validation.nationalityValid,
      },
      'checkDigits': {
        'document': vDoc,
        'passport': vDoc,
        'birth': vBirth,
        'expiry': vExpiry,
        'optional': true,
        'final': vFinal,
        'finalComposite': vFinal,
      },
      'format': MrzFormat.TD2.toString().split('.').last,
      'ocrData': ocr.toJson(),
    };

    final mrzLike = ocr.lines.map((e) => e.text).where((a) => a.contains('<')).toList();
    mrzLogger?.call(OcrMrzLog(
      rawText: ocr.text,
      rawMrzLines: mrzLike,
      fixedMrzLines: [l1, l2],
      validation: validation,
      extractedData: resultMap,
    ));

    if (!accepts) {
      final failures = <String>[
        if (validateSettings.validateNames && !namesOk) 'name',
        if (validateSettings.validateDocNumberValid && !vDoc) 'docNumber',
        if (validateSettings.validateBirthDateValid && !vBirth) 'birthDate',
        if (validateSettings.validateExpiryDateValid && !vExpiry) 'expiryDate',
        if (validateSettings.validateFinalCheckValid && !vFinal) 'finalCheck',
        if (validateSettings.validateCountry && !validation.countryValid) 'country',
        if (validateSettings.validateNationality && !validation.nationalityValid) 'nationality',
        if (!docCodeValid) 'docCode',
      ].join(', ');
      return IdMrzFailure('TD2 validation failed: $failures', [l1, l2]);
    }

    return IdMrzSuccess(MrzFormat.TD2, validation, resultMap);
  } catch (e, st) {
    log('TD2 parse exception: $e\n$st');
    return IdMrzFailure('Exception: $e', [l1, l2]);
  }
}

/// =====================================================
/// Name validator (optimized bag-of-words like other files)
/// =====================================================

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
