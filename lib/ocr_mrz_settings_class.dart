class OcrMrzSetting {
  bool validateDocNumberValid;
  bool validateBirthDateValid;
  bool validateExpiryDateValid;
  bool validatePersonalNumberValid;
  bool validateFinalCheckValid;
  bool validateNames;
  bool validateLinesLength;
  bool validateCountry;
  bool validateNationality;

  OcrMrzSetting({
     this.validateDocNumberValid = true,
     this.validateBirthDateValid = true,
     this.validateExpiryDateValid = true,
     this.validatePersonalNumberValid = true,
     this.validateFinalCheckValid = true,
     this.validateNames = true,
     this.validateLinesLength = true,
     this.validateCountry = true,
     this.validateNationality = true,
  });

  factory OcrMrzSetting.fromJson(Map<String, dynamic> json) => OcrMrzSetting(
    validateDocNumberValid: json["validateDocNumberValid"],
    validateBirthDateValid: json["validateBirthDateValid"],
    validateExpiryDateValid: json["validateExpiryDateValid"],
    validatePersonalNumberValid: json["validatePersonalNumberValid"],
    validateFinalCheckValid: json["validateFinalCheckValid"],
    validateNames: json["validateNames"],
    validateLinesLength: json["validateLinesLength"],
    validateCountry: json["validateCountry"],
    validateNationality: json["validateNationality"],
  );

  Map<String, dynamic> toJson() => {
    "validateDocNumberValid": validateDocNumberValid,
    "validateBirthDateValid": validateBirthDateValid,
    "validateExpiryDateValid": validateExpiryDateValid,
    "validatePersonalNumberValid": validatePersonalNumberValid,
    "validateFinalCheckValid": validateFinalCheckValid,
    "validateNames": validateNames,
    "validateLinesLength": validateLinesLength,
    "validateCountry": validateCountry,
    "validateNationality": validateNationality,
  };
}
