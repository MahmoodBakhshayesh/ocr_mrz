import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constant_data_class.dart';
import 'gender_class.dart';
import 'mrz_result_class_fix.dart' hide DocumentType;

class DocumentDetail {
  final String? documentNumber;
  final String? fullName;
  final DocumentCode? documentCode;
  final DateTime? documentExpiryDate;
  final DocumentCountry? documentIssueCountry;
  final DateTime? documentIssueDate;
  final DateTime? birthDate;
  final DocumentCountry? nationality;
  final DateTime? applicationDate;
  final String? mrz;
  final String? ocrText;
  final String? shortType;
  final String? docCode;
  final String? sex;
  final bool verifiedDocNum;
  final bool verifiedDocCode;
  final List<String> suggestionCodes;

  const DocumentDetail({
    this.documentNumber,
    this.shortType,
    this.suggestionCodes = const[],
    this.fullName,
    this.documentCode,
    this.documentExpiryDate,
    this.birthDate,
    this.documentIssueCountry,
    this.documentIssueDate,
    this.nationality,
    this.applicationDate,
    this.mrz,
    this.ocrText,
    this.docCode,
    this.sex,
    this.verifiedDocNum = false,
    this.verifiedDocCode = false,
  });

  static const _unset = Object();

  DocumentDetail copyWith({
    Object? documentNumber = _unset,
    Object? fullName = _unset,
    Object? documentCode = _unset,
    Object? documentExpiryDate = _unset,
    Object? birthDate = _unset,
    Object? documentIssueCountry = _unset,
    Object? documentIssueDate = _unset,
    Object? nationality = _unset,
    Object? documentMRZType = _unset,
    Object? documentSeries = _unset,
    Object? documentFeature = _unset,
    Object? applicationDate = _unset,
    Object? mrz = _unset,
    Object? ocrText = _unset,
    Object? shortType = _unset,
    Object? docCode = _unset,
    Object? sex = _unset,
    Object? verifiedDocNum = _unset,
    Object? verifiedDocCode = _unset,
    Object? suggestionCodes = _unset,
  }) {
    return DocumentDetail(
      documentNumber: identical(documentNumber, _unset) ? this.documentNumber : documentNumber as String?,
      fullName: identical(fullName, _unset) ? this.fullName : fullName as String?,
      documentCode: identical(documentCode, _unset) ? this.documentCode : documentCode as DocumentCode?,
      documentExpiryDate: identical(documentExpiryDate, _unset) ? this.documentExpiryDate : documentExpiryDate as DateTime?,
      birthDate: identical(birthDate, _unset) ? this.birthDate : birthDate as DateTime?,
      documentIssueCountry: identical(documentIssueCountry, _unset) ? this.documentIssueCountry : documentIssueCountry as DocumentCountry?,
      documentIssueDate: identical(documentIssueDate, _unset) ? this.documentIssueDate : documentIssueDate as DateTime?,
      nationality: identical(nationality, _unset) ? this.nationality : nationality as DocumentCountry?,
      applicationDate: identical(applicationDate, _unset) ? this.applicationDate : applicationDate as DateTime?,
      mrz: identical(mrz, _unset) ? this.mrz : mrz as String?,
      ocrText: identical(ocrText, _unset) ? this.ocrText : ocrText as String?,
      shortType: identical(shortType, _unset) ? this.shortType : shortType as String?,
      docCode: identical(docCode, _unset) ? this.docCode : docCode as String?,
      suggestionCodes: identical(suggestionCodes, _unset) ? this.suggestionCodes : ((suggestionCodes??[]) as List).map((a)=>a.toString()).toList() as List<String>,
      sex: identical(sex, _unset) ? this.sex : sex as String?,
      verifiedDocNum: identical(verifiedDocNum, _unset) ? this.verifiedDocNum : verifiedDocNum as bool,
      verifiedDocCode: identical(verifiedDocCode, _unset) ? this.verifiedDocCode : verifiedDocCode as bool,
    );
  }

  factory DocumentDetail.fromJson(Map<String, dynamic> json) {
    return DocumentDetail(
      documentNumber: json['documentNumber']?.toString(),
      fullName: json['fullName']?.toString(),
      documentCode: json['documentCode'] is Map<String, dynamic> ? DocumentCode.fromJson(json['documentCode']) : null,
      documentExpiryDate: parseDate(json['documentExpiryDate']),
      birthDate: parseDate(json['birthDate']),
      documentIssueCountry: json['documentIssueCountry'] is Map<String, dynamic> ? DocumentCountry.fromJson(json['documentIssueCountry']) : null,
      documentIssueDate: parseDate(json['documentIssueDate']),
      nationality: json['nationality'] is Map<String, dynamic> ? DocumentCountry.fromJson(json['nationality']) : null,
      mrz: json["mrz"],
      ocrText: json["ocrText"],
      shortType: json["shortType"],
      docCode: json["docCode"],
      sex: json["sex"],
      verifiedDocNum: json["verifiedDocNum"],
    );
  }
  factory DocumentDetail.fromMrzResult(OcrMrzResult res) {
    return DocumentDetail(
      documentNumber: res.documentNumber,
      fullName: "${res.firstName} ${res.lastName}",
      documentCode: null,
      documentExpiryDate: res.expiryDate,
      birthDate: res.birthDate,
      documentIssueCountry: ConstData.offline().getLocationWithCode(res.countryCode),
      documentIssueDate: null,
      nationality: ConstData.offline().getLocationWithCode(res.nationality),
      mrz: null,
      ocrText: null,
      shortType: res.documentCode.characters.first,
      docCode:res.documentCode,
      sex: res.sex,
      verifiedDocNum: false,
    );
  }


  factory DocumentDetail.visa() {
    return DocumentDetail(shortType: "V");
  }
  factory DocumentDetail.passport() {
    return DocumentDetail(shortType: "P",birthDate: DateTime(2000,1,1));
  }
  factory DocumentDetail.resident() {
    return DocumentDetail(shortType: "I");
  }

  Map<String, dynamic> toJson() => {
    'documentNumber': documentNumber,
    'fullName': fullName,
    'documentCode': documentCode?.code,
    'documentExpiryDate': formatDate(documentExpiryDate),
    'birthDate': formatDate(birthDate),
    'documentIssueCountry': documentIssueCountry?.code3,
    'documentIssueDate': formatDate(documentIssueDate),
    'nationality': nationality?.code3,
    'mrz': mrz,
    'ocrText': ocrText,
    'shortType': shortType,
    'docCode': docCode,
    'sex': sex,
    'verifiedDocNum': verifiedDocNum,
  };

  bool get isExpired => documentExpiryDate != null && documentExpiryDate!.isBefore(DateTime.now().subtract(Duration(days: 1)));

  bool get isExpiryFake => (documentExpiryDate?.difference(DateTime(1, 1, 1)).inDays ?? 100) < 1;

  bool get isExpiring => !isExpired && documentExpiryDate != null && documentExpiryDate!.difference(DateTime.now()).inDays.abs() < 180;

  int? get expiryRemain => documentExpiryDate == null ? null : -(DateTime.now().difference(documentExpiryDate!).inDays / 30).floor();

  bool get isEmpty => documentCode == null;

  bool get isScanned => mrz != null;

  bool get isVisa => shortType == "V";

  bool get isPassport => shortType == "P";

  Gender? get gender => Gender.values.firstWhereOrNull((a)=>a.value == sex);


  Widget get getMrzWidget => (mrz ?? "").isEmpty || true
      ? SizedBox()
      : Container(
    padding: EdgeInsets.all(4),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.08), borderRadius: BorderRadiusGeometry.circular(4)),
    child: FittedBox(
      child: Text(censorText(mrz ?? '', (fullName ?? "").split(" ")), style: TextStyle(fontFamily: "Ocr")),
    ),
  );

  bool isSameAs(OcrMrzResult res,{List<String?> notThis= const[]}) {
    // log("${res.documentCode} -- ${documentCode?.code}");
    // log("${res.documentNumber} -- ${documentNumber}");

    return (documentExpiryDate.yyyyMMdd == res.expiryDate.yyyyMMdd) && (docCode == res.documentCode) && (res.documentNumber == documentNumber) && (documentNumber ?? '').isNotEmpty;
  }

  DocumentType? getMatch([ConstData? data]) {
    data ??= ConstData.offline();
    String? dc = docCode;
    DocumentType? match;
    if (dc != null && dc.length > 1) {
      match = data!.documentType.lastOrNullWhere((a) => a.type == data!.documentCode.firstWhere((a) => a.type == shortType || a.code == documentCode?.code).type);
    }
    match ??=  data!.documentType.lastOrNullWhere((a) => a.type == shortType);
    // log("match of $dc  - ${shortType}=> ${match?.title}");
    return match;
  }

  DocumentDetailType? getTypeDetailsMatch([ConstData? data]) {
    String? dc = docCode;
    DocumentDetailType? match;
    if (docCode == null) {
      return null;
    }
    if (dc != null && dc.length > 1) {
      match =  data!.documentDetailType.lastOrNullWhere(
            (a) => a.type == docCode?.characters.first && (a.subType == "*" || a.subType == docCode?.characters.last) && (a.country == "*" || a.country == documentIssueCountry?.code3),
      );
    }
    return match;
  }

  int get birthDayIndex => birthDate==null?-1 : [
    DateFormat("MM-dd").format(DateTime.now()),
    DateFormat("MM-dd").format(DateTime.now().add(Duration(days: 1))),
    DateFormat("MM-dd").format(DateTime.now().subtract(Duration(days: 1))),
  ].indexOf(DateFormat("MM-dd").format(birthDate!));

  bool get isBirthday => birthDayIndex != -1;
  String get birthdayLabel => !isBirthday?"":["(Today)","(Tomorrow)","(Yesterday)"][birthDayIndex];



}

extension on DateTime? {
  get yyyyMMdd =>  this == null ? "" : DateFormat("yyyy-MM-dd").format(this!);
}

extension FirstWhereExt<T> on Iterable<T> {
  /// The first element satisfying [test], or `null` if there are none.
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

extension IterableLastOrNullWhere<E> on Iterable<E> {
  /// Returns the last element matching the given [predicate], or `null` if no
  /// such element was found.
  E? lastOrNullWhere(bool Function(E element) predicate) {
    E? match;
    for (final e in this) {
      if (predicate(e)) {
        match = e;
      }
    }
    return match;
  }
}


String censorText(String input, List<String> forbidden) {
  for (final word in forbidden) {
    input = input.replaceAll(word, '*' * word.length);
  }
  return input;
}

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (_) {}
  }
  return null;
}

String? formatDate(DateTime? date) {
  if (date == null) return null;
  return "${date.year.toString().padLeft(4, '0')}-"
      "${date.month.toString().padLeft(2, '0')}-"
      "${date.day.toString().padLeft(2, '0')}";


}

