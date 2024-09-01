import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../components/adresse_autocomplete.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class AddPatientScreen extends StatelessWidget {
  Map<String, String> extractedData;
  SecureStorageProvider.SecureStorageService secureStorageService =
      SecureStorageProvider.SecureStorageService();

  AddPatientScreen(
      {required this.extractedData, required this.secureStorageService});

  @override
  Widget build(BuildContext context) {
    final Map<String, String> patientData = extractedData;
    final TextEditingController lastNameController =
        TextEditingController(text: patientData['Nom']);
    final TextEditingController firstNameController =
        TextEditingController(text: patientData['Prénom']);
    final TextEditingController sexeController =
        TextEditingController(text: patientData['Sexe']);
    final TextEditingController dateOfBirthController =
        TextEditingController(text: patientData['Date de naissance']);
    final TextEditingController addressController =
        TextEditingController(text: patientData['address']);
    final TextEditingController cityController =
        TextEditingController(text: patientData['city']);
    final TextEditingController latitudeController =
        TextEditingController(text: patientData['latitude']);
    final TextEditingController longitudeController =
        TextEditingController(text: patientData['longitude']);
    final TextEditingController phoneController =
        TextEditingController(text: patientData['phone']);
    final TextEditingController noteController =
        TextEditingController(text: patientData['note']);
    final TextEditingController otherNamesController =
        TextEditingController(text: patientData['Autres prénoms']);
    final TextEditingController nationalityController =
        TextEditingController(text: patientData['Nationalité']);
    final TextEditingController nissController =
        TextEditingController(text: patientData['N° Registre national']);
    final TextEditingController numberIdCardController =
        TextEditingController(text: patientData['N° Carte']);
    final TextEditingController dateOfIssueIdCardController =
        TextEditingController(text: patientData['Expire le']);

    var phoneMaskFormatter = MaskTextInputFormatter(mask: '####/##.##.##');
    var nissMaskFormatter = MaskTextInputFormatter(mask: '##.##.##-##.##');
    var idCardMaskFormatter = MaskTextInputFormatter(mask: '###-#######-##');

    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter Patient'),
      ),
      body: Container(
        color: Colors.green[100]?.withOpacity(0.2),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: 'Nom',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
              ),
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: 'Prénom',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
              ),
              DropdownButtonFormField<String>(
                value: sexeController.text == 'm/m'
                    ? 'Homme'
                    : sexeController.text == 'f/f'
                        ? 'Femme'
                        : null,
                items: [
                  DropdownMenuItem(
                    child: Text('Homme'),
                    value: 'Homme',
                  ),
                  DropdownMenuItem(
                    child: Text('Femme'),
                    value: 'Femme',
                  ),
                ],
                onChanged: (value) {
                  sexeController.text = value == 'Homme' ? 'm/m' : 'f/f';
                },
                decoration: InputDecoration(
                  labelText: 'Sexe',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
              ),
              TextFormField(
                controller: dateOfBirthController,
                decoration: InputDecoration(
                  labelText: 'Date de naissance',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    dateOfBirthController.text =
                        DateFormat('dd/MM/yyyy').format(pickedDate);
                  }
                },
              ),
              // TextField(
              //   controller: placeOfBirthController,
              //   decoration: InputDecoration(labelText: 'Lieu de naissance'),
              // ),
              AddressAutocomplete(
                  controller: addressController,
                  cityController: cityController,
                  latitudeController: latitudeController,
                  longitudeController: longitudeController),

              TextFormField(
                controller: phoneController,
                inputFormatters: [phoneMaskFormatter],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Téléphone',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
              ),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Note',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
              ),
              TextField(
                controller: otherNamesController,
                decoration: InputDecoration(
                  labelText: 'Autres noms',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
              ),
              TextField(
                controller: nationalityController,
                decoration: InputDecoration(
                  labelText: 'Nationalité',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
              ),
              TextFormField(
                controller: nissController,
                inputFormatters: [nissMaskFormatter],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'NISS',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
              ),
              TextFormField(
                controller: numberIdCardController,
                inputFormatters: [idCardMaskFormatter],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Numéro de carte d\'identité',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
              ),
              TextFormField(
                controller: dateOfIssueIdCardController,
                decoration: InputDecoration(
                  labelText: 'Date d\'expiration de la carte d\'identité',
                  labelStyle: TextStyle(color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    dateOfIssueIdCardController.text =
                        DateFormat('dd/MM/yyyy').format(pickedDate);
                  }
                },
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    _createPatient(
                      context,
                      lastNameController.text,
                      firstNameController.text,
                      sexeController.text,
                      dateOfBirthController.text,
                      addressController.text,
                      cityController.text,
                      latitudeController.text,
                      longitudeController.text,
                      phoneController.text,
                      noteController.text,
                      otherNamesController.text,
                      nationalityController.text,
                      nissController.text,
                      numberIdCardController.text,
                      dateOfIssueIdCardController.text,
                    );
                  },
                  child: Icon(Icons.check, color: Colors.green),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPatient(
      context,
      lastNameController,
      firstNameController,
      sexeController,
      dateOfBirthController,
      addressController,
      cityController,
      latitudeController,
      longitudeController,
      phoneController,
      noteController,
      otherNamesController,
      nationalityController,
      nissController,
      numberIdCardController,
      dateOfIssueIdCardController) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/patient/create';
    final String? accessToken = await secureStorageService.getToken('Bearer');

    if (accessToken == null) {
      print('accessToken is null');
      return;
    }

    print(cityController);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'lastName': lastNameController,
          'firstName': firstNameController,
          'sexe': sexeController,
          'dateOfBirth': dateOfBirthController,
          'address': addressController,
          'city': cityController,
          'latitude': latitudeController,
          'longitude': longitudeController,
          'phone': phoneController,
          'note': noteController,
          'otherNames': otherNamesController,
          'nationality': nationalityController,
          'niss': nissController,
          'numberIdCard': numberIdCardController,
          'dateOfIssueIdCard': dateOfIssueIdCardController,
        }),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Patient créé avec succès'),
        ));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Échec de la création du patient'),
        ));
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
