import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/tmdb_service.dart';
import '../services/database_service.dart';
import 'filters_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class RandomMovieScreen extends StatefulWidget {
  const RandomMovieScreen({super.key});

  @override
  State<RandomMovieScreen> createState() => _RandomMovieScreenState();
}

class _RandomMovieScreenState extends State<RandomMovieScreen> {
  final TMDBService _tmdbService = TMDBService();
  final DatabaseService _dbService = DatabaseService();
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  Map<String, dynamic>? _currentMovie;
  bool _isLoading = false;
  
  // Состояние UI
  double _blurValue = 0.0;
  double _darkenValue = 0.0;
  String _kpRating = '-.-';

  // Хранилище фильтров (поддержка Спринта 1)
  RangeValues _currentRating = const RangeValues(6.0, 10.0);
  RangeValues _currentYear = RangeValues(1990.0, 2026.0);
  Set<String> _currentGenresText = {};
  List<int> _currentGenresIds = [];
  bool _isGenreAndLogic = false;
  List<Map<String, dynamic>> _currentActors = [];
  List<int> _castIds = [];
  bool _isCastAndLogic = false;
  RangeValues _currentRuntime = const RangeValues(40.0, 240.0);
  int? _minRuntime;
  int? _maxRuntime;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetScroll);
    _fetchRandomMovie();
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetScroll);
    _sheetController.dispose();
    super.dispose();
  }

  void _onSheetScroll() {
    if (_sheetController.isAttached) {
      double extent = _sheetController.size;
      setState(() {
        if (extent > 0.25) {
          double progress = (extent - 0.25) / (0.85 - 0.25);
          _blurValue = (progress * 15).clamp(0.0, 15.0);
          _darkenValue = (progress * 0.7).clamp(0.0, 0.7);
        } else {
          _blurValue = 0.0; 
          _darkenValue = 0.0;
        }
      });
    }
  }

  Future<void> _fetchRandomMovie() async {
    setState(() {
      _isLoading = true;
      _blurValue = 0.0;
      _darkenValue = 0.0;
      _kpRating = '-.-';
    });

    final movie = await _tmdbService.getRandomMovie(
      minRating: _currentRating.start,
      maxRating: _currentRating.end,
      minYear: _currentYear.start.toInt(),
      maxYear: _currentYear.end.toInt(),
      genreIds: _currentGenresIds,
      isGenreAndLogic: _isGenreAndLogic,
      castIds: _castIds,
      isCastAndLogic: _isCastAndLogic,
      minRuntime: _minRuntime,
      maxRuntime: _maxRuntime,
    );

    if (movie != null && movie['imdb_id'] != null) {
      _fetchKinopoiskRating(movie['title'], movie['release_date']);
    }

    setState(() {
      _currentMovie = movie;
      _isLoading = false;
    });

    if (movie == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ничего не найдено 😢 Попробуйте изменить фильтры'), backgroundColor: Colors.redAccent)
      );
    }
  }

Future<void> _fetchKinopoiskRating(String title, String? releaseDate) async {
    // Вытаскиваем чистый год (например, "2024" из строки "2024-11-05")
    final String? releaseYear = releaseDate != null && releaseDate.isNotEmpty
        ? releaseDate.split('-')[0]
        : null;

    // Передаем в TMDBService название и год релиза
    final kpData = await _tmdbService.getKinopoiskData(title, releaseYear);
    
    if (kpData != null && mounted) {
      setState(() {
        _kpRating = kpData['ratingKinopoisk']?.toString() ?? '-.-';
      });
    }
  }

  Future<void> _searchInFreeSources(String platform) async {
    final title = _currentMovie?['title'];
    if (title == null) return;
    final query = Uri.encodeComponent(title);
    final url = platform == 'vk' ? 'https://vk.com/video?q=$query' : 'https://rutube.ru/search/?query=$query';
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
        actions: [
          if (_currentMovie != null)
            IconButton(
              icon: const Icon(Icons.ios_share, shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
              onPressed: () => Share.share(
                '🍿 Глянь, что выпало в CineMatch: ${_currentMovie!['title']}\n\ncinematch://movie?id=${_currentMovie!['id']}',
                subject: 'CineMatch Movie',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
            onPressed: () async {
              final result = await showModalBottomSheet<Map<String, dynamic>>(
                context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                builder: (context) => FiltersSheet(
                  initialRating: _currentRating, 
                  initialYear: _currentYear, 
                  initialGenres: _currentGenresText,
                  initialActors: _currentActors,
                  initialGenreLogic: _isGenreAndLogic,
                  initialCastLogic: _isCastAndLogic,
                  initialRuntime: _currentRuntime,
                ),
              );
              if (result != null) {
                setState(() {
                  _currentRating = result['rating'];
                  _currentYear = result['year'];
                  _currentGenresText = result['genresText'];
                  _currentGenresIds = result['genresIds'];
                  _currentActors = List<Map<String, dynamic>>.from(result['selectedActors'] ?? []);
                  _isGenreAndLogic = result['isGenreAndLogic'];
                  _castIds = result['castIds'];
                  _isCastAndLogic = result['isCastAndLogic'];
                  _currentRuntime = result['runtime'] as RangeValues? ?? const RangeValues(40.0, 240.0);
                  _minRuntime = result['minRuntime'];
                  _maxRuntime = result['maxRuntime'];
                });
                _fetchRandomMovie();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _currentMovie == null
              ? _buildEmptyState()
              : Stack(
                  children: [
                    Positioned.fill(child: Image.network(_tmdbService.getImageUrl(_currentMovie!['poster_path']), fit: BoxFit.cover)),
                    if (_blurValue > 0.1) Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: _blurValue, sigmaY: _blurValue), child: Container(color: Colors.black.withValues(alpha: _darkenValue)))),
                    Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black26, Colors.transparent, Colors.black])))),
                    
                    _buildContentSheet(),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fetchRandomMovie,
        backgroundColor: const Color(0xFF00E5FF),
        icon: const Icon(Icons.casino, color: Colors.black),
        label: const Text('СЛЕДУЮЩИЙ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildContentSheet() {
    final movie = _currentMovie!;
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.25, minChildSize: 0.15, maxChildSize: 0.85,
      builder: (context, scroll) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            
            // 1. Заголовок и Лайк
            Row(
              children: [
                Expanded(child: Text(movie['title'] ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black)]))),
                StreamBuilder<bool>(
                  stream: _dbService.isFavorite(movie['id']),
                  builder: (context, snap) => IconButton(
                    iconSize: 32, icon: Icon(snap.data == true ? Icons.favorite : Icons.favorite_border, color: snap.data == true ? Colors.redAccent : Colors.white),
                    onPressed: () => snap.data == true ? _dbService.removeFavorite(movie['id']) : _dbService.addFavorite(movie),
                  ),
                ),
              ],
            ),
            
            // --- ДОБАВИЛИ ЖАНРЫ СЮДА ---
            if (movie['genres'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  (movie['genres'] as List).map((g) => g['name']).join(' • '),
                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ),
            // -----------------------------
            
            const SizedBox(height: 12),
            
            // 2. ОЦЕНКИ
            _buildRatingPanel(movie),
            const SizedBox(height: 24),

            // 3. В МОЙ ПУЛ МЭТЧЕЙ
            _buildPoolButton(),
            const SizedBox(height: 24),

            // 4. ГДЕ СМОТРЕТЬ
            if (_getProviders(movie).isNotEmpty) _buildSection('Где смотреть', _buildProvidersList(movie)),

            // 5. КАДРЫ
            if (_getScreenshots(movie).isNotEmpty) _buildSection('Кадры', _buildScreenshotsList(movie)),

            // 6. ПОИСК В СЕТИ
            _buildSection('Поиск в сети', _buildFreeSearchRow(movie)),

            // 7. СМОТРЕТЬ ТРЕЙЛЕР
            if (_hasTrailer(movie)) _buildTrailerButton(movie),

            // 8. ОПИСАНИЕ
            _buildSection('Описание', Text(movie['overview'] ?? 'Описание отсутствует.', style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5))),
            
            // 9. В РОЛЯХ
            if (_getActors(movie).isNotEmpty) _buildSection('В ролях', _buildActorsList(movie)),

            // 10. РЕЦЕНЗИИ
            const Divider(color: Colors.white10, height: 60),
            _buildSection('Рецензии коммьюнити', _buildReviewPlaceholder()),
            
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // --- Вспомогательные блоки ---

  Widget _buildRatingPanel(Map<String, dynamic> m) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_ratingItem('TMDB', m['vote_average']?.toString() ?? '0.0', Colors.amber), _ratingItem('КП', _kpRating, Colors.orangeAccent), _ratingItem('ГОД', m['release_date']?.split('-')[0] ?? '---', Colors.white)]));

  Widget _ratingItem(String l, String v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.white54)), Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c))]);

  Widget _buildPoolButton() => SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавлено в пул мэтчей! 🃏', style: TextStyle(color: Colors.black)), backgroundColor: Color(0xFF00E5FF))), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), icon: const Icon(Icons.style), label: const Text('В МОЙ ПУЛ МЭТЧЕЙ', style: TextStyle(fontWeight: FontWeight.bold))));

  Widget _buildSection(String title, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 12), child, const SizedBox(height: 24)]);

  List _getProviders(Map m) => [...(m['watch/providers']?['results']?['RU']?['flatrate'] ?? []), ...(m['watch/providers']?['results']?['RU']?['free'] ?? [])];
  
  Widget _buildProvidersList(Map m) => SizedBox(height: 45, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _getProviders(m).length, itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(right: 12), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_tmdbService.getImageUrl(_getProviders(m)[i]['logo_path']), width: 45, height: 45)))));

  List _getScreenshots(Map m) => (m['images']?['backdrops'] as List?)?.take(10).toList() ?? [];

  Widget _buildScreenshotsList(Map m) => SizedBox(height: 150, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _getScreenshots(m).length, itemBuilder: (context, i) => Container(width: 240, margin: const EdgeInsets.only(right: 12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_tmdbService.getImageUrl(_getScreenshots(m)[i]['file_path']), fit: BoxFit.cover)))));

  Widget _buildFreeSearchRow(Map m) => Row(children: [Expanded(child: _sourceBtn('VK Видео', () => _searchInFreeSources('vk'), Colors.blueAccent)), const SizedBox(width: 12), Expanded(child: _sourceBtn('Rutube', () => _searchInFreeSources('rutube'), Colors.white24))]);

  Widget _sourceBtn(String l, VoidCallback o, Color c) => OutlinedButton(onPressed: o, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: c), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l));

  bool _hasTrailer(Map m) => m['videos']?['results']?.any((v) => v['site'] == 'YouTube' && v['type'] == 'Trailer') ?? false;

  Widget _buildTrailerButton(Map m) => Padding(padding: const EdgeInsets.only(bottom: 24), child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: () => _tmdbService.launchTrailer(m['videos']['results']), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), icon: const Icon(Icons.play_arrow), label: const Text('СМОТРЕТЬ ТРЕЙЛЕР'))));

  List _getActors(Map m) => (m['credits']?['cast'] as List?)?.take(10).toList() ?? [];

  Widget _buildActorsList(Map m) => SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _getActors(m).length, itemBuilder: (context, i) => Container(width: 80, margin: const EdgeInsets.only(right: 12), child: Column(children: [ClipOval(child: _getActors(m)[i]['profile_path'] != null ? Image.network(_tmdbService.getImageUrl(_getActors(m)[i]['profile_path']), width: 65, height: 65, fit: BoxFit.cover) : Container(width: 65, height: 65, color: Colors.white10, child: const Icon(Icons.person))), const SizedBox(height: 8), Text(_getActors(m)[i]['name'] ?? '', maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))]))));

  Widget _buildReviewPlaceholder() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [CircleAvatar(radius: 12, backgroundColor: Colors.white12, child: Icon(Icons.person, size: 14)), SizedBox(width: 8), Text('Киноман_2026', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))), Spacer(), Icon(Icons.star, color: Colors.amber, size: 12), Text(' 10/10', style: TextStyle(fontSize: 11))]), SizedBox(height: 8), Text('Лучший фильм за последнее время! Попробуйте свайпать с друзьями.', style: TextStyle(color: Colors.white70, fontSize: 13))]));

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Фильмы не найдены 😢'), const SizedBox(height: 16), ElevatedButton(onPressed: _fetchRandomMovie, child: const Text('Сбросить фильтры'))]));
}