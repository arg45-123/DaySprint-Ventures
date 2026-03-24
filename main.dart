import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'choose_role_screen.dart';
import 'job_dashboard_screen.dart';
import 'hire_dashboard_screen.dart';
import 'selfie_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling background message: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Local Notifications init
  var androidInit = const AndroidInitializationSettings('@mipmap/ic_launcher');
  var iosInit = const DarwinInitializationSettings();
  var initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Force sign-out to ensure HomePage is shown on start
  await FirebaseAuth.instance.signOut();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  void _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // iOS permission
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Device token (print in console for testing)
    String? token = await messaging.getToken();
    print("FCM Device Token: $token");

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print("Foreground message received: ${message.notification?.title}");

      if (message.notification != null) {
        const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'default_channel', // channel id
          'General Notifications', // channel name
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );

        const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

        await flutterLocalNotificationsPlugin.show(
          0, // notification id
          message.notification?.title,
          message.notification?.body,
          notificationDetails,
        );
      }
    });

    // When app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Message clicked!: ${message.notification?.title}");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One Day Employees',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Main: Auth state: Waiting for connection');
          return const Center(child: CircularProgressIndicator());
        }
        final user = snapshot.data;
        print('Main: Auth state: ${user != null ? 'Authenticated, UID: ${user.uid}' : 'Unauthenticated'}');
        if (user == null) {
          print('Main: Navigating to HomePage (unauthenticated)');
          return const HomePage();
        }
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('workers')
              .doc(user.uid)
              .get(),
          builder: (context, workerSnapshot) {
            if (workerSnapshot.connectionState == ConnectionState.waiting) {
              print('Main: Checking workers collection for UID: ${user.uid}');
              return const Center(child: CircularProgressIndicator());
            }
            if (workerSnapshot.hasError) {
              print('Main: Worker snapshot error: ${workerSnapshot.error}');
              return const ChooseRoleScreen();
            }
            if (workerSnapshot.hasData && workerSnapshot.data!.exists) {
              print('Main: Worker document exists for UID: ${user.uid}, Data: ${workerSnapshot.data!.data()}');
              return const HomeScreen();
            }
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('employers')
                  .doc(user.uid)
                  .get(),
              builder: (context, employerSnapshot) {
                if (employerSnapshot.connectionState == ConnectionState.waiting) {
                  print('Main: Checking employers collection for UID: ${user.uid}');
                  return const Center(child: CircularProgressIndicator());
                }
                if (employerSnapshot.hasError) {
                  print('Main: Employer snapshot error: ${employerSnapshot.error}');
                  return const ChooseRoleScreen();
                }
                if (employerSnapshot.hasData && employerSnapshot.data!.exists) {
                  print('Main: Employer document exists for UID: ${user.uid}, Data: ${employerSnapshot.data!.data()}');
                  return HireDashboardScreen(userId: user.uid);
                }
                print('Main: No role found for UID: ${user.uid}, navigating to ChooseRoleScreen');
                return const ChooseRoleScreen();
              },
            );
          },
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/one_day_image.jpg',
                height: 200,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  print('Main: Navigating to ChooseRoleScreen from HomePage');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChooseRoleScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
