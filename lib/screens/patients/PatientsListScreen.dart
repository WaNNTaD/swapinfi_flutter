import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import 'package:new_swapinfi/screens/tours/TourManagementScreen.dart';
import 'dart:async';

class PatientsListScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final SecureStorageProvider.SecureStorageService secureStorageService;
  final List<String>? patientsId;
  final List<dynamic>? patients;
  final String? tourId;
  final bool fromHomeScreen;
  final bool canEdit;
  final bool showFullDetails;
  final List<dynamic>? replacementPatients;

  PatientsListScreen(
      {required this.user,
      required this.secureStorageService,
      this.patientsId,
      this.patients,
      this.tourId,
      this.fromHomeScreen = false,
      this.canEdit = true,
      this.showFullDetails = false,
      this.replacementPatients});

  @override
  _PatientsListScreenState createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends State<PatientsListScreen> {
  List<dynamic>? patients;
  List<dynamic>? filteredPatients;

  List<String> selectedPatientIds = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.patients != null) {
      setState(() {
        patients = widget.patients;
        filteredPatients = patients;
      });
    } else {
      _getPatients();
    }
    _checkUserIds();
    _searchController.addListener(_filterPatients);
  }

  void _checkUserIds() {
    if (widget.patientsId != null) {
      setState(() {
        selectedPatientIds = widget.patientsId!;
      });
    } else if (widget.patients != null) {
      setState(() {
        selectedPatientIds = widget.patients!
            .map((patient) => patient['id'].toString())
            .toList();
      });
    }
  }

  Future<void> _getPatients() async {
    if (widget.patients != null) {
      setState(() {
        patients = widget.patients;
        filteredPatients = patients;
      });
      return;
    }
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/patient/${widget.user['id']}';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        patients = jsonDecode(response.body);
        filteredPatients = patients;
      });
      if (widget.replacementPatients != null) {
        setState(() {
          if (patients == null) {
            patients = widget.replacementPatients;
            for (var patient in patients!) {
              selectedPatientIds.add(patient['id'].toString());
            }
          } else {
            patients!.addAll(widget.replacementPatients!);
            for (var patient in widget.replacementPatients!) {
              selectedPatientIds.add(patient['id'].toString());
            }
          }
        });
      }
    } else {
      print('Failed to load patients');
    }
  }

  Future<void> createTour(String tourName) async {
    final String apiUrl = 'https://api_swapinfi.lebourbier.be/api/tour/create';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': tourName,
        'ids': selectedPatientIds,
      }),
    );

    if (response.statusCode == 200) {
      final newTour = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tournée créée avec succès'),
      ));
      if (widget.fromHomeScreen) {
        Navigator.pop(context, newTour); // Pass the new tour back
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la création de la tournée'),
      ));
    }
  }

  Future<void> _updateTour() async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/update/${widget.tourId}';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.put(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'ids': selectedPatientIds,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tournée mise à jour avec succès'),
      ));
      if (widget.patients != null) {
        Navigator.pop(context, true);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TourManagementScreen(
              tourId: widget.tourId.toString(),
              secureStorageService: widget.secureStorageService,
              user: widget.user,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour de la tournée'),
      ));
    }
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredPatients = patients?.where((patient) {
        final firstName = patient['firstName']?.toLowerCase() ?? '';
        final lastName = patient['lastName']?.toLowerCase() ?? '';
        final city = patient['city']?.toLowerCase();
        return firstName.contains(query) ||
            lastName.contains(query) ||
            city.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patients != null
            ? 'Liste des patients'
            : 'Selectionner des patients'),
      ),
      body: Container(
        color: Colors.green[100]?.withOpacity(0.2), // Ajout du fond vert
        child: Column(
          children: [
            if (widget
                .canEdit) // Afficher le champ de recherche seulement si l'utilisateur peut éditer
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  cursorColor: Colors.green,
                  decoration: InputDecoration(
                    labelText: 'Rechercher',
                    labelStyle: TextStyle(color: Colors.green),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: filteredPatients == null
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: filteredPatients!.length,
                      itemBuilder: (context, index) {
                        final patient = filteredPatients![index];
                        return ListTile(
                          leading: Icon(Icons.person),
                          title: Text(
                              '${patient['lastName'] ?? 'Nom inconnu'} ${patient['firstName'] ?? 'Prénom inconnu'}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Date de naissance: ${patient['dateOfBirth'] ?? 'Non renseignée'}'),
                              Text(
                                  'Ville: ${patient['city'] ?? 'Adresse non renseignée'}'),
                            ],
                          ),
                          trailing: widget.canEdit
                              ? widget.replacementPatients != null &&
                                      widget.replacementPatients!
                                          .contains(patient)
                                  ? Icon(Icons.swap_horiz, color: Colors.green)
                                  : Icon(
                                      selectedPatientIds.contains(
                                              patient['id'].toString())
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                    )
                              : null,
                          tileColor: widget.replacementPatients != null &&
                                  widget.replacementPatients!.contains(patient)
                              ? Colors.green[50]
                              : null,
                          onTap: !widget.canEdit ||
                                  (widget.replacementPatients != null &&
                                      widget.replacementPatients!
                                          .contains(patient))
                              ? () {
                                  _showPatientDetailsModal(context, patient);
                                }
                              : () {
                                  setState(() {
                                    if (selectedPatientIds
                                        .contains(patient['id'].toString())) {
                                      selectedPatientIds
                                          .remove(patient['id'].toString());
                                    } else {
                                      selectedPatientIds
                                          .add(patient['id'].toString());
                                    }
                                  });
                                },
                          onLongPress: widget.canEdit
                              ? () {
                                  _showPatientDetailsModal(context, patient);
                                }
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget
              .canEdit // Afficher les boutons d'action seulement si l'utilisateur peut éditer
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _toggleSelectAllPatients,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.select_all),
                  heroTag: null,
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: selectedPatientIds.isEmpty
                      ? null
                      : () {
                          if (widget.tourId != null) {
                            // Call the update function if tourId exists
                            _updateTour();
                          } else {
                            // Show the create tour modal if tourId does not exist
                            _showCreateTourModal(context);
                          }
                        },
                  backgroundColor:
                      selectedPatientIds.isEmpty ? Colors.grey : Colors.green,
                  child: Icon(Icons.check),
                  heroTag: null,
                ),
              ],
            )
          : null,
    );
  }

  void _showCreateTourModal(BuildContext context) {
    TextEditingController _tourNameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _tourNameController,
                  cursorColor: Colors.green,
                  decoration: InputDecoration(
                    labelText: 'Nom de la tournée',
                    labelStyle: TextStyle(color: Colors.green),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    createTour(_tourNameController.text);
                    Navigator.pop(context);
                  },
                  child: Icon(Icons.check),
                  style: ElevatedButton.styleFrom(
                    iconColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPatientDetailsModal(
      BuildContext context, Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return FractionallySizedBox(
              widthFactor: 1.0, // Prendre toute la largeur
              heightFactor: 0.75,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Détails du patient',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                  children: [
                                    TextSpan(
                                        text: 'Nom: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextSpan(
                                        text:
                                            '${patient['lastName']} ${patient['firstName']}'),
                                  ],
                                ),
                              ),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                  children: [
                                    TextSpan(
                                        text: 'Date de naissance: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextSpan(text: '${patient['dateOfBirth']}'),
                                  ],
                                ),
                              ),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                  children: [
                                    TextSpan(
                                        text: 'Sexe: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextSpan(text: '${patient['sexe']}'),
                                  ],
                                ),
                              ),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                  children: [
                                    TextSpan(
                                        text: 'Ville: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextSpan(text: '${patient['city']}'),
                                  ],
                                ),
                              ),
                              if (!widget.canEdit)
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black),
                                    children: [
                                      TextSpan(
                                          text: 'Note: ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      TextSpan(
                                          text:
                                              '${patient['note'] ?? 'Pas de note'}'),
                                    ],
                                  ),
                                ),
                              if (widget.canEdit || widget.showFullDetails) ...[
                                SizedBox(height: 10),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black),
                                    children: [
                                      TextSpan(
                                          text: 'Adresse: ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      TextSpan(
                                          text:
                                              '${patient['address'] ?? 'Adresse non renseignée'}'),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black),
                                    children: [
                                      TextSpan(
                                          text: 'Téléphone: ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      TextSpan(text: '${patient['phone']}'),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black),
                                    children: [
                                      TextSpan(
                                          text: 'Niss: ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      TextSpan(text: '${patient['niss']}'),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black),
                                    children: [
                                      TextSpan(
                                          text: 'Numéro de carte: ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      TextSpan(
                                          text: '${patient['numberIdCard']}'),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black),
                                    children: [
                                      TextSpan(
                                          text: 'Note: ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      TextSpan(
                                          text:
                                              '${patient['note'] ?? 'Pas de note'}'),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (widget.canEdit && widget.replacementPatients == null)
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              _showSharePatientModal(context, patient);
                            },
                            child: Text(
                              'Partager ce patient avec une infirmière',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSharePatientModal(
      BuildContext context, Map<String, dynamic> patient) {
    TextEditingController _searchController = TextEditingController();
    List<dynamic> searchResults = [];
    Timer? _debounce;

    Future<void> _searchUsers(String query) async {
      final String apiUrl =
          'https://api_swapinfi.lebourbier.be/api/user/search/$query';
      final String? accessToken =
          await widget.secureStorageService.getToken('Bearer');

      final response = await http.get(
        Uri.parse('$apiUrl?query=$query'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        searchResults = jsonDecode(response.body);
        setState(() {});
      } else {
        print('Failed to search users');
      }
    }

    Future<void> _sharePatientWithUser(int userId) async {
      final String apiUrl =
          'https://api_swapinfi.lebourbier.be/api/patient/attach/$userId/${patient['id']}';
      final String? accessToken =
          await widget.secureStorageService.getToken('Bearer');

      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Patient partagé avec succès'),
        ));
        Navigator.pop(context); // Close the modal
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Échec du partage du patient'),
        ));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            _searchController.addListener(() {
              if (_debounce?.isActive ?? false) _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                if (_searchController.text.isNotEmpty) {
                  _searchUsers(_searchController.text);
                } else {
                  setState(() {
                    searchResults.clear();
                  });
                }
              });
            });

            return FractionallySizedBox(
              widthFactor: 1.0,
              heightFactor: 0.75,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partager ce patient avec une infirmière',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _searchController,
                        cursorColor: Colors.green,
                        decoration: InputDecoration(
                          labelText: 'Rechercher par nom ou prénom',
                          labelStyle: TextStyle(color: Colors.green),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final user = searchResults[index];
                            return ListTile(
                              leading: Icon(Icons.person),
                              title: Text(
                                  '${user['first_name']} ${user['last_name']}'),
                              onTap: () => _sharePatientWithUser(user['id']),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleSelectAllPatients() {
    setState(() {
      if (selectedPatientIds.length == filteredPatients!.length) {
        selectedPatientIds.clear();
      } else {
        selectedPatientIds = filteredPatients!
            .map((patient) => patient['id'].toString())
            .toList();
      }
    });
  }
}
