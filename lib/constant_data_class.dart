import 'dart:convert';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'const_data_json.dart';

class ConstData {
  final List<DocumentType> documentType;
  final List<DocumentDetailType> documentDetailType;
  final List<DocumentCode> documentCode;
  final List<DocumentAirport> city;
  final List<DocumentCountry> country;
  final List<DocumentAirport> airport;

  ConstData({required this.documentType, required this.documentDetailType, required this.documentCode, required this.city, required this.country, required this.airport});

  ConstData copyWith({
    List<DocumentType>? documentType,
    List<DocumentDetailType>? documentDetailType,
    List<DocumentCode>? documentCode,
    List<DocumentAirport>? city,
    List<DocumentCountry>? country,
    List<DocumentAirport>? airport,
  }) => ConstData(
    documentType: documentType ?? this.documentType,
    documentDetailType: documentDetailType ?? this.documentDetailType,
    documentCode: documentCode ?? this.documentCode,
    city: city ?? this.city,
    country: country ?? this.country,
    airport: airport ?? this.airport,
  );

  factory ConstData.fromJson(Map<String, dynamic> json) => ConstData(
    documentType: List<DocumentType>.from((json["documentType"] ?? []).map((x) => DocumentType.fromJson(x))),
    documentDetailType: List<DocumentDetailType>.from(json["documentDetailType"].map((x) => DocumentDetailType.fromJson(x))),
    documentCode: List<DocumentCode>.from(json["documentCode"].map((x) => DocumentCode.fromJson(x))),
    city: List<DocumentAirport>.from(json["city"].map((x) => DocumentAirport.fromJson(x))),
    country: List<DocumentCountry>.from(json["country"].map((x) => DocumentCountry.fromJson(x))),
    airport: List<DocumentAirport>.from(json["airport"].map((x) => DocumentAirport.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "documentType": List<dynamic>.from(documentType.map((x) => x.toJson())),
    "documentDetailType": List<dynamic>.from(documentDetailType.map((x) => x.toJson())),
    "documentCode": List<dynamic>.from(documentCode.map((x) => x.toJson())),
    "city": List<dynamic>.from(city.map((x) => x.toJson())),
    "country": List<dynamic>.from(country.map((x) => x.toJson())),
    "airport": List<dynamic>.from(airport.map((x) => x.toJson())),
  };

  factory ConstData.offline() => ConstData.fromJson(constDataJson);

  DocumentCountry? getLocationWithCode(String code) {
    if (country.any((a) => a.code3 == code)) {
      return country.firstWhere((a) => a.code3 == code);
    } else {
      return null;
    }
  }
}

class DocumentAirport {
  final String type;
  final String code3;
  final String name;
  final String? country;

  DocumentAirport({required this.type, required this.code3, required this.name, required this.country});

  DocumentAirport copyWith({String? type, String? code3, String? name, String? country}) => DocumentAirport(type: type ?? this.type, code3: code3 ?? this.code3, name: name ?? this.name, country: country ?? this.country);

  factory DocumentAirport.fromJson(Map<String, dynamic> json) => DocumentAirport(type: json["type"], code3: json["code3"], name: json["name"], country: json["country"]);

  Map<String, dynamic> toJson() => {"type": type, "code3": code3, "name": name, "country": country};

  @override
  String toString() => "$code3";
}

class DocumentCountry {
  final String type;
  final String code2;
  final String code3;
  final String name;

  DocumentCountry({required this.type, required this.code2, required this.code3, required this.name});

  DocumentCountry copyWith({String? type, String? code2, String? code3, String? name}) => DocumentCountry(type: type ?? this.type, code2: code2 ?? this.code2, code3: code3 ?? this.code3, name: name ?? this.name);

  factory DocumentCountry.fromJson(Map<String, dynamic> json) => DocumentCountry(type: json["type"], code2: json["code2"], code3: json["code3"] ?? '', name: json["name"]);

  Map<String, dynamic> toJson() => {"type": type, "code2": code2, "code3": code3, "name": name};

  @override
  String toString() => "$code3";
}

class DocumentCode {
  final String name;
  final String code;
  final String type;

  DocumentCode({required this.name, required this.code, required this.type});

  DocumentCode copyWith({String? name, String? code, String? type}) => DocumentCode(name: name ?? this.name, code: code ?? this.code, type: type ?? this.type);

  factory DocumentCode.fromJson(Map<String, dynamic> json) => DocumentCode(name: json["name"], code: json["code"], type: json["type"]);

  Map<String, dynamic> toJson() => {"name": name, "code": code, "type": type};

  @override
  String toString() => "$name";
}

class DocumentDetailType {
  final String type;
  final String subType;
  final String country;
  final String title;
  final String code;
  final String? note;

  DocumentDetailType({required this.type, required this.subType, required this.country, required this.title, required this.code, this.note});

  DocumentDetailType copyWith({String? type, String? subType, String? country, String? title, String? code, String? note}) =>
      DocumentDetailType(type: type ?? this.type, subType: subType ?? this.subType, country: country ?? this.country, title: title ?? this.title, code: code ?? this.code, note: note ?? this.note);

  factory DocumentDetailType.fromJson(Map<String, dynamic> json) => DocumentDetailType(type: json["type"], subType: json["subType"], country: json["country"], title: json["title"], code: json["code"], note: json["note"]);

  Map<String, dynamic> toJson() => {"type": type, "subType": subType, "country": country, "title": title, "code": code, "note": note};
}

class DocumentType {
  final String type;
  final String color;
  final String title;
  final String code;

  DocumentType({required this.type, required this.color, required this.title, required this.code});

  DocumentType copyWith({String? type, String? color, String? title, String? code}) => DocumentType(type: type ?? this.type, color: color ?? this.color, title: title ?? this.title, code: code ?? this.code);

  factory DocumentType.fromJson(Map<String, dynamic> json) => DocumentType(type: json["type"], color: json["color"], title: json["title"], code: json["code"]);

  Map<String, dynamic> toJson() => {"type": type, "color": color, "title": title, "code": code};
}
