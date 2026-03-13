import 'package:collection/collection.dart';
import 'package:ocr_mrz/mrz_parser/mrz_candidate.dart';
import 'package:ocr_mrz/mrz_parser/mrz_result.dart';

/// A helper class to perform a majority vote on a stream of values.
class _MajorityVote<T> {
  final Map<T, int> _counts = {};
  final int minConfidence;

  _MajorityVote(this.minConfidence);

  void add(T? value) {
    if (value != null) {
      _counts.update(value, (count) => count + 1, ifAbsent: () => 1);
    }
  }

  void clear() => _counts.clear();

  T? get bestGuess => _counts.isEmpty ? null : _counts.entries.sortedBy<num>((e) => e.value).last.key;

  T? get result {
    if (_counts.isEmpty) return null;
    final topEntry = _counts.entries.sortedBy<num>((e) => e.value).last;
    if (topEntry.value >= minConfidence) return topEntry.key;
    return null;
  }
}

/// Aggregates data from multiple `MrzCandidate` frames to build a confident result.
class MrzAggregator {
  final int _nameConfidence;
  
  // Confirmed final values
  MrzFormat? _finalFormat;
  String? _finalDocType, _finalCountryCode, _finalIssuingState, _finalDocNumber, _finalSex, _finalNationality, _finalLastName, _finalFirstName, _finalOptional1, _finalOptional2;
  DateTime? _finalBirthDate, _finalExpiryDate;
  String? _finalMrzLines;

  // Majority votes for non-validated fields
  late _MajorityVote<String> _lastNameVote, _firstNameVote;
  
  // Best guesses for real-time feedback
  final _bestGuessFormat = _MajorityVote<MrzFormat>(0);
  final _bestGuessDocType = _MajorityVote<String>(0);
  final _bestGuessCountry = _MajorityVote<String>(0);
  final _bestGuessIssuing = _MajorityVote<String>(0);
  final _bestGuessDocNum = _MajorityVote<String>(0);
  final _bestGuessBirthDate = _MajorityVote<DateTime>(0);
  final _bestGuessSex = _MajorityVote<String>(0);
  final _bestGuessExpiry = _MajorityVote<DateTime>(0);
  final _bestGuessNat = _MajorityVote<String>(0);
  final _bestGuessOpt1 = _MajorityVote<String>(0);
  final _bestGuessOpt2 = _MajorityVote<String>(0);
  
  int _totalFrames = 0;
  int _docNumSuccess = 0, _birthDateSuccess = 0, _expiryDateSuccess = 0, _optionalDataSuccess = 0, _finalCompositeSuccess = 0;


  MrzAggregator({int nameConfidence = 3}) : _nameConfidence = nameConfidence {
    reset();
  }
  
  void reset() {
    _finalFormat = null;
    _finalDocType = null; _finalCountryCode = null; _finalIssuingState = null;
    _finalDocNumber = null; _finalBirthDate = null; _finalSex = null;
    _finalExpiryDate = null; _finalNationality = null; _finalLastName = null;
    _finalFirstName = null; _finalOptional1 = null; _finalOptional2 = null;
    _finalMrzLines = null;

    _lastNameVote = _MajorityVote<String>(_nameConfidence);
    _firstNameVote = _MajorityVote<String>(_nameConfidence);

    _bestGuessFormat.clear(); _bestGuessDocType.clear(); _bestGuessCountry.clear();
    _bestGuessIssuing.clear(); _bestGuessDocNum.clear(); _bestGuessBirthDate.clear();
    _bestGuessSex.clear(); _bestGuessExpiry.clear(); _bestGuessNat.clear();
    _bestGuessOpt1.clear(); _bestGuessOpt2.clear();

    _totalFrames = 0;
    _docNumSuccess = 0;
    _birthDateSuccess = 0;
    _expiryDateSuccess = 0;
    _optionalDataSuccess = 0;
    _finalCompositeSuccess = 0;
  }

  MrzResult? add(MrzCandidate candidate) {
    if (candidate.format == MrzFormat.Unknown) return null;
    _totalFrames++;
    
    // --- Document Change Detection ---
    if (_finalBirthDate != null && candidate.birthDate != null && candidate.birthDateValid && candidate.birthDate != _finalBirthDate) {
      reset();
    }
    // --- End Detection ---

    // Update best guesses on every frame
    _bestGuessFormat.add(candidate.format);
    _bestGuessDocType.add(candidate.documentType);
    _bestGuessCountry.add(candidate.countryCode);
    _bestGuessIssuing.add(candidate.issuingState);
    _bestGuessSex.add(candidate.sex);
    _bestGuessNat.add(candidate.nationality);
    _bestGuessOpt1.add(candidate.optionalData1);
    _bestGuessOpt2.add(candidate.optionalData2);

    // Immediately confirm validated fields
    if (candidate.docNumberValid) {
       _finalDocNumber ??= candidate.documentNumber;
       _bestGuessDocNum.add(candidate.documentNumber);
    }
    if (candidate.birthDateValid) {
      _finalBirthDate ??= candidate.birthDate;
      _bestGuessBirthDate.add(candidate.birthDate);
    }
    if (candidate.expiryDateValid) {
      _finalExpiryDate ??= candidate.expiryDate;
      _bestGuessExpiry.add(candidate.expiryDate);
    }
    _finalFormat ??= candidate.format;
    _finalCountryCode ??= candidate.countryCode;
    _finalIssuingState ??= candidate.issuingState;
    _finalNationality ??= candidate.nationality;
    _finalSex ??= candidate.sex;
    _finalDocType ??= candidate.documentType;
    
    // Use confidence for non-validated names
    _lastNameVote.add(candidate.lastName);
    _firstNameVote.add(candidate.firstName);
    _finalLastName ??= _lastNameVote.result;
    _finalFirstName ??= _firstNameVote.result;
    
    // Once all fields are confirmed, lock in the MRZ lines
    if (_buildResult() != null) {
      _finalMrzLines ??= candidate.lines.join('\n');
    }

    return _buildResult();
  }
  
  String getSummaryString() {
    final fields = {
      'DocType': _finalDocType, 'Country': _finalCountryCode, 'DocNum': _finalDocNumber,
      'BirthDate': _finalBirthDate, 'Expiry': _finalExpiryDate, 'Sex': _finalSex,
      'Nat.': _finalNationality, 'L.Name': _finalLastName, 'F.Name': _finalFirstName,
    };
    return fields.entries.map((e) => '${e.key} ${e.value != null ? '✅' : '❌'}').join(' | ');
  }

  List<String> getShapedMrz() {
    final format = _bestGuessFormat.bestGuess;
    if (format == null) return [];

    String f(String? value, int length) => (value ?? '').padRight(length, '<');
    String d(DateTime? value) => value != null ? '${(value.year % 100).toString().padLeft(2, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}' : '<<<<<<';
    
    final lName = _lastNameVote.bestGuess ?? _finalLastName;
    final fName = _firstNameVote.bestGuess ?? _finalFirstName;

    if (format == MrzFormat.TD3) {
      final line1 = '${f(_bestGuessDocType.bestGuess, 1)}<${f(_bestGuessCountry.bestGuess, 3)}${f(lName, 0)}<<${f(fName, 0)}'.padRight(44, '<');
      final line2 = '${f(_bestGuessDocNum.bestGuess, 9)}<${f(_bestGuessNat.bestGuess, 3)}${d(_bestGuessBirthDate.bestGuess)}<${f(_bestGuessSex.bestGuess, 1)}${d(_bestGuessExpiry.bestGuess)}${f(_bestGuessOpt1.bestGuess, 14)}<<<<<'.padRight(44, '<');
      return [line1, line2];
    } else if (format == MrzFormat.TD1) {
      final line1 = '${f(_bestGuessDocType.bestGuess, 1)}<${f(_bestGuessCountry.bestGuess, 3)}${f(_bestGuessDocNum.bestGuess, 9)}<${f(_bestGuessOpt1.bestGuess, 15)}'.padRight(30, '<');
      final line2 = '${d(_bestGuessBirthDate.bestGuess)}<${f(_bestGuessSex.bestGuess, 1)}${d(_bestGuessExpiry.bestGuess)}<${f(_bestGuessNat.bestGuess, 3)}<<<<<<<<<<<'.padRight(30, '<');
      final line3 = '${f(lName, 0)}<<${f(fName, 0)}'.padRight(30, '<');
      return [line1, line2, line3];
    } else if (format == MrzFormat.TD2) {
      final line1 = '${f(_bestGuessDocType.bestGuess, 1)}<${f(_bestGuessCountry.bestGuess, 3)}${f(lName, 0)}<<${f(fName, 0)}'.padRight(36, '<');
      final line2 = '${f(_bestGuessDocNum.bestGuess, 9)}<${f(_bestGuessNat.bestGuess, 3)}${d(_bestGuessBirthDate.bestGuess)}<${f(_bestGuessSex.bestGuess, 1)}${d(_bestGuessExpiry.bestGuess)}${f(_bestGuessOpt1.bestGuess, 7)}<'.padRight(36, '<');
      return [line1, line2];
    }
    return [];
  }

  MrzResult? _buildResult() {
    if (_finalDocNumber==null || _finalBirthDate==null || _finalExpiryDate==null || _finalLastName==null || _finalFirstName==null || _finalNationality==null || _finalDocType==null || _finalCountryCode==null || _finalFormat==null || _finalSex == null) {
      return null;
    }

    return MrzResult(
      format: _finalFormat!,
      mrzLines: _finalMrzLines?.split('\n') ?? [],
      documentType: _finalDocType!,
      countryCode: _finalCountryCode!,
      issuingState: _finalIssuingState ?? _finalCountryCode!,
      documentNumber: _finalDocNumber!,
      lastName: _finalLastName!,
      firstName: _finalFirstName!,
      birthDate: _finalBirthDate!,
      sex: _finalSex!,
      expiryDate: _finalExpiryDate!,
      nationality: _finalNationality!,
      optionalData1: _finalOptional1,
      optionalData2: _finalOptional2,
      checkDigits: MrzCheckDigitResult(
        documentNumber: true, birthDate: true, expiryDate: true,
        optionalData: _optionalDataSuccess > _totalFrames / 2, 
        finalComposite: _finalCompositeSuccess > _totalFrames / 2,
      ),
    );
  }
}
