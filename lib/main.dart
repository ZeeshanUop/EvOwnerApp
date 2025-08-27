import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';

import 'Screens/Auth/SignIn.dart';
import 'Services/NotificationServices.dart';
import 'Handler/Booking_Screen_Route_handler.dart';
import 'Screens/MainScreens/Notifications/NotificationScreen.dart';
import 'Screens/SplashScreens/splash_screen.dart';
import 'Provider/FavouriteProvider.dart';
import 'Provider/ThemeNodeNotifier.dart';


/// Background handler for EV Owner app
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await EvOwnerNotificationService.showBackground(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();

  // Register background FCM handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ChangeNotifierProvider(create: (_) => ThemeModeNotifier()),
      ],
      child: const MyApp(),
    ),
  );
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize notification service (foreground + taps)
      await EvOwnerNotificationService.init();

      // Handle tap when app was killed
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        EvOwnerNotificationService.handleClick(initialMessage.data);

      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeModeNotifier>(context);

    return OverlaySupport.global(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'EV Owner',
        navigatorKey: EvOwnerNotificationService.navKey, // ✅ use service key
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeNotifier.themeMode,
        home: SplashScreen(),
        routes: {
          '/booking': (context) => BookingScreenRouteHandler(),
          '/SignIn': (context) => const SignInScreen(),
          '/notifications': (context) => const NotificationScreen(),
        },
      ),
    );
  }
}
