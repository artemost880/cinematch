import 'package:dio/dio.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

class TMDBService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.themoviedb.org/3',
    queryParameters: {
      'api_key': '518345addd8c574e41183682be0a1072',
      'language': 'ru-RU',
    },
  ));

  // 1. Поиск фильмов по текстовому названию
  Future<List<dynamic>> searchMovies(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _dio.get(
        '/search/movie',
        queryParameters: {
          'query': query,
          'include_adult': false,
          'language': 'ru-RU',
        },
      );
      return response.data['results'] as List<dynamic>;
    } catch (e) {
      print('Ошибка при поиске фильма: $e');
      return [];
    }
  }

  // 2. НОВЫЙ МЕТОД: Поиск актеров по имени (для умного автодополнения)
  Future<List<dynamic>> searchPerson(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _dio.get(
        '/search/person',
        queryParameters: {
          'query': query,
          'include_adult': false,
          'language': 'ru-RU',
        },
      );
      // Возвращаем список людей (нам понадобятся их 'id' и 'name')
      return response.data['results'] as List<dynamic>;
    } catch (e) {
      print('Ошибка при поиске актера: $e');
      return [];
    }
  }

  // 3. Получить список фильмов для комнат (теперь с расширенными фильтрами)
  Future<Map<String, dynamic>> getMoviesByGenre(
    int genreId, {
    int page = 1,
    double minRating = 0.0,
    double maxRating = 10.0,
    int minYear = 1950,
    int maxYear = 2026,
    List<int> castIds = const [],
    bool isCastAndLogic = false,
    int? minRuntime,
    int? maxRuntime,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'sort_by': 'popularity.desc',
        'with_genres': genreId.toString(),
        'page': page,
        'vote_count.gte': 150,
        'region': 'RU',
        'vote_average.gte': minRating,
        'vote_average.lte': maxRating,
        'primary_release_date.gte': '$minYear-01-01',
        'primary_release_date.lte': '$maxYear-12-31',
      };

      // Фильтр по актерам (И / ИЛИ)
      if (castIds.isNotEmpty) {
        queryParams['with_cast'] = castIds.join(isCastAndLogic ? ',' : '|');
      }

      // Фильтр по длительности
      if (minRuntime != null) queryParams['with_runtime.gte'] = minRuntime;
      if (maxRuntime != null) queryParams['with_runtime.lte'] = maxRuntime;

      final response = await _dio.get('/discover/movie', queryParameters: queryParams);
      
      return {
        'results': response.data['results'] as List<dynamic>,
        'total_pages': response.data['total_pages'] as int,
      };
    } catch (e) {
      print('Ошибка получения списка фильмов: $e');
      return {'results': [], 'total_pages': 1};
    }
  }

  // 4. Получить случайный фильм (Ядро механики RandomMovieScreen)
  Future<Map<String, dynamic>?> getRandomMovie({
    double minRating = 0.0,
    double maxRating = 10.0,
    int minYear = 1950,
    int maxYear = 2026,
    List<int> genreIds = const [],
    bool isGenreAndLogic = false, // Новая логика И/ИЛИ для жанров
    List<int> castIds = const [],
    bool isCastAndLogic = false,  // Новая логика И/ИЛИ для актеров
    int? minRuntime,
    int? maxRuntime,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'sort_by': 'popularity.desc',
        'include_adult': false,
        'vote_average.gte': minRating,
        'vote_average.lte': maxRating,
        'primary_release_date.gte': '$minYear-01-01',
        'primary_release_date.lte': '$maxYear-12-31',
        'vote_count.gte': 150, 
        'with_original_language': 'en|ru', 
        'region': 'RU', 
      };

      // Применяем логику И/ИЛИ для жанров (запятая = И, черта = ИЛИ)
      if (genreIds.isNotEmpty) {
        queryParams['with_genres'] = genreIds.join(isGenreAndLogic ? ',' : '|');
      }

      // Применяем логику И/ИЛИ для актеров
      if (castIds.isNotEmpty) {
        queryParams['with_cast'] = castIds.join(isCastAndLogic ? ',' : '|');
      }

      // Фильтр по хронометражу (если задан)
      if (minRuntime != null) queryParams['with_runtime.gte'] = minRuntime;
      if (maxRuntime != null) queryParams['with_runtime.lte'] = maxRuntime;

      // Узнаем, сколько всего страниц подходит под фильтры
      final firstResponse = await _dio.get('/discover/movie', queryParameters: queryParams);
      final int totalPages = firstResponse.data['total_pages'] ?? 1;

      if (totalPages == 0 || firstResponse.data['results'].isEmpty) return null;

      // TMDB ограничивает пагинацию 500 страницами
      final int maxPage = totalPages > 500 ? 500 : totalPages;
      final int randomPage = Random().nextInt(maxPage) + 1;
      
      queryParams['page'] = randomPage;
      final finalResponse = await _dio.get('/discover/movie', queryParameters: queryParams);

      final results = finalResponse.data['results'] as List<dynamic>;
      if (results.isNotEmpty) {
         results.shuffle(); 
         
         final movieData = results.first;
         if (movieData['title'] == null || movieData['title'].toString().isEmpty) {
           return getRandomMovie(
             minRating: minRating, maxRating: maxRating, 
             minYear: minYear, maxYear: maxYear, genreIds: genreIds,
             isGenreAndLogic: isGenreAndLogic, castIds: castIds, 
             isCastAndLogic: isCastAndLogic, minRuntime: minRuntime, maxRuntime: maxRuntime
           ); 
         }

         return await getMovieDetails(movieData['id']);
      }
      return null;
    } catch (e) {
      print('Ошибка при запросе случайного фильма: $e');
      return null;
    }
  }

  // 5. Получить ПОЛНЫЕ детали фильма (Агрегатор данных)
  Future<Map<String, dynamic>?> getMovieDetails(int movieId) async {
    try {
      final response = await _dio.get(
        '/movie/$movieId',
        queryParameters: {
          'append_to_response': 'credits,videos,images,watch/providers',
          'include_image_language': 'ru,null', 
        },
      );
      return response.data;
    } catch (e) {
      print('Ошибка получения деталей фильма: $e');
      return null;
    }
  }

  // 6. Запрос к API Кинопоиска
  Future<Map<String, dynamic>?> getKinopoiskData(String? imdbId) async {
    if (imdbId == null || imdbId.isEmpty) return null;
    
    try {
      final kpDio = Dio();
      final response = await kpDio.get(
        'https://kinopoiskapiunofficial.tech/api/v2.2/films',
        queryParameters: {'imdbId': imdbId},
        options: Options(headers: {
          'X-API-KEY': 'c3348a19-eea2-4828-942e-581fce2e1a6b', 
          'Content-Type': 'application/json',
        }),
      );
      
      if (response.data['items'] != null && response.data['items'].isNotEmpty) {
        return response.data['items'][0];
      }
      return null;
    } catch (e) {
      print('Ошибка Кинопоиска: $e');
      return null;
    }
  }

  // --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ---
  String getImageUrl(String? path) {
    if (path == null) return '';
    return 'https://image.tmdb.org/t/p/w500$path';
  }

  Future<void> launchTrailer(List<dynamic>? videos) async {
    if (videos == null || videos.isEmpty) return;
    
    final trailer = videos.firstWhere(
      (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
      orElse: () => null,
    );

    if (trailer != null) {
      final url = Uri.parse('https://www.youtube.com/watch?v=${trailer['key']}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }
}