import 'dart:developer';

import 'package:ocr_mrz/name_validation_data_class.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';

import 'my_ocr_handler.dart';

// List<String> extractWords(String text) {
//   final wordRegExp = RegExp(r'\b\w+\b');
//   return wordRegExp.allMatches(text).map((match) => match.group(0)!).toList();
// }

List<String> extractWords(String text) {
  // Replace case transitions (e.g., a lowercase letter followed by an uppercase) with a space
  final separated = text.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
  );

  // Now extract all word-like tokens
  final wordRegExp = RegExp(r'\b\w+\b');
  return wordRegExp.allMatches(separated).map((m) => m.group(0)!).toList();
}


class MrzName {
  final String rawSurname; // e.g. "ERIKSSON"
  final List<String> rawGivenNames; // e.g. ["ANNA", "MARIA"]
  final String surname; // pretty (spaces, trimmed)
  final List<String> givenNames; // pretty
  final String full; // "ERIKSSON ANNA MARIA"

  MrzName({required this.rawSurname, required this.rawGivenNames, required this.surname, required this.givenNames, required this.full});

  String get firstName => givenNames.join(" ");
  String get lastName => surname;

  bool validateNames(Iterable<String> lines, OcrMrzSetting setting,List<NameValidationData> name) {
    if(setting.nameValidationMode == NameValidationMode.none){
      return true;
    }else if(setting.nameValidationMode == NameValidationMode.exact){
      List<String> words = [];
      for (var l in lines) {
        words.addAll(extractWords(l).map((a) => a.toLowerCase()));
      }
      final isFirstNameValid = firstName.toLowerCase().split(" ").every((a) => words.contains(a.toLowerCase()));
      final isLastNameValid = lastName.toLowerCase().split(" ").every((a) => words.contains(a.toLowerCase()));
      // log("lookin for $firstName and $lastName => in ${words.join(", ")}");

      final res = isLastNameValid && isFirstNameValid;
      final nameValidation = name.any((a)=>"${a.firstName} ${a.lastName} ${a.middleName??''}".toUpperCase().split(" ").contains(firstName.toUpperCase()) || "${a.firstName} ${a.lastName} ${a.middleName??''}".toUpperCase().split(" ").contains(lastName.toUpperCase()));
      return res || nameValidation;
    }else {
      List<String> words = [];
      for (var l in lines) {
        words.addAll(extractWords(l).map((a) => a.toLowerCase()));
      }
      final isFirstNameValid = firstName.toLowerCase().split(" ").every((a) => words.any((b)=>b.contains(a.toLowerCase())));
      final isLastNameValid = lastName.toLowerCase().split(" ").every((a) => words.any((b)=>b.contains(a.toLowerCase())));
      final res = isLastNameValid && isFirstNameValid;

      final nameValidation = name.any((a)=>"${a.firstName} ${a.lastName} ${a.middleName??''}".toUpperCase().split(" ").any((b)=>b.contains(firstName.toUpperCase())) || "${a.firstName} ${a.lastName} ${a.middleName??''}".toUpperCase().split(" ").any((b)=>b.contains(lastName.toUpperCase())));
      return res || nameValidation;
    }


      // log("validate name ${firstName} and ${lastName} in\n ${lines.join("\n")}");

  }
}



String _pretty(String s) {
  // Replace '<' with spaces, collapse, trim.
  final t = s.replaceAll('<', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

MrzName _parseNamesField(String namesField) {
  // namesField is something like: "ERIKSSON<<ANNA<MARIA<<<<<<<<<<<<"
  final parts = namesField.split('<<');
  final rawSurname = parts.isNotEmpty ? parts[0] : '';
  final rawGivenChunk = parts.length > 1 ? parts[1] : '';

  final rawGivenNames = rawGivenChunk.split('<').where((p) => p.isNotEmpty).toList();

  final surnamePretty = _pretty(rawSurname);
  final givenPretty = rawGivenNames.map(_pretty).where((p) => p.isNotEmpty).toList();

  final fullPretty = [if (surnamePretty.isNotEmpty) surnamePretty, if (givenPretty.isNotEmpty) givenPretty.join(' ')].join(' ').trim();

  return MrzName(rawSurname: rawSurname, rawGivenNames: rawGivenNames, surname: surnamePretty, givenNames: givenPretty, full: fullPretty);
}

/// TD3 & TD2: names are on line 1 after the first 5 chars (docType+issuer).
MrzName parseNamesTd3OrTd2(String line1) {
  // Guard length
  final start = line1.length >= 5 ? 5 : 0;
  final namesField = line1.substring(start);
  return _parseNamesField(namesField);
}

/// TD1: names are on line 3 (entire line).
MrzName parseNamesTd1(String line3) {
  return _parseNamesField(line3);
}


MrzName parseMrzNames(DocumentStandardType type, List<String> lines) {
  switch (type) {
    case DocumentStandardType.td3:
    case DocumentStandardType.td2:
      return parseNamesTd3OrTd2(lines[0]);
    case DocumentStandardType.td1:
      // TD1 is 3×30; line 3 contains names.
      return parseNamesTd1(lines.length >= 3 ? lines[2] : '');
  }
}
