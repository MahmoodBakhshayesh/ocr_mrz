import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:ocr_mrz/enums.dart';
import 'package:ocr_mrz/session_status_class.dart';

import 'mrz_result_class_fix.dart';

/// ---------- Majority Vote Utilities ----------

typedef Normalizer<T> = T Function(T v);

class MajorityCounter<T> {
  final Map<T, int> _counts = <T, int>{};
  final Normalizer<T> normalize;

  MajorityCounter({required this.normalize});

  void add(T value, {int weight = 1}) {
    final key = normalize(value);
    _counts.update(key, (c) => c + weight, ifAbsent: () => weight);
  }

  bool get isEmpty => _counts.isEmpty;

  /// Returns (value, count). Deterministic tie-break by lexicographic toString.
  (T, int)? top() {
    if (_counts.isEmpty) return null;
    final entries =
        _counts.entries.toList()..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.toString().compareTo(b.key.toString());
        });
    final e = entries.first;
    return (e.key, e.value);
  }

  Map<T, int> snapshot() => Map.unmodifiable(_counts);
}

String _normCode(String v) => v.trim().toUpperCase();

String _normName(String v) => v.trim(); // keep case; MRZ names are uppercase anyway

String _normSex(String v) => v.trim().toUpperCase(); // 'M','F','X','<'

String _normString(String v) => v.trim();

String _dateKey(DateTime d) => d.toIso8601String().split('T').first; // yyyy-MM-dd

DateTime _parseDateKey(String k) {
  // k is in yyyy-MM-dd format
  return DateTime.tryParse("$k 00:00:00Z") ?? DateTime.now().toUtc();
}

/// ---------- Aggregated Field Stats ----------

class FieldStat<T> {
  final T? consensus;
  final int consensusCount;
  final Map<T, int> histogram;

  FieldStat({required this.consensus, required this.consensusCount, required this.histogram});
}

class OcrMrzConsensus {
  // Final chosen values (null means no valid votes)
  final String? countryCode;
  final String? docCode;
  final String? issuingState;
  final String? documentNumber;
  final String? lastName;
  final String? firstName;
  final String? nationality;
  final DateTime? birthDate;
  final DateTime? expiryDate;
  final String? sex;
  final String? personalNumber;
  final String? optionalData;
  final String? line1;
  final String? line2;
  final String? line3;
  final String? docType;
  final List<String> mrzLines;

  // Per-field stats
  final FieldStat<String> countryCodeStat;
  final FieldStat<String> docCodeStat;
  final FieldStat<String> issuingStateStat;
  final FieldStat<String> documentNumberStat;
  final FieldStat<String> lastNameStat;
  final FieldStat<String> firstNameStat;
  final FieldStat<String> nationalityStat;
  final FieldStat<String> sexStat;
  final FieldStat<String> personalNumberStat;
  final FieldStat<String> optionalDataStat;
  final FieldStat<String> line1Stat;
  final FieldStat<String> line2Stat;
  final FieldStat<String> line3Stat;
  final FieldStat<String> docTypeStat;
  final FieldStat<String> birthDateStat; // key is yyyy-MM-dd
  final FieldStat<String> expiryDateStat; // key is yyyy-MM-dd

  OcrMrzConsensus({
    required this.countryCode,
    required this.docCode,
    required this.docCodeStat,
    required this.issuingState,
    required this.documentNumber,
    required this.lastName,
    required this.firstName,
    required this.nationality,
    required this.birthDate,
    required this.expiryDate,
    required this.sex,
    required this.personalNumber,
    required this.optionalData,
    required this.line1,
    required this.line2,
    required this.line3,
    required this.countryCodeStat,
    required this.issuingStateStat,
    required this.documentNumberStat,
    required this.lastNameStat,
    required this.firstNameStat,
    required this.nationalityStat,
    required this.sexStat,
    required this.personalNumberStat,
    required this.optionalDataStat,
    required this.line1Stat,
    required this.line2Stat,
    required this.line3Stat,
    required this.birthDateStat,
    required this.expiryDateStat,
    required this.docTypeStat,
    required this.docType,
    this.mrzLines = const [],
  });

  OcrMrzValidation get valid => toResult().valid;

  OcrMrzResult toResult({MrzFormat format = MrzFormat.TD3, MrzFormat mrzFormat = MrzFormat.TD3}) {
    return OcrMrzResult(
      line1: mrzLines.isEmpty ? "" : mrzLines[0],
      line2: mrzLines.isEmpty ? "" : mrzLines[1],
      line3: mrzLines.length < 3 ? null : mrzLines[2],
      documentType: docType ?? '',
      mrzFormat: mrzFormat,
      countryCode: countryCode ?? '',
      documentCode: docCode ?? '',
      issuingState: issuingState ?? (countryCode ?? ''),
      lastName: lastName ?? '',
      firstName: firstName ?? '',
      documentNumber: documentNumber ?? '',
      nationality: nationality ?? '',
      birthDate: birthDate,
      expiryDate: expiryDate,
      sex: sex ?? '',
      personalNumber: personalNumber ?? '',
      optionalData: optionalData ?? '',
      valid: OcrMrzValidation(
        docNumberValid: documentNumber != null,
        docCodeValid: docCode != null,
        countryValid: countryCode != null,
        birthDateValid: birthDate != null,
        nameValid: firstName != null,
        personalNumberValid: personalNumber != null,
        linesLengthValid: line1 != null,
        expiryDateValid: expiryDate != null,
        nationalityValid: nationality != null,
        finalCheckValid: docType != "P" || (documentNumber != null && countryCode != null && birthDate != null && firstName != null && personalNumber != null && line1 != null && expiryDate != null && nationality != null),
      ),
      // fresh; you could pass something smarter here
      checkDigits: CheckDigits(document: false, birth: false, expiry: false, optional: false),
      ocrData: OcrData(text: '', lines: []),
      // assuming you have an empty() factory/placeholder
      format: format,
    );
  }

  @override
  String toString() {
    final buf = StringBuffer();

    void logField(String name, FieldStat stat) {
      final ok = stat.consensus != null && stat.consensus.toString().isNotEmpty;
      final emoji = ok ? '✅' : '❌';
      buf.write('$name: ${stat.consensus ?? "-"}  ($emoji ${stat.consensusCount}) \t');
    }

    logField("CountryCode", countryCodeStat);
    logField("IssuingState", issuingStateStat);
    logField("DocumentNumber", documentNumberStat);
    logField("LastName", lastNameStat);
    logField("FirstName", firstNameStat);
    logField("Nationality", nationalityStat);
    logField("BirthDate", birthDateStat);
    logField("ExpiryDate", expiryDateStat);
    logField("Sex", sexStat);
    logField("PersonalNumber", personalNumberStat);
    logField("OptionalData", optionalDataStat);
    logField("Line1", line1Stat);
    logField("Line2", line2Stat);
    logField("Line3", line3Stat);
    logField("docType", docTypeStat);

    return buf.toString();
  }

  Map<String, dynamic> toJson({bool includeHistograms = false}) {
    Map<String, dynamic> fieldToJson(FieldStat stat) {
      return {"value": stat.consensus, "count": stat.consensusCount, if (includeHistograms) "histogram": stat.histogram};
    }

    return {
      "countryCode": fieldToJson(countryCodeStat),
      "docCode": fieldToJson(docCodeStat),
      "issuingState": fieldToJson(issuingStateStat),
      "documentNumber": fieldToJson(documentNumberStat),
      "lastName": fieldToJson(lastNameStat),
      "firstName": fieldToJson(firstNameStat),
      "nationality": fieldToJson(nationalityStat),
      "birthDate": fieldToJson(birthDateStat),
      "expiryDate": fieldToJson(expiryDateStat),
      "sex": fieldToJson(sexStat),
      "personalNumber": fieldToJson(personalNumberStat),
      "optionalData": fieldToJson(optionalDataStat),
      "line1": fieldToJson(line1Stat),
      "line2": fieldToJson(line2Stat),
      "line3": fieldToJson(line3Stat),
      "docType": fieldToJson(docTypeStat),
    };
  }
}

/// ---------- Aggregator ----------

class OcrMrzAggregator {
  // Counters (normalize for robust grouping)
  OcrMrzValidation validation = OcrMrzValidation();
  final _country = MajorityCounter<String>(normalize: _normCode);
  final _docCode = MajorityCounter<String>(normalize: _normCode);
  final _issuing = MajorityCounter<String>(normalize: _normCode);
  final _docNo = MajorityCounter<String>(normalize: _normString);
  final _lname = MajorityCounter<String>(normalize: _normName);
  final _fname = MajorityCounter<String>(normalize: _normName);
  final _nat = MajorityCounter<String>(normalize: _normCode);
  final _sex = MajorityCounter<String>(normalize: _normSex);
  final _pnum = MajorityCounter<String>(normalize: _normString);
  final _opt = MajorityCounter<String>(normalize: _normString);
  final _line1 = MajorityCounter<String>(normalize: _normString);
  final _line2 = MajorityCounter<String>(normalize: _normString);
  final _line3 = MajorityCounter<String>(normalize: _normString);

  // Dates are counted as yyyy-MM-dd keys, then converted back
  final _birth = MajorityCounter<String>(normalize: _normString);
  final _expiry = MajorityCounter<String>(normalize: _normString);
  final _docType = MajorityCounter<String>(normalize: _normString);
  final _birthCheck = MajorityCounter<String>(normalize: _normString);
  final _expCheck = MajorityCounter<String>(normalize: _normString);
  final _numCheck = MajorityCounter<String>(normalize: _normString);

  int _framesSeen = 0;
  int _step = 0;
  DocumentStandardType? _type;

  /// Add a frame. Only validated values are counted.
  void add(OcrMrzResult r) {
    _framesSeen++;

    final v = r.valid;
    final cd = r.checkDigits;
    _docType.add(r.documentType);

    if (v.docCodeValid && r.documentCode.isNotEmpty) {
      _docCode.add(r.documentCode);
    }

    // Country / issuing state:
    if (v.countryValid && r.countryCode.trim().isNotEmpty) _country.add(r.countryCode);
    // Issuing state has no dedicated flag; fall back to countryValid if passport/TD3, or accept when not empty
    if ((r.isPassport && v.countryValid) || r.issuingState.trim().isNotEmpty) {
      _issuing.add(r.issuingState.isNotEmpty ? r.issuingState : r.countryCode);
    }

    // Document number:
    // Gate by both OcrMrzValidation.docNumberValid and checkDigits.document when present.
    // if (v.docNumberValid && (cd.document == true) && r.documentNumber.trim().isNotEmpty) {
    //   _docNo.add(r.documentNumber);
    // }
    // Document number:

    // Gate by both OcrMrzValidation.docNumberValid and checkDigits.document when present.
    if (r.documentNumber.isNotEmpty) {
      _docNo.add(r.documentNumber);
    }

    // Names (gate by nameValid)
    if (v.nameValid) {
      if (r.lastName.trim().isNotEmpty) _lname.add(r.lastName);
      if (r.firstName.trim().isNotEmpty) _fname.add(r.firstName);
    }

    // Nationality
    if (v.nationalityValid && r.nationality.trim().isNotEmpty) _nat.add(r.nationality);

    // Dates
    // if (v.birthDateValid && (cd.birth == true) && r.birthDate != null) {
    //   _birth.add(_dateKey(r.birthDate!));
    // }
    // if (v.expiryDateValid && (cd.expiry == true) && r.expiryDate != null) {
    //   _expiry.add(_dateKey(r.expiryDate!));
    // }

    if (r.expiryDate != null) {
      _expiry.add(_dateKey(r.expiryDate!));
    }

    if (r.birthDate != null) {
      _birth.add(_dateKey(r.birthDate!));
    }

    // Sex (no explicit flag; count when char looks MRZ-like and lines lengths are valid)
    // if (v.linesLengthValid && r.sex.trim().isNotEmpty) {
    //   final s = _normSex(r.sex);
    //   if (s == 'M' || s == 'F' || s == 'X' || s == '<') {
    //     _sex.add(s);
    //   }
    // }

    // Sex (no explicit flag; count when char looks MRZ-like and lines lengths are valid)
    if (r.sex.trim().isNotEmpty) {
      final s = _normSex(r.sex);
      if (s == 'M' || s == 'F' || s == 'X' || s == '<') {
        _sex.add(s);
      }
    }

    // Personal / optional numbers (gate by personalNumberValid and checkDigits.optional)
    if (v.personalNumberValid && (cd.optional == true)) {
      if (r.personalNumber.trim().isNotEmpty) _pnum.add(r.personalNumber);
      if (r.optionalData.trim().isNotEmpty) _opt.add(r.optionalData);
    }

    // Raw lines (gate by linesLengthValid to avoid partials)
    if (v.linesLengthValid) {
      if (r.line1.trim().isNotEmpty) _line1.add(r.line1);
      if (r.line2.trim().isNotEmpty) _line2.add(r.line2);
      if ((r.line3 ?? '').trim().isNotEmpty) _line3.add(r.line3!.trim());
    }
  }

  void addBirthDate(String birth) {
    _birth.add(birth);
  }

  void addExpiryDate(String exp) {
    _expiry.add(exp);
  }

  void addCountry(String con) {
    _country.add(con);
    _issuing.add(con);
  }

  void addNationality(String nat) {
    _nat.add(nat);
  }

  void addSex(String sex) {
    _sex.add(sex);
  }

  void addDocCode(String code) {
    _docCode.add(code);
  }

  void addDocNum(String num) {
    _docNo.add(num);
  }

  void addFirstName(String name) {
    _fname.add(name);
  }

  void addLastName(String name) {
    _lname.add(name);
  }

  void addBirthCheck(String check) {
    log("Setting birth check $check");
    _birthCheck.add(check);
  }

  void addExpCheck(String check) {
    log("Setting exp check $check");
    _expCheck.add(check);
  }

  void addNumCheck(String check) {
    _numCheck.add(check);
  }

  void setStep(int step) {
    _step = step;
  }

  void setType(DocumentStandardType? type) {
    _type = type;
  }

  /// Build consensus values and expose stats/histograms.
  OcrMrzConsensus build() {
    String? _pickStr(MajorityCounter<String> c) => c.top()?.$1;
    int _pickCnt(MajorityCounter<String> c) => c.top()?.$2 ?? 0;

    final country = _pickStr(_country);
    final docCode = _pickStr(_docCode);
    final issuing = _pickStr(_issuing);
    final docNo = _pickStr(_docNo);
    final lname = _pickStr(_lname);
    final fname = _pickStr(_fname);
    final nat = _pickStr(_nat);
    final sex = _pickStr(_sex);
    final pnum = _pickStr(_pnum);
    final opt = _pickStr(_opt);
    final l1 = _pickStr(_line1);
    final l2 = _pickStr(_line2);
    final l3 = _pickStr(_line3);

    final birthKey = _pickStr(_birth);
    final expiryKey = _pickStr(_expiry);
    final docType = _pickStr(_docType);

    return OcrMrzConsensus(
      countryCode: country,
      issuingState: issuing ?? country,
      docCode: docCode ?? docCode,
      // fallback
      documentNumber: docNo,
      lastName: lname,
      firstName: fname,
      nationality: nat,
      birthDate: birthKey != null ? _parseDateKey(birthKey) : null,
      expiryDate: expiryKey != null ? _parseDateKey(expiryKey) : null,
      sex: sex,
      personalNumber: pnum,
      optionalData: opt,
      line1: l1,
      line2: l2,
      line3: l3,
      docType: docType,
      countryCodeStat: FieldStat(consensus: country, consensusCount: _pickCnt(_country), histogram: _country.snapshot()),
      docCodeStat: FieldStat(consensus: docCode, consensusCount: _pickCnt(_docCode), histogram: _docCode.snapshot()),
      issuingStateStat: FieldStat(consensus: issuing, consensusCount: _pickCnt(_issuing), histogram: _issuing.snapshot()),
      documentNumberStat: FieldStat(consensus: docNo, consensusCount: _pickCnt(_docNo), histogram: _docNo.snapshot()),
      lastNameStat: FieldStat(consensus: lname, consensusCount: _pickCnt(_lname), histogram: _lname.snapshot()),
      firstNameStat: FieldStat(consensus: fname, consensusCount: _pickCnt(_fname), histogram: _fname.snapshot()),
      nationalityStat: FieldStat(consensus: nat, consensusCount: _pickCnt(_nat), histogram: _nat.snapshot()),
      sexStat: FieldStat(consensus: sex, consensusCount: _pickCnt(_sex), histogram: _sex.snapshot()),
      personalNumberStat: FieldStat(consensus: pnum, consensusCount: _pickCnt(_pnum), histogram: _pnum.snapshot()),
      optionalDataStat: FieldStat(consensus: opt, consensusCount: _pickCnt(_opt), histogram: _opt.snapshot()),
      line1Stat: FieldStat(consensus: l1, consensusCount: _pickCnt(_line1), histogram: _line1.snapshot()),
      line2Stat: FieldStat(consensus: l2, consensusCount: _pickCnt(_line2), histogram: _line2.snapshot()),
      line3Stat: FieldStat(consensus: l3, consensusCount: _pickCnt(_line3), histogram: _line3.snapshot()),
      birthDateStat: FieldStat(consensus: birthKey, consensusCount: _pickCnt(_birth), histogram: _birth.snapshot()),
      expiryDateStat: FieldStat(consensus: expiryKey, consensusCount: _pickCnt(_expiry), histogram: _expiry.snapshot()),
      docTypeStat: FieldStat(consensus: docType, consensusCount: _pickCnt(_docType), histogram: _docType.snapshot()),

      mrzLines: buildMrz(),
    );
  }

  SessionStatus buildStatus() {
    String? _pickStr(MajorityCounter<String> c) => c.top()?.$1;
    int _pickCnt(MajorityCounter<String> c) => c.top()?.$2 ?? 0;

    final country = _pickStr(_country);
    final docCode = _pickStr(_docCode);
    final issuing = _pickStr(_issuing);
    final docNo = _pickStr(_docNo);
    final lname = _pickStr(_lname);
    final fname = _pickStr(_fname);
    final nat = _pickStr(_nat);
    final sex = _pickStr(_sex);
    final pnum = _pickStr(_pnum);
    final opt = _pickStr(_opt);
    final l1 = _pickStr(_line1);
    final l2 = _pickStr(_line2);
    final l3 = _pickStr(_line3);

    final birthKey = _pickStr(_birth);
    final birthCheckKey = _pickStr(_birthCheck);
    final expiryKey = _pickStr(_expiry);
    final expiryCheckKey = _pickStr(_expCheck);
    final docType = _pickStr(_docType);
    return SessionStatus(
      step: _step,
      type: _type,
      birthDate: birthKey,
      expiryDate: expiryKey,
      firstName: fname,
      lastName: lname,
      nationality: nat,
      docCode: docCode,
      issuing: issuing,
      sex: sex,
      countryCode: country,
      dateSexStr: validation.expiryDateValid ? "$birthKey$birthCheckKey$sex$expiryKey$expiryCheckKey" : null,
    );

    // return OcrMrzConsensus(
    //   countryCode: country,
    //   issuingState: issuing ?? country,
    //   docCode: docCode ?? docCode,
    //   // fallback
    //   documentNumber: docNo,
    //   lastName: lname,
    //   firstName: fname,
    //   nationality: nat,
    //   birthDate: birthKey != null ? _parseDateKey(birthKey) : null,
    //   expiryDate: expiryKey != null ? _parseDateKey(expiryKey) : null,
    //   sex: sex,
    //   personalNumber: pnum,
    //   optionalData: opt,
    //   line1: l1,
    //   line2: l2,
    //   line3: l3,
    //   docType: docType,
    //   countryCodeStat: FieldStat(consensus: country, consensusCount: _pickCnt(_country), histogram: _country.snapshot()),
    //   docCodeStat: FieldStat(consensus: docCode, consensusCount: _pickCnt(_docCode), histogram: _docCode.snapshot()),
    //   issuingStateStat: FieldStat(consensus: issuing, consensusCount: _pickCnt(_issuing), histogram: _issuing.snapshot()),
    //   documentNumberStat: FieldStat(consensus: docNo, consensusCount: _pickCnt(_docNo), histogram: _docNo.snapshot()),
    //   lastNameStat: FieldStat(consensus: lname, consensusCount: _pickCnt(_lname), histogram: _lname.snapshot()),
    //   firstNameStat: FieldStat(consensus: fname, consensusCount: _pickCnt(_fname), histogram: _fname.snapshot()),
    //   nationalityStat: FieldStat(consensus: nat, consensusCount: _pickCnt(_nat), histogram: _nat.snapshot()),
    //   sexStat: FieldStat(consensus: sex, consensusCount: _pickCnt(_sex), histogram: _sex.snapshot()),
    //   personalNumberStat: FieldStat(consensus: pnum, consensusCount: _pickCnt(_pnum), histogram: _pnum.snapshot()),
    //   optionalDataStat: FieldStat(consensus: opt, consensusCount: _pickCnt(_opt), histogram: _opt.snapshot()),
    //   line1Stat: FieldStat(consensus: l1, consensusCount: _pickCnt(_line1), histogram: _line1.snapshot()),
    //   line2Stat: FieldStat(consensus: l2, consensusCount: _pickCnt(_line2), histogram: _line2.snapshot()),
    //   line3Stat: FieldStat(consensus: l3, consensusCount: _pickCnt(_line3), histogram: _line3.snapshot()),
    //   birthDateStat: FieldStat(consensus: birthKey, consensusCount: _pickCnt(_birth), histogram: _birth.snapshot()),
    //   expiryDateStat: FieldStat(consensus: expiryKey, consensusCount: _pickCnt(_expiry), histogram: _expiry.snapshot()),
    //   docTypeStat: FieldStat(consensus: docType, consensusCount: _pickCnt(_docType), histogram: _docType.snapshot()),
    // );
  }

  List<String> buildMrz({bool hideName = false}) {
    String? _pickStr(MajorityCounter<String> c) => (c.top()?.$1) ?? '';
    int _pickCnt(MajorityCounter<String> c) => c.top()?.$2 ?? 0;
    final List<String> lines = [];
    var firstName = _pickStr(_fname)?.replaceAll(" ", "<")??'';
    var lastName = _pickStr(_lname)?.replaceAll(" ", "<")??'';
    if(hideName){
      firstName = mask(firstName);
      lastName = mask(lastName);
    }

    if (_type == DocumentStandardType.td1) {
      String line1 = "${_pickStr(_docCode)}${_pickStr(_issuing)}${_pickStr(_docNo)}${_pickStr(_numCheck)}".padRight(30, "<");
      String line2 = "${_pickStr(_birth)}${_pickStr(_birthCheck)}${_pickStr(_sex)}${_pickStr(_expiry)}${_pickStr(_expCheck)}${_pickStr(_nat)}".padRight(30, "<");
      String line3 = "${lastName}<<${firstName}".padRight(30, "<");
      lines.addAll([line1, line2, line3]);
    } else if (_type == DocumentStandardType.td2 || _type == DocumentStandardType.td3) {
      String line1 = "${_pickStr(_docCode)}${_pickStr(_issuing)}${lastName}<<${firstName}".padRight(44, "<");
      String line2 = "${_pickStr(_docNo)}${_pickStr(_numCheck)}${_pickStr(_nat)}${_pickStr(_birth)}${_pickStr(_birthCheck)}${_pickStr(_sex)}${_pickStr(_expiry)}${_pickStr(_expCheck)}".padRight(44, "<");
      lines.addAll([line1, line2]);
    }
    return lines;
  }

  String mask(String input) {
    return '*' * input.length;
  }

  void reset() {
    _country._counts.clear();
    _docCode._counts.clear();
    _issuing._counts.clear();
    _docNo._counts.clear();
    _lname._counts.clear();
    _fname._counts.clear();
    _nat._counts.clear();
    _sex._counts.clear();
    _pnum._counts.clear();
    _opt._counts.clear();
    _line1._counts.clear();
    _line2._counts.clear();
    _line3._counts.clear();
    _birth._counts.clear();
    _expiry._counts.clear();
    _docType._counts.clear();
    _birthCheck._counts.clear();
    _expCheck._counts.clear();
    _numCheck._counts.clear();
    _framesSeen = 0;
    _step = 0;
    _type = null;
  }

  int get framesSeen => _framesSeen;
}
