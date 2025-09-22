import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:ocr_mrz/aggregator.dart';
import 'package:ocr_mrz/doc_code_validator.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';
import 'package:ocr_mrz/my_name_handler.dart';
import 'package:ocr_mrz/session_status_class.dart';
import 'package:ocr_mrz/travel_doc_util.dart';

import 'enums.dart';

final _dateSexRe = RegExp(r'(\d{6})(\d)([MFX])(\d{6})(\d)', caseSensitive: false);

class SessionOcrHandlerConsensus {
  OcrMrzConsensus handleSession(OcrMrzAggregator aggregator, OcrData ocr) {
    try {
      final List<String> lines = ocr.lines.map((a) => a.text).toList();
      final List<String> baseLines = List<String>.of(ocr.lines.map((a) => a.text).toList());
      var updatedSession = aggregator.buildStatus();
      // log("handleSession ${updatedSession.step}");
      // if (updatedSession.step == 1) {
      String secondLineGuess = lines.firstWhere((a) => _dateSexRe.hasMatch(a), orElse: () => '');
      if (secondLineGuess.isNotEmpty) {
        final dateSexMatch = _dateSexRe.firstMatch(secondLineGuess);
        String dateSexStr = dateSexMatch!.group(0)!;
        final birthDateStr = dateSexMatch.group(1);
        final birthCheck = dateSexMatch.group(2);
        final sexStr = dateSexMatch.group(3);
        final expiryDateStr = dateSexMatch.group(4);
        final expiryCheck = dateSexMatch.group(5);
        bool birthDateValid = _computeMrzCheckDigit(birthDateStr!) == birthCheck;
        bool expDateValid = _computeMrzCheckDigit(expiryDateStr!) == expiryCheck;
        bool sexValid = ["M", "F", "X", "<"].contains(sexStr);

        var currentVal = aggregator.validation;
        currentVal.birthDateValid = birthDateValid;
        currentVal.expiryDateValid = expDateValid;
        currentVal.sexValid = sexValid;
        aggregator.validation = currentVal;

        if (birthDateValid && expDateValid) {
          aggregator.addBirthDate(birthDateStr);
          aggregator.addExpiryDate(expiryDateStr);
          aggregator.addExpCheck(expiryCheck!);
          aggregator.addBirthCheck(birthCheck!);
          aggregator.addSex(sexStr!);
          aggregator.setStep(2);

        }
      }

      updatedSession = aggregator.buildStatus();

      if ((updatedSession.step??0) >= 2) {
        DocumentStandardType? type;
        // log("date sex str - > ${updatedSession.dateSexStr}");
        final parts = updatedSession.dateSexStr!.split(RegExp(r'[^0-9]+'));
        String? nationalityStr;
        String birth = parts[0];
        String exp = parts[1];
        // log("look before $birth or after $exp  ${updatedSession.line2??''}");
        // final countryBeforeBirthReg = RegExp(r'[A-Za-z]{3}' + birth);
        final countryBeforeBirthReg = RegExp(r'([A-Za-z0-9]{3})(?=' + RegExp.escape(birth) + r')');
        final countryAfterExpReg = RegExp(RegExp.escape(exp) + r'([A-Za-z]{3})');
        String line1 = "";
        String? line3;
        for (var l in lines) {
          int index = lines.indexOf(l);
          l = normalize(l);
          final countryBeforeBirthMatch = countryBeforeBirthReg.firstMatch(normalize(l));
          if (countryBeforeBirthMatch != null) {
            // log("we have before ${countryBeforeBirthMatch.group(0)}");
            type = l.length < 40 ? DocumentStandardType.td2 : DocumentStandardType.td3;
            nationalityStr = countryBeforeBirthMatch.group(0)!;
            if (index != 0) {
              line1 = lines[index - 1];
            }
            updatedSession = updatedSession.copyWith(logDetails: "Found Valid Nationality ${nationalityStr} in ${countryBeforeBirthMatch.group(0)}$birth");

          }else{
            // if(normalize(l).contains(birth) || true) {
            //   log("not Found Valid Nationality before ${birth} in ${normalize(l)}");
            // }
          }
          final countryAfterExpMatch = countryAfterExpReg.firstMatch(normalize(l));
          if (countryAfterExpMatch != null ) {
            // log("we have match after ${countryAfterExpMatch.group(1)}");
            type = DocumentStandardType.td1;
            nationalityStr = countryAfterExpMatch.group(1)!;
            if (index != 0) {
              line1 = lines[index - 1];
            }
            if (index != lines.length - 1) {
              line3 = lines[index + 1];
            }
            updatedSession = updatedSession.copyWith(logDetails: "Found Valid Nationality ${nationalityStr} in $exp${countryAfterExpMatch.group(0)}");
          }else{
            // if(normalize(l).contains(exp) || true) {
            //   log("not Found Valid Nationality after ${exp} in ${normalize(l)}");
            // }
          }

          if (nationalityStr != null) {
            // log("potensial nat ${nationalityStr}");
            final fixedNationalityStr = fixAlphaOnlyField(nationalityStr);
            if (isValidMrzCountry(nationalityStr) || isValidMrzCountry(fixedNationalityStr)) {
              var currentVal = aggregator.validation;
              currentVal.nationalityValid = isValidMrzCountry(nationalityStr) || isValidMrzCountry(fixedNationalityStr);


              aggregator.addNationality(nationalityStr);
              aggregator.validation = currentVal;
              aggregator.setType(type);
              aggregator.setStep(3);
              updatedSession = updatedSession.copyWith(step: 3, details: 'Found nationality', nationality: nationalityStr, type: type, line1: line1, line2: normalize(l), line3: line3, validation: currentVal);
            }

            // final fixedNationalityStr = fixAlphaOnlyField(nationalityStr);
            if (isValidMrzCountry(nationalityStr)) {
              var currentVal = aggregator.validation;
              currentVal.nationalityValid = isValidMrzCountry(nationalityStr);
              aggregator.addNationality(nationalityStr);
              aggregator.validation = currentVal;
              aggregator.setType(type);
              aggregator.setStep(3);
              updatedSession = updatedSession.copyWith(step: 3, details: 'Found nationality', nationality: nationalityStr, type: type, line1: line1, line2: normalize(l), line3: line3, validation: currentVal);
            }
          } else {
            updatedSession = updatedSession.copyWith(logDetails: "Did not found valid Nationality before $birth or after $exp in\n${lines.where((a) => a.contains(birth) || a.contains(exp)).map((b) => normalize(b)).join("\n")}");
            // log("not valid nat ${nationalityStr} in ${lines.map((a) => normalize(a)).join("\n")}");
          }
        }
      }
      updatedSession = aggregator.buildStatus();
      if ((updatedSession.step??0) >= 3) {
        String? numberStr;
        if (updatedSession.type == DocumentStandardType.td1) {
          String dateStart = updatedSession.birthDate!;
          for (var l in lines) {
            int index = lines.indexOf(l);
            if (l.startsWith(dateStart)) {

              var currentVal = aggregator.validation;

              String firstLineGuess = normalize(lines[index - 1]);
              if (firstLineGuess.length >= 15) {
                String firstFiveChars = firstLineGuess.substring(0, 5);
                String docCode = firstFiveChars.substring(0, 2);
                String countryCode = firstFiveChars.substring(2, 5);
                bool validCode = DocumentCodeHelper.isValid(docCode);
                bool validCountry = isValidMrzCountry(countryCode);
                if (validCode && validCountry) {
                  numberStr = firstLineGuess.substring(5, 14);
                  final numberStrCheck = firstLineGuess[14];
                  bool validDocNumber = _computeMrzCheckDigit(numberStr) == numberStrCheck;

                  currentVal.countryValid = validCountry;
                  currentVal.docCodeValid = validCode;

                  aggregator.addDocNum(numberStr);
                  aggregator.addDocCode(docCode);
                  aggregator.addCountry(countryCode);
                  aggregator.addNumCheck(numberStrCheck);

                  aggregator.validation = currentVal;

                  currentVal.docNumberValid = validDocNumber;
                  currentVal.linesLengthValid = true;
                  currentVal.finalCheckValid = true;
                  currentVal.personalNumberValid = true;
                  if (validDocNumber) {

                    var currentVal = aggregator.validation;
                    currentVal.docNumberValid = true;
                    aggregator.setStep(4);
                    aggregator.validation = currentVal;
                  }
                }
              }
            }
          }
        } else {
          final parts = updatedSession.dateSexStr!.split(RegExp(r'[^0-9]+'));
          String birth = parts[0];
          String natBirth = "${updatedSession.nationality}$birth";
          String natOnly = "${updatedSession.nationality}";

          // final numberBeforeNatReg = RegExp(r'^(.*?)(?=' + RegExp.escape(natBirth) + r')');
          final numberBeforeNatReg = RegExp(r'([A-Z0-9<]{9,12})(\d)(?=' + RegExp.escape(natOnly) + r')');
          for (var l in lines) {
            int index = lines.indexOf(l);
            final numberBeforeNatMatch = numberBeforeNatReg.firstMatch(normalize(l));
            if (numberBeforeNatMatch != null && index != 0) {
              // log("we have before ${countryBeforeBirthMatch.group(0)}");
              numberStr = numberBeforeNatMatch.group(1)!.replaceAll("O", '0').replaceAll("<", '');
              String numberStrCheck = numberBeforeNatMatch.group(2)!;
              bool docNumberValid = _computeMrzCheckDigit(numberStr!) == numberStrCheck;
              var currentVal = aggregator.validation;
              currentVal.docNumberValid = docNumberValid;

              String firstLineGuess = lines[index - 1];
              if (firstLineGuess.length > 5) {
                String firstFiveChars = firstLineGuess.substring(0, 5);
                String docCode = firstFiveChars.substring(0, 2);
                String countryCode = firstFiveChars.substring(2, 5);
                bool validCode = DocumentCodeHelper.isValid(docCode);
                bool validCountry = isValidMrzCountry(countryCode);



                if (validCode && validCountry) {
                  currentVal.countryValid = validCountry;
                  currentVal.docCodeValid = validCode;
                  currentVal.finalCheckValid = true;
                  currentVal.personalNumberValid = true;
                  currentVal.linesLengthValid = true;

                  aggregator.setStep(4);
                  aggregator.addDocNum(numberStr);
                  aggregator.addNumCheck(numberStrCheck);
                  aggregator.addDocCode(docCode);
                  aggregator.addCountry(countryCode);
                  aggregator.addNationality(fixAlphaOnlyField(natOnly));

                }
              }

            }


          }
        }
      }

      updatedSession= aggregator.buildStatus();
      if ((updatedSession.step??0) >= 4) {
        if (updatedSession.type == DocumentStandardType.td1) {

          int line2Index = lines.indexWhere((a)=>a.contains(updatedSession.birthDate!));
          if(line2Index != -1 && lines.length>= line2Index){
            String line3 = fixAlphaOnlyField(lines[line2Index+1]);
            MrzName? name = parseNamesTd1(line3);
            String firstName = name.givenNames.join(" ");
            String lastName = name.surname;
            List<String> otherLines = [...lines.where((a) => a != line3).map((a) => normalize(a))];
            var currentVal = aggregator.validation;
            currentVal.nameValid = name.validateNames(otherLines);
            aggregator.validation = currentVal;
            aggregator.addFirstName(firstName);
            aggregator.addLastName(lastName);
          }


            // updatedSession = updatedSession.copyWith(step: 5, details: 'Found names', line3: normalize(line3), firstName: firstName, lastName: lastName, validation: currentVal, logDetails: "Found Name: $firstName  $lastName");
        } else {
          String line1Start = updatedSession.docCode! + updatedSession.countryCode!;

          for (var l in lines) {
            if (l.startsWith(line1Start)) {
              MrzName? name = parseNamesTd3OrTd2(l);
              String firstName = name.givenNames.join(" ");
              String lastName = name.surname;
              List<String> otherLines = [...lines.where((a) => a != l).map((a) => normalize(a))];
              var currentVal = aggregator.validation;
              currentVal.nameValid = name.validateNames(otherLines);
              aggregator.validation = currentVal;
              aggregator.addFirstName(firstName);
              aggregator.addLastName(lastName);


              // var currentVal = updatedSession.validation ?? OcrMrzValidation();
              // currentVal.nameValid = name.validateNames(otherLines);
              // updatedSession = updatedSession.copyWith(step: 5, details: 'Found names', line1: normalize(l), firstName: firstName, lastName: lastName, validation: currentVal, logDetails: "Found Name: $firstName  $lastName");
            }
          }
        }
      }

      // if (updatedSession.step == 6) {
      //   if (updatedSession.type == DocumentStandardType.td1) {
      //   } else {
      //     final optionalAndFinalCheckReg = RegExp(r'^(.*?<+)(\d{0,2})$');
      //     // String datesSex = updatedSession.dateSexStr!;
      //     String expWithCheck = updatedSession.expiryDate! + updatedSession.expCheck!;
      //     for (var l in baseLines) {
      //       l = normalize(l);
      //       if (l.length > 20) {
      //         List<String> parts = l.split(expWithCheck);
      //         if (parts.length > 1) {
      //           String optionalAndFinalGuess = parts[1];
      //           final optionalAndFinalCheckMatch = optionalAndFinalCheckReg.firstMatch(optionalAndFinalGuess);
      //           if (optionalAndFinalCheckMatch != null) {
      //             String optionalStr = optionalAndFinalCheckMatch.group(1)!;
      //             String finalCheckStr = optionalAndFinalCheckMatch.group(2)!;
      //
      //             bool finalCheckValid = (updatedSession.getFinalCheckValue)==_computeMrzCheckDigit(finalCheckStr);
      //             var currentVal = updatedSession.validation!;
      //             currentVal.finalCheckValid = finalCheckValid;
      //             if(finalCheckValid) {
      //               updatedSession = updatedSession.copyWith(step: 7, details: 'Found Final Check', optional: optionalStr, finalCheck: finalCheckStr);
      //             }else{
      //               log("final check not valid ==> ${updatedSession.getFinalCheckValue} ${finalCheckStr}");
      //             }
      //
      //           }
      //         }
      //       }
      //     }
      //   }
      // }

      // log("${updatedSession.step} ${updatedSession.logDetails??''}");
      return aggregator.build();
    } catch (e) {
      if (e is Error) {
        log("$e\n${e.stackTrace}");
      }
      rethrow;
    }
  }

  static String normalize(String line) {
    line = line.replaceAll(" ", '');
    line = line.replaceAll("«", "<<");
    final b = StringBuffer();
    for (final rune in line.toUpperCase().runes) {
      var ch = String.fromCharCode(rune);
      ch = _normMap[ch] ?? ch;
      final cu = ch.codeUnitAt(0);
      final isAZ = cu >= 65 && cu <= 90;
      final is09 = cu >= 48 && cu <= 57;
      if (isAZ || is09 || cu == 60) {
        b.writeCharCode(cu);
      }
    }
    return b.toString();
  }

  static String normalizeWithLength(String line, {int len = 44}) {
    line = line.replaceAll(" ", '');
    final b = StringBuffer();
    for (final rune in line.toUpperCase().runes) {
      var ch = String.fromCharCode(rune);
      ch = _normMap[ch] ?? ch;
      final cu = ch.codeUnitAt(0);
      final isAZ = cu >= 65 && cu <= 90;
      final is09 = cu >= 48 && cu <= 57;
      if (isAZ || is09 || cu == 60) {
        b.writeCharCode(cu);
        if (b.length == len) break;
      }
    }
    while (b.length < len) b.write('<');
    return b.toString();
  }
}

const _normMap = {
  '«': '<',
  '|': '<',
  '\\': '<',
  '/': '<',
  '“': '<',
  '”': '<',
  '’': '<',
  '‘': '<',
  ' ': '<',
  '—': '-', // rarely present; we strip to '-' then filtered out
  '–': '-',
};

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
    return DateTime.utc(fullYear, month, day);
  } catch (_) {
    return null;
  }
}

String fixAlphaOnlyField(String value) {
  final map = {'0': 'O', '1': 'I', '5': 'S', '8': 'B', '6': 'G'};
  return value.toUpperCase().split('').map((c) => map[c] ?? c).join();
}
