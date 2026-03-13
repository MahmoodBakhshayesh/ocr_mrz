import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:collection/collection.dart';
import 'package:ocr_mrz/mrz_parser/mrz_aggregator.dart';
import 'package:ocr_mrz/mrz_parser/mrz_candidate.dart';
import 'package:ocr_mrz/mrz_parser/mrz_result.dart';
import 'package:ocr_mrz/mrz_parser/mrz_utils.dart';

class MrzParser {
  MrzAggregator _aggregator;
  final int confidence;

  MrzParser({this.confidence = 3}) : _aggregator = MrzAggregator(nameConfidence: confidence);

  /// Resets the internal aggregator to start a new scanning session.
  void reset() {
    _aggregator = MrzAggregator(nameConfidence: confidence);
  }

  /// Returns a map representing the current progress of the aggregator.
  Map<String, dynamic> getProgress(OcrData ocrData) {
    return {
      'ocrText': ocrData.text,
      'summaryString': _aggregator.getSummaryString(),
      'shapedMrz': _aggregator.getShapedMrz(),
      // 'fieldCounts': _aggregator.getProgress(),
    };
  }

  /// Processes a single frame of OCR data and returns a final `MrzResult`
  /// if the aggregator has reached sufficient confidence.
  MrzResult? parse(OcrData ocrData) {
    
    // 1. Find the best possible group of MRZ lines from the OCR output.
    final potentialLines = _findPotentialMrzLines(ocrData.lines.map((e) => e.text).toList());

    if (potentialLines == null) {
      return null;
    }

    // 2. Normalize each line to the correct length and character set.
    final normalizedLines = [
      for (int i = 0; i < potentialLines.length; i++)
        normalizeLine(potentialLines[i], potentialLines.first.length),
    ];

    // 3. Create a candidate for this frame.
    final candidate = MrzCandidate(lines: normalizedLines);

    // 4. Add the candidate to the aggregator, which returns a result if confident.
    return _aggregator.add(candidate);
  }

  /// Finds the most likely group of MRZ lines from all lines detected by OCR.
  List<String>? _findPotentialMrzLines(List<String> allLines) {
    // Filter for lines that look like they could be part of an MRZ.
    final mrzLikeLines = allLines.where((line) => line.contains('<') && line.length > 25).toList();
    if (mrzLikeLines.length < 2) {
      return null;
    }

    // --- Heuristic: Find groups of 2 or 3 lines with identical lengths ---
    List<String>? bestGroup;

    // Check for 3-line groups (TD1 format)
    for (int i = 0; i <= mrzLikeLines.length - 3; i++) {
      final group = mrzLikeLines.sublist(i, i + 3);
      final l1 = group[0].replaceAll(' ', '').length;
      final l2 = group[1].replaceAll(' ', '').length;
      final l3 = group[2].replaceAll(' ', '').length;

      if (l1 == 30 && l1 == l2 && l2 == l3) {
        bestGroup = group;
        break;
      }
    }
    
    // Check for 2-line groups (TD2/TD3) if no 3-line group was found
    if (bestGroup == null) {
       for (int i = 0; i <= mrzLikeLines.length - 2; i++) {
        final group = mrzLikeLines.sublist(i, i + 2);
        final l1 = group[0].replaceAll(' ', '').length;
        final l2 = group[1].replaceAll(' ', '').length;

        if (l1 == l2 && (l1 == 44 || l1 == 36)) {
          bestGroup = group;
          break;
        }
      }
    }
    
    return bestGroup;
  }
}
