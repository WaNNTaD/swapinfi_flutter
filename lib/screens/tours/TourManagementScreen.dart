import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import 'dart:convert';
import '../patients/PatientsListScreen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class TourManagementScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String tourId;
  final SecureStorageProvider.SecureStorageService secureStorageService;

  TourManagementScreen(
      {required this.tourId,
      required this.secureStorageService,
      required this.user});

  @override
  _TourManagementScreenState createState() => _TourManagementScreenState();
}

class _TourManagementScreenState extends State<TourManagementScreen> {
  late List<Map<String, dynamic>> patients;
  late List<String>? userIds;
  late Map<String, dynamic> tour;
  late Future<void> _futureTour;

  @override
  void initState() {
    super.initState();
    _futureTour = getTourById(widget.tourId);
  }

  void _sortPatients() {
    patients.sort((a, b) {
      final orderA = a['pivot']['order'];
      final orderB = b['pivot']['order'];
      if (orderA == null && orderB == null) return 0;
      if (orderA == null) return 1;
      if (orderB == null) return -1;
      return orderA.compareTo(orderB);
    });
  }

  void _tabOfIds() {
    List<String> ids = [];
    for (int i = 0; i < patients.length; i++) {
      ids.add(patients[i]['id'].toString());
    }
    userIds = ids;
  }

  Future<void> getTourById(String tourId) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/show/$tourId';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.get(Uri.parse(apiUrl), headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      tour = jsonDecode(response.body);
      setState(() {
        patients = List<Map<String, dynamic>>.from(tour['patients']);
        _sortPatients();
        _tabOfIds();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la récupération de la tournée')),
      );
    }
  }

  Future<void> sendUpdatedOrder() async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/update-order/${tour['id']}';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');
    final List<Map<String, dynamic>> orderedPatients = patients.map((patient) {
      return {
        'id': patient['id'],
        'order': patient['pivot']['order'],
      };
    }).toList();

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
      body: jsonEncode({'patients': orderedPatients}),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ordre des patients mis à jour avec succès')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Échec de la mise à jour de l\'ordre des patients')),
      );
    }
  }

  Future<void> deletePatientFromTour(String tourId, String patientId) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/delete-patient/$tourId/$patientId';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.delete(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        patients
            .removeWhere((patient) => patient['id'].toString() == patientId);
        _updatePatientOrder();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Patient supprimé de la tournée avec succès')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la suppression du patient')),
      );
    }
  }

  Future<void> _deleteTour() async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/delete/${tour['id']}';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.delete(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tournée supprimée avec succès')),
      );
      Navigator.pop(context); // Go back to the previous screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la suppression de la tournée')),
      );
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Vérifie si les services de localisation sont activés
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Les services de localisation ne sont pas activés. Ne pas continuer
      return Future.error('Les services de localisation sont désactivés.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Les permissions sont refusées, ne pas continuer
        return Future.error('Les permissions de localisation sont refusées.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Les permissions sont refusées de façon permanente, ne pas continuer
      return Future.error(
          'Les permissions de localisation sont refusées de façon permanente.');
    }

    // Lorsque nous arrivons ici, les permissions sont accordées et nous pouvons obtenir la position
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<List<String>> getTravelTimes(
      List<Map<String, dynamic>> patients) async {
    List<String> travelTimes = [];

    try {
      // Obtenir la position actuelle de l'utilisateur
      Position currentPosition = await _determinePosition();

      // Ajouter le temps de trajet de la position actuelle au premier patient
      final startLat = currentPosition.latitude;
      final startLng = currentPosition.longitude;
      final firstPatientLat = patients[0]['latitude'];
      final firstPatientLng = patients[0]['longitude'];

      var response = await http.get(Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car?api_key=5b3ce3597851110001cf6248df1f9501c9664faa8eaabe26717c4528&start=$startLng,$startLat&end=$firstPatientLng,$firstPatientLat'));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var duration =
            data['features'][0]['properties']['segments'][0]['duration'];
        travelTimes.add((duration / 60).toStringAsFixed(0) + ' min');
      } else {
        travelTimes.add('N/A');
      }

      // Calculer les temps de trajet entre les patients suivants
      for (int i = 0; i < patients.length - 1; i++) {
        final startLat = patients[i]['latitude'];
        final startLng = patients[i]['longitude'];
        final endLat = patients[i + 1]['latitude'];
        final endLng = patients[i + 1]['longitude'];

        response = await http.get(Uri.parse(
            'https://api.openrouteservice.org/v2/directions/driving-car?api_key=5b3ce3597851110001cf6248df1f9501c9664faa8eaabe26717c4528&start=$startLng,$startLat&end=$endLng,$endLat'));

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          var duration =
              data['features'][0]['properties']['segments'][0]['duration'];
          travelTimes.add((duration / 60).toStringAsFixed(0) + ' min');
        } else {
          travelTimes.add('N/A');
        }
      }
    } catch (e) {
      print('Error fetching travel times: $e');
      for (int i = 0; i < patients.length; i++) {
        travelTimes.add('N/A');
      }
    }
    return travelTimes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestion de la tournée'),
      ),
      body: FutureBuilder<void>(
        future: _futureTour,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur de chargement de la tournée'));
          } else {
            return FutureBuilder<List<String>>(
              future: getTravelTimes(patients),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('Erreur de chargement des temps de trajet'));
                } else {
                  final travelTimes = snapshot.data!;
                  return AnimatedReorderableListView(
                    items: patients,
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      return Material(
                        key: ValueKey(patient['id']),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green[300],
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
                          margin:
                              EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Icon(Icons.person),
                                title: Text(
                                    '${patient['lastName']} ${patient['firstName']}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Date de naissance: ${patient['dateOfBirth']}'),
                                    Text(
                                        'Ville: ${patient['city'] ?? 'Adresse non renseignée'}'),
                                  ],
                                ),
                                trailing: Icon(Icons.drag_handle),
                                onTap: () =>
                                    _showPatientDetailsModal(context, patient),
                              ),
                              if (index == 0 && travelTimes.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    final String url =
                                        'maps://?saddr=${patients[0]['latitude']},${patients[0]['longitude']}';
                                    launchUrl(Uri.parse(url));
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 6),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white, // Couleur de fond
                                      borderRadius: BorderRadius.circular(
                                          20), // Bord arrondi
                                    ),
                                    width:
                                        MediaQuery.of(context).size.width / 4,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.directions_car,
                                            color: Colors.black),
                                        SizedBox(width: 5),
                                        Text(travelTimes[0]),
                                      ],
                                    ),
                                  ),
                                ),
                              if (index > 0 && travelTimes.length > index)
                                GestureDetector(
                                  onTap: () {
                                    final String url =
                                        'maps://?saddr=${patients[index - 1]['latitude']},${patients[index - 1]['longitude']}&daddr=${patients[index]['latitude']},${patients[index]['longitude']}';
                                    launchUrl(Uri.parse(url));
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 10),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white, // Couleur de fond
                                      borderRadius: BorderRadius.circular(
                                          20), // Bord arrondi
                                    ),
                                    width:
                                        MediaQuery.of(context).size.width / 4,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.directions_car,
                                            color: Colors.black),
                                        SizedBox(width: 5),
                                        Text(travelTimes[index]),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    onReorder: this._onReorder,
                    enterTransition: [FadeIn(), ScaleIn()],
                    exitTransition: [SlideInLeft()],
                    insertDuration: const Duration(milliseconds: 300),
                    removeDuration: const Duration(milliseconds: 300),
                  );
                }
              },
            );
          }
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment:
            CrossAxisAlignment.start, // Ajout pour aligner à gauche
        children: [
          FloatingActionButton(
            onPressed: () {
              _showDeleteConfirmationDialog(context);
            },
            backgroundColor: Colors.red,
            child: Icon(Icons.delete),
            heroTag: null,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientsListScreen(
                    user: widget.user,
                    secureStorageService: widget.secureStorageService,
                    patientsId: userIds,
                    tourId: tour?['id'].toString(),
                  ),
                ),
              );
            },
            backgroundColor: Colors.green,
            child: Icon(Icons.add),
            heroTag: null,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              _openEntireTourInMaps();
            },
            backgroundColor: Colors.blue,
            child: Icon(Icons.map),
            heroTag: null,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showPatientDetailsModal(
      BuildContext context, Map<String, dynamic> patient) {
    TextEditingController noteController =
        TextEditingController(text: patient['note'] ?? '');
    bool isEditing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Détails du patient',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.person, size: 40),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${patient['lastName']} ${patient['firstName']}'),
                              Text(
                                  'Date de naissance: ${patient['dateOfBirth']}'),
                              Text('Sexe: ${patient['sexe']}'),
                              SizedBox(height: 10),
                              Text(
                                  'Adresse: ${patient['address'] ?? 'Adresse non renseignée'}'),
                              SizedBox(height: 10),
                              Text('Téléphone: ${patient['phone']}'),
                              SizedBox(height: 10),
                              Text('Niss: ${patient['niss']}'),
                              SizedBox(height: 10),
                              Text(
                                  'Numéro de carte: ${patient['numberIdCard']}'),
                              SizedBox(height: 10),
                              Text('Note:'),
                              isEditing
                                  ? TextField(
                                      controller: noteController,
                                      maxLines: null,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                      ),
                                    )
                                  : Text(patient['note'] ?? 'Pas de note'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Background color
                      ),
                      onPressed: () =>
                          _showConfirmationDialog(context, patient),
                      child: Text(
                        'Soins patients effectué',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          iconSize: 30,
                          icon: isEditing
                              ? Icon(Icons.check, color: Colors.green)
                              : Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            setState(() {
                              isEditing = !isEditing;
                              if (!isEditing) {
                                // Save the updated note
                                patient['note'] = noteController.text;
                              }
                            });
                          },
                        ),
                        IconButton(
                          iconSize: 30,
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            Navigator.pop(context);
                            deletePatientFromTour(tour['id'].toString(),
                                patient['id'].toString());
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showConfirmationDialog(
      BuildContext context, Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirmation"),
          content:
              Text("Les soins du patient ont-ils correctement été effectués?"),
          actions: [
            TextButton(
              child: Text("Annuler"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Valider"),
              onPressed: () {
                // Handle the validation logic here
                Navigator.of(context).pop();
                // Optionally close the patient details modal
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Soins du patient validés avec succès."),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Êtes-vous sûr de vouloir supprimer cette tournée ?'),
          actions: [
            TextButton(
              child: Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Supprimer'),
              onPressed: () {
                // Call the delete tour method here
                _deleteTour();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _openEntireTourInMaps() async {
    if (patients.isEmpty) return;

    // Obtenir la position actuelle de l'utilisateur
    Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    // Base URL pour l'application Plans d'Apple
    String url =
        'maps://?saddr=${currentPosition.latitude},${currentPosition.longitude}';

    // Ajouter chaque patient en tant qu'arrêt
    for (int i = 0; i < patients.length; i++) {
      final lat = patients[i]['latitude'];
      final lng = patients[i]['longitude'];
      if (i == 0) {
        url += '&daddr=$lat,$lng';
      } else {
        url += ' to:$lat,$lng';
      }
    }

    // Lancer l'URL
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final patient = patients.removeAt(oldIndex);
      patients.insert(newIndex, patient);
      _updatePatientOrder();
    });
  }

  void _updatePatientOrder() {
    for (int i = 0; i < patients.length; i++) {
      patients[i]['pivot']['order'] = i;
    }
    sendUpdatedOrder(); // Appeler la fonction pour envoyer l'ordre mis à jour
  }

  String getAddressBeforeComma(String address) {
    final addressParts = address.split(',');
    return addressParts[0];
  }
}
