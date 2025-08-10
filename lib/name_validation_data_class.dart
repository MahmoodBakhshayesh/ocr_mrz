class NameValidationData {
  String lastName;
  String firstName;
  String? middleName;

  NameValidationData({required this.lastName, required this.firstName, this.middleName});

  factory NameValidationData.fromJson(Map<String, dynamic> json) => NameValidationData(lastName: json["lastName"], firstName: json["firstName"], middleName: json["middleName"]);

  Map<String, dynamic> toJson() => {"lastName": lastName, "firstName": firstName, "middleName": middleName};
}
