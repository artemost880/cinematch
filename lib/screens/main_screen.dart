import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import '../services/tmdb_service.dart';

// Импорт экранов
import 'home_screen.dart';
import 'search_screen.dart';
import 'rooms_lobby_screen.dart';
import 'favorites_screen.dart';
import 'movie_details_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final TMDBService _tmdbService = TMDBService();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  // Настройка Deep Linking (cinematch://movie?id=...)
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Ошибка Deep Link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme == 'cinematch' && uri.host == 'movie') {
      final idString = uri.queryParameters['id'];
      if (idString != null) {
        final movieId = int.tryParse(idString);
        if (movieId != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
          );

          final fullMovieData = await _tmdbService.getMovieDetails(movieId);
          
          if (mounted) Navigator.pop(context);

          if (fullMovieData != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: fullMovieData)),
            );
          }
        }
      }
    }
  }

  // Метод для переключения вкладок, который мы будем пробрасывать внутрь HomeScreen
  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Формируем список экранов внутри build, чтобы иметь доступ к _onItemTapped
    final List<Widget> screens = [
      HomeScreen(onNavigateToTab: _onItemTapped), // 0: Главная
      const SearchScreen(),                       // 1: Поиск
      const RoomsLobbyScreen(),                   // 2: Мэтч (Комнаты)
      const FavoritesScreen(),                    // 3: Избранное
      
      // 4: Заглушка профиля (Спринт 2)
      const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 80, color: Color(0xFF00E5FF)),
              SizedBox(height: 16),
              Text('Профиль', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Скоро здесь будет авторизация', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          backgroundColor: const Color(0xFF1E1E1E),
          selectedItemColor: const Color(0xFF00E5FF),
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Главная',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Icon(Icons.saved_search),
              label: 'Поиск',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Мэтч',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              activeIcon: Icon(Icons.favorite),
              label: 'Избранное',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}