import 'package:dio/dio.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

class TMDBService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org/3'));
  final String apiKey = '518345addd8c574e41183682be0a1072'; 

  // Публичный доступ к инстансу для пагинации текстового поиска
  Dio getDioInstance() => _dio;

  // Публичный хелпер нормализации
  Map<String, dynamic> normalizeItemHelper(Map<String, dynamic> item, String contentType) {
    return _normalizeItem(item, contentType);
  }

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

  String getImageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  Future<Map<String, dynamic>?> getMovieDetails(int id, {String contentType = 'movie'}) async {
    try {
      final endpoint = contentType == 'movie' ? '/movie/$id' : '/tv/$id';
      final appendResponse = contentType == 'movie' 
          ? 'videos,images,credits,watch/providers' 
          : 'videos,images,credits,watch/providers,external_ids';

      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'api_key': apiKey,
          'language': 'ru-RU',
          'append_to_response': appendResponse,
        },
      );

      final data = response.data;
      if (contentType == 'tv' && data['external_ids'] != null) {
        data['imdb_id'] = data['external_ids']['imdb_id'];
      }

      return _normalizeItem(data, contentType);
    } catch (e) {
      return null;
    }
  }

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

  // Вспомогательный метод для разделения положительных и отрицательных фильтров жанров
  void _parseAndSetGenreParams(Map<String, dynamic> params, String genreString) {
    final List<String> positiveGenres = [];
    final List<String> negativeGenres = [];
    
    // Определяем разделитель (запятая = AND, трубка = OR)
    String separator = ',';
    if (genreString.contains('|')) {
      separator = '|';
    }
    
    // Разделяем на положительные и отрицательные ID
    final parts = genreString.split(RegExp(r'[,|]'));
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        if (trimmed.startsWith('!')) {
          negativeGenres.add(trimmed.substring(1)); // Убираем "!" для without_genres
        } else {
          positiveGenres.add(trimmed);
        }
      }
    }
    
    // Устанавливаем параметры TMDB API, сохраняя разделитель (логику)
    if (positiveGenres.isNotEmpty) {
      params['with_genres'] = positiveGenres.join(separator);
    }
    if (negativeGenres.isNotEmpty) {
      params['without_genres'] = negativeGenres.join(','); // Отрицательные всегда через запятую (AND логика)
    }
  }

  Future<Map<String, dynamic>> getMoviesByGenre(
    dynamic genreId, {
    int page = 1,
    double minRating = 0.0,
    double maxRating = 10.0,
    int minYear = 1950,
    int maxYear = 2026,
    List<int> castIds = const [],
    bool isCastAndLogic = false,
    int? minRuntime,
    int? maxRuntime,
    String contentType = 'movie',
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

      if (genreId != null && genreId.toString().isNotEmpty) {
        _parseAndSetGenreParams(params, genreId.toString());
      }

      if (contentType == 'tv') {
        params['vote_count.gte'] = 40; 
      }

      if (contentType == 'movie') {
        params['vote_count.gte'] = 40; 
        if (minRuntime != null) params['with_runtime.gte'] = minRuntime;
        if (maxRuntime != null) params['with_runtime.lte'] = maxRuntime;
      }

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

  Future<Map<String, dynamic>?> getRandomMovie({
    double minRating = 0.0,
    double maxRating = 10.0,
    int minYear = 1950,
    int maxYear = 2026,
    dynamic genreIds = '',
    bool isGenreAndLogic = false,
    List<int> castIds = const [],
    bool isCastAndLogic = false,
    int? minRuntime,
    int? maxRuntime,
    String contentType = 'movie',
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

      if (contentType == 'tv') {
        params['vote_count.gte'] = 80; 
      } else {
        params['vote_count.gte'] = 100; 
      }

      if (genreIds is String && genreIds.isNotEmpty) {
        _parseAndSetGenreParams(params, genreIds);
      } else if (genreIds is List && genreIds.isNotEmpty) {
        _parseAndSetGenreParams(params, genreIds.join(isGenreAndLogic ? ',' : '|'));
      }

      if (castIds.isNotEmpty) {
        params['with_cast'] = castIds.join(isCastAndLogic ? ',' : '|');
      }
      if (contentType == 'movie') {
        if (minRuntime != null) params['with_runtime.gte'] = minRuntime;
        if (maxRuntime != null) params['with_runtime.lte'] = maxRuntime;
      }

      final firstResp = await _dio.get(endpoint, queryParameters: params);
      final int totalPages = firstResp.data['total_pages'] ?? 1;
      final int maxPage = totalPages > 500 ? 500 : totalPages;
      final int targetPage = Random().nextInt(maxPage) + 1;

      params['page'] = targetPage;
      final finalResp = await _dio.get(endpoint, queryParameters: params);
      final List<dynamic> results = finalResp.data['results'] ?? [];

      if (results.isEmpty) return null;
      final randomItem = results[Random().nextInt(results.length)];
      
      return await getMovieDetails(randomItem['id'], contentType: contentType);
    } catch (e) {
      return null;
    }
  }

  // Официальный поиск рейтингов Кинопоиска через ключевые слова по Swagger
  Future<Map<String, dynamic>?> getKinopoiskData(String? title, String? year) async {
    if (title == null || title.isEmpty) return null;

    try {
      // 1. Ищем фильм/сериал по названию через официальный эндпоинт ключевых слов
      final searchResponse = await _dio.get(
        'https://kinopoiskapiunofficial.tech/api/v2.1/films/search-by-keyword',
        queryParameters: {
          'keyword': title,
          'page': 1,
        },
        options: Options(headers: {'X-API-KEY': 'c3348a19-eea2-4828-942e-581fce2e1a6b'})
      );

      final List<dynamic> films = searchResponse.data['films'] ?? [];
      if (films.isEmpty) return null;

      // 2. Фильтруем результаты, сопоставляя год выпуска из TMDB
      final exactMatch = films.firstWhere(
        (f) => year != null && f['year']?.toString() == year,
        orElse: () => films.first,
      );

      final int? kinopoiskId = exactMatch['filmId'] as int?;
      if (kinopoiskId == null) return null;

      // 3. Запрашиваем официальную карточку по kinopoiskId, чтобы вытащить рейтинг
      final mainResponse = await _dio.get(
        'https://kinopoiskapiunofficial.tech/api/v2.2/films/$kinopoiskId',
        options: Options(headers: {'X-API-KEY': 'c3348a19-eea2-4828-942e-581fce2e1a6b'})
      );

      return mainResponse.data;
    } catch (e) {
      return null;
    }
  }

  Future<void> launchTrailer(List<dynamic>? videos) async {
    if (videos == null || videos.isEmpty) return;
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