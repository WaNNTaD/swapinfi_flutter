import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import '../profile/ProfileVisitorScreen.dart';

class SearchUserScreen extends StatefulWidget {
  final SecureStorageProvider.SecureStorageService secureStorageService;

  SearchUserScreen({required this.secureStorageService});

  @override
  _SearchUserScreenState createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _searchHistory = [];
  Timer? _debounce;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();

    _searchController.addListener(() {
      _onSearchChanged();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(() {
      _onSearchChanged();
    });
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _loadSearchHistory() async {
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.get(
      Uri.parse('https://api_swapinfi.lebourbier.be/api/search'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      setState(() {
        _searchHistory = data
            .map((item) => {
                  'id': item['id'],
                  'user_id': item['searched_user']['id'],
                  'first_name': item['searched_user']['first_name'],
                  'last_name': item['searched_user']['last_name'],
                  'profile_picture': item['searched_user']['profile_picture']
                })
            .toList();
      });
    } else {
      print('Erreur de chargement de l\'historique des recherches');
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true; // Start loading
    });

    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.get(
      Uri.parse('https://api_swapinfi.lebourbier.be/api/user/search/$query'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      setState(() {
        _searchResults =
            data.map((item) => item as Map<String, dynamic>).toList();
        _isLoading = false; // Stop loading
      });
    } else {
      setState(() {
        _isLoading = false; // Stop loading on error
        _searchResults = []; // Clear results on error
      });
      print('Erreur lors de la recherche');
    }
  }

  Future<void> _saveSearch(String userId) async {
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.post(
      Uri.parse('https://api_swapinfi.lebourbier.be/api/search/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'searched_user_id': userId}),
    );

    if (response.statusCode == 200) {
      _loadSearchHistory();
      // Navigate to ProfileVisitorScreen with the user ID
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileVisitorScreen(
            userId: userId,
            secureStorageService: widget.secureStorageService,
          ),
        ),
      );
    } else {
      print('Erreur lors de l\'enregistrement de la recherche');
    }
  }

  Future<void> _deleteSearch(String searchId) async {
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.delete(
      Uri.parse(
          'https://api_swapinfi.lebourbier.be/api/search/delete/$searchId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      // Supprimez la recherche localement si la suppression sur le serveur a réussi
      setState(() {
        _searchHistory.removeWhere((item) => item['id'].toString() == searchId);
      });
    } else {
      // Gérer les erreurs ici
      print('Erreur de suppression de la recherche');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rechercher des utilisateurs'),
      ),
      body: Container(
        color: Colors.green[100]?.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un utilisateur...',
                  suffixIcon: Icon(Icons.search),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                cursorColor: Colors.green,
              ),
              SizedBox(height: 10),
              if (_searchController.text.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recherches récentes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: Colors.green))
                    : _searchController.text.isEmpty
                        ? ListView.builder(
                            itemCount: _searchHistory.length,
                            itemBuilder: (context, index) {
                              final item = _searchHistory[index];
                              String profilePictureUrl = item[
                                          'profile_picture'] !=
                                      null
                                  ? 'https://api_swapinfi.lebourbier.be/storage/profile_pictures/${item['profile_picture']}'
                                  : 'assets/user.png';
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      profilePictureUrl.startsWith('http')
                                          ? NetworkImage(profilePictureUrl)
                                          : AssetImage(profilePictureUrl)
                                              as ImageProvider,
                                ),
                                title: Text(
                                  '${item['first_name']} ${item['last_name']}',
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.close, color: Colors.grey),
                                  onPressed: () {
                                    _deleteSearch(item['id'].toString());
                                  },
                                ),
                                onTap: () {
                                  _performSearch(
                                      '${item['first_name']} ${item['last_name']}');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProfileVisitorScreen(
                                        userId: item['user_id'].toString(),
                                        secureStorageService:
                                            widget.secureStorageService,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          )
                        : _searchResults.isEmpty
                            ? Center(child: Text('Aucun résultat'))
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final item = _searchResults[index];
                                  String profilePictureUrl = item[
                                              'profile_picture'] !=
                                          null
                                      ? 'https://api_swapinfi.lebourbier.be/storage/profile_pictures/${item['profile_picture']}'
                                      : 'assets/user.png';
                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 20,
                                      backgroundImage:
                                          profilePictureUrl.startsWith('http')
                                              ? NetworkImage(profilePictureUrl)
                                              : AssetImage(profilePictureUrl)
                                                  as ImageProvider,
                                    ),
                                    title: Text(
                                      '${item['first_name']} ${item['last_name']}',
                                    ),
                                    onTap: () {
                                      _saveSearch(item['id'].toString());
                                    },
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
