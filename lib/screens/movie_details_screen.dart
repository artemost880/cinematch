import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/tmdb_service.dart';
import '../services/database_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> movie;
  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final TMDBService _tmdbService = TMDBService();
  final DatabaseService _dbService = DatabaseService();
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  double _blurValue = 0.0;
  double _darkenValue = 0.0;
  String _kpRating = '-.-'; 

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetScroll);
    _fetchKinopoiskRating();
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetScroll);
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _fetchKinopoiskRating() async {
    final imdbId = widget.movie['imdb_id']; 
    if (imdbId != null) {
      final kpData = await _tmdbService.getKinopoiskData(imdbId);
      if (kpData != null && mounted) {
        setState(() => _kpRating = kpData['ratingKinopoisk']?.toString() ?? '-.-');
      }
    }
  }

  Future<void> _searchInFreeSources(String platform) async {
    final title = widget.movie['title'];
    if (title == null) return;
    
    final query = Uri.encodeComponent(title);
    final url = platform == 'vk' 
        ? 'https://vk.com/video?q=$query' 
        : 'https://rutube.ru/search/?query=$query';
        
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _onSheetScroll() {
    if (_sheetController.isAttached) {
      double extent = _sheetController.size;
      setState(() {
        if (extent > 0.3) {
          double progress = (extent - 0.3) / (0.85 - 0.3);
          _blurValue = (progress * 15).clamp(0.0, 15.0);
          _darkenValue = (progress * 0.7).clamp(0.0, 0.7);
        } else {
          _blurValue = 0.0; 
          _darkenValue = 0.0;
        }
      });
    }
  }

  List<dynamic> _getWatchProviders() {
    final ru = widget.movie['watch/providers']?['results']?['RU'];
    return ru == null ? [] : [...(ru['flatrate'] ?? []), ...(ru['free'] ?? [])];
  }

  List<dynamic> _getScreenshots() => 
      (widget.movie['images']?['backdrops'] as List<dynamic>?)?.take(10).toList() ?? [];

  List<dynamic> _getActors() => 
      (widget.movie['credits']?['cast'] as List<dynamic>?)?.take(10).toList() ?? [];

  bool _hasTrailer() => 
      widget.movie['videos']?['results']?.any((v) => v['site'] == 'YouTube' && v['type'] == 'Trailer') ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
            onPressed: () {
              final title = widget.movie['title'] ?? 'Фильм';
              Share.share(
                '🍿 CineMatch: $title\n\ncinematch://movie?id=${widget.movie['id']}',
                subject: 'CineMatch Movie',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.movie['poster_path'] != null
                ? Image.network(_tmdbService.getImageUrl(widget.movie['poster_path']), fit: BoxFit.cover)
                : Container(color: Colors.black),
          ),
          if (_blurValue > 0.1)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: _blurValue, sigmaY: _blurValue),
                child: Container(color: Colors.black.withValues(alpha: _darkenValue)),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.2), Colors.transparent, Colors.black],
                ),
              ),
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.3, 
            minChildSize: 0.2, 
            maxChildSize: 0.9,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 5, 
                      decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(10))
                    )
                  ),
                  const SizedBox(height: 20),
                  
                  // 1. Заголовок и Лайк
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.movie['title'] ?? '', 
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black)])
                        )
                      ),
                      StreamBuilder<bool>(
                        stream: _dbService.isFavorite(widget.movie['id']),
                        builder: (context, snap) => IconButton(
                          iconSize: 32, 
                          icon: Icon(snap.data == true ? Icons.favorite : Icons.favorite_border, color: snap.data == true ? Colors.redAccent : Colors.white),
                          onPressed: () => snap.data == true ? _dbService.removeFavorite(widget.movie['id']) : _dbService.addFavorite(widget.movie),
                        ),
                      ),
                    ],
                  ),
                  
                  // --- ЖАНРЫ (ТО, ЧТО МЫ ХОТЕЛИ ДОБАВИТЬ) ---
                  if (widget.movie['genres'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: Text(
                        (widget.movie['genres'] as List).map((g) => g['name']).join(' • '),
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ),
                  // -----------------------------------------
                  
                  // 2. Оценки
                  _buildRatingPanel(),
                  const SizedBox(height: 24),

                  // 3. Пул Мэтчей
                  _buildPoolButton(),
                  const SizedBox(height: 24),

                  // 4. Где смотреть
                  if (_getWatchProviders().isNotEmpty) _buildSection('Где смотреть', _buildProvidersList()),

                  // 5. Кадры
                  if (_getScreenshots().isNotEmpty) _buildSection('Кадры', _buildScreenshotsList()),

                  // 6. Поиск в сети
                  _buildSection('Поиск в сети', _buildFreeSearchRow()),

                  // 7. Смотреть трейлер
                  if (_hasTrailer()) _buildTrailerButton(),

                  // 8. Описание
                  _buildSection('Описание', Text(widget.movie['overview'] ?? 'Описание отсутствует.', style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5))),
                  
                  // 9. В ролях
                  if (_getActors().isNotEmpty) _buildSection('В ролях', _buildActorsList()),

                  // 10. Рецензии
                  const Divider(color: Colors.white10, height: 60),
                  _buildSection('Рецензии коммьюнити', _buildReviewPlaceholder()),
                  
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Вспомогательные блоки ---
  Widget _buildRatingPanel() => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_ratingItem('TMDB', widget.movie['vote_average']?.toString() ?? '0.0', Colors.amber), _ratingItem('КП', _kpRating, Colors.orangeAccent), _ratingItem('ГОД', widget.movie['release_date']?.split('-')[0] ?? '---', Colors.white)]));

  Widget _ratingItem(String l, String v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.white54)), Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c))]);

  Widget _buildPoolButton() => SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавлено в ваш пул мэтчей! 🃏', style: TextStyle(color: Colors.black)), backgroundColor: Color(0xFF00E5FF))), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), icon: const Icon(Icons.style), label: const Text('В МОЙ ПУЛ МЭТЧЕЙ', style: TextStyle(fontWeight: FontWeight.bold))));

  Widget _buildSection(String title, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 12), child, const SizedBox(height: 24)]);

  Widget _buildProvidersList() => SizedBox(height: 45, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _getWatchProviders().length, itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(right: 12), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_tmdbService.getImageUrl(_getWatchProviders()[i]['logo_path']), width: 45, height: 45)))));

  Widget _buildScreenshotsList() => SizedBox(height: 150, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _getScreenshots().length, itemBuilder: (context, i) => Container(width: 240, margin: const EdgeInsets.only(right: 12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_tmdbService.getImageUrl(_getScreenshots()[i]['file_path']), fit: BoxFit.cover)))));

  Widget _buildFreeSearchRow() => Row(children: [Expanded(child: _sourceBtn('VK Видео', () => _searchInFreeSources('vk'), Colors.blueAccent)), const SizedBox(width: 12), Expanded(child: _sourceBtn('Rutube', () => _searchInFreeSources('rutube'), Colors.white24))]);

  Widget _sourceBtn(String l, VoidCallback o, Color c) => OutlinedButton(onPressed: o, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: c), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l));

  Widget _buildTrailerButton() => Padding(padding: const EdgeInsets.only(bottom: 24), child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: () => _tmdbService.launchTrailer(widget.movie['videos']['results']), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), icon: const Icon(Icons.play_arrow), label: const Text('СМОТРЕТЬ ТРЕЙЛЕР'))));

  Widget _buildActorsList() => SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _getActors().length, itemBuilder: (context, i) => Container(width: 80, margin: const EdgeInsets.only(right: 12), child: Column(children: [ClipOval(child: _getActors()[i]['profile_path'] != null ? Image.network(_tmdbService.getImageUrl(_getActors()[i]['profile_path']), width: 65, height: 65, fit: BoxFit.cover) : Container(width: 65, height: 65, color: Colors.white10, child: const Icon(Icons.person))), const SizedBox(height: 8), Text(_getActors()[i]['name'] ?? '', maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))]))));

  Widget _buildReviewPlaceholder() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [CircleAvatar(radius: 12, backgroundColor: Colors.white12, child: Icon(Icons.person, size: 14)), SizedBox(width: 8), Text('Киноман_2026', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))), Spacer(), Icon(Icons.star, color: Colors.amber, size: 12), Text(' 10/10', style: TextStyle(fontSize: 11))]), SizedBox(height: 8), Text('Лучший фильм, что я видел за последнее время! Обязательно к просмотру.', style: TextStyle(color: Colors.white70, fontSize: 13))]));
}