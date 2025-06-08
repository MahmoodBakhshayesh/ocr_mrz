class OcrMrzResult {
  String documentType;
  String countryCode;
  String lastName;
  String firstName;
  String passportNumber;
  String nationality;
  DateTime? birthDate;
  DateTime? expiryDate;
  List<String> mrzLines;

  OcrMrzResult({
    required this.documentType,
    required this.countryCode,
    required this.lastName,
    required this.firstName,
    required this.passportNumber,
    required this.nationality,
    required this.birthDate,
    required this.expiryDate,
    required this.mrzLines,
  });

  factory OcrMrzResult.fromJson(Map<String, dynamic> json) => OcrMrzResult(
    documentType: json["documentType"],
    countryCode: json["countryCode"],
    lastName: json["lastName"],
    firstName: json["firstName"],
    passportNumber: json["passportNumber"],
    nationality: json["nationality"],
    mrzLines: List<String>.from(json["mrzLines"]),
    birthDate: DateTime.tryParse(json["birthDate"]),
    expiryDate: DateTime.tryParse(json["expiryDate"]),
  );

  Map<String, dynamic> toJson() => {
    "documentType": documentType,
    "countryCode": countryCode,
    "lastName": lastName,
    "firstName": firstName,
    "passportNumber": passportNumber,

    "nationality": nationality,
    "mrzLines": mrzLines,
    "birthDate":birthDate==null?null: "${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}",
    "expiryDate": expiryDate==null?null:"${expiryDate!.year.toString().padLeft(4, '0')}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}",
  };
}