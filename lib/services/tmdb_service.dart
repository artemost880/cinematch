import 'package:dio/dio.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

class TMDBService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org/3'));
  final String apiKey = 'YOUR_TMDB_API_KEY'; // Подставьте ваш API-ключ TMDB

  // Вспомогательный метод для склейки полей фильмов и сериалов (Нормализация данных)
  Map<String, dynamic> _normalizeItem(Map<String, dynamic> item, String contentType) {
    if (contentType == 'tv') {
      item['title'] = item['name'] ?? item['original_name'] ?? 'Без названия';
      item['release_date'] = item['first_air_date'] ?? '---';
      item['is_tv'] = true;
    } else {
      item['is_tv'] = false;
    }
    return item;
  }

  // Получение полного URL для изображений (постеры, кадры, аватарки)
  String getImageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  // Получение детальной информации о фильме или сериале
  Future<Map<String, dynamic>?> getMovieDetails(int id, {String contentType = 'movie'}) async {
    try {
      final endpoint = contentType == 'movie' ? '/movie/$id' : '/tv/$id';
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'api_key': apiKey,
          'language': 'ru-RU',
          'append_to_response': 'videos,images,credits,watch/providers',
        },
      );
      return _normalizeItem(response.data, contentType);
    } catch (e) {
      return null;
    }
  }

  // Текстовый поиск фильмов и сериалов (убирает ошибки в Делегате и Экране Поиска)
  Future<List<dynamic>> searchMovies(String query, {String contentType = 'movie'}) async {
    try {
      final endpoint = contentType == 'movie' ? '/search/movie' : '/search/tv';
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'api_key': apiKey,
          'language': 'ru-RU',
          'query': query,
          'page': 1,
        },
      );
      final List<dynamic> results = response.data['results'] ?? [];
      return results.map((item) => _normalizeItem(item, contentType)).toList();
    } catch (e) {
      return [];
    }
  }

  // Поиск актеров по имени (используется для автокомплита в шторке фильтров)
  Future<List<dynamic>> searchPerson(String query) async {
    try {
      final response = await _dio.get(
        '/search/person',
        queryParameters: {
          'api_key': apiKey,
          'language': 'ru-RU',
          'query': query,
          'page': 1,
        },
      );
      return response.data['results'] ?? [];
    } catch (e) {
      return [];
    }
  }

  // Получение подборок контента по жанру и расширенным фильтрам (с пагинацией)
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
    String contentType = 'movie', // 'movie' или 'tv'
  }) async {
    try {
      final endpoint = contentType == 'movie' ? '/discover/movie' : '/discover/tv';
      final dateMinKey = contentType == 'movie' ? 'primary_release_date.gte' : 'first_air_date.gte';
      final dateMaxKey = contentType == 'movie' ? 'primary_release_date.lte' : 'first_air_date.lte';

      final Map<String, dynamic> params = {
        'api_key': apiKey,
        'language': 'ru-RU',
        'page': page,
        'vote_average.gte': minRating,
        'vote_average.lte': maxRating,
        '$dateMinKey': '$minYear-01-01',
        '$dateMaxKey': '$maxYear-12-31',
      };

      // Передаем ID жанра
      params['with_genres'] = genreId.toString();

      // Хронометраж (поддерживается базовым API TMDB только для фильмов)
      if (contentType == 'movie') {
        if (minRuntime != null) params['with_runtime.gte'] = minRuntime;
        if (maxRuntime != null) params['with_runtime.lte'] = maxRuntime;
      }

      // Фильтр по актерскому составу
      if (castIds.isNotEmpty) {
        params['with_cast'] = castIds.join(isCastAndLogic ? ',' : '|');
      }

      final response = await _dio.get(endpoint, queryParameters: params);
      
      final List<dynamic> results = response.data['results'] ?? [];
      final normalizedResults = results.map((item) => _normalizeItem(item, contentType)).toList();

      return {
        'results': normalizedResults,
        'total_pages': response.data['total_pages'] ?? 1,
      };
    } catch (e) {
      return {'results': [], 'total_pages': 1};
    }
  }

  // Рандомайзер (вытаскивает случайный фильм/сериал по заданным фильтрам)
  Future<Map<String, dynamic>?> getRandomMovie({
    double minRating = 0.0,
    double maxRating = 10.0,
    int minYear = 1950,
    int maxYear = 2026,
    List<int> genreIds = const [],
    bool isGenreAndLogic = false,
    List<int> castIds = const [],
    bool isCastAndLogic = false,
    int? minRuntime,
    int? maxRuntime,
    String contentType = 'movie', // 'movie' или 'tv'
  }) async {
    try {
      final endpoint = contentType == 'movie' ? '/discover/movie' : '/discover/tv';
      final dateMinKey = contentType == 'movie' ? 'primary_release_date.gte' : 'first_air_date.gte';
      final dateMaxKey = contentType == 'movie' ? 'primary_release_date.lte' : 'first_air_date.lte';

      final Map<String, dynamic> params = {
        'api_key': apiKey,
        'language': 'ru-RU',
        'vote_average.gte': minRating,
        'vote_average.lte': maxRating,
        '$dateMinKey': '$minYear-01-01',
        '$dateMaxKey': '$maxYear-12-31',
      };

      if (genreIds.isNotEmpty) {
        params['with_genres'] = genreIds.join(isGenreAndLogic ? ',' : '|');
      }
      if (castIds.isNotEmpty) {
        params['with_cast'] = castIds.join(isCastAndLogic ? ',' : '|');
      }
      if (contentType == 'movie') {
        if (minRuntime != null) params['with_runtime.gte'] = minRuntime;
        if (maxRuntime != null) params['with_runtime.lte'] = maxRuntime;
      }

      // Пингуем API, чтобы узнать общее число страниц по заданным фильтрам
      final firstResp = await _dio.get(endpoint, queryParameters: params);
      final int totalPages = firstResp.data['total_pages'] ?? 1;
      
      // TMDB имеет жесткий лимит в 500 страниц на discover-запросы
      final int maxPage = totalPages > 500 ? 500 : totalPages;
      final int targetPage = Random().nextInt(maxPage) + 1;

      // Делаем финальный запрос на случайную страницу
      params['page'] = targetPage;
      final finalResp = await _dio.get(endpoint, queryParameters: params);
      final List<dynamic> results = finalResp.data['results'] ?? [];

      if (results.isEmpty) return null;

      // Берем случайный элемент из полученной страницы
      final randomItem = results[Random().nextInt(results.length)];
      
      // Запрашиваем полные детали (актеры, кадры, трейлер) для карточки
      return await getMovieDetails(randomItem['id'], contentType: contentType);
    } catch (e) {
      return null;
    }
  }

  // Получение рейтинга Кинопоиска по IMDb ID
  Future<Map<String, dynamic>?> getKinopoiskData(String imdbId) async {
    try {
      final response = await _dio.get(
        'https://kinopoiskapiunofficial.tech/api/v2.2/films/external_id/$imdbId', 
        options: Options(headers: {'X-API-KEY': 'YOUR_KINOPOISK_API_KEY'}) // Вставьте ваш токен Кинопоиска
      );
      return response.data;
    } catch (e) {
      return null;
    }
  }

  // Запуск трейлера на YouTube через внешнее приложение или браузер
  Future<void> launchTrailer(List<dynamic>? videos) async {
    if (videos == null || videos.isEmpty) return;
    
    // Ищем официальный трейлер на YouTube
    final trailer = videos.firstWhere(
      (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
      orElse: () => videos.firstWhere((v) => v['site'] == 'YouTube', orElse: () => null),
    );

    if (trailer != null && trailer['key'] != null) {
      final Uri url = Uri.parse('https://www.youtube.com/watch?v=${trailer['key']}');
      final Uri appUrl = Uri.parse('youtube://www.youtube.com/watch?v=${trailer['key']}');
      
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }
}