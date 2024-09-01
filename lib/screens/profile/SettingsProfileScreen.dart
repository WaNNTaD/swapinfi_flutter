import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import 'dart:convert';
import 'dart:io';
import 'ProfileScreen.dart';

class SettingsProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final SecureStorageProvider.SecureStorageService secureStorageService;
  final Function(Map<String, dynamic>) onProfileUpdated;

  SettingsProfileScreen({
    required this.user,
    required this.secureStorageService,
    required this.onProfileUpdated,
  });

  @override
  _SettingsProfileScreenState createState() => _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends State<SettingsProfileScreen> {
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _phoneController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool isEmailValid = true;

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.user['description'] ?? '';
    _emailController.text = widget.user['email'] ?? '';
    _phoneController.text = widget.user['phone'] ?? '';
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfilePicture(File image) async {
    final url =
        'https://api_swapinfi.lebourbier.be/api/user/update-picture/${widget.user['id']}';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Photo de profil mise à jour avec succès'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour de la photo de profil'),
      ));
    }
  }

  Future<void> _updateProfile() async {
    if (!validateEmail(_emailController.text)) {
      setState(() {
        isEmailValid = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Veuillez entrer une adresse e-mail valide.'),
      ));
      return;
    }

    setState(() {
      isEmailValid = true;
    });

    final url =
        'https://api_swapinfi.lebourbier.be/api/user/update/${widget.user['id']}';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'description': _descriptionController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
      }),
    );

    if (response.statusCode == 200) {
      final updatedUser = {
        'id': widget.user['id'],
        'first_name': widget.user['first_name'],
        'last_name': widget.user['last_name'],
        'description': _descriptionController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'profile_picture': widget.user['profile_picture'],
      };
      widget.onProfileUpdated(
          updatedUser); // Appeler le callback avec les nouvelles données
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Profil mis à jour avec succès'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour du profil'),
      ));
    }
  }

  bool validateEmail(String email) {
    String pattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    RegExp regex = RegExp(pattern);
    return regex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paramètres du profil'),
      ),
      body: Container(
        color: Colors.green[100]?.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              GestureDetector(
                onTap: () => _showImageSourceActionSheet(context),
                child: CircleAvatar(
                  radius: 50,
                  child: ClipOval(
                    child: Image(
                      image: _image != null
                          ? FileImage(_image!)
                          : (widget.user['profile_picture'] != null
                              ? NetworkImage(
                                  'https://api_swapinfi.lebourbier.be/storage/profile_pictures/${widget.user['profile_picture']}')
                              : AssetImage(
                                  'assets/default_profile.png')) as ImageProvider,
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
                  labelStyle: TextStyle(fontSize: 16, color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
                maxLines: 3,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(fontSize: 16, color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                  errorText: isEmailValid ? null : 'Adresse e-mail invalide',
                ),
                cursorColor: Colors.green,
                onChanged: (value) {
                  setState(() {
                    isEmailValid = validateEmail(value);
                  });
                },
              ),
              SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Téléphone',
                  labelStyle: TextStyle(fontSize: 16, color: Colors.green),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isEmailValid ? _updateProfile : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'Enregistrer',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _showChangePasswordModal(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // Fond transparent
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                    side: BorderSide(color: Colors.green), // Contour vert
                  ),
                ),
                child: Text(
                  'Modifier mot de passe',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
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

  void _showChangePasswordModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ChangePasswordForm(
            secureStorageService: widget.secureStorageService,
            user: widget.user,
          ),
        );
      },
    );
  }
}

class ChangePasswordForm extends StatefulWidget {
  final SecureStorageProvider.SecureStorageService secureStorageService;
  final Map<String, dynamic> user;

  ChangePasswordForm({required this.secureStorageService, required this.user});

  @override
  _ChangePasswordFormState createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isOldPasswordValid = true;
  String? _newPasswordError;
  bool _showErrors = false;
  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Map<String, bool> _passwordCriteria = {
    'au moins 8 caractères': false,
    'une lettre majuscule': false,
    'un chiffre': false,
    'un caractère spécial': false,
  };

  void _validatePassword(String password) {
    _passwordCriteria['au moins 8 caractères'] = password.length >= 8;
    _passwordCriteria['une lettre majuscule'] =
        password.contains(RegExp(r'[A-Z]'));
    _passwordCriteria['un chiffre'] = password.contains(RegExp(r'\d'));
    _passwordCriteria['un caractère spécial'] =
        password.contains(RegExp(r'[!@#\$&*~]'));

    if (_passwordCriteria.values.every((criteria) => criteria)) {
      _newPasswordError = null;
    } else {
      _newPasswordError = 'Le mot de passe doit contenir :\n' +
          _passwordCriteria.entries
              .where((entry) => !entry.value)
              .map((entry) => entry.key)
              .join('\n');
    }
  }

  Future<void> _changePassword() async {
    setState(() {
      _isOldPasswordValid = _oldPasswordController.text.isNotEmpty;
      _validatePassword(_newPasswordController.text);
      _showErrors = true; // Set to true to show errors
    });

    if (!_isOldPasswordValid ||
        _newPasswordError != null ||
        _newPasswordController.text != _confirmPasswordController.text) {
      return;
    }

    final url = 'https://api_swapinfi.lebourbier.be/api/user/change-password';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'email': widget.user['email'],
        'password': _newPasswordController.text,
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Mot de passe modifié avec succès'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la modification du mot de passe'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _oldPasswordController,
            decoration: InputDecoration(
              labelText: 'Ancien mot de passe',
              labelStyle: TextStyle(color: Colors.green),
              errorText: _showErrors && !_isOldPasswordValid
                  ? 'Ancien mot de passe requis'
                  : null,
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isOldPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _isOldPasswordVisible = !_isOldPasswordVisible;
                  });
                },
              ),
            ),
            obscureText: !_isOldPasswordVisible,
            cursorColor: Colors.green,
          ),
          SizedBox(height: 10),
          TextField(
            controller: _newPasswordController,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              labelStyle: TextStyle(color: Colors.green),
              errorText: _showErrors ? _newPasswordError : null,
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isNewPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _isNewPasswordVisible = !_isNewPasswordVisible;
                  });
                },
              ),
            ),
            onChanged: _validatePassword,
            obscureText: !_isNewPasswordVisible,
            cursorColor: Colors.green,
          ),
          SizedBox(height: 10),
          TextField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Confirmer le nouveau mot de passe',
              labelStyle: TextStyle(color: Colors.green),
              errorText: _showErrors &&
                      _newPasswordController.text !=
                          _confirmPasswordController.text
                  ? 'Les mots de passe ne correspondent pas'
                  : null,
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
            ),
            obscureText: !_isConfirmPasswordVisible,
            cursorColor: Colors.green,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'Valider',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
