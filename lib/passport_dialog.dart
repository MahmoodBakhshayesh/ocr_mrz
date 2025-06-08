import 'package:flutter/material.dart';
import 'package:ocr_mrz/mrz_result_class.dart';
import 'package:intl/intl.dart';

class PassportDialog extends StatelessWidget {

  final OcrMrzResult result;

  final double width;

  final double height;

  const PassportDialog({
    super.key,
    required this.result,
    this.width = 350,
    this.height = 220,
  });
  String _formatDate(DateTime? date) =>date==null?'': DateFormat('yyyy-MM-dd').format(date);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black45)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerSection(),
            const SizedBox(height: 12),
            _infoRow('Name', '${result.firstName} ${result.lastName}'),
            _infoRow('Passport No', result.passportNumber),
            _infoRow('Nationality', result.nationality),
            _infoRow('Country Code', result.countryCode),
            _infoRow('Birth Date', _formatDate(result.birthDate)),
            _infoRow('Expiry Date', _formatDate(result.expiryDate)),
            Divider(),
            _mrzSection(),
          ],
        ),
      ),
    );
  }

  Widget _headerSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${result.documentType} Passport',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Icon(Icons.account_circle, color: Colors.white70, size: 32),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(color: Colors.white70))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _mrzSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: result.mrzLines.map(
            (line) => FittedBox(
              child: Text(
                        line,
                        style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 1.2,
                        ),
                      ),
            ),
      ).toList(),
    );
  }
}
