import 'package:flutter/material.dart';
import '../services/tmdb_service.dart';
import 'movie_details_screen.dart';
import 'random_movie_screen.dart';
import 'genre_movies_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const HomeScreen({super.key, required this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TMDBService _tmdbService = TMDBService();

  List<dynamic> _trendingMovies = [];
  List<dynamic> _actionMovies = [];
  List<dynamic> _comedyMovies = [];
  bool _isLoading = true;

  // Полный словарь всех жанров для нашей новой ленты категорий
  final Map<String, int> _allGenres = {
    'Экшен': 28, 'Приключения': 12, 'Анимация': 16, 'Комедия': 35,
    'Криминал': 80, 'Документальный': 99, 'Драма': 18, 'Семейный': 10751,
    'Фэнтези': 14, 'История': 36, 'Ужасы': 27, 'Музыка': 10402,
    'Детектив': 9648, 'Мелодрама': 10749, 'Фантастика': 878,
    'Триллер': 53, 'Военный': 10752,
  };

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final results = await Future.wait([
      _tmdbService.getMoviesByGenre(28), 
      _tmdbService.getMoviesByGenre(35), 
      _tmdbService.getMoviesByGenre(878, minYear: 2024, minRating: 7.0), 
    ]);

    if (mounted) {
      setState(() {
        _actionMovies = results[0]['results'] ?? [];
        _comedyMovies = results[1]['results'] ?? [];
        _trendingMovies = results[2]['results'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'CINEMATCH', 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 22, 
            letterSpacing: 2, 
            color: Color(0xFF00E5FF)
          )
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('У вас пока нет новых уведомлений'))
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : RefreshIndicator(
              color: const Color(0xFF00E5FF),
              onRefresh: _loadCollections,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEventBanner(),
                    const SizedBox(height: 24),
                    
                    _buildQuickActions(context),
                    const SizedBox(height: 32),

                    // --- ВОТ ОН: НАШ НОВЫЙ БЛОК СО ВСЕМИ ЖАНРАМИ ---
                    _buildGenresCarousel(),
                    const SizedBox(height: 32),
                    // ----------------------------------------------

                    _buildCollectionRow('Популярные новинки', _trendingMovies, context),
                    const SizedBox(height: 24),
                    _buildCollectionRow('Адреналин и Экшен', _actionMovies, context),
                    const SizedBox(height: 24),
                    _buildCollectionRow('Посмеяться от души', _comedyMovies, context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEventBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2575FC).withValues(alpha: 0.3), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10, bottom: -10,
            child: Icon(Icons.stars, size: 140, color: Colors.white.withValues(alpha: 0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: const Text('АКТУАЛЬНО', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                const Text('Конкурс рецензий', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text('Пиши отзывы и забирай OG-пины', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _actionCard(
              icon: Icons.casino, 
              label: 'Рандомайзер', 
              color: const Color(0xFF00E5FF),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RandomMovieScreen())),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _actionCard(
              icon: Icons.groups, 
              label: 'Киновечер', 
              color: Colors.white,
              onTap: () => widget.onNavigateToTab(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // --- МЕТОД ОТРИСОВКИ КАРУСЕЛИ КАТЕГОРИЙ (ЖАНРОВ) ---
  Widget _buildGenresCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Категории', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 45, // Высота для кнопок
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _allGenres.length,
            itemBuilder: (context, index) {
              String genreName = _allGenres.keys.elementAt(index);
              int genreId = _allGenres.values.elementAt(index);
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  label: Text(genreName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GenreMoviesScreen(
                          genreId: genreId,
                          genreName: genreName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  // --------------------------------------------------

  Widget _buildCollectionRow(String title, List<dynamic> movies, BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  int gId = 28; 
                  double minRating = 0.0;
                  int minYear = 1950;

                  if (title == 'Популярные новинки') { gId = 878; minRating = 7.0; minYear = 2024; }
                  else if (title == 'Посмеяться от души') { gId = 35; }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GenreMoviesScreen(
                        genreId: gId,
                        genreName: title,
                        initialMinRating: minRating,
                        initialMinYear: minYear,
                      ),
                    ),
                  );
                },
                child: const Text('Все', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _buildMovieCard(movie, context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie, BuildContext context) {
    return GestureDetector(
      onTap: () async {
        showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))));
        final fullData = await _tmdbService.getMovieDetails(movie['id']);
        if (mounted) Navigator.pop(context);
        if (fullData != null && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: fullData)));
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: movie['poster_path'] != null
                    ? Image.network(_tmdbService.getImageUrl(movie['poster_path']), fit: BoxFit.cover, width: 140)
                    : Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie['title'] ?? '', 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)
            ),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 12),
                const SizedBox(width: 4),
                Text(
                  '${movie['vote_average']}', 
                  style: const TextStyle(fontSize: 11, color: Colors.white70)
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}