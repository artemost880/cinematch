import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'screens/welcome_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CineMatchApp());
}

class CineMatchApp extends StatelessWidget {
  const CineMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineMatch',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E5FF),
      ),
      // StreamBuilder следит за состоянием авторизации в реальном времени
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Если данные еще подгружаются
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // Если пользователь есть (уже нажимал "Войти")
          if (snapshot.hasData) {
            return const MainScreen(); // Изменили HomeScreen() на MainScreen()
          }
          // Если пользователя нет
          return const WelcomeScreen();
        },
      ),
    );
  }
}