import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../patients/PatientsListScreen.dart';
import '../tours/TourListScreen.dart';

class ConversationScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Map<String, dynamic> receiver;
  final String conversationId;
  final SecureStorageProvider.SecureStorageService secureStorageService;

  ConversationScreen({
    required this.currentUser,
    required this.conversationId,
    required this.secureStorageService,
    required this.receiver,
  });

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<dynamic>? messages = [];
  TextEditingController _messageController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  bool integratingReplacement = false;
  List<int> selectedPatientIds = [];
  List<dynamic> tours = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  int limit = 15;
  int offset = 0;

  @override
  void initState() {
    super.initState();
    _getMessages(initialLoad: true);
    _getTours();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToBottom();
    });
  }

  void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _getMessages({bool initialLoad = false}) async {
    if (initialLoad) {
      setState(() {
        isLoading = true;
      });
      offset = 0;
    } else {
      setState(() {
        isLoadingMore = true;
      });
    }

    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/message/conversation/${widget.conversationId}';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.get(
      Uri.parse('$apiUrl?limit=$limit&offset=$offset'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> newMessages = jsonDecode(response.body).reversed.toList();
      for (var message in newMessages) {
        if (message['is_read'] == 0 &&
            message['receiver_id'] == widget.currentUser['id']) {
          await _markMessageAsRead(message['id']);
        }
      }

      setState(() {
        if (initialLoad) {
          messages = newMessages;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollToBottom();
          });
        } else {
          messages = [...newMessages, ...messages!];
        }
        offset += limit;
        isLoading = false;
        isLoadingMore = false;
      });
    } else {
      print('Failed to load messages');
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels <=
            _scrollController.position.minScrollExtent &&
        !isLoading &&
        !isLoadingMore) {
      _getMessages();
    }
  }

  Future<void> _markMessageAsRead(int messageId) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/message/update/$messageId';
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
        'is_read': 1,
      }),
    );

    if (response.statusCode != 200) {
      print('Failed to update message status');
    }
  }

  Future<void> _sendMessage(String content, [int? replacementId]) async {
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
        'user1_id': widget.currentUser['id'],
        'user2_id': widget.receiver['id'],
        'content': content,
        if (replacementId != null) 'replacement_id': replacementId,
      }),
    );

    if (response.statusCode == 200) {
      _messageController.clear();
      _getMessages(initialLoad: true);
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de l\'envoi du message'),
      ));
    }
  }

  Future<int?> _createReplacement(
      int userId, int postId, String replacementDate, int tourId) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/replacement/create';
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
        'user_id': userId,
        'post_id': postId,
        'replacement_date': replacementDate,
        'tour_id': tourId,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['id'];
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la création de la demande de remplacement'),
      ));
      return null;
    }
  }

  Future<void> _acceptDeclineReplacement(
      int replacementId, String status) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/replacement/accept-decline/$replacementId';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    final response = await http.put(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode == 200) {
      final replacement = jsonDecode(response.body);
      String responseContent;
      if (status == 'approved') {
        responseContent =
            'Votre demande de remplacement pour le ${replacement['replacement_date']} a été acceptée.';
      } else {
        responseContent =
            'Votre demande de remplacement pour le ${replacement['replacement_date']} a été refusée.';
      }
      await _sendMessage(responseContent, replacementId);
      _getMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour du remplacement'),
      ));
    }
  }

  Future<void> _getTours() async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/${widget.currentUser['id']}';
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

  Future<void> _updateTour(List<int> selectedPatientIds,
      List<int> existingPatientIds, int tourId) async {
    final String apiUrl =
        'https://api_swapinfi.lebourbier.be/api/tour/update/$tourId';
    final String? accessToken =
        await widget.secureStorageService.getToken('Bearer');

    // Combine the selected patient ids with existing patient ids and replacement patient ids
    final updatedPatientIds = [
      ...existingPatientIds,
      ...selectedPatientIds,
    ];
    print(updatedPatientIds);
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
      setState(() {
        selectedPatientIds = [];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour de la tournée'),
      ));
    }
  }

  void _showReplacementOptionsModal(
      BuildContext context, Map<String, dynamic> replacement) {
    bool isCurrentUserReplacement =
        replacement['user_id'] == widget.currentUser['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permet un contrôle de défilement
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.40, // Ajuster la hauteur du modal
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUserReplacement
                      ? 'Options de remplacement'
                      : 'Liste des patients',
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
                          user: widget.currentUser,
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
                      integratingReplacement = true;
                      selectedPatientIds = List<int>.from(
                          replacement['tour']['patients'].map((p) => p['id']));
                      _showTourSelectionModal(context);
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.group, color: Colors.purple),
                  title: Text(
                      'Afficher la liste de remplacements et des tournées'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TourListScreen(
                          secureStorageService: widget.secureStorageService,
                        ),
                      ),
                    );
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
                          user: widget.currentUser,
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

  void _showPostDetailsModal(BuildContext context, Map<String, dynamic> post) {
    bool isCurrentUserPost = post['user_id'] == widget.currentUser['id'];
    TextEditingController editContentController =
        TextEditingController(text: post['content']);
    bool isEditingContent = false;

    String formattedDate = 'Unknown Date';
    if (post['created_at'] != null) {
      DateTime parsedDate = DateTime.parse(post['created_at']);
      formattedDate = DateFormat('dd/MM/yyyy').format(parsedDate);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            bool isReplacementRequested = false;
            bool isReplacementApproved = false;

            for (var message in messages!) {
              if (message['replacement_id'] != null &&
                  message['replacement']['post_id'] == post['id']) {
                isReplacementApproved = true;
                break;
              }
            }

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
                      Text(
                        post['title'] ?? 'Sans titre',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            post['content'] ?? 'Pas de contenu',
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
                      if (!isCurrentUserPost && !isReplacementRequested)
                        Center(
                          child: ElevatedButton(
                            onPressed: isReplacementApproved
                                ? null
                                : () async {
                                    final replacementId =
                                        await _createReplacement(
                                            widget.currentUser['id'],
                                            post['id'],
                                            post['replace_date'],
                                            post['tour']['id']);

                                    if (replacementId != null) {
                                      String messageContent =
                                          'Je souhaiterai vous remplacer ce $formattedDate pour la tournée "${post['tour']['name']}".';
                                      await _sendMessage(
                                          messageContent, replacementId);
                                      setState(() {
                                        isReplacementRequested = true;
                                      });
                                    }
                                    Navigator.pop(context);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isReplacementApproved
                                  ? Colors.grey
                                  : Colors.green,
                            ),
                            child: Text(
                              'Accepter le remplacement',
                              style: TextStyle(
                                  color: isReplacementApproved
                                      ? Colors.black
                                      : Colors.white),
                            ),
                          ),
                        ),
                      if (!isCurrentUserPost)
                        Center(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PatientsListScreen(
                                    user: widget.currentUser,
                                    secureStorageService:
                                        widget.secureStorageService,
                                    tourId: post['tour_id'].toString(),
                                    patients: post['tour']['patients'],
                                    fromHomeScreen: false,
                                    canEdit: post['user_id'] ==
                                        widget.currentUser['id'],
                                  ),
                                ),
                              );
                              if (result == true) {
                                _getMessages();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: Text(
                              'Voir la tournée',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      if (isCurrentUserPost)
                        Center(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PatientsListScreen(
                                    user: widget.currentUser,
                                    secureStorageService:
                                        widget.secureStorageService,
                                    tourId: post['tour_id'].toString(),
                                    patients: post['tour']['patients'],
                                    fromHomeScreen: false,
                                    canEdit: post['user_id'] ==
                                        widget.currentUser['id'],
                                  ),
                                ),
                              );
                              if (result == true) {
                                _getMessages();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: Text(
                              'Tournée "${post['tour']['name']}"',
                              style: TextStyle(color: Colors.white),
                            ),
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

  void _showTourSelectionModal(BuildContext context) {
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
                  'Sélectionner une tournée',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: tours.map((tour) {
                      return ListTile(
                        title: Text(
                          tour['name'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          List<int> existingPatientIds = List<int>.from(
                              tour['patients'].map((p) => p['id']));

                          _updateTour(selectedPatientIds, existingPatientIds,
                              tour['id']);
                          Navigator.pop(context);
                          setState(() {
                            integratingReplacement = false;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isCurrentUser) {
    bool isReplacementRequest =
        message['content'].contains('Je souhaiterai vous remplacer');
    int? replacementId = message['replacement_id'];
    String? replacementStatus = message['replacement']?['status'];
    String? replacementDate = message['replacement']?['replacement_date'];
    int? replacementUserId = message['replacement']?['user_id'];

    // Format the replacement date
    String formattedReplacementDate = 'Unknown Date';
    if (replacementDate != null) {
      DateTime parsedDate = DateTime.parse(replacementDate);
      formattedReplacementDate = DateFormat('dd/MM/yyyy').format(parsedDate);
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: CircleAvatar(
                radius: 14,
                backgroundImage: NetworkImage(
                  'https://api_swapinfi.lebourbier.be/storage/profile_pictures/${widget.receiver['profile_picture']}',
                ),
              ),
            ),
          SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 5),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrentUser ? Colors.green[300] : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isCurrentUser ? Colors.white : Colors.black,
                    ),
                  ),
                  if (replacementStatus == 'approved' &&
                      ((replacementUserId == widget.currentUser['id'] &&
                              !isCurrentUser) ||
                          (replacementUserId != widget.currentUser['id'] &&
                              isCurrentUser)) &&
                      replacementDate != null)
                    GestureDetector(
                      onTap: () {
                        if (replacementUserId == widget.currentUser['id']) {
                          _showReplacementOptionsModal(
                              context, message['replacement']);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientsListScreen(
                                user: widget.currentUser,
                                secureStorageService:
                                    widget.secureStorageService,
                                tourId: message['replacement']['tour_id']
                                    .toString(),
                                patients: message['replacement']['tour']
                                    ['patients'],
                                fromHomeScreen: false,
                                canEdit: false,
                                showFullDetails: true,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        margin: EdgeInsets.only(top: 8),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.yellow[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Remplacement $formattedReplacementDate',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (isReplacementRequest &&
                      !isCurrentUser &&
                      replacementId != null)
                    if (replacementStatus == 'pending') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await _acceptDeclineReplacement(
                                  replacementId, 'approved');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: Text('Accepter',
                                style: TextStyle(color: Colors.white)),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () async {
                              await _acceptDeclineReplacement(
                                  replacementId, 'declined');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: Text('Refuser',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ] else if (replacementStatus == 'approved') ...[
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          'Accepté',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ] else if (replacementStatus == 'declined') ...[
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          'Refusé',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  if (message['post'] != null)
                    GestureDetector(
                      onTap: () =>
                          _showPostDetailsModal(context, message['post']),
                      child: Container(
                        margin: EdgeInsets.only(top: 8),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? Colors.white : Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message['post']['title'],
                          style: TextStyle(
                            fontSize: 14,
                            color: isCurrentUser ? Colors.green : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildDateDivider(String date) {
    DateTime parsedDate = DateTime.parse(date);
    String formattedDate = DateFormat('dd/MM/yyyy').format(parsedDate);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          formattedDate,
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.receiver['first_name']} ${widget.receiver['last_name']}'),
      ),
      body: Container(
        color: Colors.green[100]?.withOpacity(0.2),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    itemCount: messages?.length ?? 0,
                    itemBuilder: (context, index) {
                      final message = messages![index];
                      final bool isCurrentUser =
                          message['sender_id'] == widget.currentUser['id'];
                      final bool showDateDivider = index == 0 ||
                          message['created_at'].substring(0, 10) !=
                              messages![index - 1]['created_at']
                                  .substring(0, 10);
                      return Column(
                        children: [
                          if (showDateDivider)
                            _buildDateDivider(
                                message['created_at'].substring(0, 10)),
                          _buildMessageBubble(message, isCurrentUser),
                        ],
                      );
                    },
                  ),
                  if (isLoadingMore)
                    Positioned(
                      top: 0,
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
            Padding(
              padding: const EdgeInsets.all(8.0).copyWith(bottom: 28.0),
              child: Row(
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
                          _sendMessage(_messageController.text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        iconColor: Colors.white,
                        padding: EdgeInsets.all(5),
                      ),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Icon(Icons.send, size: 20),
                      ),
                    ),
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
