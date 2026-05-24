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
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  List<dynamic> _movies = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isFilterMode = false; // true = по фильтрам, false = по тексту

  // Пагинация
  int _currentPage = 1;
  int _totalPages = 1;

  // Хранилище фильтров
  RangeValues _currentRating = const RangeValues(0.0, 10.0);
  RangeValues _currentYear = const RangeValues(1950.0, 2026.0);
  RangeValues _currentRuntime = const RangeValues(40.0, 240.0);
  Set<String> _currentGenresText = {};
  String _currentGenresQuery = ''; // Новое query-хранилище для позитивных и негативных жанров
  bool _isGenreAndLogic = false;
  List<Map<String, dynamic>> _selectedActors = [];
  bool _isCastAndLogic = false;
  String _currentContentType = 'movie'; 

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Следим за прокруткой для бесконечного листания
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoading && !_isLoadingMore && _currentPage < _totalPages) {
        _loadNextPage();
      }
    }
  }

  // --- ТЕКСТОВЫЙ ПОИСК (ПЕРВАЯ СТРАНИЦА) ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _movies = [];
        _isFilterMode = false;
        _currentPage = 1;
        _totalPages = 1;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() {
        _isLoading = true;
        _isFilterMode = false; 
        _currentPage = 1;
      });

      final results = await _tmdbService.searchMovies(query, contentType: _currentContentType);
      
      if (mounted) {
        setState(() {
          _movies = results;
          _totalPages = 5; // Базовый лимит страниц для текстового поиска
          _isLoading = false;
        });
      }
    });
  }

  // --- ПОИСК ПО ФИЛЬТРАМ (ПЕРВАЯ СТРАНИЦА) ---
  void _openFilters() async {
    FocusScope.of(context).unfocus(); 

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
        initialContentType: _currentContentType, 
        showGenres: true,
      ),
    );

    if (result != null) {
      setState(() {
        _currentRating = result['rating'];
        _currentYear = result['year'];
        _currentRuntime = result['runtime'];
        _currentGenresText = result['genresText'];
        _currentGenresQuery = result['genresQuery']; // Получаем готовую строку (включая инвертированные жанры с "!")
        _isGenreAndLogic = result['isGenreAndLogic'];
        _selectedActors = result['selectedActors'];
        _isCastAndLogic = result['isCastAndLogic'];
        _currentContentType = result['contentType']; 
        
        _searchController.clear(); 
        _isFilterMode = true; 
        _isLoading = true;
        _currentPage = 1;
      });

      _fetchByFilters();
    }
  }

// ИСПРАВЛЕНО: Убрали лишний текст перед объявлением метода
 Future<void> _fetchByFilters() async {
    // Передаем готовую собранную query-строку жанров в метод получения данных
    final data = await _tmdbService.getMoviesByGenre(
      _currentGenresQuery, 
      page: _currentPage,
      minRating: _currentRating.start,
      maxRating: _currentRating.end,
      minYear: _currentYear.start.toInt(),
      maxYear: _currentYear.end.toInt(),
      castIds: _selectedActors.map((a) => a['id'] as int).toList(),
      isCastAndLogic: _isCastAndLogic, // ИСПРАВЛЕНО: заменили = на :
      minRuntime: _currentRuntime.start.toInt(),
      maxRuntime: _currentRuntime.end == 240.0 ? null : _currentRuntime.end.toInt(), // ИСПРАВЛЕНО: убрали лишнюю скобку )
      contentType: _currentContentType, 
    );

    if (mounted) {
      setState(() {
        _movies = data['results'] ?? [];
        _totalPages = data['total_pages'] ?? 1;
        _isLoading = false;
      });
    }
  }

  // --- ЗАГРУЗКА СЛЕДУЮЩЕЙ СТРАНИЦЫ (БЕСКОНЕЧНЫЙ СКРОЛЛ) ---
  Future<void> _loadNextPage() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;

    List<dynamic> newItems = [];

    if (_isFilterMode) {
      final data = await _tmdbService.getMoviesByGenre(
        _currentGenresQuery,
        page: nextPage,
        minRating: _currentRating.start,
        maxRating: _currentRating.end,
        minYear: _currentYear.start.toInt(),
        maxYear: _currentYear.end.toInt(),
        castIds: _selectedActors.map((a) => a['id'] as int).toList(),
        isCastAndLogic: _isCastAndLogic,
        minRuntime: _currentRuntime.start.toInt(),
        maxRuntime: _currentRuntime.end == 240.0 ? null : _currentRuntime.end.toInt(),
        contentType: _currentContentType,
      );
      newItems = data['results'] ?? [];
    } else {
      try {
        final endpoint = _currentContentType == 'movie' ? '/search/movie' : '/search/tv';
        final dio = _tmdbService.getDioInstance(); 
        final response = await dio.get(
          endpoint,
          queryParameters: {
            'api_key': _tmdbService.apiKey,
            'language': 'ru-RU',
            'query': _searchController.text,
            'page': nextPage,
          },
        );
        final List<dynamic> results = response.data['results'] ?? [];
        newItems = results.map((item) => _tmdbService.normalizeItemHelper(item, _currentContentType)).toList();
      } catch (_) {}
    }

    if (mounted && newItems.isNotEmpty) {
      setState(() {
        _movies.addAll(newItems);
        _currentPage = nextPage;
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Панель поиска и фильтров
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
                        hintText: 'Название фильма или сериала...',
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

            if (_isFilterMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Поиск активен: ${_currentContentType == 'tv' ? 'Сериалы' : 'Фильмы'}', 
                      style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isFilterMode = false;
                          _movies = [];
                          _currentPage = 1;
                          _totalPages = 1;
                        });
                      },
                      child: const Text('Сбросить', style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),

            // Вывод элементов
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
      controller: _scrollController, 
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _movies.length + (_isLoadingMore ? 2 : 0), 
      itemBuilder: (context, index) {
        if (index >= _movies.length) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        }
        
        final movie = _movies[index];
        return GestureDetector(
          onTap: () async {
            FocusScope.of(context).unfocus();
            showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))));
            
            final fullData = await _tmdbService.getMovieDetails(movie['id'], contentType: _currentContentType);
            
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