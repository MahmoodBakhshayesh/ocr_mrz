import 'package:flutter/material.dart';
import 'package:ocr_mrz/mrz_result_class.dart';
import 'package:intl/intl.dart';

import 'ocr_data_dialog.dart';

class PassportDialog extends StatefulWidget {

  final OcrMrzResult result;

  final double width;

  final double height;

  const PassportDialog({
    super.key,
    required this.result,
    this.width = 350,
    this.height = 220,
  });

  @override
  State<PassportDialog> createState() => _PassportDialogState();
}

class _PassportDialogState extends State<PassportDialog> {
  bool showText = false;
  String _formatDate(DateTime? date) =>date==null?'': DateFormat('yyyy-MM-dd').format(date);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: widget.width,
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
            _headerSection(context,widget.result),
            const SizedBox(height: 12),
            _infoRow('Name', '${widget.result.firstName} ${widget.result.lastName}'),
            _infoRow('Passport No', widget.result.passportNumber),
            _infoRow('Nationality', widget.result.nationality),
            _infoRow('Country Code', widget.result.countryCode),
            _infoRow('Birth Date', _formatDate(widget.result.birthDate)),
            _infoRow('Expiry Date', _formatDate(widget.result.expiryDate)),
            Divider(),
            _mrzSection(),
            Divider(),
            showText?ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 400),
              child: ListView(
                shrinkWrap: true,
                children:widget.result.ocrData.lines.map((a)=>SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Text(a.text,style: TextStyle(color: Colors.white,fontSize: 10,height: 1),))).toList(),
              ),
            ):SizedBox()
            // Expanded(
            //   child: ExpansionTile(
            //     tilePadding: EdgeInsets.zero,
            //     dense: true,
            //     title: Text("More",style: TextStyle(color: Colors.white),),children: [
            //       Column(
            //         children: result.ocrData.lines.map((a)=>Text(a.text,style: TextStyle(color: Colors.white),)).toList(),
            //       )
            //   ],),
            // )
          ],
        ),
      ),
    );
  }

  Widget _headerSection(BuildContext context,OcrMrzResult res) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${widget.result.documentType} Passport',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        GestureDetector(
            onTap: (){
              showText = !showText;
              setState((){});
             // showDialog(context: context, builder: (BuildContext context) {
             //   return OcrDataDialog(ocrData: res.ocrData,);
             // },);
            },
            child: Icon(Icons.info, color: Colors.white70, size: 32)),
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
      children: widget.result.mrzLines.map(
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
