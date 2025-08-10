import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';

class OcrSettingDialog extends StatefulWidget {
  final OcrMrzSetting current;

  const OcrSettingDialog({super.key, required this.current});

  @override
  State<OcrSettingDialog> createState() => _OcrSettingDialogState();
}

class _OcrSettingDialogState extends State<OcrSettingDialog> {
  late OcrMrzSetting tmp = widget.current;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Settings",style: TextStyle(fontWeight: FontWeight.bold),),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(children: [
              Row(
                children: [
                  Expanded(child: Text("Name Validation")),
                  CupertinoSwitch(
                    value: tmp.validateNames,
                    onChanged: (a) {
                      tmp.validateNames = a;
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text("Lines Length Validation")),
                  CupertinoSwitch(
                    value: tmp.validateLinesLength,
                    onChanged: (a) {
                      tmp.validateLinesLength = a;
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text("CountryCode Validation")),
                  CupertinoSwitch(
                    value: tmp.validateCountry,
                    onChanged: (a) {
                      tmp.validateCountry = a;
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text("Nationality Validation")),
                  CupertinoSwitch(
                    value: tmp.validateNationality,
                    onChanged: (a) {
                      tmp.validateNationality = a;
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text("BirthDate Validation")),
                  CupertinoSwitch(
                    value: tmp.validateBirthDateValid,
                    onChanged: (a) {
                      tmp.validateBirthDateValid = a;
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text("ExpiryDate Validation")),
                  CupertinoSwitch(
                    value: tmp.validateExpiryDateValid,
                    onChanged: (a) {
                      tmp.validateExpiryDateValid = a;
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text("Document Number Validation")),
                  CupertinoSwitch(
                    value: tmp.validateDocNumberValid,
                    onChanged: (a) {
                      tmp.validateDocNumberValid = a;
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text("Personal Number Validation")),
                  CupertinoSwitch(
                    value: tmp.validatePersonalNumberValid,
                    onChanged: (a) {
                      tmp.validatePersonalNumberValid = a;
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text("Final Check Validation")),
                  CupertinoSwitch(
                    value: tmp.validateFinalCheckValid,
                    onChanged: (a) {
                      tmp.validateFinalCheckValid = a;
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],),
          ),
          Divider(),
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))
                    ),
                    onPressed: (){
                  Navigator.of(context).pop(tmp);
                }, child: Text("Apply")),
              ),
              const SizedBox(width: 4),
            ],
          )
        ],
      ),
    );
  }
}
