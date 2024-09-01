import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import 'dart:convert';
import 'dart:io';
import '../patients/PatientsListScreen.dart';
import '../tours/TourManagementScreen.dart';
import 'SettingsProfileScreen.dart';

class ProfileScreen extends StatefulWidget {
  final SecureStorageProvider.SecureStorageService secureStorageService;

  ProfileScreen({required this.secureStorageService});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? user;
  List<dynamic> regions = [];
  List<dynamic> tours = [];
  final ImagePicker _picker = ImagePicker();
  File? _image;

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
        user = jsonDecode(response.body);
      });
      _getRegions();
    }
  }

  Future<void> _getRegions() async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/patient/region/${user!['id']}';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');
    final response = await http.get(Uri.parse(apiUrl), headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      setState(() {
        regions = jsonDecode(response.body);
      });
    }
  }

  Future<void> _getTours() async {
    // Implement API call to fetch tours
    // Example:
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/${user!['id']}';
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

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _updateProfilePicture(File(pickedFile.path));
    }
  }

  Future<void> _updateProfilePicture(File image) async {
    final url =
        'https://api_swapinfi.lebourbier.be/api/user/update-picture/${user!['id']}';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..files
          .add(await http.MultipartFile.fromPath('profile_picture', image.path))
      ..headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      });

    final response = await request.send();

    if (response.statusCode == 302) {
      // Actualiser les données de l'utilisateur
      _getCurrentUser();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Photo de profil mise à jour avec succès'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour de la photo de profil'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    String profilePictureUrl = user!['profile_picture'] != null &&
            user!['profile_picture'].isNotEmpty
        ? 'https://api_swapinfi.lebourbier.be/storage/profile_pictures/${user!['profile_picture']}'
        : 'assets/default_profile.png';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Profil'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsProfileScreen(
                    user: user!,
                    secureStorageService: widget.secureStorageService,
                    onProfileUpdated: (updatedUser) {
                      setState(() {
                        user = updatedUser;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.green[100]?.withOpacity(0.2),
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showImageSourceActionSheet(context),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _image != null
                                ? FileImage(_image!)
                                : (profilePictureUrl.startsWith('http')
                                        ? NetworkImage(profilePictureUrl)
                                        : AssetImage(profilePictureUrl))
                                    as ImageProvider,
                          ),
                        ),
                        SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user!['first_name']} ${user!['last_name']}',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text('Infirmier(ère)'),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    if (user!['description'] != null &&
                        user!['description'].isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Description',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text('${user!['description']}'),
                          ],
                        ),
                      ),
                    SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          Center(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.email, color: Colors.green),
                                    SizedBox(width: 10),
                                    Text('${user!['email']}'),
                                  ],
                                ),
                                SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(Icons.phone, color: Colors.green),
                                    SizedBox(width: 10),
                                    Text('${user!['phone']}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        await _getTours();
                        _showTourModal(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        'Tournées',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Régions couvertes',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          if (regions.isEmpty)
                            Center(
                              child: Text('Aucune région couverte'),
                            ),
                          if (regions.isNotEmpty)
                            Text(
                              regions.map((region) => region).join(', '),
                              style: TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Galerie'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Appareil photo'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTourModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Vos Tournées',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Expanded(
                        child: ListView(
                          shrinkWrap: true,
                          children: tours.isEmpty
                              ? [
                                  Center(
                                      child: Text('Aucune tournée disponible'))
                                ]
                              : tours
                                  .map((tour) => Container(
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.8),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
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
                                            ),
                                          ),
                                          trailing: Icon(Icons.chevron_right),
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TourManagementScreen(
                                                        tourId: tour['id']
                                                            .toString(),
                                                        secureStorageService: widget
                                                            .secureStorageService,
                                                        user: user!),
                                              ),
                                            );
                                          },
                                        ),
                                      ))
                                  .toList(),
                        ),
                      ),
                      SizedBox(height: 10),
                      Center(
                        child: IconButton(
                          iconSize: 50,
                          icon: Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PatientsListScreen(
                                    user: user!,
                                    secureStorageService:
                                        widget.secureStorageService),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
