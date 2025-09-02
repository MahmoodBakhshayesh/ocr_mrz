class DocumentCodeHelper {
  /// Map of MRZ document codes → Human readable description
  static const Map<String, String> _docCodeDescriptions = {
    // General 1-char codes
    'A': 'Crew Member Certificate',
    'C': 'Residence Permit / Immigration Card / Crew Member Certificate',
    'D': 'Diplomatic Travel Document (non-passport)',
    'I': 'Identity Card',
    'O': 'Official Travel Document (non-passport)',
    'P': 'Passport (general)',
    'R': 'Refugee Travel Document (1951 Convention)',
    'S': 'Seafarer’s Identity Document',
    'V': 'Visa',
    'X': 'Stateless Person Travel Document (1954 Convention)',

    // Two-char / variant codes
    'C<': 'Residence Permit / Immigration Card',
    'CA': 'Residence Permit - Variant A (Canada PR Card, etc.)',
    'CB': 'Residence Permit - Variant B',

    'D<': 'Diplomatic Travel Document (non-passport)',

    'I<': 'Identity Card',
    'IA': 'Identity Card - Variant A',
    'IB': 'Identity Card - Variant B',

    'O<': 'Official Travel Document (non-passport)',

    'P<': 'Ordinary Passport',
    'PD': 'Diplomatic Passport',
    'PE': 'Romania e-passport variant',
    'PO': 'Official Passport',
    'PS': 'Service Passport',
    'PT': 'Temporary Passport',
    'PX': 'Passport - Other national variant',

    'R<': 'Refugee Travel Document (1951 Convention)',

    'S<': 'Seafarer’s Identity Document',

    'V<': 'Visa',
    'VA': 'Visa - Variant A',
    'VB': 'Visa - Variant B',

    'X<': 'Stateless Person Travel Document (1954 Convention)',
  };

  /// Returns true if [code] is a valid ICAO document code.
  static bool isValid(String code) {
    return _docCodeDescriptions.containsKey(code);
  }

  /// Returns the description of [code], or "Unknown Document Code" if not found.
  static String describe(String code) {
    return _docCodeDescriptions[code] ?? 'Unknown Document Code';
  }
}


const validDocumentCodes = <String>[
  // General single-letter codes
  'A',   // Crew Member Certificate (alt use in some states)
  'C',   // Residence Permit / Immigration Card / Crew Member Certificate
  'D',   // Diplomatic Travel Document (non-passport)
  'I',   // Identity Card
  'O',   // Official Travel Document (non-passport)
  'P',   // Passport (general category)
  'R',   // Refugee Travel Document (1951 Convention)
  'S',   // Seafarer’s Identity Document
  'V',   // Visa
  'X',   // Stateless Person Travel Document (1954 Convention)

  // Two-character / variant codes
  'C<',  // Residence Permit / Immigration Card
  'CA',  // Residence Permit (e.g. Canada PR Card)
  'CB',  // Residence Permit - Variant B

  'D<',  // Diplomatic Travel Document (non-passport)

  'I<',  // Identity Card
  'IA',  // Identity Card - Variant A
  'IB',  // Identity Card - Variant B

  'O<',  // Official Travel Document (non-passport)

  'P<',  // Ordinary Passport (most common form)
  'PD',  // Diplomatic Passport
  'PE',  // Romania e-passport variant
  'PO',  // Official Passport
  'PS',  // Service Passport
  'PT',  // Temporary Passport
  'PX',  // Passport - Other national variant

  'R<',  // Refugee Travel Document (1951 Convention)

  'S<',  // Seafarer’s Identity Document

  'V<',  // Visa (most common form)
  'VA',  // Visa - Variant A
  'VB',  // Visa - Variant B

  'X<',  // Stateless Person Travel Document (1954 Convention)
];
