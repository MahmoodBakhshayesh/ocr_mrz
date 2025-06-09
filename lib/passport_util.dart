import 'dart:convert';
import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';

// String _computeMrzCheckDigit(String input) {
//   final weights = [7, 3, 1];
//   int sum = 0;
//
//   for (int i = 0; i < input.length; i++) {
//     final c = input[i];
//     int v;
//     if (RegExp(r'[0-9]').hasMatch(c)) {
//       v = int.parse(c);
//     } else if (RegExp(r'[A-Z]').hasMatch(c)) {
//       v = c.codeUnitAt(0) - 55;
//     } else {
//       v = 0;
//     }
//     sum += v * weights[i % 3];
//   }
//   return (sum % 10).toString();
// }

String _normalizeLine(String line) {
  final map = {'«': '<', '|': '<', '\\': '<', '/': '<', '“': '<', '”': '<', '’': '<', '‘': '<', ' ': '<', 'O': '0', 'Q': '0', 'K': '<', 'X': '<'};

  return line.toUpperCase().split('').map((c) => map[c] ?? c).where((c) => RegExp(r'[A-Z0-9<]').hasMatch(c)).join().padRight(44, '<').substring(0, 44);
}

Map<String, dynamic>? tryParseMrzFromOcrLines(OcrData ocrData) {
  List<String> ocrLines = ocrData.lines.map((a) => a.text).toList();
  final mrzLines = ocrLines.map(_normalizeLine).where((line) => line.length == 44 && line.contains(RegExp(r'<{3,}'))).toList();

  if (mrzLines.length < 2) return null;

  final line1 = mrzLines[mrzLines.length - 2];
  var line2 = mrzLines[mrzLines.length - 1];
  line2 = repairMrzLine2Strict(line2); // ✅ repaired

  try {
    final documentType = line1.substring(0, 1);
    final countryCode = line1.substring(2, 5);
    final nameParts = line1.substring(5).split('<<');
    var lastName = nameParts[0].replaceAll('<', ' ').trim();
    var firstName = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';
    firstName = _cleanMrzName(firstName);
    lastName = _cleanMrzName(lastName);

    final passportNumber = line2.substring(0, 9).replaceAll('<', '');
    final passportCheck = line2.substring(9, 10);
    final nationality = line2.substring(10, 13);
    final birthDate = line2.substring(13, 19);
    final birthCheck = line2.substring(19, 20);
    final sex = line2.substring(20, 21);
    final expiryDate = line2.substring(21, 27);
    final expiryCheck = line2.substring(27, 28);
    final personalNumber = line2.substring(28, 42);
    final personalCheck = line2.substring(42, 43);
    final finalCheck = line2.substring(43, 44);

    final validPassport = _computeMrzCheckDigit(line2.substring(0, 9)) == passportCheck;
    final validBirth = _computeMrzCheckDigit(birthDate) == birthCheck;
    final validExpiry = _computeMrzCheckDigit(expiryDate) == expiryCheck;
    final validOptional = _computeMrzCheckDigit(personalNumber) == personalCheck;

    final composite = line2.substring(0, 10) + birthDate + birthCheck + expiryDate + expiryCheck + personalNumber + personalCheck;
    final validFinal = _computeMrzCheckDigit(composite) == finalCheck;

    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      return null;
    }
    bool validNames = validateNames(firstName, lastName, ocrLines.where((a) => !mrzLines.contains(a)));

    bool validBirthDate = _parseMrzDate(birthDate)!=null;
    bool validExpiryDate = _parseMrzDate(expiryDate)!=null;
    if (!validNames) {
      log("invalid names");
      return null;
    }
    if (!validBirthDate || !validBirth) {
      log("invalid BirthDate $birthDate");
      log(line1);
      log(line2);
      return null;
    }
    if (!validExpiryDate || !validExpiry) {
      log("invalid ExpiryDate $expiryDate");
      return null;
    }
    final resultMap = {
      'line1': line1,
      'line2': line2,
      'documentType': documentType,
      'countryCode': countryCode,
      'lastName': lastName,
      'firstName': firstName,
      'passportNumber': passportNumber,
      'nationality': nationality,
      'birthDate': _parseMrzDate(birthDate)?.toIso8601String(),
      'expiryDate': _parseMrzDate(expiryDate)?.toIso8601String(),
      'sex': sex,
      'personalNumber': personalNumber,
      'valid': validPassport && validBirth && validExpiry && validOptional && validFinal,
      'checkDigits': {'passport': validPassport, 'birth': validBirth, 'expiry': validExpiry, 'optional': validOptional, 'final': validFinal},
      "ocrData": ocrData.toJson(),
    };
    // if (resultMap != null && resultMap['valid']) {
    //   log("✅ Valid MRZ:");
    //   log(jsonEncode(resultMap));
    // log("Name: ${mrz['firstName']} ${mrz['lastName']}");
    // log("Passport: ${mrz['passportNumber']}, DOB: ${mrz['birthDate']}, Exp: ${mrz['expiryDate']}");
    // } else {
    //   // log("❌ MRZ not valid yet, keep scanning...");
    // }
    return resultMap;
  } catch (_) {
    return null;
  }
}

String _computeMrzCheckDigit(String input) {
  final weights = [7, 3, 1];
  int sum = 0;

  for (int i = 0; i < input.length; i++) {
    final c = input[i];
    int v;
    if (RegExp(r'[0-9]').hasMatch(c)) {
      v = int.parse(c);
    } else if (RegExp(r'[A-Z]').hasMatch(c)) {
      v = c.codeUnitAt(0) - 55;
    } else {
      v = 0;
    }
    sum += v * weights[i % 3];
  }

  return (sum % 10).toString();
}

String? _findValidDateWithCheck(List<String> chars, int start, int end, String expectedCheck) {
  for (int i = start; i <= end - 6; i++) {
    final segment = chars.sublist(i, i + 6).map((c) {
      if (RegExp(r'\d').hasMatch(c)) return c;
      if (c == 'O') return '0';
      if (c == 'I' || c == 'L') return '1';
      if (c == 'S') return '5';
      if (c == '<') return '0';
      return '0';
    }).join();

    if (_computeMrzCheckDigit(segment) == expectedCheck) {
      return segment;
    }
  }
  return null;
}

String repairMrzLine2Strict(String rawLine) {
  final Map<String, String> replacements = {
    '«': '<', '|': '<', '\\': '<', '/': '<',
    '“': '<', '”': '<', '’': '<', '‘': '<',
    ' ': '<', 'K': '<', 'X': '<'
  };

  // Normalize known noise
  String cleaned = rawLine
      .toUpperCase()
      .split('')
      .map((c) => replacements[c] ?? c)
      .where((c) => RegExp(r'[A-Z0-9<]').hasMatch(c))
      .join();

  // Pad or trim to exactly 44
  if (cleaned.length < 44) cleaned = cleaned.padRight(44, '<');
  if (cleaned.length > 44) cleaned = cleaned.substring(0, 44);

  // Generate candidates by removing up to 2 extra '<'
  List<String> generateCandidates(String line) {
    final List<String> results = [line];

    // All 1-char removed variations
    for (int i = 0; i < line.length; i++) {
      if (line[i] == '<') {
        results.add(line.substring(0, i) + line.substring(i + 1));
      }
    }

    // All 2-char removed variations
    for (int i = 0; i < line.length; i++) {
      if (line[i] != '<') continue;
      for (int j = i + 1; j < line.length; j++) {
        if (line[j] != '<') continue;
        final removed = line.substring(0, i) +
            line.substring(i + 1, j) +
            line.substring(j + 1);
        results.add(removed);
      }
    }

    return results;
  }

  for (final candidate in generateCandidates(cleaned)) {
    String line = candidate;
    if (line.length < 44) line = line.padRight(44, '<');
    if (line.length > 44) line = line.substring(0, 44);

    final birth = line.substring(13, 19);
    final birthCheck = line[19];
    final expiry = line.substring(21, 27);
    final expiryCheck = line[27];

    final isBirthValid =
        RegExp(r'^\d{6}$').hasMatch(birth) &&
            _computeMrzCheckDigit(birth) == birthCheck;

    final isExpiryValid =
        RegExp(r'^\d{6}$').hasMatch(expiry) &&
            _computeMrzCheckDigit(expiry) == expiryCheck;

    if (isBirthValid && isExpiryValid) {
      // Optionally validate sex field too
      if (!(line[20] == 'M' || line[20] == 'F' || line[20] == '<')) {
        line = line.substring(0, 20) + '<' + line.substring(21);
      }

      return line;
    }
  }

  // If no valid candidate found, return original cleaned version
  return cleaned;
}











String _cleanMrzName(String input) {
  return input
      .replaceAll('0', 'O')
      .replaceAll('1', 'I')
      .replaceAll('5', 'S')
      .replaceAll(RegExp(r'[2-9]'), '') // remove other digits
      .replaceAll('<', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

DateTime? _parseMrzDate(String yymmdd) {
  if (!RegExp(r'^\d{6}$').hasMatch(yymmdd)) return null;

  final year = int.parse(yymmdd.substring(0, 2));
  final month = int.parse(yymmdd.substring(2, 4));
  final day = int.parse(yymmdd.substring(4, 6));

  // MRZ dates assume:
  // - birth: usually 1900–2029 (but safe to assume <= current year)
  // - expiry: usually 2000–2099
  final now = DateTime.now().year % 100;

  final fullYear = year <= now + 10 ? 2000 + year : 1900 + year;

  try {
    return DateTime(fullYear, month, day);
  } catch (_) {
    return null;
  }
}

bool validateNames(String firstName, String lastName, Iterable<String> lines) {
  List<String> words = [];
  for (var l in lines) {
    words.addAll(extractWords(l).map((a) => a.toLowerCase()));
  }
  final isFirstNameValid = firstName.toLowerCase().split(" ").every((a) => words.contains(a.toLowerCase()));
  final isLastNameValid = lastName.toLowerCase().split(" ").every((a) => words.contains(a.toLowerCase()));
  final res = isLastNameValid && isFirstNameValid;
  if (!isFirstNameValid) {
    log("${firstName.toLowerCase().split(" ")} in $words");
  }
  if (!isLastNameValid) {
    log("${lastName.toLowerCase().split(" ")} in $words");
  }
  return res;
}

List<String> extractWords(String text) {
  final wordRegExp = RegExp(r'\b\w+\b');
  return wordRegExp.allMatches(text).map((match) => match.group(0)!).toList();
}

void handleOcr(OcrData ocr, void Function(OcrMrzResult res) onFoundMrz) {
  // final ocrLines = ocr.lines.map((a)=>a.text).toList();
  try {
    final mrz = tryParseMrzFromOcrLines(ocr);
    if (mrz != null) {
      log("✅ Valid MRZ:");
      final ocrMR = OcrMrzResult.fromJson(mrz);
      log("${ocrMR.line1}\n${ocrMR.line2}");
      onFoundMrz(ocrMR);
    }
  } catch (e) {
    log(e.toString());
    if (e is Error) {
      log(e.stackTrace.toString());
    }
  }
}
