import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../login/SignInScreen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String accessToken;

  ProfileSetupScreen({required this.user, required this.accessToken});

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  File? _image;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
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

  Future<void> _updateProfilePicture(File image) async {
    final url =
        'https://api_swapinfi.lebourbier.be/api/user/update-picture/${widget.user['id']}';
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..files
          .add(await http.MultipartFile.fromPath('profile_picture', image.path))
      ..headers.addAll({
        'Authorization': 'Bearer ${widget.accessToken}',
        'Accept': 'application/json',
      });

    final response = await request.send();

    if (response.statusCode == 302) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Photo de profil mise à jour avec succès'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour de la photo de profil'),
      ));
    }
  }

  Future<void> _handleProfileSetup() async {
    final description = _descriptionController.text;
    if (_image != null) {
      await _updateProfilePicture(_image!);
    }

    final response = await http.put(
      Uri.parse(
          'https://api_swapinfi.lebourbier.be/api/user/update/${widget.user['id']}'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.accessToken}',
      },
      body: jsonEncode({
        'description': description,
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la configuration du profil')),
      );
    }
  }

  void _skipProfileSetup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[200],
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            Text(
              'Configurer le profil',
              style: TextStyle(
                color: Colors.green[900],
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () => _showImageSourceActionSheet(context),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green[200],
                child: _image != null
                    ? ClipOval(
                        child: Image.file(
                          _image!,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                        ),
                      )
                    : ClipOval(
                        child: Image.asset(
                          'assets/default_profile.png',
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.green),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleProfileSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(
                'Enregistrer',
                style: TextStyle(color: Colors.green, fontSize: 18),
              ),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: _skipProfileSetup,
              child: Text(
                'Pas maintenant',
                style: TextStyle(color: Colors.green[900], fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
