import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../patients/PatientsListScreen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> data = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  DateTime? _selectedDate;
  late SecureStorageProvider.SecureStorageService secureStorageService;
  bool _isSearchBarVisible = false;
  Map<String, dynamic>? user;
  List<dynamic> tours = [];
  Map<String, dynamic>? selectedTour;
  List<Map<String, dynamic>> filteredData = [];
  File? _image;
  bool isLoadingMore = false;
  int limit = 15;
  int offset = 0;
  bool isDateFiltered = false;
  bool isSearchFiltered = false;

  @override
  void initState() {
    super.initState();
    secureStorageService = SecureStorageProvider.SecureStorageService();
    _getPosts(initialLoad: true);
    _loadUser();
    _searchController.addListener(_filterPosts);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Center(child: Text('Posts')),
          actions: [
            IconButton(
              icon: Icon(Icons.date_range,
                  color: _selectedDate == null ? Colors.green : Colors.red),
              onPressed: () async {
                if (isDateFiltered) {
                  setState(() {
                    _selectedDate = null;
                    isDateFiltered = false;
                    _getPosts(initialLoad: true);
                  });
                } else {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null && pickedDate != _selectedDate) {
                    setState(() {
                      _selectedDate = pickedDate;
                      isDateFiltered = true;
                    });
                    await _searchPostsByDate(pickedDate);
                  }
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                if (isSearchFiltered) {
                  setState(() {
                    _isSearchBarVisible = false;
                    isSearchFiltered = false;
                    _getPosts(initialLoad: true);
                  });
                } else {
                  setState(() {
                    _isSearchBarVisible = !_isSearchBarVisible;
                  });
                }
              },
            ),
          ],
        ),
        body: Container(
          color: Colors.green[100]?.withOpacity(0.1),
          child: Column(
            children: [
              if (_isSearchBarVisible)
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                    ),
                    cursorColor: Colors.green,
                    onChanged: (value) {
                      _searchPostsByQuery(value);
                    },
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      color: Colors.green[100]?.withOpacity(0.2),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo.metrics.pixels ==
                                  scrollInfo.metrics.maxScrollExtent &&
                              !isLoadingMore &&
                              !isDateFiltered &&
                              !isSearchFiltered) {
                            _getPosts();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          itemCount: filteredData.length,
                          itemBuilder: (context, index) {
                            return _buildItem(filteredData[index]);
                          },
                        ),
                      ),
                    ),
                    if (isLoadingMore)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.green,
          onPressed: () {
            _showAddMessageModal(context);
          },
          child: Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    String profilePictureUrl = item['user']['profile_picture'] != null
        ? 'https://api_swapinfi.lebourbier.be/storage/profile_pictures/${(item['user'] as Map<String, dynamic>?)?['profile_picture']}'
        : 'assets/user.png';
    String patientsAddresses = item['patients']
        .map((patient) => patient['city'])
        .toSet() // Convertit la liste en Set pour éliminer les doublons
        .join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: GestureDetector(
        onTap: () => _showDetailsModal(context, item),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: profilePictureUrl.startsWith('http')
                  ? NetworkImage(profilePictureUrl)
                  : AssetImage(profilePictureUrl) as ImageProvider,
            ),
            title: Text(
              item['title']!,
              style: TextStyle(fontSize: 18),
            ),
            subtitle: Text(
              patientsAddresses,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailsModal(BuildContext context, Map<String, dynamic> item) {
    bool canEdit = item['user_id'].toString() == user?['id'].toString() ||
        user?['role'] ==
            'admin'; // Afficher true si l'utilisateur peut modifier le contenu (son propre message ou un message en tant qu'admin
    TextEditingController editContentController =
        TextEditingController(text: item['content']);
    bool isEditingContent = false;
    String profilePictureUrl = item['user']['profile_picture'] != null
        ? 'https://api_swapinfi.lebourbier.be/storage/profile_pictures/${(item['user'] as Map<String, dynamic>?)?['profile_picture']}'
        : 'assets/user.png';

    String formattedDate = 'Unknown Date';
    if (item['date'] != null) {
      DateTime parsedDate = DateTime.parse(item['date']);
      formattedDate = DateFormat('dd/MM/yyyy').format(parsedDate);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return FractionallySizedBox(
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage:
                                profilePictureUrl.startsWith('http')
                                    ? NetworkImage(profilePictureUrl)
                                    : AssetImage(profilePictureUrl)
                                        as ImageProvider,
                          ),
                          SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title']!,
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Text(
                                ((item['user'] as Map<String, dynamic>?)?[
                                            'first_name'] ??
                                        'Unknown') +
                                    ' ' +
                                    ((item['user'] as Map<String, dynamic>?)?[
                                            'last_name'] ??
                                        ''),
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: canEdit && isEditingContent
                              ? TextField(
                                  controller: editContentController,
                                  maxLines: null,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Modifier le contenu',
                                  ),
                                )
                              : Text(
                                  item['content']!,
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          'Créé le $formattedDate',
                          style: TextStyle(
                              fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PatientsListScreen(
                                  user: user!,
                                  secureStorageService: secureStorageService,
                                  tourId: item['tour']['id'].toString(),
                                  patients: item['tour']['patients'],
                                  fromHomeScreen: false,
                                  canEdit: canEdit,
                                ),
                              ),
                            );
                            if (result == true) {
                              _getPosts();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, // Couleur de fond
                          ),
                          child: Text(
                              canEdit
                                  ? 'Tournée "${item['tour']['name']}"'
                                  : 'Voir la tournée',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (canEdit)
                              IconButton(
                                iconSize: 36.0,
                                icon: Icon(
                                  isEditingContent ? Icons.check : Icons.edit,
                                  color: isEditingContent
                                      ? Colors.green
                                      : Colors.blue,
                                ),
                                onPressed: () {
                                  if (isEditingContent) {
                                    _updatePost(item['id']!,
                                        editContentController.text);
                                    setState(() {
                                      isEditingContent = false;
                                      item['content'] =
                                          editContentController.text;
                                    });
                                  } else {
                                    setState(() {
                                      isEditingContent = true;
                                    });
                                  }
                                },
                              ),
                            if (!canEdit)
                              IconButton(
                                iconSize: 36.0,
                                icon: Icon(Icons.message, color: Colors.green),
                                onPressed: () {
                                  Navigator.pop(
                                      context); // Ferme le modal actuel
                                  _showMessageRequestModal(
                                      context, item); // Ouvre le nouveau modal
                                },
                              ),
                            if (canEdit)
                              IconButton(
                                iconSize: 36.0,
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text('Confirmer la suppression'),
                                        content: Text(
                                            'Voulez-vous vraiment supprimer cet élément ?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: Text('Annuler'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              _deletePost(item['id']!);
                                              Navigator.of(context).pop();
                                              Navigator.of(context)
                                                  .pop(); // Fermer le modal après la suppression
                                            },
                                            child: Text('Supprimer'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
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

  void _showAddMessageModal(BuildContext context) {
    DateTime? _selectedDate;

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
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        labelText: 'Contenu',
                        labelStyle: TextStyle(
                            color: Colors
                                .green), // Couleur verte du titre lorsque sélectionné
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 20.0,
                          horizontal: 20.0,
                        ),
                      ),
                      cursorColor: Colors.green,
                      style: TextStyle(fontSize: 20, color: Colors.green),
                      maxLines: 5,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (selectedDate != null) {
                          setState(() {
                            _selectedDate = selectedDate;
                          });
                        }
                      },
                      child: Text(
                        _selectedDate == null
                            ? 'Sélectionner une date'
                            : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                        style: TextStyle(color: Colors.white), // Police blanche
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: 20.0,
                          horizontal: 40.0,
                        ),
                        textStyle: TextStyle(
                            fontSize: 20,
                            color: Colors.white), // Police blanche
                        backgroundColor: Colors.green, // Couleur de fond verte
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        elevation: 10,
                        shadowColor: Colors.green.withOpacity(0.5),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _showPatientSelectionModal(context, setState);
                      },
                      child: Text(
                        selectedTour?['name'] ?? 'Sélectionner patients',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: 20.0,
                          horizontal: 40.0,
                        ),
                        textStyle: TextStyle(fontSize: 20),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        elevation: 10,
                        shadowColor: Colors.green.withOpacity(0.5),
                      ),
                    ),
                    SizedBox(height: 20),
                    IconButton(
                      onPressed: () {
                        if (_contentController.text.isNotEmpty &&
                            _selectedDate != null) {
                          String date =
                              DateFormat('dd/MM/yyyy').format(_selectedDate!);

                          _titleController.text = 'Remplacement $date';
                          _createPost(_titleController.text,
                              _contentController.text, _selectedDate!);
                          Navigator.pop(context);
                          _titleController.clear();
                          _contentController.clear();
                          _selectedDate = null;
                        }
                      },
                      icon: Icon(
                        Icons.check,
                        color: Colors.green, // Icône verte
                        size: 40,
                      ),
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

  void _showPatientSelectionModal(
      BuildContext context, StateSetter parentSetState) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sélectionner patients',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.group_add, color: Colors.green),
                  title: Text('Ajouter une tournée complète'),
                  onTap: () {
                    _showTourModal(context, parentSetState);
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.person_add, color: Colors.blue),
                  title: Text('Ajouter patient par patient'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientsListScreen(
                          user: user!,
                          secureStorageService: secureStorageService,
                          fromHomeScreen: true, // Passer le paramètre
                        ),
                      ),
                    ).then((newTour) {
                      if (newTour != null) {
                        Navigator.pop(context);
                        setState(() {
                          selectedTour = newTour;
                        });
                        parentSetState(() {
                          selectedTour = newTour;
                        });
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _searchPostsByDate(DateTime date) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/post/search/date/${DateFormat('yyyy-MM-dd').format(date)}';
    final String? accessToken = await secureStorageService.getToken('Bearer');

    if (accessToken == null) {
      print('accessToken is null');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);

        final List<Map<String, dynamic>> posts = body
            .map((dynamic item) {
              if (item is Map) {
                return item
                    .map((key, value) => MapEntry(key.toString(), value));
              } else {
                // Gérer d'autres types si nécessaire
                return {};
              }
            })
            .toList()
            .cast<Map<String, dynamic>>();

        setState(() {
          data.clear();
          for (var p in posts) {
            data.add({
              'id': p['id'].toString(),
              'title': p['title'].toString(),
              'content': p['content'].toString(),
              'date': p['created_at'],
              'replace_date': p['replace_date']?.toString(),
              'user_id': p['user_id'].toString(),
              'user': p['user'],
              'patients': p['tour']['patients'],
              'tour': p['tour']
            });
          }
          filteredData = List.from(data);
        });
      } else {
        print('Failed to load posts');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _searchPostsByQuery(String query) async {
    if (query.isEmpty) {
      setState(() {
        isSearchFiltered = false;
        _getPosts(initialLoad: true);
      });
      return;
    }

    setState(() {
      isSearchFiltered = true;
      isLoadingMore = true;
    });

    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/post/search/$query';
    final String? accessToken = await secureStorageService.getToken('Bearer');

    if (accessToken == null) {
      print('accessToken is null');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);

        final List<Map<String, dynamic>> posts = body
            .map((dynamic item) {
              if (item is Map) {
                return item
                    .map((key, value) => MapEntry(key.toString(), value));
              } else {
                return {};
              }
            })
            .toList()
            .cast<Map<String, dynamic>>();

        setState(() {
          data.clear();
          for (var p in posts) {
            data.add({
              'id': p['id'].toString(),
              'title': p['title'].toString(),
              'content': p['content'].toString(),
              'date': p['created_at'],
              'replace_date': p['replace_date']?.toString(),
              'user_id': p['user_id'].toString(),
              'user': p['user'],
              'patients': p['tour']['patients'],
              'tour': p['tour']
            });
          }
          filteredData = List.from(data);
          isLoadingMore = false;
        });
      } else {
        print('Failed to load posts');
        setState(() {
          isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  void _showTourModal(BuildContext context, StateSetter parentSetState) {
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
                                          color: Colors.green[300],
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
                                            setState(() {
                                              selectedTour = tour;
                                            });
                                            parentSetState(() {
                                              selectedTour = tour;
                                            });
                                            Navigator.pop(
                                                context); // Fermer le modal de sélection de tournée
                                            Navigator.pop(
                                                context); // Fermer le modal de sélection de patients
                                          },
                                        ),
                                      ))
                                  .toList(),
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

  void _showMessageRequestModal(
      BuildContext context, Map<String, dynamic> post) {
    TextEditingController _messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Envoyer une demande',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    labelStyle: TextStyle(color: Colors.green),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 20.0,
                    ),
                  ),
                  cursorColor: Colors.green,
                  style: TextStyle(fontSize: 20, color: Colors.green),
                  maxLines: 5,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_messageController.text.isNotEmpty) {
                      _sendMessage(post, _messageController.text);
                      Navigator.pop(context);
                    }
                  },
                  child: Text('Envoyer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendMessage(Map<String, dynamic> post, String content) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/message/create';
    final String? accessToken = await secureStorageService.getToken('Bearer');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user1_id': user!['id'],
        'user2_id': post['user']['id'],
        'content': content,
        'post_id': post['id'], // Envoi le post ID avec le message
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Message envoyé avec succès'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de l\'envoi du message'),
      ));
    }
  }

  Future<void> _createPost(String title, String content, DateTime date) async {
    final String apiUrl = 'https://api_swapinfi.lebourbier.be/api/post/create';
    final String? accessToken = await secureStorageService.getToken('Bearer');

    if (accessToken == null) {
      print('accessToken is null');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'title': title,
          'content': content,
          'replace_date': date.toIso8601String(),
          'tour_id': selectedTour?['id'],
        }),
      );

      if (response.statusCode == 200) {
        _getPosts(initialLoad: true);
        selectedTour = null;
      } else {
        print('Failed to create post');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _getPosts({bool initialLoad = false}) async {
    if (initialLoad) {
      setState(() {
        offset = 0;
        isLoadingMore = true;
      });
    } else {
      setState(() {
        isLoadingMore = true;
      });
    }

    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/post?limit=$limit&offset=$offset';
    final String? accessToken = await secureStorageService.getToken('Bearer');

    if (accessToken == null) {
      print('accessToken is null');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);

        final List<Map<String, dynamic>> posts = body
            .map((dynamic item) {
              if (item is Map) {
                return item
                    .map((key, value) => MapEntry(key.toString(), value));
              } else {
                return {};
              }
            })
            .toList()
            .cast<Map<String, dynamic>>();

        setState(() {
          if (initialLoad) {
            data.clear();
          }
          for (var p in posts) {
            data.add({
              'id': p['id'].toString(),
              'title': p['title'].toString(),
              'content': p['content'].toString(),
              'date': p['created_at'],
              'user_id': p['user_id'].toString(),
              'user': p['user'],
              'patients': p['tour']['patients'],
              'tour': p['tour']
            });
          }
          filteredData = List.from(data);
          offset += limit;
          isLoadingMore = false;
        });
      } else {
        print('Failed to load posts');
        setState(() {
          isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  Future<void> _deletePost(String id) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/post/delete/$id';
    final String? accessToken = await secureStorageService.getToken('Bearer');

    if (accessToken == null) {
      print('accessToken is null');
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 204) {
        setState(() {
          filteredData.removeWhere((element) => element['id'] == id);
        });
      } else {
        print('Failed to delete post');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _updatePost(String id, String content) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/post/update/$id';
    final String? accessToken = await secureStorageService.getToken('Bearer');

    if (accessToken == null) {
      print('accessToken is null');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          data.firstWhere((element) => element['id'] == id)['content'] =
              content;
        });
      } else {
        print('Failed to update post');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString('user');

    if (userJson != null) {
      setState(() {
        user = jsonDecode(userJson);
      });
      _getTours();
    }
  }

  Future<void> _getTours() async {
    // Implement API call to fetch tours
    // Example:
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/${user!['id']}';
    final String? accessToken = await secureStorageService.getToken('Bearer');
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

  void _filterPosts() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      filteredData = data.where((item) {
        final title = item['title']?.toLowerCase() ?? '';
        final addresses = item['patients']
            .map((patient) => patient['city'].toLowerCase())
            .join(', ');

        return title.contains(query) || addresses.contains(query);
      }).toList();
    });
  }
}
