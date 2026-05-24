import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'tmdb_service.dart';

class RoomService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TMDBService _tmdb = TMDBService();

  // Простая генерация гостевого ID для Спринта 1 (до внедрения Firebase Auth)
  static String? _cachedUid;
  String get uid {
    _cachedUid ??= 'guest_${Random().nextInt(100000)}';
    return _cachedUid!;
  }

  // 1. Создание комнаты (Лобби)
  Future<String> createRoom() async {
    final code = (Random().nextInt(900000) + 100000).toString(); // 6 цифр
    await _db.collection('rooms').doc(code).set({
      'code': code,
      'creator': uid,
      'participants': [uid],
      'status': 'waiting',
      'min_likes': 2,
      'deck_size': 20,
      'created_at': FieldValue.serverTimestamp(),
    });
    return code;
  }

  // 2. Присоединение по коду
  Future<bool> joinRoom(String code) async {
    final doc = await _db.collection('rooms').doc(code).get();
    if (!doc.exists) return false;

    await _db.collection('rooms').doc(code).update({
      'participants': FieldValue.arrayUnion([uid])
    });
    return true;
  }

  // 3. Выход из комнаты
  Future<void> leaveRoom(String code) async {
    final doc = await _db.collection('rooms').doc(code).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final participants = List<String>.from(data['participants'] ?? []);
    participants.remove(uid);

    if (participants.isEmpty) {
      // Если все вышли — удаляем комнату, чтобы не засорять БД
      await _db.collection('rooms').doc(code).delete();
    } else {
      await _db.collection('rooms').doc(code).update({
        'participants': participants,
        // Если вышел создатель, передаем права случайному оставшемуся
        if (data['creator'] == uid) 'creator': participants.first, 
      });
    }
  }

  // 4. Обновление настроек лобби
  Future<void> updateSettings(String code, {required int minLikes, required int deckSize}) async {
    await _db.collection('rooms').doc(code).update({
      'min_likes': minLikes,
      'deck_size': deckSize,
    });
  }

  // 5. ЗАПУСК ИГРЫ (Теперь с полным набором фильтров!)
  Future<void> startRoom(
    String code, {
    required double minRating,
    required double maxRating,
    required int minYear,
    required int maxYear,
    required List<int> genreIds,
    required int deckSize,
    bool isGenreAndLogic = false,
    List<int> castIds = const [],
    bool isCastAndLogic = false,
    int? minRuntime,
    int? maxRuntime,
  }) async {
    
    // 1. Формируем колоду
    final deck = await _populateDeck(
      minRating: minRating,
      maxRating: maxRating,
      minYear: minYear,
      maxYear: maxYear,
      genreIds: genreIds,
      deckSize: deckSize,
      isGenreAndLogic: isGenreAndLogic,
      castIds: castIds,
      isCastAndLogic: isCastAndLogic,
      minRuntime: minRuntime,
      maxRuntime: maxRuntime,
    );

    // 2. Меняем статус на active, что автоматически перекинет всех на экран свайпов
    await _db.collection('rooms').doc(code).update({
      'status': 'active',
      'deck': deck,
    });
  }

  // 6. Формирование колоды (Молниеносная версия)
  Future<List<dynamic>> _populateDeck({
    required double minRating,
    required double maxRating,
    required int minYear,
    required int maxYear,
    required List<int> genreIds,
    required int deckSize,
    required bool isGenreAndLogic,
    required List<int> castIds,
    required bool isCastAndLogic,
    int? minRuntime,
    int? maxRuntime,
  }) async {
    
    // TMDB API ожидает хотя бы один базовый жанр для эндпоинта /discover/movie, 
    // если он не выбран, берем 28 (Экшен) по умолчанию, чтобы запрос не упал.
    int primaryGenre = genreIds.isNotEmpty ? genreIds.first : 28;

    final response = await _tmdb.getMoviesByGenre(
      primaryGenre,
      minRating: minRating,
      maxRating: maxRating,
      minYear: minYear,
      maxYear: maxYear,
      castIds: castIds,
      isCastAndLogic: isCastAndLogic,
      minRuntime: minRuntime,
      maxRuntime: maxRuntime,
    );

    List<dynamic> results = response['results'] ?? [];
    results.shuffle(); // Перемешиваем, чтобы игры не были одинаковыми

    // Мы возвращаем "легкие" карточки без тяжелых запросов деталей.
    // Экран RoomSessionScreen сам подгрузит актеров и трейлеры в фоне!
    return results.take(deckSize).toList();
  }

  // 7. Голосование (Лайк)
  Future<void> likeMovie(String code, Map<String, dynamic> movie) async {
    final voteRef = _db.collection('rooms').doc(code).collection('votes').doc(movie['id'].toString());
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(voteRef);
      if (!snapshot.exists) {
        // Первый лайк фильму
        transaction.set(voteRef, {
          'movie': movie,
          'count': 1,
          'users': [uid]
        });
      } else {
        // Защита от двойного голосования одного юзера
        List<dynamic> users = snapshot.data()?['users'] ?? [];
        if (!users.contains(uid)) {
          transaction.update(voteRef, {
            'count': FieldValue.increment(1),
            'users': FieldValue.arrayUnion([uid])
          });
        }
      }
    });
  }

  // 8. Перезапуск комнаты для новой игры
  Future<void> resetRoom(String code) async {
    await _db.collection('rooms').doc(code).update({
      'status': 'waiting',
      'deck': FieldValue.delete(),
    });
    
    // Очищаем историю голосов
    final votes = await _db.collection('rooms').doc(code).collection('votes').get();
    for (var doc in votes.docs) {
      await doc.reference.delete();
    }
  }

  // --- Слушатели для интерфейса (Real-time) ---
  Stream<DocumentSnapshot> listenToRoom(String code) => _db.collection('rooms').doc(code).snapshots();
  
  Stream<QuerySnapshot> listenToVotes(String code) => _db.collection('rooms').doc(code).collection('votes').orderBy('count', descending: true).snapshots();
  
  Stream<QuerySnapshot> listenToMatches(String code) => _db.collection('rooms').doc(code).collection('votes').snapshots(); 
}