import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home/HomeScreen.dart';
import 'screens/profile/ProfileScreen.dart';
import 'screens/messages/ConversationsListScreen.dart';
import 'screens/register/SignUpScreen.dart';
import 'screens/login/SignInScreen.dart';
import 'screens/id_card_reader/OldIdCardReaderScreen.dart';
import 'screens/id_card_reader/IdCardReaderScreen.dart';
import 'screens/patients/AddPatientScreen.dart';
import 'screens/users/SearchUserScreen.dart';
import 'screens/tours/TourListScreen.dart';
import 'providers/auth/auth_bloc.dart';
import 'providers/auth/auth_provider.dart';
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:wivoce_laravel_echo_client/wivoce_laravel_echo_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

void main() {
  final AuthProvider authProvider = AuthProvider();
  final SecureStorageProvider.SecureStorageService secureStorageService =
      SecureStorageProvider.SecureStorageService();
  runApp(App(
      authProvider: authProvider, secureStorageService: secureStorageService));
}

class App extends StatelessWidget {
  final AuthProvider authProvider;
  final SecureStorageProvider.SecureStorageService secureStorageService;

  App({required this.authProvider, required this.secureStorageService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthProvider(),
        ),
        BlocProvider(
          create: (context) => AuthBloc(
              authProvider: authProvider,
              secureStorageService: secureStorageService)
            ..add(CheckAuthStatus()),
        ),
      ],
      child: MaterialApp(
        title: 'Test',
        theme: ThemeData(
          tabBarTheme: TabBarTheme(
            labelColor: Colors.green[800],
            unselectedLabelColor: Colors.green[400],
            indicatorColor: Colors.green[800],
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.green[100]?.withOpacity(0.2),
            titleTextStyle: TextStyle(color: Colors.green[400]),
            iconTheme: IconThemeData(color: Colors.green[400]),
            actionsIconTheme: IconThemeData(color: Colors.green[400]),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => SignInScreen(),
          '/signup': (context) => SignUpScreen(),
          '/maintabs': (context) =>
              MainTabs(secureStorageService: secureStorageService),
        },
      ),
    );
  }
}

class MainTabs extends StatefulWidget {
  final SecureStorageProvider.SecureStorageService secureStorageService;

  MainTabs({required this.secureStorageService});

  @override
  _MainTabsState createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  IO.Socket? socket;
  late Echo echo;
  Map<String, dynamic>? user;
  int? userId;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    // _initializeSocket();
    _loadUser();
  }

  Future<void> _loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString('user');

    if (userJson != null) {
      setState(() {
        user = jsonDecode(userJson);
        userId =
            user?['id']; // Assignez l'ID de l'utilisateur à la variable d'état
      });
      // _initializeEcho();
    }
  }

  void _initializeNotifications() {
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(iOS: initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // void _initializeSocket() async {
  //   final wsUrl = Uri.parse(
  //       'ws://192.168.1.12:6001/socket.io/?EIO=4&transport=websocket');
  //   final channel = WebSocketChannel.connect(wsUrl);

  //   await channel.ready;

  //   channel.stream.listen((message) {
  //     channel.sink.add('received!');
  //     print('Received: $message');
  //     // channel.sink.close(status.goingAway);
  //   });
  // }

  // void _initializeEcho() {
  //   String host = '192.168.1.12:6001';
  //   String token =
  //       '9dae4da2c5f33255384c173b2119f349'; // Remplacez par le jeton approprié
  //   String channelName = 'private-messages.$userId';

  //   echo = Echo(
  //     client: IO.io('ws://$host/socket.io/', <String, dynamic>{
  //       'transports': ['websocket'],
  //       'query': {
  //         'EIO': '4',
  //         'transport': 'websocket',
  //       },
  //       'extraHeaders': {
  //         'Authorization': 'Bearer $token',
  //       }
  //     }),
  //     broadcaster: EchoBroadcasterType.SocketIO,
  //     options: {
  //       'auth': {
  //         'headers': {
  //           'Authorization': 'Bearer $token',
  //         },
  //       },
  //     },
  //   );

  //   echo.private(channelName).listen('NewMessageEvent', (data) {
  //     print('New message: ${data['message']}');
  //     _showNotification('New Message', data['message']);
  //   });

  //   echo.connector.socket.on('connect', (_) {
  //     print('connected to websocket');
  //   });

  //   echo.connector.socket.on('disconnect', (_) {
  //     print('disconnected from websocket');
  //   });
  // }

  Future<void> _showNotification(String title, String body) async {
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('SwapInfi'),
          leading: IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _showLogoutConfirmationModal(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.person_add),
              onPressed: () => _showAddPatientModal(context),
            ),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchUserScreen(
                      secureStorageService: widget.secureStorageService,
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.home), text: 'Accueil'),
              Tab(icon: Icon(Icons.person), text: 'Profil'),
              Tab(icon: Icon(Icons.message), text: 'Messages'),
              Tab(icon: Icon(Icons.list), text: 'Tournées'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            HomeScreen(),
            ProfileScreen(secureStorageService: widget.secureStorageService),
            ConversationsListScreen(
                secureStorageService: widget.secureStorageService),
            TourListScreen(secureStorageService: widget.secureStorageService),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmationModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Déconnexion'),
          content: Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<AuthBloc>().add(SignOutRequested());
                Navigator.of(context).pushNamedAndRemoveUntil(
                    '/', (Route<dynamic> route) => false);
              },
              child: Text('Déconnexion'),
            ),
          ],
        );
      },
    );
  }

  void _showAddPatientModal(BuildContext context) {
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
                  'Ajouter Patient',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.person_add, color: Colors.blue),
                  title: Text('Entrée manuelle'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddPatientScreen(
                          extractedData: Map<String, String>(),
                          secureStorageService: widget.secureStorageService,
                        ),
                      ),
                    );
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.credit_card, color: Colors.green),
                  title: Text('Lecteur de carte d\'identité'),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title:
                              Text('Sélectionner le type de carte d\'identité'),
                          content: Text(
                              'Veuillez choisir la version de la carte d\'identité que vous souhaitez scanner.'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => IdCardReaderScreen(
                                      secureStorageService:
                                          widget.secureStorageService,
                                    ),
                                  ),
                                );
                              },
                              child: Text('Nouvelle carte'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OldIdCardReaderScreen(
                                      secureStorageService:
                                          widget.secureStorageService,
                                    ),
                                  ),
                                );
                              },
                              child: Text('Ancienne carte'),
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
        );
      },
    );
  }
}
