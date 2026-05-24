import 'package:flutter/material.dart';
import 'dart:math';
import '../services/tmdb_service.dart';
import 'movie_details_screen.dart';
import 'filters_sheet.dart'; 

class GenreMoviesScreen extends StatefulWidget {
  final int genreId;
  final String genreName;
  // Параметры для перехода с главного экрана
  final double initialMinRating;
  final int initialMinYear;

  const GenreMoviesScreen({
    super.key, 
    required this.genreId, 
    required this.genreName,
    this.initialMinRating = 0.0,
    this.initialMinYear = 1950,
  });

  @override
  State<GenreMoviesScreen> createState() => _GenreMoviesScreenState();
}

class _GenreMoviesScreenState extends State<GenreMoviesScreen> {
  final TMDBService _tmdbService = TMDBService();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _movies = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalPages = 1;

  // Хранилище фильтров для этого экрана
  late RangeValues _currentRating;
  late RangeValues _currentYear;
  RangeValues _currentRuntime = const RangeValues(40.0, 240.0);
  List<Map<String, dynamic>> _selectedActors = [];
  bool _isCastAndLogic = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем стартовые фильтры из параметров
    _currentRating = RangeValues(widget.initialMinRating, 10.0);
    _currentYear = RangeValues(widget.initialMinYear.toDouble(), 2026.0);
    
    _fetchMovies(isRefresh: true);

    // Слушатель для бесконечного скролла
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore && !_isLoading) {
        _fetchMovies(isRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Обновленный метод загрузки с поддержкой пагинации
  Future<void> _fetchMovies({required bool isRefresh, int? specificPage}) async {
    if (isRefresh) {
      setState(() { _isLoading = true; _currentPage = specificPage ?? 1; _movies.clear(); });
    } else {
      if (_currentPage >= _totalPages) return;
      setState(() { _isLoadingMore = true; _currentPage++; });
    }

    final data = await _tmdbService.getMoviesByGenre(
      widget.genreId, 
      page: _currentPage,
      minRating: _currentRating.start,
      maxRating: _currentRating.end,
      minYear: _currentYear.start.toInt(),
      maxYear: _currentYear.end.toInt(),
      castIds: _selectedActors.map((a) => a['id'] as int).toList(),
      isCastAndLogic: _isCastAndLogic,
      minRuntime: _currentRuntime.start.toInt(),
      maxRuntime: _currentRuntime.end == 240.0 ? null : _currentRuntime.end.toInt(),
    );
    
    if (mounted) {
      setState(() {
        if (isRefresh) {
          _movies = data['results'];
        } else {
          _movies.addAll(data['results']);
        }
        _totalPages = data['total_pages'];
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  // Метод вызова шторки с новыми фильтрами
  void _showFiltersBottomSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FiltersSheet(
          initialRating: _currentRating,
          initialYear: _currentYear,
          initialGenres: const {}, // Пустой сет
          showGenres: false,       // СКРЫВАЕМ БЛОК ЖАНРОВ
          initialActors: _selectedActors, 
          initialGenreLogic: false, 
          initialCastLogic: _isCastAndLogic, 
          initialRuntime: _currentRuntime,
        );
      },
    );

    if (result != null) {
      setState(() {
        _currentRating = result['rating'];
        _currentYear = result['year'];
        _currentRuntime = result['runtime'];
        _selectedActors = result['selectedActors'];
        _isCastAndLogic = result['isCastAndLogic'];
      });
      _fetchMovies(isRefresh: true); // Применили фильтры -> грузим первую страницу заново
    }
  }

  // Твоя функция рандома (теперь просто запрашивает случайную страницу)
  void _loadRandomMovies() {
    if (_totalPages <= 1) return; 
    final int maxPage = _totalPages > 500 ? 500 : _totalPages;
    final int randomPage = Random().nextInt(maxPage) + 1;
    _fetchMovies(isRefresh: true, specificPage: randomPage);
  }

  Future<void> _openMovieDetails(int movieId) async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
    );

    final fullMovieData = await _tmdbService.getMovieDetails(movieId);
    
    if (mounted) Navigator.pop(context);

    if (fullMovieData != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: fullMovieData)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.genreName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: _showFiltersBottomSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _movies.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 64, color: Colors.white54),
                        const SizedBox(height: 16),
                        Text(
                          'По таким фильтрам в жанре "${widget.genreName}" ничего не найдено 😢\nПопробуйте смягчить условия.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  controller: _scrollController, // Добавили контроллер для скролла
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.65, crossAxisSpacing: 16, mainAxisSpacing: 16,
                  ),
                  itemCount: _movies.length + (_isLoadingMore ? 2 : 0), // Место под лоадеры внизу
                  itemBuilder: (context, index) {
                    if (index >= _movies.length) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
                    }

                    final movie = _movies[index];
                    return GestureDetector(
                      onTap: () => _openMovieDetails(movie['id']),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            movie['poster_path'] != null
                                ? Image.network(_tmdbService.getImageUrl(movie['poster_path']), fit: BoxFit.cover)
                                : Container(color: Colors.grey[900]),
                            Positioned.fill(
                              child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)]))),
                            ),
                            Positioned(
                              bottom: 12, left: 12, right: 12,
                              child: Text(movie['title'] ?? 'Без названия', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            Positioned(
                              top: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text('${movie['vote_average']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _movies.isEmpty ? null : FloatingActionButton.extended(
        onPressed: _loadRandomMovies,
        backgroundColor: const Color(0xFF00E5FF),
        icon: const Icon(Icons.casino, color: Colors.black),
        label: const Text('ДРУГИЕ ФИЛЬМЫ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}