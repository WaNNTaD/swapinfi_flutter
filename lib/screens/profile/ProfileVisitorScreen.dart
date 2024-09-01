import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;

class ProfileVisitorScreen extends StatefulWidget {
  final String userId;
  final SecureStorageProvider.SecureStorageService secureStorageService;

  ProfileVisitorScreen(
      {required this.userId, required this.secureStorageService});

  @override
  _ProfileVisitorScreenState createState() => _ProfileVisitorScreenState();
}

class _ProfileVisitorScreenState extends State<ProfileVisitorScreen> {
  Map<String, dynamic>? user;
  Map<String, dynamic>? currentUser;
  List<dynamic> regions = [];
  TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getUserById(widget.userId);
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
      _getRegions();
    }
  }

  Future<void> _getUserById(String userId) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/user/show/$userId';
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
    if (user == null) return;

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

  void _showMessageModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Envoyer un message privé',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    labelStyle:
                        TextStyle(color: Colors.green), // Label text color
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.green), // Border color when focused
                    ),
                  ),
                  cursorColor: Colors.green, // Cursor color
                  maxLines: 4,
                  style: TextStyle(color: Colors.green), // Text color
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_messageController.text.isNotEmpty) {
                      _sendMessage(_messageController.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // background color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text('Envoyer', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendMessage(String message) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/message/create';
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
        'user1_id': currentUser?[
            'id'], // Assuming this method gets the current user's ID
        'user2_id': user!['id'],
        'content': message,
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Message envoyé avec succès'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de l\'envoi du message'),
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
        title: Text('Profil de ${user!['first_name']} ${user!['last_name']}'),
      ),
      body: Container(
        color: Colors.green[100]?.withOpacity(0.2),
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: profilePictureUrl.startsWith('http')
                      ? NetworkImage(profilePictureUrl)
                      : AssetImage(profilePictureUrl) as ImageProvider,
                ),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user!['first_name']} ${user!['last_name']}',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text('Infirmier(ère)'),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _showMessageModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // background color
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Envoyer un message privé',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 10),
            if (user!['description'] != null && user!['description'].isNotEmpty)
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text('${user!['description']}'),
                  ],
                ),
              ),
            SizedBox(height: 20),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            SizedBox(height: 20),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    );
  }
}
