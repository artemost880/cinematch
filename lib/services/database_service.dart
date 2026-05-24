import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Получаем ID текущего пользователя
  String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');
    return user.uid;
  }

  // Ссылка на личную коллекцию "favorites" в базе
  CollectionReference get _favoritesRef {
    return _db.collection('users').doc(uid).collection('favorites');
  }

  // Добавить фильм в избранное
  Future<void> addFavorite(Map<String, dynamic> movie) async {
    // Используем ID фильма от TMDB как имя документа, чтобы избежать дубликатов
    await _favoritesRef.doc(movie['id'].toString()).set(movie);
  }

  // Удалить из избранного
  Future<void> removeFavorite(int movieId) async {
    await _favoritesRef.doc(movieId.toString()).delete();
  }

  // Получить поток (Stream) всех избранных фильмов для отрисовки списка
  Stream<QuerySnapshot> getFavorites() {
    return _favoritesRef.snapshots();
  }

  // Проверить, находится ли фильм в избранном (чтобы закрашивать сердечко)
  Stream<bool> isFavorite(int movieId) {
    return _favoritesRef.doc(movieId.toString()).snapshots().map((doc) => doc.exists);
  }
}