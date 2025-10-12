/// Utilities to fix MRZ name areas where OCR misreads '<' as C/E/K, or repeats letters.
class MrzNameFixer {
  /// Clean a single token (e.g., "jackkkkkk" -> "JACK", "mikeecCCCC" -> "MIKEE").
  /// Rules:
  ///  - Keep A–Z only, uppercase
  ///  - Drop trailing runs of C/E/K (often OCR of '<')
  ///  - Collapse runs of >=3 identical letters to 2 (preserve legit doubles like LL, EE)
  ///  - If still ends with KK/CC, trim to a single K/C
  static String _cleanToken(String token) {
    if (token.trim().isEmpty) return '';
    var t = token.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

    // 1) remove trailing runs of C/E/K (common misread of '<')
    t = t.replaceAll(RegExp(r'([CEK])\1+$'), '');

    // 2) collapse runs of 3+ to exactly 2 (keep legit doubles)
    t = t.replaceAllMapped(RegExp(r'(.)\1{2,}'), (m) => '${m.group(1)}${m.group(1)}');

    // 3) if still ends with KK/CC..., trim to a single
    t = t.replaceAllMapped(RegExp(r'([CK])\1+$'), (m) => m.group(1)!);

    return t;
  }

  /// Build a proper MRZ name field from messy OCR text.
  /// Output format: SURNAME<<GIVEN<OTHER..., padded/truncated to [width] with '<'.
  static String fixNameField(String raw, {int width = 39}) {
    final tokens = RegExp(r'[A-Za-z]+')
        .allMatches(raw)
        .map((m) => _cleanToken(m.group(0)!))
        .where((s) => s.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return ''.padRight(width, '<');
    }

    final surname = tokens.first;
    final given = tokens.skip(1).toList();

    var mrz = '$surname<<${given.join('<')}';
    if (mrz.length > width) {
      mrz = mrz.substring(0, width);
    } else if (mrz.length < width) {
      mrz = mrz.padRight(width, '<');
    }
    return mrz;
  }

  /// Fixes a full **TD3 line 1** (passports: 44 chars total).
  /// - Keeps the first 2 chars (document code) + next 3 (issuing state) as-is.
  /// - Rebuilds the name area (cols 6–44, width 39) using MRZ separators.
  static String fixTd3Line1(String line1) {
    if (line1.isEmpty) return line1;
    final up = line1.toUpperCase();
    final padded = up.length >= 44 ? up.substring(0, 44) : up.padRight(44, '<');

    final docCode = padded.substring(0, 2);   // e.g., "P<"
    final issuer  = padded.substring(2, 5);   // e.g., "UTO"
    final nameRaw = padded.substring(5);      // columns 6–44 (39 chars)

    final fixedName = fixNameField(nameRaw, width: 39);
    return '$docCode$issuer$fixedName';
  }
}
