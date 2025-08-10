import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/name_validation_data_class.dart';

import 'mrz_result_class_fix.dart';
import 'ocr_mrz_settings_class.dart';

// Reuse these from your codebase if already defined; otherwise keep here.
String _normalizeIdLine(String line) {
  final map = {
    '«': '<', '|': '<', '\\': '<', '/': '<', '“': '<', '”': '<',
    '’': '<', '‘': '<', ' ': '<',
  };
  return line
      .toUpperCase()
      .split('')
      .map((c) => map[c] ?? c)
      .where((c) => RegExp(r'[A-Z0-9<]').hasMatch(c))
      .join();
}

String _enforceLen(String s, int len) => s.length >= len ? s.substring(0, len) : s.padRight(len, '<');

String _cleanName(String input) => input
    .replaceAll('0', 'O')
    .replaceAll('1', 'I')
    .replaceAll('5', 'S')
    .replaceAll(RegExp(r'[2-9]'), '')
    .replaceAll('<', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

DateTime? _parseDateYYMMDD(String yymmdd) {
  if (!RegExp(r'^\d{6}$').hasMatch(yymmdd)) return null;
  final yy = int.parse(yymmdd.substring(0, 2));
  final mm = int.parse(yymmdd.substring(2, 4));
  final dd = int.parse(yymmdd.substring(4, 6));
  final nowYY = DateTime.now().year % 100;
  final year = yy <= nowYY + 10 ? 2000 + yy : 1900 + yy;
  try {
    return DateTime(year, mm, dd);
  } catch (_) {
    return null;
  }
}

// If you already have this in a shared file, remove this copy and import it.
String _computeMrzCheckDigit(String input) {
  const weights = [7, 3, 1];
  int sum = 0;
  for (int i = 0; i < input.length; i++) {
    final c = input[i];
    int v;
    if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
      v = c.codeUnitAt(0) - 48; // 0-9
    } else if (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) {
      v = c.codeUnitAt(0) - 55; // A=10..Z=35
    } else {
      v = 0; // '<'
    }
    sum += v * weights[i % 3];
  }
  return (sum % 10).toString();
}

// Replace with your own set if you already have it
bool isValidMrzCountry(String code) => code.length == 3 && RegExp(r'^[A-Z<]{3}$').hasMatch(code) && !code.contains('<');

// -------------------- TD1 (3 × 30) --------------------

/// Public: find and parse a TD1 triplet; returns JSON for OcrMrzResult.fromJson or null.
Map<String, dynamic>? tryParseTD1FromOcrLines(
    OcrData ocrData,
    OcrMrzSetting? setting,
    List<NameValidationData>? nameValidations,
    ) {
  final raw = ocrData.lines.map((e) => e.text).toList();
  final normalized = raw.map(_normalizeIdLine).toList();
  final s = setting ?? OcrMrzSetting();

  return _findTd1TripletAndParse(
    normalized: normalized,
    rawAllLines: raw,
    validateSettings: s,
    nameValidations: nameValidations,
    ocr: ocrData,
  );
}

Map<String, dynamic>? _findTd1TripletAndParse({
  required List<String> normalized,
  required List<String> rawAllLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
}) {
  // Collect lines that can be 30 chars (TD1)
  final idxToLine = <int, String>{};
  for (int i = 0; i < normalized.length; i++) {
    final l = _enforceLen(normalized[i], 30);
    if (l.length == 30) idxToLine[i] = l;
  }
  if (idxToLine.length < 3) return null;

  // Candidate L1: first char is alpha (document code), contains issuing state-ish at [2..5)
  // Candidate L3: must contain '<<' (names)
  // We search for i, i+1, i+2 primarily; also allow small window to handle OCR shuffles.
  const window = 3;
  final indices = idxToLine.keys.toList()..sort();

  for (final i in indices) {
    final l1 = idxToLine[i]!;
    if (!RegExp(r'^[A-Z]').hasMatch(l1)) continue; // doc code must be alpha
    // enforce name line existence nearby
    for (int j = i + 1; j <= i + window; j++) {
      for (int k = j + 1; k <= i + window + 1; k++) {
        if (!idxToLine.containsKey(j) || !idxToLine.containsKey(k)) continue;
        final l2cand = idxToLine[j]!;
        final l3cand = idxToLine[k]!;
        if (!l3cand.contains('<<')) continue;

        // Repair/sanitize specific fields
        final line1 = _repairTd1Line1(l1);
        final line2 = _repairTd1Line2(l2cand);
        final line3 = _repairTd1Line3(l3cand);

        if (!_looksLikeTd1Line2(line2)) continue;

        // Build other lines (exclude these three indices)
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
        );
        if (parsed != null) {
          parsed['ocrData'] = ocr.toJson();
          return parsed;
        }
      }
    }
  }
  return null;
}

String _repairTd1Line1(String l1) {
  // Fix common OCR in doc number and country area
  final buf = l1.split('');
  // issuing state at [2..5)
  for (int i = 2; i < 5 && i < buf.length; i++) {
    buf[i] = _fixAlpha(buf[i]);
  }
  // doc number at [5..14)
  for (int i = 5; i < 14 && i < buf.length; i++) {
    buf[i] = _fixAlnumPrefDigits(buf[i]);
  }
  return buf.join();
}

String _repairTd1Line2(String l2) {
  final buf = l2.split('');
  // birth [0..6), birth check [6], sex [7], expiry [8..14), expiry check [14], nationality [15..18)
  for (int i = 0; i < 6 && i < buf.length; i++) buf[i] = _toDigit(buf[i]);
  if (buf.length > 6) buf[6] = _toDigit(buf[6]);
  if (buf.length > 7) buf[7] = (buf[7] == 'M' || buf[7] == 'F' || buf[7] == '<') ? buf[7] : '<';
  for (int i = 8; i < 14 && i < buf.length; i++) buf[i] = _toDigit(buf[i]);
  if (buf.length > 14) buf[14] = _toDigit(buf[14]);
  for (int i = 15; i < 18 && i < buf.length; i++) buf[i] = _fixAlpha(buf[i]);
  return buf.join();
}

String _repairTd1Line3(String l3) {
  // names line — keep alnum and fillers, collapse weird bursts
  return l3.replaceAll(RegExp(r'[^\w<]'), '<');
}

bool _looksLikeTd1Line2(String l2) {
  if (l2.length != 30) return false;
  final birth = l2.substring(0, 6);
  final birthChk = l2[6];
  final sex = l2[7];
  final expiry = l2.substring(8, 14);
  final expiryChk = l2[14];

  final birthOk = RegExp(r'^\d{6}$').hasMatch(birth) && _computeMrzCheckDigit(birth) == birthChk;
  final expiryOk = RegExp(r'^\d{6}$').hasMatch(expiry) && _computeMrzCheckDigit(expiry) == expiryChk;
  final sexOk = (sex == 'M' || sex == 'F' || sex == '<');

  return birthOk && expiryOk && sexOk;
}

/// Fix OCR mistakes for alpha-only MRZ fields (like country or nationality).
String fixAlphaOnlyField(String value) {
  final map = {
    '0': 'O',
    '1': 'I',
    '5': 'S',
    '8': 'B',
    '6': 'G',
  };
  return value
      .toUpperCase()
      .split('')
      .map((c) => map[c] ?? c)
      .join();
}

Map<String, dynamic>? _parseTd1({
  required String l1,
  required String l2,
  required String l3,
  required List<String> otherLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
}) {
  try {
    // Line1 (30):
    // [0..2) docType(2), [2..5) issuingState(3), [5..14) docNo(9), [14] docChk, [15..30) opt1
    final documentType = l1.substring(0, 1);        // first char
    final issuingState = fixAlphaOnlyField(l1.substring(2, 5));
    final docNo = l1.substring(5, 14);
    final docChk = l1[14];
    final opt1 = l1.substring(15, 30);

    // Line2 (30):
    // [0..6) birth, [6] birthChk, [7] sex, [8..14) expiry, [14] expiryChk,
    // [15..18) nationality, [18..29) opt2, [29] finalComposite
    final birth = l2.substring(0, 6);
    final birthChk = l2[6];
    final sex = l2[7];
    final expiry = l2.substring(8, 14);
    final expiryChk = l2[14];
    final nationality = fixAlphaOnlyField(l2.substring(15, 18));
    final opt2 = l2.substring(18, 29);
    final finalComposite = l2[29];

    // Line3 (30): names "LAST<<FIRST<MIDDLE..."
    final nameField = l3;
    final nameParts = nameField.split('<<');
    String lastName = nameParts.isNotEmpty ? nameParts[0].replaceAll('<', ' ').trim() : '';
    String firstName = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';
    lastName = _cleanName(lastName);
    firstName = _cleanName(firstName);
    if (firstName.isEmpty || lastName.isEmpty) return null;

    // Validations
    final vDoc = _computeMrzCheckDigit(docNo) == docChk;
    final vBirth = RegExp(r'^\d{6}$').hasMatch(birth) && _computeMrzCheckDigit(birth) == birthChk;
    final vExpiry = RegExp(r'^\d{6}$').hasMatch(expiry) && _computeMrzCheckDigit(expiry) == expiryChk;

    final namesOk = validateSettings.validateNames
        ? ( _validateNames(firstName, lastName, otherLines) ||
        (nameValidations?.any((a) =>
        a.firstName.toLowerCase() == firstName.toLowerCase() &&
            a.lastName.toLowerCase() == lastName.toLowerCase()) ?? false))
        : true;

    final issuingOk = !validateSettings.validateCountry || isValidMrzCountry(issuingState);
    final nationalityOk = !validateSettings.validateNationality || isValidMrzCountry(nationality);

    // Composite (TD1 final check at end of L2)
    final compositeInput = docNo + docChk + birth + birthChk + expiry + expiryChk + opt2; // ICAO Doc 9303 specifies opt2 in composite
    final vFinal = _computeMrzCheckDigit(compositeInput) == finalComposite;

    // Build result
    return {
      'line1': l1,
      'line2': l2,
      "line3":l3,
      'documentType': documentType,   // usually 'I' for ID
      'mrzFormat': 'TD1',
      'issuingState': issuingState,
      'countryCode': issuingState,
      'lastName': lastName,
      'firstName': firstName,
      'documentNumber': docNo,
      'passportNumber': docNo,        // legacy mirror
      'nationality': nationality,
      'birthDate': _parseDateYYMMDD(birth)?.toIso8601String(),
      'expiryDate': _parseDateYYMMDD(expiry)?.toIso8601String(),
      'sex': sex,
      'optionalData': opt2.isNotEmpty ? opt2 : opt1,  // prefer L2 optional
      'personalNumber': opt2.isNotEmpty ? opt2 : opt1,
      'valid': {
        'docNumberValid': vDoc,
        'birthDateValid': vBirth,
        'expiryDateValid': vExpiry,
        'personalNumberValid': true,     // no direct check digit for optional
        'finalCheckValid': vFinal,
        'hasFinalCheck': true,
        'nameValid': namesOk,
        'linesLengthValid': true,
        'countryValid': issuingOk,
        'nationalityValid': nationalityOk,
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
      'format': MrzFormat.TD1.toString().split('.').last
    };
  } catch (_) {
    return null;
  }
}

// -------------------- TD2 (2 × 36) --------------------

/// Public: find and parse a TD2 pair; returns JSON for OcrMrzResult.fromJson or null.
Map<String, dynamic>? tryParseTD2FromOcrLines(
    OcrData ocrData,
    OcrMrzSetting? setting,
    List<NameValidationData>? nameValidations,
    ) {
  final raw = ocrData.lines.map((e) => e.text).toList();
  final normalized = raw.map(_normalizeIdLine).toList();
  final s = setting ?? OcrMrzSetting();

  return _findTd2PairAndParse(
    normalized: normalized,
    rawAllLines: raw,
    validateSettings: s,
    nameValidations: nameValidations,
    ocr: ocrData,
  );
}

Map<String, dynamic>? _findTd2PairAndParse({
  required List<String> normalized,
  required List<String> rawAllLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
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
    // Line1: alpha doc code at start, must contain '<<' for names
    if (!RegExp(r'^[A-Z]').hasMatch(l1cand)) continue;
    if (!l1cand.contains('<<')) continue;

    final l1 = _repairTd2Line1(l1cand);

    // search for line2 nearby
    for (int j = i + 1; j <= i + window; j++) {
      if (!idxToLine.containsKey(j)) continue;
      final l2cand = idxToLine[j]!;
      // Line2 starts with document number (not 'V', usually not '<')
      if (l2cand.startsWith('V')) continue;

      final l2 = _repairTd2Line2(l2cand);
      if (!_looksLikeTd2Line2(l2)) continue;

      // Build other lines
      final other = <String>[];
      for (int t = 0; t < rawAllLines.length; t++) {
        if (t != i && t != j) other.add(rawAllLines[t]);
      }

      final parsed = _parseTd2(
        l1: l1,
        l2: l2,
        otherLines: other,
        validateSettings: validateSettings,
        nameValidations: nameValidations,
      );
      if (parsed != null) {
        parsed['ocrData'] = ocr.toJson();
        return parsed;
      }
    }
  }
  return null;
}

String _repairTd2Line1(String l1) {
  final buf = l1.split('');
  // issuing state [2..5)
  for (int i = 2; i < 5 && i < buf.length; i++) buf[i] = _fixAlpha(buf[i]);
  return buf.join();
}

String _repairTd2Line2(String l2) {
  final buf = l2.split('');
  // [0..9) docNo, [9] docChk, [10..13) nationality, [13..19) birth, [19] birthChk,
  // [20] sex, [21..27) expiry, [27] expiryChk, [28..35) optional, [35] final
  for (int i = 13; i < 19 && i < buf.length; i++) buf[i] = _toDigit(buf[i]); // birth
  if (buf.length > 19) buf[19] = _toDigit(buf[19]); // birth chk
  if (buf.length > 20) buf[20] = (buf[20] == 'M' || buf[20] == 'F' || buf[20] == '<') ? buf[20] : '<';
  for (int i = 21; i < 27 && i < buf.length; i++) buf[i] = _toDigit(buf[i]); // expiry
  if (buf.length > 27) buf[27] = _toDigit(buf[27]); // expiry chk
  for (int i = 10; i < 13 && i < buf.length; i++) buf[i] = _fixAlpha(buf[i]); // nationality
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

  final vDoc = _computeMrzCheckDigit(docNo) == docChk;
  final vBirth = RegExp(r'^\d{6}$').hasMatch(birth) && _computeMrzCheckDigit(birth) == birthChk;
  final vExpiry = RegExp(r'^\d{6}$').hasMatch(expiry) && _computeMrzCheckDigit(expiry) == expiryChk;
  final vNat = isValidMrzCountry(nationality);
  final vSex = (sex == 'M' || sex == 'F' || sex == '<');
  return vDoc && vBirth && vExpiry && vNat && vSex;
}

Map<String, dynamic>? _parseTd2({
  required String l1,
  required String l2,
  required List<String> otherLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
}) {
  try {
    // Line1 (36): [0..2) docType(2), [2..5) issuingState(3), [5..) names
    final documentType = l1.substring(0, 1); // first char
    final issuingState = fixAlphaOnlyField(l1.substring(2, 5));
    final nameField = l1.substring(5);
    final nameParts = nameField.split('<<');
    String lastName = nameParts.isNotEmpty ? nameParts[0].replaceAll('<', ' ').trim() : '';
    String firstName = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';
    lastName = _cleanName(lastName);
    firstName = _cleanName(firstName);
    if (firstName.isEmpty || lastName.isEmpty) return null;

    // Line2 (36):
    // [0..9) docNo, [9] docChk, [10..13) nationality, [13..19) birth, [19] birthChk,
    // [20] sex, [21..27) expiry, [27] expiryChk, [28..35) optional, [35] final
    final docNo = l2.substring(0, 9);
    final docChk = l2[9];
    final nationality = fixAlphaOnlyField(l2.substring(10, 13));
    final birth = l2.substring(13, 19);
    final birthChk = l2[19];
    final sex = l2[20];
    final expiry = l2.substring(21, 27);
    final expiryChk = l2[27];
    final optional = l2.substring(28, 35);
    final finalComposite = l2[35];

    final vDoc = _computeMrzCheckDigit(docNo) == docChk;
    final vBirth = RegExp(r'^\d{6}$').hasMatch(birth) && _computeMrzCheckDigit(birth) == birthChk;
    final vExpiry = RegExp(r'^\d{6}$').hasMatch(expiry) && _computeMrzCheckDigit(expiry) == expiryChk;

    final namesOk = validateSettings.validateNames
        ? ( _validateNames(firstName, lastName, otherLines) ||
        (nameValidations?.any((a) =>
        a.firstName.toLowerCase() == firstName.toLowerCase() &&
            a.lastName.toLowerCase() == lastName.toLowerCase()) ?? false))
        : true;

    final issuingOk = !validateSettings.validateCountry || isValidMrzCountry(issuingState);
    final nationalityOk = !validateSettings.validateNationality || isValidMrzCountry(nationality);

    // Composite (TD2 final at end of L2)
    final compositeInput = docNo + docChk + birth + birthChk + expiry + expiryChk + optional;
    final vFinal = _computeMrzCheckDigit(compositeInput) == finalComposite;

    return {
      'line1': l1,
      'line2': l2,
      'documentType': documentType,  // typically 'I'
      'mrzFormat': 'TD2',
      'issuingState': issuingState,
      'countryCode': issuingState,
      'lastName': lastName,
      'firstName': firstName,
      'documentNumber': docNo,
      'passportNumber': docNo,
      'nationality': nationality,
      'birthDate': _parseDateYYMMDD(birth)?.toIso8601String(),
      'expiryDate': _parseDateYYMMDD(expiry)?.toIso8601String(),
      'sex': sex,
      'optionalData': optional,
      'personalNumber': optional,
      'valid': {
        'docNumberValid': vDoc,
        'birthDateValid': vBirth,
        'expiryDateValid': vExpiry,
        'personalNumberValid': true,
        'finalCheckValid': vFinal,
        'hasFinalCheck': true,
        'nameValid': namesOk,
        'linesLengthValid': true,
        'countryValid': issuingOk,
        'nationalityValid': nationalityOk,
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
      'format': MrzFormat.TD2.toString().split('.').last
    };
  } catch (_) {
    return null;
  }
}

// -------------------- Shared helpers --------------------

String _toDigit(String c) {
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

/// Keep alnum but bias ambiguous OCR towards digits (for doc numbers).
String _fixAlnumPrefDigits(String c) {
  final d = _toDigit(c);
  // If it's still a letter after mapping, keep it (alphanumeric allowed).
  if (RegExp(r'^[0-9]$').hasMatch(d)) return d;
  return c;
}

bool _validateNames(String firstName, String lastName, Iterable<String> lines) {
  final words = <String>[];
  for (final l in lines) {
    words.addAll(RegExp(r'\b\w+\b').allMatches(l).map((m) => m.group(0)!.toLowerCase()));
  }
  final fOk = firstName.toLowerCase().split(' ').every(words.contains);
  final lOk = lastName.toLowerCase().split(' ').every(words.contains);
  return fOk && lOk;
}
