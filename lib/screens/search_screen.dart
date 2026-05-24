import 'package:flutter/material.dart';
import 'dart:async';
import '../services/tmdb_service.dart';
import 'movie_details_screen.dart';
import 'filters_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TMDBService _tmdbService = TMDBService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _movies = [];
  bool _isLoading = false;
  bool _isFilterMode = false; // true = ищем по фильтрам, false = по тексту

  // Хранилище фильтров
  RangeValues _currentRating = const RangeValues(0.0, 10.0);
  RangeValues _currentYear = RangeValues(1950.0, 2026.0);
  RangeValues _currentRuntime = const RangeValues(40.0, 240.0);
  Set<String> _currentGenresText = {};
  List<int> _currentGenresIds = [];
  bool _isGenreAndLogic = false;
  List<Map<String, dynamic>> _selectedActors = [];
  bool _isCastAndLogic = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- ТЕКСТОВЫЙ ПОИСК ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _movies = [];
        _isFilterMode = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() {
        _isLoading = true;
        _isFilterMode = false; // Перешли в текстовый режим
      });

      final results = await _tmdbService.searchMovies(query);
      
      if (mounted) {
        setState(() {
          _movies = results;
          _isLoading = false;
        });
      }
    });
  }

  // --- ПОИСК ПО ФИЛЬТРАМ ---
  void _openFilters() async {
    FocusScope.of(context).unfocus(); // Прячем клавиатуру

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FiltersSheet(
        initialRating: _currentRating,
        initialYear: _currentYear,
        initialGenres: _currentGenresText,
        initialActors: _selectedActors,
        initialGenreLogic: _isGenreAndLogic,
        initialCastLogic: _isCastAndLogic,
        initialRuntime: _currentRuntime,
        showGenres: true,
      ),
    );

    if (result != null) {
      setState(() {
        _currentRating = result['rating'];
        _currentYear = result['year'];
        _currentRuntime = result['runtime'];
        _currentGenresText = result['genresText'];
        _currentGenresIds = result['genresIds'];
        _isGenreAndLogic = result['isGenreAndLogic'];
        _selectedActors = result['selectedActors'];
        _isCastAndLogic = result['isCastAndLogic'];
        
        _searchController.clear(); // Стираем текст
        _isFilterMode = true; // Переходим в режим фильтров
        _isLoading = true;
      });

      _fetchByFilters();
    }
  }

  Future<void> _fetchByFilters() async {
    // В TMDB /discover/movie работает лучше, если есть хотя бы 1 жанр. 
    // Если юзер ничего не выбрал - ставим 28 (Экшен) по умолчанию
    int primaryGenre = _currentGenresIds.isNotEmpty ? _currentGenresIds.first : 28;

    final data = await _tmdbService.getMoviesByGenre(
      primaryGenre,
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
        _movies = data['results'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя панель (Поиск + Кнопка фильтров)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Название фильма...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _isFilterMode ? const Color(0xFF00E5FF).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isFilterMode ? const Color(0xFF00E5FF) : Colors.transparent),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.tune, color: _isFilterMode ? const Color(0xFF00E5FF) : Colors.white),
                      onPressed: _openFilters,
                    ),
                  ),
                ],
              ),
            ),
            
            // Если включен режим фильтров — показываем плашку для сброса
            if (_isFilterMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Поиск по фильтрам активен', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isFilterMode = false;
                          _movies = [];
                        });
                      },
                      child: const Text('Сбросить', style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),

            // Основной контент (Грид с фильмами или заглушка)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                  : _movies.isEmpty
                      ? _buildEmptyState()
                      : _buildMoviesGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_filter, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            _isFilterMode ? 'По таким фильтрам ничего не найдено' : 'Начните поиск', 
            style: const TextStyle(color: Colors.white54, fontSize: 18)
          ),
          const SizedBox(height: 8),
          const Text('Вводите название или используйте фильтры', style: TextStyle(color: Colors.white30, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMoviesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _movies.length,
      itemBuilder: (context, index) {
        final movie = _movies[index];
        return GestureDetector(
          onTap: () async {
            FocusScope.of(context).unfocus();
            showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))));
            final fullData = await _tmdbService.getMovieDetails(movie['id']);
            if (mounted) Navigator.pop(context);
            if (fullData != null && mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: fullData)));
            }
          },
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
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const SizedBox(width: 4),
                        Text('${movie['vote_average']?.toStringAsFixed(1) ?? '0.0'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}