import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Получить текущего пользователя
  User? get currentUser => _auth.currentUser;

  // Поток состояния авторизации (слушаем, вошел юзер или вышел)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. Анонимный вход (Оставляем для тех, кто хочет просто потестить)
  Future<User?> signInAnonymously() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      return result.user;
    } catch (e) {
      // Игнорируем принты в проде, но для дебага полезно
      return null;
    }
  }

  // 2. Регистрация (Email + Пароль + Имя)
  Future<User?> registerWithEmailAndPassword(String email, String password, String username) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      User? user = result.user;

      if (user != null) {
        // Как только юзер зарегистрировался в Auth, создаем ему профиль в Firestore
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'username': username,
          'created_at': FieldValue.serverTimestamp(),
          'pins': ['early_bird'], // Сразу даем пин "Ранняя пташка" за регистрацию в бете!
          'bio': 'Киноман', // Дефолтный статус
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
      // Пробрасываем ошибку с понятным текстом для UI
      if (e.code == 'weak-password') {
        throw Exception('Слишком простой пароль.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('Этот Email уже зарегистрирован.');
      }
      throw Exception('Ошибка регистрации. Проверьте данные.');
    }
  }

  // 3. Вход (Email + Пароль)
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Неверный Email или пароль.');
      }
      throw Exception('Ошибка входа.');
    }
  }

  // 4. Выход из аккаунта
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Ошибка при выходе из аккаунта.');
    }
  }
}