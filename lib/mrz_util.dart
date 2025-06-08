import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:ocr_mrz/mrz_result_class.dart';

OcrMrzResult? parseMRZ(String line1, String line2,{List<String> baseLines = const [],required OcrData ocrData}) {
  try {
    line1 = line1.padRight(44, '<').substring(0, 44);
    line2 = line2.padRight(44, '<').substring(0, 44);

    // Line 1: Names
    final documentType = line1.substring(0, 1); // "P"
    final countryCode = line1.substring(2, 5); // e.g. "UGA"

    final nameData = line1.substring(5);
    final nameParts = nameData.split('<<');
    final lastName = nameParts[0].replaceAll('<', ' ').trim();
    final firstName = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';

    if(firstName.trim().isEmpty || lastName.trim().isEmpty){
      return null;
    }

    // Line 2: Other info (optional, expand as needed)
    final passportNumber = line2.substring(0, 9).replaceAll('<', '').trim();
    final nationality = line2.substring(10, 13).replaceAll('<', '').trim();
    final birthDateRaw = line2.substring(13, 19); // YYMMDD
    final expiryDateRaw = line2.substring(21, 27); // YYMMDD

    // Convert dates
    String formatDate(String raw) {
      // return raw;
      // log(raw);
      final regex = RegExp(r'^\d{6}$'); // Ensure it is exactly 6 digits

      if (!regex.hasMatch(raw)) {
        // log("❌$line1\n$line2");
        // log("❌${baseLines.join("\n")}");
        return '0001-01-01';
      }
      final year = int.parse(raw.substring(0, 2));
      final month = raw.substring(2, 4);
      final day = raw.substring(4, 6);
      final fullYear = (year >= 50 ? '19' : '20') + year.toString().padLeft(2, '0');
      return '$fullYear-$month-$day';
    }

    final result = {
      'documentType': documentType,
      'countryCode': countryCode,
      'lastName': lastName,
      'firstName': firstName,
      'ocrData': ocrData.toJson(),
      'passportNumber': passportNumber,
      'nationality': nationality,
      'birthDate': formatDate(birthDateRaw),
      'expiryDate': formatDate(expiryDateRaw),
      "mrzLines": [line1, line2],
    };
    return OcrMrzResult.fromJson(result);
  } catch (e) {
    if (e is Error) {
      log(e.stackTrace.toString());
    } else {
      log(e.toString());
    }
    return null;
  }
}

List<String> extractMrzLines(List<String> allLines) {
  return allLines
      .where((line) => line.contains(RegExp(r'<{1,}'))) // MRZ has lots of <<<<
      .toList();
}

List<String> extractWords(String text) {
  final wordRegExp = RegExp(r'\b\w+\b');
  return wordRegExp.allMatches(text).map((match) => match.group(0)!).toList();
}

void processFrameLines(OcrData ocrData, void Function(OcrMrzResult res) onFoundMrz) {
  List<String> allLines = ocrData.lines.map((a)=>a.text).toList();
  // allLines = allLines.map((a)=>normalizeToMrzCompatible(a)).toList();
  // log("processFrameLines for ${allLines.length} lines");
  try {
    final mrzLines = extractMrzLines(allLines);
    List<String> notMrz = List<String>.from(allLines.where((a)=>!mrzLines.contains(a)));
    if (mrzLines.length < 2) return;
    final fixedMrzLines = mrzLines.map((a) => normalizeMrzLine(a)).toList();
    final copy = List<String>.from(fixedMrzLines);
    fixedMrzLines[1] = repairMrzLine2(fixedMrzLines[1]);
    final parsed = parseMRZ(fixedMrzLines[0], fixedMrzLines[1],baseLines: copy, ocrData: ocrData);
    if (parsed == null) {
      return;
    }
    final vizLines = notMrz;
    final vizLinesLower = vizLines.map((e) => e.toLowerCase()).toList();
    List<String> words = [];
    for (var l in vizLinesLower) {
      words.addAll(extractWords(l));
    }
    final isFirstNameValid = parsed.firstName.split(" ").every((a)=>words.contains(a.toLowerCase()));
    final isLastNameValid = parsed.lastName.split(" ").every((a)=>words.contains(a.toLowerCase()));
    // final isFirstNameValid = vizLinesLower.any((line) => line.contains(parsed.firstName.split(" ").join("<").toLowerCase()));
    // final isLastNameValid = vizLinesLower.any((line) => line.contains(parsed.lastName.split(" ").join("<").toLowerCase()));
    // final isFirstNameValid = matchesMrzName(parsed.firstName,vizLinesLower);
    // final isLastNameValid = matchesMrzName(parsed.lastName,vizLinesLower);
    if (isFirstNameValid && isLastNameValid) {
      // log('✅ Passport matched:');
      // log(mrzLines.join("\n"));
      // log(fixedMrzLines.join("\n"));
      parsed.mrzLines = fixedMrzLines;
      // log(copy.join("\n"));
      onFoundMrz(parsed);
    } else {
      if (!isFirstNameValid) {
        log("${parsed.firstName.split(" ")} in $words");
        // log(vizLinesLower.join("\n"));
      }
      // if (!isLastNameValid) {
      //   log("${parsed.lastName.toLowerCase()} in");
      //   log(vizLinesLower.join("\n"));
      // }

      // log(allLines.join("\n"));
      // log(mrzLines.join("\n"));
      // log(fixedMrzLines.join("\n"));
      log('❌ $isFirstNameValid $isLastNameValid does not match VIZ. Keep scanning...');
      return;
    }
  } catch (e) {
    if (e is Error) {
      log(e.stackTrace.toString());
    }
    return;
  }
}

String normalizeMrzLine(String line) {
  return normalizeMrzLineSafe(line);
  final allowed = RegExp(r'[A-Z0-9<]');
  final raw =
      line
          .toUpperCase()
          .replaceAll(RegExp(r'[«KX#|\\\/]'), '<') // Replace known bad chars with '<'
          .replaceAll(RegExp(r'\s+'), '') // Remove all spaces between alphanumerics
          .split('')
          .where((c) => allowed.hasMatch(c)) // Filter only allowed MRZ chars
          .join();

  return raw.padRight(44, '<').substring(0, 44); // trim excess
}

String normalizeMrzLineSafe(String input) {
  final allowed = RegExp(r'[A-Z0-9<]');
  final correctionMap = {'«': '<', '|': '<', '/': '<', '\\': '<', '#': '<', '“': '<', '”': '<', '‘': '<', '’': '<'};

  // Step 1: Pre-clean known misreads
  input = input.toUpperCase();
  input = input.split('').map((c) => correctionMap[c] ?? c).join();

  // Step 2: Replace multiple Ks with '<'
  input = input.replaceAll(RegExp(r'K{2,}'), '<');

  // Step 3: Remove spaces *between letters* (e.g. "LUC I A" → "LUCIA")
  final chars = input.split('');
  final buffer = StringBuffer();

  for (int i = 0; i < chars.length; i++) {
    final char = chars[i];

    if (char == ' ') {
      final prev = i > 0 ? chars[i - 1] : '';
      final next = i < chars.length - 1 ? chars[i + 1] : '';
      final isLetterSandwich = RegExp(r'[A-Z]').hasMatch(prev) && RegExp(r'[A-Z]').hasMatch(next);
      if (isLetterSandwich) continue; // skip space
      buffer.write('<');
    } else if (char == 'K') {
      // Single K — preserve if not surrounded by garbage
      final prev = i > 0 ? chars[i - 1] : '';
      final next = i < chars.length - 1 ? chars[i + 1] : '';
      final isSurroundedByGarbage = ['<', 'K', ' ', '«'].contains(prev) && ['<', 'K', ' ', '«'].contains(next);
      if (isSurroundedByGarbage)
        buffer.write('<');
      else
        buffer.write('K');
    } else if (allowed.hasMatch(char)) {
      buffer.write(char);
    }
  }

  return buffer.toString().padRight(44, '<').substring(0, 44);
}

String repairMrzLine2(String input) {
  final map = {
    '«': '<', '|': '<', '\\': '<', '/': '<', '“': '<', '”': '<',
    '’': '<', '‘': '<', ' ': '<', 'O': '0', 'Q': '0', 'K': '<', 'X': '<'
  };

  // Step 1: Clean and sanitize input
  final cleaned = input.toUpperCase()
      .split('')
      .map((c) => map[c] ?? c)
      .where((c) => RegExp(r'[A-Z0-9<]').hasMatch(c))
      .toList();

  final chars = List<String>.from(cleaned)..addAll(List.filled(44 - cleaned.length, '<'));
  chars.length = 44;

  // Step 2: Strict repair of each field

  // -- birth date (13–18)
  for (int i = 13; i <= 18; i++) {
    if (!RegExp(r'\d').hasMatch(chars[i])) {
      chars[i] = '0';
    }
  }

  // -- sex (20)
  if (!(chars[20] == 'M' || chars[20] == 'F' || chars[20] == '<')) {
    chars[20] = '<';
  }

  // -- expiry date (21–26)
  for (int i = 21; i <= 26; i++) {
    if (!RegExp(r'\d').hasMatch(chars[i])) {
      chars[i] = '0';
    }
  }

  // Final: rejoin as clean MRZ line
  return chars.join().padRight(44, '<').substring(0, 44);
}



String normalizeToMrzCompatible(String input) {
  final map = {
    'À': 'A',
    'Á': 'A',
    'Â': 'A',
    'Ã': 'A',
    'Ä': 'A',
    'Å': 'A',
    'Æ': 'AE',
    'Ç': 'C',
    'È': 'E',
    'É': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Ì': 'I',
    'Í': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Ñ': 'N',
    'Ò': 'O',
    'Ó': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'Ö': 'O',
    'Ø': 'O',
    'Ù': 'U',
    'Ú': 'U',
    'Û': 'U',
    'Ü': 'U',
    'Ý': 'Y',
    'Ÿ': 'Y',
    'Ž': 'Z',
    'ß': 'SS',
    'Œ': 'OE',
    'Š': 'S',
  };

  return input.toUpperCase().split('').map((c) => map[c] ?? c).join().replaceAll(RegExp(r'[^A-Z0-9 ]'), ''); // strip special chars
}

bool matchesMrzName(String mrzName, List<String> vizLines) {
  final normalizedMrz = mrzName.toUpperCase();
  return vizLines.any((line) {
    final normalizedViz = normalizeToMrzCompatible(line);
    final res = normalizedViz.contains(normalizedMrz);
    log("CHECKING .... ${normalizedViz} contains ${normalizedMrz}");
    return res;
  });
}
