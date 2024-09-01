import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController cityController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;

  AddressAutocomplete(
      {required this.controller,
      required this.cityController,
      required this.latitudeController,
      required this.longitudeController});

  @override
  _AddressAutocompleteState createState() => _AddressAutocompleteState();
}

class _AddressAutocompleteState extends State<AddressAutocomplete> {
  Future<List<Map<String, dynamic>>> _getSuggestions(String query) async {
    if (query.isEmpty) return [];

    final response = await http.get(
      Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=be',
      ),
    );

    if (response.statusCode == 200) {
      final List jsonResponse = json.decode(response.body);
      print(jsonResponse);
      return jsonResponse.map((place) {
        return {
          'display_name': place['display_name'],
          'lat': place['lat'],
          'lon': place['lon'],
          'city': place['address']['town'] ??
              place['address']['city'] ??
              place['address']['village'] ??
              place['address']['municipality'] ??
              place['address']['county'] ??
              place['address'],
        };
      }).toList();
    } else {
      throw Exception('Failed to load suggestions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Map<String, dynamic>>(
      suggestionsCallback: (pattern) async {
        return await _getSuggestions(pattern);
      },
      itemBuilder: (context, suggestion) {
        return ListTile(
          title: Text(suggestion['display_name']),
        );
      },
      onSelected: (suggestion) {
        print(suggestion['city']);
        print(suggestion['lat']);
        print(suggestion['lon']);
        setState(() {
          widget.controller.text = suggestion['display_name'];
          widget.cityController.text = suggestion['city'];
          widget.latitudeController.text = suggestion['lat'];
          widget.longitudeController.text = suggestion['lon'];
        });
      },
      hideOnLoading: true,
      hideOnError: true,
      builder: (context, controller, focusNode) {
        controller.text = widget.controller.text;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Adresse',
            labelStyle: TextStyle(color: Colors.green),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
          ),
          cursorColor: Colors.green,
        );
      },
    );
  }
}
