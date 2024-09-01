import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import 'package:intl/intl.dart';
import 'TourManagementScreen.dart';
import '../patients/PatientsListScreen.dart';

class TourListScreen extends StatefulWidget {
  final SecureStorageProvider.SecureStorageService secureStorageService;

  TourListScreen({
    required this.secureStorageService,
  });

  @override
  _TourListScreenState createState() => _TourListScreenState();
}

class _TourListScreenState extends State<TourListScreen> {
  List<dynamic> tours = [];
  List<dynamic> replacements = [];
  bool showReplacements = true;
  bool integratingReplacement = false;
  List<int> selectedPatientIds = [];
  Map<String, dynamic>? currentUser;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    final String apiUrl = 'https://api_swapinfi.lebourbier.be/api/user/current';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');
    final response = await http.get(Uri.parse(apiUrl), headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      setState(() {
        currentUser = jsonDecode(response.body);
      });
      _getTours();
      _getReplacements();
    }
  }

  Future<void> _getTours() async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/${currentUser!['id']}';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.get(Uri.parse(apiUrl), headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      setState(() {
        tours = jsonDecode(response.body);
      });
    }
  }

  Future<void> _getReplacements() async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/replacement/user/${currentUser!['id']}';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.get(Uri.parse(apiUrl), headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      setState(() {
        replacements = jsonDecode(response.body);
      });
    }
  }

  Future<void> _updateTour(List<int> selectedPatientIds,
      List<int> existingPatientIds, int tourId) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/update/$tourId';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    // Combine the selected patient ids with existing patient ids
    final updatedPatientIds = [...existingPatientIds, ...selectedPatientIds];

    final response = await http.put(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'ids': updatedPatientIds,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tournée mise à jour avec succès'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour de la tournée'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Vos Tournées et Remplacements'),
        backgroundColor: Colors.green[100]?.withOpacity(0.2),
      ),
      body: Container(
        color: Colors.green[100]?.withOpacity(0.2),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              integratingReplacement
                  ? 'Sélectionner une tournée'
                  : 'Vos Tournées',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: tours.isEmpty
                    ? [Center(child: Text('Aucune tournée disponible'))]
                    : tours
                        .map((tour) => Container(
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              margin: EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 10),
                              child: ListTile(
                                title: Text(
                                  tour['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                trailing: Icon(Icons.chevron_right,
                                    color: Colors.white),
                                onTap: () {
                                  if (integratingReplacement) {
                                    List<int> existingPatientIds =
                                        List<int>.from(tour['patients']
                                            .map((p) => p['id']));
                                    _updateTour(selectedPatientIds,
                                        existingPatientIds, tour['id']);
                                    setState(() {
                                      integratingReplacement = false;
                                      showReplacements = true;
                                    });
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TourManagementScreen(
                                                tourId: tour['id'].toString(),
                                                secureStorageService:
                                                    widget.secureStorageService,
                                                user: currentUser!),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ))
                        .toList(),
              ),
            ),
            if (showReplacements) ...[
              SizedBox(height: 20),
              Text(
                'Vos Remplacements',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: replacements.isEmpty
                      ? [Center(child: Text('Aucun remplacement disponible'))]
                      : replacements.map((replacement) {
                          String replacementDate = DateFormat('dd/MM/yyyy')
                              .format(DateTime.parse(
                                  replacement['replacement_date']));
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.green, // Couleur de la bordure
                                width: 2, // Largeur de la bordure
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            margin: EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
                            child: ListTile(
                              title: Text(
                                'Remplacement $replacementDate',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                if (replacement['user_id'] ==
                                    currentUser!['id']) {
                                  _showReplacementOptionsModal(
                                      context, replacement);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PatientsListScreen(
                                        user: currentUser!,
                                        secureStorageService:
                                            widget.secureStorageService,
                                        tourId:
                                            replacement['tour_id'].toString(),
                                        patients: replacement['tour']
                                            ['patients'],
                                        fromHomeScreen: false,
                                        canEdit: false,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        }).toList(),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showReplacementOptionsModal(
      BuildContext context, Map<String, dynamic> replacement) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.60,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Options de remplacement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.create_new_folder, color: Colors.blue),
                  title: Text(
                      'Créer une nouvelle tournée à partir de ce remplacement'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientsListScreen(
                          user: currentUser!,
                          secureStorageService: widget.secureStorageService,
                          replacementPatients: replacement['tour']['patients'],
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.add_to_photos, color: Colors.green),
                  title:
                      Text('Intégrer ce remplacement à une tournée existante'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      showReplacements = false;
                      integratingReplacement = true;
                      selectedPatientIds =
                          (replacement['tour']['patients'] as List)
                              .map<int>((patient) => patient['id'] as int)
                              .toList();
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.person, color: Colors.orange),
                  title: Text('Visualiser la liste des patients'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientsListScreen(
                          user: currentUser!,
                          secureStorageService: widget.secureStorageService,
                          tourId: replacement['tour_id'].toString(),
                          patients: replacement['tour']['patients'],
                          fromHomeScreen: false,
                          canEdit: false,
                          showFullDetails: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
