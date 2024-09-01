import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import 'dart:convert';
import 'ConversationScreen.dart';

class ConversationsListScreen extends StatefulWidget {
  final SecureStorageProvider.SecureStorageService secureStorageService;

  ConversationsListScreen({required this.secureStorageService});

  @override
  _ConversationsListScreenState createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  List<dynamic>? conversations;
  List<dynamic>? lastMessages;
  List<dynamic>? filteredConversations;
  List<dynamic>? filteredUsers;
  List<dynamic>? users;
  TextEditingController _userSearchController = TextEditingController();
  TextEditingController _searchController = TextEditingController();
  TextEditingController _messageController = TextEditingController();
  Map<String, dynamic>? user;
  Map<String, dynamic>? selectedUser;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _getAllUsers();
    _searchController.addListener(_filterConversations);
    _userSearchController.addListener(_filterUsers);
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
      _getConversations();
    } else {
      print('Failed to load user');
    }
  }

  Future<void> _getAllUsers() async {
    final String apiUrl = 'https://api_swapinfi.lebourbier.be/api/user';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.get(Uri.parse(apiUrl), headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      setState(() {
        users = jsonDecode(response.body);
        filteredUsers = users;
      });
    } else {
      print('Failed to load users');
    }
  }

  Future<void> _getConversations() async {
    if (user == null) return;

    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/conversation/user/${user!['id']}';
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
        conversations = jsonDecode(response.body)[0] ?? [];
        lastMessages = jsonDecode(response.body)[1] ?? [];
        filteredConversations = conversations;
      });
    } else {
      print('Failed to load conversations');
    }
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      filteredConversations = conversations?.where((conversation) {
        final user1FullName =
            '${conversation['user1']['first_name']} ${conversation['user1']['last_name']}'
                .toLowerCase();
        final user2FullName =
            '${conversation['user2']['first_name']} ${conversation['user2']['last_name']}'
                .toLowerCase();
        final user1FullNameReverse =
            '${conversation['user1']['last_name']} ${conversation['user1']['first_name']}'
                .toLowerCase();
        final user2FullNameReverse =
            '${conversation['user2']['last_name']} ${conversation['user2']['first_name']}'
                .toLowerCase();

        return user1FullName.contains(query) ||
            user2FullName.contains(query) ||
            user1FullNameReverse.contains(query) ||
            user2FullNameReverse.contains(query);
      }).toList();
    });
  }

  void _filterUsers() {
    final query = _userSearchController.text.toLowerCase();
    setState(() {
      filteredUsers = users?.where((user) {
        final firstName = user['first_name']?.toLowerCase() ?? '';
        final lastName = user['last_name']?.toLowerCase() ?? '';
        return firstName.contains(query) || lastName.contains(query);
      }).toList();
    });
  }

  Future<void> _createConversation(String message) async {
    if (selectedUser == null || message.isEmpty) return;

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
        'user1_id': user!['id'],
        'user2_id': selectedUser!['id'],
        'content': message,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Conversation créée avec succès'),
      ));
      Navigator.pop(context);
      _getConversations(); // Refresh the conversation list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la création de la conversation'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Conversations'),
      ),
      body: Container(
        color: Colors.green[100]?.withOpacity(0.2),
        child: Column(
          children: [
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
              child: filteredConversations == null
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: filteredConversations!.length,
                      itemBuilder: (context, index) {
                        final conversation = filteredConversations![index];
                        final otherUserId =
                            (conversation['user1']['id'] == user!['id'])
                                ? conversation['user2']['id']
                                : conversation['user1']['id'];
                        final otherUserProfilePicture =
                            conversation['user1']['id'] == user!['id']
                                ? conversation['user2']['profile_picture']
                                : conversation['user1']['profile_picture'];
                        final lastMessage = lastMessages?.firstWhere(
                            (msg) =>
                                msg['conversation_id'] == conversation['id'],
                            orElse: () => {'content': 'Pas de message'});

                        return Column(
                          children: [
                            Container(
                              color: lastMessage['is_read'] == 0 &&
                                      lastMessage['sender_id'] != user!['id']
                                  ? Colors.green[200]
                                  : Colors.white,
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: otherUserProfilePicture !=
                                          null
                                      ? NetworkImage(
                                          'https://api_swapinfi.lebourbier.be/storage/profile_pictures/$otherUserProfilePicture')
                                      : AssetImage('assets/user.png')
                                          as ImageProvider,
                                ),
                                title: Text(
                                  '${conversation['user1_id'] == user!['id'] ? conversation['user2']['first_name'] : conversation['user1']['first_name']} ${conversation['user1_id'] == user!['id'] ? conversation['user2']['last_name'] : conversation['user1']['last_name']}',
                                ),
                                subtitle: Text(
                                    lastMessage['content'] ?? 'Pas de message'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ConversationScreen(
                                        currentUser: user!,
                                        conversationId:
                                            conversation['id'].toString(),
                                        secureStorageService:
                                            widget.secureStorageService,
                                        receiver: conversation['user1_id'] ==
                                                user!['id']
                                            ? conversation['user2']
                                            : conversation['user1'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Divider(height: 1, color: Colors.grey),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateConversationModal(context);
        },
        backgroundColor: Colors.green,
        child: Icon(Icons.add),
      ),
    );
  }

  void _showCreateConversationModal(BuildContext context) {
    _userSearchController.clear();
    setState(() {
      selectedUser = null;
      filteredUsers = users;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            _userSearchController.addListener(() {
              final query = _userSearchController.text.toLowerCase();
              setState(() {
                filteredUsers = users?.where((user) {
                  final firstName = user['first_name']?.toLowerCase() ?? '';
                  final lastName = user['last_name']?.toLowerCase() ?? '';
                  return firstName.contains(query) || lastName.contains(query);
                }).toList();
              });
            });

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
                      'Créer une nouvelle conversation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _userSearchController,
                      cursorColor: Colors.green,
                      decoration: InputDecoration(
                        labelText: 'Rechercher un utilisateur',
                        labelStyle: TextStyle(color: Colors.green),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: filteredUsers == null
                          ? Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: filteredUsers!.length,
                              itemBuilder: (context, index) {
                                final userItem = filteredUsers![index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: userItem[
                                                'profile_picture'] !=
                                            null
                                        ? NetworkImage(
                                            'https://api_swapinfi.lebourbier.be/storage/profile_pictures/${userItem['profile_picture']}')
                                        : AssetImage('assets/user.png')
                                            as ImageProvider,
                                  ),
                                  title: Text(
                                      '${userItem['first_name']} ${userItem['last_name']}'),
                                  onTap: () {
                                    setState(() {
                                      selectedUser = userItem;
                                    });
                                  },
                                  selected: selectedUser == userItem,
                                  selectedColor: Colors.green,
                                );
                              },
                            ),
                    ),
                    if (selectedUser != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              cursorColor: Colors.green,
                              decoration: InputDecoration(
                                labelText: 'Écrire un message',
                                labelStyle: TextStyle(color: Colors.green),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.green),
                                ),
                              ),
                              minLines: 1,
                              maxLines: 4,
                            ),
                          ),
                          SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: BoxConstraints.tightFor(width: 50),
                            child: ElevatedButton(
                              onPressed: () {
                                if (_messageController.text.isNotEmpty) {
                                  _createConversation(_messageController.text);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                iconColor: Colors.white,
                                padding: EdgeInsets.all(
                                    5), // Ajuste le padding pour centrer l'icône
                              ),
                              child: SizedBox(
                                width: 24, // Largeur de l'icône
                                height: 24, // Hauteur de l'icône
                                child: Icon(Icons.send,
                                    size: 20), // Taille de l'icône
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
