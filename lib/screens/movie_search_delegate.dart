import 'package:flutter/material.dart';
import '../services/tmdb_service.dart';
import 'movie_details_screen.dart';

class MovieSearchDelegate extends SearchDelegate {
  final TMDBService _tmdbService = TMDBService();

  // Меняем текст-подсказку в строке поиска
  @override
  String get searchFieldLabel => 'Название фильма...';

  // Меняем тему, чтобы поиск выглядел в стиле нашего темного приложения
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E)),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  // Кнопка очистки справа (крестик)
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '', // Очищаем строку
      ),
    ];
  }

  // Кнопка "Назад" слева (стрелочка)
  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null), // Закрываем поиск
    );
  }

  // Что показывать, когда пользователь нажал "Найти" (Enter)
  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  // Что показывать, пока пользователь печатает (живые подсказки)
  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  // Общий метод для отображения результатов
  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Введите название фильма', style: TextStyle(color: Colors.white54)));
    }

    return FutureBuilder<List<dynamic>>(
      future: _tmdbService.searchMovies(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Ничего не найдено 😢'));
        }

        final movies = snapshot.data!;

        return ListView.builder(
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: movie['poster_path'] != null
                    ? Image.network(_tmdbService.getImageUrl(movie['poster_path']), width: 50, height: 75, fit: BoxFit.cover)
                    : Container(width: 50, height: 75, color: Colors.grey[800], child: const Icon(Icons.movie, color: Colors.white54)),
              ),
              title: Text(movie['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('⭐ ${movie['vote_average']} | 📅 ${movie['release_date']?.split('-')[0] ?? ''}', style: const TextStyle(color: Colors.amber)),
              onTap: () async {
                // При клике загружаем полные детали и открываем шторку!
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
                );
                final fullMovieData = await _tmdbService.getMovieDetails(movie['id']);
                if (context.mounted) Navigator.pop(context); // убираем крутилку
                
                if (fullMovieData != null && context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: fullMovieData)));
                }
              },
            );
          },
        );
      },
    );
  }
}