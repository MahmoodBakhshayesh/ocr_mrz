import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';

class OcrMrzResult {
  String line1;
  String line2;
  String documentType;
  String countryCode;
  String lastName;
  String firstName;
  String passportNumber;
  String nationality;
  DateTime? birthDate;
  DateTime? expiryDate;
  String sex;
  String personalNumber;
  bool valid;
  CheckDigits checkDigits;
  OcrData ocrData;

  OcrMrzResult({
    required this.line1,
    required this.line2,
    required this.documentType,
    required this.countryCode,
    required this.lastName,
    required this.firstName,
    required this.passportNumber,
    required this.nationality,
    required this.birthDate,
    required this.expiryDate,
    required this.sex,
    required this.personalNumber,
    required this.valid,
    required this.checkDigits,
    required this.ocrData,
  });

  factory OcrMrzResult.fromJson(Map<String, dynamic> json) => OcrMrzResult(
    line1: json["line1"],
    line2: json["line2"],
    documentType: json["documentType"],
    countryCode: json["countryCode"],
    lastName: json["lastName"],
    firstName: json["firstName"],
    passportNumber: json["passportNumber"],
    nationality: json["nationality"],
    birthDate: DateTime.tryParse(json["birthDate"]),
    expiryDate: DateTime.tryParse(json["expiryDate"]),
    sex: json["sex"],
    personalNumber: json["personalNumber"],
    valid: json["valid"],
    checkDigits: CheckDigits.fromJson(json["checkDigits"]),
    ocrData: OcrData.fromJson(json["ocrData"]),
  );

  List<String> get mrzLines => [line1,line2];

  Map<String, dynamic> toJson() => {
    "line1": line1,
    "line2": line2,
    "documentType": documentType,
    "countryCode": countryCode,
    "lastName": lastName,
    "firstName": firstName,
    "passportNumber": passportNumber,
    "nationality": nationality,
    "birthDate": birthDate?.toIso8601String(),
    "expiryDate": expiryDate?.toIso8601String(),
    "sex": sex,
    "personalNumber": personalNumber,
    "valid": valid,
    "checkDigits": checkDigits.toJson(),
    "ocrData": ocrData.toJson(),
  };
}

class CheckDigits {
  bool passport;
  bool birth;
  bool expiry;
  bool optional;
  bool checkDigitsFinal;

  CheckDigits({
    required this.passport,
    required this.birth,
    required this.expiry,
    required this.optional,
    required this.checkDigitsFinal,
  });

  factory CheckDigits.fromJson(Map<String, dynamic> json) => CheckDigits(
    passport: json["passport"],
    birth: json["birth"],
    expiry: json["expiry"],
    optional: json["optional"],
    checkDigitsFinal: json["final"],
  );

  Map<String, dynamic> toJson() => {
    "passport": passport,
    "birth": birth,
    "expiry": expiry,
    "optional": optional,
    "final": checkDigitsFinal,
  };
}
