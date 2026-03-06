import 'dart:convert';

import 'name_validation_data_class.dart';

String normalizeName(String str) {
  return str
      .toUpperCase()
      .replaceAll(RegExp(r'K'), '') // حذف K
      .replaceAll(RegExp(r'[^A-Z]'), ''); // فقط حروف انگلیسی
}

int levenshtein(String a, String b) {
  final matrix = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));

  for (int i = 0; i <= a.length; i++) {
    matrix[i][0] = i;
  }

  for (int j = 0; j <= b.length; j++) {
    matrix[0][j] = j;
  }

  for (int i = 1; i <= a.length; i++) {
    for (int j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;

      matrix[i][j] = [
        matrix[i - 1][j] + 1, // delete
        matrix[i][j - 1] + 1, // insert
        matrix[i - 1][j - 1] + cost, // replace
      ].reduce((a, b) => a < b ? a : b);
    }
  }

  return matrix[a.length][b.length];
}

Map<String, dynamic> findMostSimilar(List<String> names, String target) {
  final normalizedTarget = normalizeName(target);

  String? bestMatch;
  int bestScore = 999999;
  int? index;

  for (final name in names) {
    final normalizedName = normalizeName(name);

    final score = levenshtein(normalizedName, normalizedTarget);

    if (score < bestScore) {
      bestScore = score;
      bestMatch = name;
      index = names.indexOf(name);
    }
  }

  return {"match": bestMatch, "distance": bestScore,'index':index};
}

NameValidationData? findMostSimilarByNameData(List<NameValidationData> base , {String firstname = "",String lastname='',String middlename= ""}) {
 final names = base.map((a)=>"${a.lastName??''}${a.middleName??''}${a.firstName??''}").toList();
 final target = "$lastname$middlename$firstname";
 final mapResult = findMostSimilar(names,target);
 final index =  mapResult["index"];
 if(index == null) return null;

 print(jsonEncode(mapResult));
 return base[index];
}
