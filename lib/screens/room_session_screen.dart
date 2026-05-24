import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/tmdb_service.dart';
import '../services/room_service.dart';
import 'movie_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class RoomSessionScreen extends StatefulWidget {
  final String roomCode;
  const RoomSessionScreen({super.key, required this.roomCode});

  @override
  State<RoomSessionScreen> createState() => _RoomSessionScreenState();
}

class _RoomSessionScreenState extends State<RoomSessionScreen> with TickerProviderStateMixin {
  final TMDBService _tmdbService = TMDBService();
  final RoomService _roomService = RoomService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Данные сессии
  List<dynamic> _deck = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  int _participantsCount = 1;
  int _minLikesToMatch = 2;
  bool _isCreator = false;

  // Динамические полные данные для текущей карточки
  Map<String, dynamic>? _currentFullMovie;
  String _kpRating = '-.-';
  double _userRating = 0.0;

  // Анимации
  late AnimationController _shakeController;
  List<Offset> _firePositions = [];
  
  // Слушатели
  StreamSubscription<QuerySnapshot>? _matchSubscription;
  StreamSubscription<DocumentSnapshot>? _roomSubscription;

  // Контроллер шторки
  late DraggableScrollableController _sheetController;
  double _blurValue = 0.0;
  double _darkenValue = 0.0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _initSheetController();
    _loadInitialData();
    _listenForMatches();
    _listenForRoomStatus();
  }

  void _initSheetController() {
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(() {
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
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _matchSubscription?.cancel();
    _roomSubscription?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  // Загрузка колоды и настроек
  Future<void> _loadInitialData() async {
    final doc = await _db.collection('rooms').doc(widget.roomCode).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _deck = List.from(data['deck'] ?? [])..shuffle(); // Каждому свой рандом
        _participantsCount = (data['participants'] as List).length;
        _minLikesToMatch = data['min_likes'] ?? 2;
        _isCreator = data['creator'] == _roomService.uid;
        _isLoading = false;
      });
      _loadFullDataForCurrent(); // Загружаем тяжелые данные для первой карточки
    }
  }

  // Фоновая загрузка тяжелых данных (Кадры, Актеры, Кинопоиск)
  Future<void> _loadFullDataForCurrent() async {
    if (_currentIndex >= _deck.length) return;
    
    setState(() {
      _currentFullMovie = null;
      _kpRating = '-.-';
      _userRating = 0.0;
    });

    final lightMovie = _deck[_currentIndex];
    final fullData = await _tmdbService.getMovieDetails(lightMovie['id']);
    
    if (fullData != null && mounted && lightMovie['id'] == _deck[_currentIndex]['id']) {
      setState(() => _currentFullMovie = fullData);
      
      if (fullData['imdb_id'] != null) {
        final kpData = await _tmdbService.getKinopoiskData(fullData['imdb_id']);
        if (kpData != null && mounted && lightMovie['id'] == _deck[_currentIndex]['id']) {
          setState(() => _kpRating = kpData['ratingKinopoisk']?.toString() ?? '-.-');
        }
      }
    }
  }

  // Слушаем закрытие комнаты
  void _listenForRoomStatus() {
    _roomSubscription = _roomService.listenToRoom(widget.roomCode).listen((snap) {
      if (!snap.exists && mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      } else if (snap.exists && mounted) {
        final data = snap.data() as Map<String, dynamic>?;
        if (data != null && data['status'] == 'waiting') {
          Navigator.pop(context); 
        }
      }
    });
  }

  // Спецэффект Мэтча
  void _triggerMatchEffects() {
    _shakeController.forward(from: 0);
    setState(() {
      _firePositions = List.generate(20, (index) => Offset(Random().nextDouble(), Random().nextDouble()));
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _firePositions = []);
    });
  }

  void _listenForMatches() {
    _matchSubscription = _roomService.listenToMatches(widget.roomCode).listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _triggerMatchEffects();
          final movie = (change.doc.data() as Map<String, dynamic>)['movie'];
          Future.delayed(const Duration(milliseconds: 600), () => _showMatchDialog(movie));
        }
      }
    });
  }

  void _showMatchDialog(Map<String, dynamic> movie) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TweenAnimationBuilder(
        duration: const Duration(milliseconds: 500),
        tween: Tween<double>(begin: 0, end: 1),
        curve: Curves.elasticOut,
        builder: (context, val, child) => Transform.scale(
          scale: val,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.orangeAccent, width: 2),
                boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 40)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥🔥 МЭТЧ! 🔥🔥', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(_tmdbService.getImageUrl(movie['poster_path']), height: 250, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 16),
                  Text(movie['title'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                    child: const Text('ПРОДОЛЖИТЬ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _roomService.leaveRoom(widget.roomCode);
                    },
                    child: const Text('ЗАВЕРШИТЬ ВЫБОР', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _nextMovie() {
    if (_currentIndex < _deck.length) {
      setState(() {
        _currentIndex++;
        _blurValue = 0.0;
        _darkenValue = 0.0;
        _sheetController.dispose();
        _initSheetController();
      });
      _loadFullDataForCurrent(); // Грузим данные для следующей карточки
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('КОД: ${widget.roomCode}', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _showExitDialog),
        ),
        body: Stack(
          children: [
            // ТРЯСКА ЭКРАНА
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final double offset = sin(_shakeController.value * pi * 10) * 8;
                return Transform.translate(offset: Offset(offset, 0), child: child);
              },
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                : _currentIndex >= _deck.length 
                  ? _buildMatchesSummary() 
                  : _buildMovieCard(_deck[_currentIndex]),
            ),

            // ОГОНЬКИ
            ..._firePositions.map((pos) => Positioned(
              left: pos.dx * MediaQuery.of(context).size.width,
              top: pos.dy * MediaQuery.of(context).size.height,
              child: TweenAnimationBuilder(
                duration: const Duration(seconds: 1),
                tween: Tween<double>(begin: 1, end: 0),
                builder: (context, val, child) => Opacity(opacity: val, child: const Text('🔥', style: TextStyle(fontSize: 30))),
              ),
            )),
          ],
        ),
      ),
    );
  }

  // --- УНИФИЦИРОВАННАЯ КАРТОЧКА ФИЛЬМА ---
  Widget _buildMovieCard(Map<String, dynamic> baseMovie) {
    // Используем полные данные, если они уже загрузились, иначе показываем базу
    final movie = _currentFullMovie ?? baseMovie;

    return Stack(
      key: ValueKey(movie['id']),
      children: [
        Positioned.fill(child: Image.network(_tmdbService.getImageUrl(movie['poster_path']), fit: BoxFit.cover)),
        if (_blurValue > 0)
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: _blurValue, sigmaY: _blurValue), child: Container(color: Colors.black.withValues(alpha: _darkenValue)))),
        Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black38, Colors.transparent, Colors.black87])))),
        
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.3, minChildSize: 0.2, maxChildSize: 0.85,
          builder: (context, scroll) => SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                
                // Заголовок
                Text(movie['title'] ?? '', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                
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
                
                // 1. ОЦЕНКИ
                _buildRatingPanel(movie),
                const SizedBox(height: 24),

                // 2. В МОЙ ПУЛ МЭТЧЕЙ
                _buildPoolButton(),
                const SizedBox(height: 24),

                // (Опционально) Ползунок личной оценки
                _buildUserRatingSlider(),
                const SizedBox(height: 24),

                // 3. ГДЕ СМОТРЕТЬ
                if (_getWatchProviders(movie).isNotEmpty) _buildSection('Где смотреть', _buildProvidersList(movie)),

                // 4. КАДРЫ
                if (_getScreenshots(movie).isNotEmpty) _buildSection('Кадры', _buildScreenshotsList(movie)),

                // 5. ПОИСК В СЕТИ
                _buildSection('Поиск в сети', _buildFreeSearchRow(movie)),

                // 6. СМОТРЕТЬ ТРЕЙЛЕР
                if (_hasTrailer(movie)) _buildTrailerButton(movie),

                // 7. ОПИСАНИЕ
                _buildSection('Описание', Text(movie['overview'] ?? 'Описание отсутствует.', style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5))),
                
                // 8. В РОЛЯХ
                if (_getActors(movie).isNotEmpty) _buildSection('В ролях', _buildActorsList(movie)),

                // 9. РЕЦЕНЗИИ
                const Divider(color: Colors.white10, height: 60),
                _buildSection('Рецензии коммьюнити', _buildReviewPlaceholder()),
                
                const SizedBox(height: 160), // Большой отступ для кнопок Лайк/Дислайк
              ],
            ),
          ),
        ),

        // КНОПКИ ЛАЙК / ДИСЛАЙК
        Positioned(
          bottom: 40, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _circleBtn(Icons.close, Colors.redAccent, () => _nextMovie()),
              _circleBtn(Icons.favorite, const Color(0xFF00E5FF), () {
                _roomService.likeMovie(widget.roomCode, movie);
                _nextMovie();
              }),
            ],
          ),
        )
      ],
    );
  }

  // --- МЕТОДЫ ИЗВЛЕЧЕНИЯ ДАННЫХ И ПОСТРОЕНИЯ БЛОКОВ ---

  List<dynamic> _getWatchProviders(Map<String, dynamic> movie) {
    final ru = movie['watch/providers']?['results']?['RU'];
    return ru == null ? [] : [...(ru['flatrate'] ?? []), ...(ru['free'] ?? [])];
  }

  List<dynamic> _getScreenshots(Map<String, dynamic> movie) => (movie['images']?['backdrops'] as List<dynamic>?)?.take(10).toList() ?? [];

  List<dynamic> _getActors(Map<String, dynamic> movie) => (movie['credits']?['cast'] as List<dynamic>?)?.take(10).toList() ?? [];

  bool _hasTrailer(Map<String, dynamic> movie) => movie['videos']?['results']?.any((v) => v['site'] == 'YouTube' && v['type'] == 'Trailer') ?? false;

  Future<void> _searchInFreeSources(String? title, String platform) async {
    if (title == null) return;
    final query = Uri.encodeComponent(title);
    final url = platform == 'vk' ? 'https://vk.com/video?q=$query' : 'https://rutube.ru/search/?query=$query';
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _buildRatingPanel(Map<String, dynamic> movie) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_ratingItem('TMDB', movie['vote_average']?.toString() ?? '0.0', Colors.amber), _ratingItem('КП', _kpRating, Colors.orangeAccent), _ratingItem('ГОД', movie['release_date']?.split('-')[0] ?? '---', Colors.white)]));

  Widget _ratingItem(String l, String v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.white54)), Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c))]);

  Widget _buildPoolButton() => SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавлено в ваш пул мэтчей! 🃏', style: TextStyle(color: Colors.black)), backgroundColor: Color(0xFF00E5FF))), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), icon: const Icon(Icons.style), label: const Text('В МОЙ ПУЛ МЭТЧЕЙ', style: TextStyle(fontWeight: FontWeight.bold))));

  Widget _buildUserRatingSlider() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('МОЯ ОЦЕНКА', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54)), Slider(value: _userRating, min: 0, max: 10, divisions: 10, label: _userRating.toInt().toString(), activeColor: const Color(0xFF00E5FF), onChanged: (v) => setState(() => _userRating = v))]);

  Widget _buildSection(String title, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 12), child, const SizedBox(height: 24)]);

  Widget _buildProvidersList(Map<String, dynamic> movie) => SizedBox(height: 45, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _getWatchProviders(movie).length, itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(right: 12), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_tmdbService.getImageUrl(_getWatchProviders(movie)[i]['logo_path']), width: 45, height: 45)))));

  Widget _buildScreenshotsList(Map<String, dynamic> movie) => SizedBox(height: 150, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _getScreenshots(movie).length, itemBuilder: (context, i) => Container(width: 240, margin: const EdgeInsets.only(right: 12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_tmdbService.getImageUrl(_getScreenshots(movie)[i]['file_path']), fit: BoxFit.cover)))));

  Widget _buildFreeSearchRow(Map<String, dynamic> movie) => Row(children: [Expanded(child: _sourceBtn('VK Видео', () => _searchInFreeSources(movie['title'], 'vk'), Colors.blueAccent)), const SizedBox(width: 12), Expanded(child: _sourceBtn('Rutube', () => _searchInFreeSources(movie['title'], 'rutube'), Colors.white24))]);

  Widget _sourceBtn(String l, VoidCallback o, Color c) => OutlinedButton(onPressed: o, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: c), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l));

  Widget _buildTrailerButton(Map<String, dynamic> movie) => Padding(padding: const EdgeInsets.only(bottom: 24), child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: () => _tmdbService.launchTrailer(movie['videos']['results']), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), icon: const Icon(Icons.play_arrow), label: const Text('СМОТРЕТЬ ТРЕЙЛЕР'))));

  Widget _buildActorsList(Map<String, dynamic> movie) => SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _getActors(movie).length, itemBuilder: (context, i) => Container(width: 80, margin: const EdgeInsets.only(right: 12), child: Column(children: [ClipOval(child: _getActors(movie)[i]['profile_path'] != null ? Image.network(_tmdbService.getImageUrl(_getActors(movie)[i]['profile_path']), width: 65, height: 65, fit: BoxFit.cover) : Container(width: 65, height: 65, color: Colors.white10, child: const Icon(Icons.person))), const SizedBox(height: 8), Text(_getActors(movie)[i]['name'] ?? '', maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))]))));

  Widget _buildReviewPlaceholder() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [CircleAvatar(radius: 12, backgroundColor: Colors.white12, child: Icon(Icons.person, size: 14)), SizedBox(width: 8), Text('Киноман_2026', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))), Spacer(), Icon(Icons.star, color: Colors.amber, size: 12), Text(' 10/10', style: TextStyle(fontSize: 11))]), SizedBox(height: 8), Text('Лучший фильм, что я видел за последнее время! Обязательно к просмотру.', style: TextStyle(color: Colors.white70, fontSize: 13))]));


  // --- ЭКРАН ИТОГОВ "МОИ МЭТЧИ" ---
  Widget _buildMatchesSummary() {
    return Container(
      color: const Color(0xFF121212),
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
      child: Column(
        children: [
          const Text('МОИ МЭТЧИ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _roomService.listenToVotes(widget.roomCode),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('Нет совпадений 😢', style: TextStyle(color: Colors.white54)));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final movie = data['movie'];
                    final likes = data['count'] ?? 0;
                    final bool isMatch = likes >= _minLikesToMatch;

                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie))),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMatch ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isMatch ? Colors.orangeAccent : Colors.white10),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_tmdbService.getImageUrl(movie['poster_path']), width: 60, height: 90, fit: BoxFit.cover)),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isMatch) const Text('🔥 МЭТЧ!', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(movie['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2),
                                  const SizedBox(height: 4),
                                  Text('Лайков: $likes из $_participantsCount', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white24),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (_isCreator) Expanded(
                child: ElevatedButton(
                  onPressed: () => _roomService.resetRoom(widget.roomCode),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text('НОВАЯ КОЛОДА', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              if (_isCreator) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _roomService.leaveRoom(widget.roomCode),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text('ЗАВЕРШИТЬ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Выйти?'),
        content: const Text('Вы покинуте подбор. Если участников станет меньше 2, комната закроется.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА')),
          TextButton(onPressed: () => _roomService.leaveRoom(widget.roomCode), child: const Text('ВЫЙТИ', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black45, border: Border.all(color: color.withValues(alpha: 0.5), width: 2), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10)]),
        child: Icon(icon, size: 35, color: color),
      ),
    );
  }
}