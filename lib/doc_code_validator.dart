class DocumentCodeHelper {
  /// Explicit known ICAO codes (canonical)
  static const Map<String, String> _docCodeDescriptions = {
    'P<': 'Ordinary Passport',
    'PD': 'Diplomatic Passport',
    'PO': 'Official Passport',
    'PS': 'Service Passport',
    'PT': 'Temporary Passport',
    'PX': 'Passport - Other national variant',
    'PE': 'Romania e-passport variant',

    'V<': 'Visa (default)',
    'VA': 'Visa - Variant A',
    'VB': 'Visa - Variant B',

    'I<': 'Identity Card',
    'IA': 'Identity Card - Variant A',
    'IB': 'Identity Card - Variant B',

    'C<': 'Residence Permit / Immigration Card',
    'CA': 'Residence Permit - Variant A',
    'CB': 'Residence Permit - Variant B',

    'R<': 'Refugee Travel Document (1951 Convention)',
    'S<': 'Seafarer’s Identity Document',
    'X<': 'Stateless Person Travel Document (1954 Convention)',
    'D<': 'Diplomatic Travel Document (non-passport)',
    'O<': 'Official Travel Document (non-passport)',
  };

  /// Category mapping (first letter → broad type)
  static const Map<String, String> _categories = {
    'P': 'Passport',
    'V': 'Visa',
    'I': 'Identity Card',
    'C': 'Residence Permit',
    'R': 'Refugee Travel Document',
    'S': 'Seafarer Document',
    'X': 'Stateless Person Document',
    'D': 'Diplomatic Document',
    'O': 'Official Document',
    'A': 'Crew Member Certificate',
  };

  /// Returns true if [code] is a valid doc code prefix
  static bool isValid(String code) {
    if (_docCodeDescriptions.containsKey(code)) return true;
    return _categories.containsKey(code.substring(0, 1));
  }

  /// Returns category (Passport, Visa, etc.)
  static String category(String code) {
    return _categories[code.substring(0, 1)] ?? 'Unknown';
  }

  /// Returns description (if known), or falls back to category
  static String describe(String code) {
    return _docCodeDescriptions[code] ?? category(code);
  }
}
