import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AuthService _authService = AuthService();
  
  // Контроллеры для текстовых полей
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoginMode = true; // true = Вход, false = Регистрация
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLoginMode && username.isEmpty)) {
      _showError('Пожалуйста, заполните все поля');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        // Логика ВХОДА
        await _authService.signInWithEmailAndPassword(email, password);
      } else {
        // Логика РЕГИСТРАЦИИ
        await _authService.registerWithEmailAndPassword(email, password, username);
      }
      // При успешном входе ничего не делаем — StreamBuilder в main.dart сам переключит экран!
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
      setState(() => _isLoading = false);
    }
  }

  void _guestLogin() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInAnonymously();
    } catch (e) {
      _showError('Ошибка гостевого входа');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Логотип
                const Icon(Icons.movie_filter, size: 80, color: Color(0xFF00E5FF)),
                const SizedBox(height: 16),
                const Text(
                  'CINEMATCH',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: Color(0xFF00E5FF)),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode ? 'С возвращением!' : 'Создайте аккаунт',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 48),

                // Поле имени (только при регистрации)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _isLoginMode ? 0 : 70, // Прячем или показываем с анимацией
                  curve: Curves.easeInOut,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: _buildTextField(
                      controller: _usernameController,
                      icon: Icons.person_outline,
                      hint: 'Имя пользователя',
                    ),
                  ),
                ),
                if (!_isLoginMode) const SizedBox(height: 16),

                // Поле Email
                _buildTextField(
                  controller: _emailController,
                  icon: Icons.alternate_email,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Поле Пароля
                _buildTextField(
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  hint: 'Пароль',
                  isPassword: true,
                ),
                const SizedBox(height: 32),

                // Главная кнопка действия
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text(
                            _isLoginMode ? 'ВОЙТИ' : 'ЗАРЕГИСТРИРОВАТЬСЯ',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Переключатель Вход/Регистрация
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLoginMode ? 'Нет аккаунта?' : 'Уже есть аккаунт?',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                          _emailController.clear();
                          _passwordController.clear();
                          _usernameController.clear();
                        });
                      },
                      child: Text(
                        _isLoginMode ? 'Создать' : 'Войти',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                // Разделитель
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white10)),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('ИЛИ', style: TextStyle(color: Colors.white30))),
                      Expanded(child: Divider(color: Colors.white10)),
                    ],
                  ),
                ),

                // Гостевой вход (оставим для тех, кто хочет просто протестить мэтчи)
                TextButton(
                  onPressed: _isLoading ? null : _guestLogin,
                  child: const Text('Продолжить без регистрации', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Вспомогательный метод для красивых текстовых полей
  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00E5FF))),
      ),
    );
  }
}