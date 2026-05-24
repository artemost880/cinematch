import 'package:flutter/material.dart';
import '../services/tmdb_service.dart';
import 'dart:async';

class FiltersSheet extends StatefulWidget {
  final RangeValues initialRating;
  final RangeValues initialYear;
  final Set<String> initialGenres;
  final List<Map<String, dynamic>>? initialActors;
  final bool initialGenreLogic;
  final bool initialCastLogic;
  final RangeValues? initialRuntime;
  final String initialContentType; // 'movie' или 'tv'
  final bool showGenres; 

  const FiltersSheet({
    super.key,
    required this.initialRating,
    required this.initialYear,
    required this.initialGenres,
    this.initialActors,
    this.initialGenreLogic = false,
    this.initialCastLogic = false,
    this.initialRuntime,
    this.initialContentType = 'movie',
    this.showGenres = true,
  });

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  final TMDBService _tmdbService = TMDBService();

  // Основные фильтры
  late RangeValues _rating;
  late RangeValues _year;
  late RangeValues _runtime; 
  late Set<String> _selectedGenresText;
  late bool _isGenreAndLogic;
  late List<Map<String, dynamic>> _selectedActors;
  late bool _isCastAndLogic;
  late String _contentType; // Состояние для тумблера: фильмы / сериалы

  // Поиск актеров
  final TextEditingController _actorSearchController = TextEditingController();
  List<dynamic> _actorSearchResults = [];
  bool _isSearchingActor = false;
  Timer? _debounce;

  // Базовый справочник жанров для фильмов
  final Map<String, int> _genresMap = {
    'Экшен': 28, 'Приключения': 12, 'Анимация': 16, 'Комедия': 35,
    'Криминал': 80, 'Документальный': 99, 'Драма': 18, 'Семейный': 10751,
    'Фэнтези': 14, 'История': 36, 'Ужасы': 27, 'Музыка': 10402,
    'Детектив': 9648, 'Мелодрама': 10749, 'Фантастика': 878,
    'ТВ-фильм': 10770, 'Триллер': 53, 'Военный': 10752, 'Вестерн': 37
  };

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _year = widget.initialYear;
    _selectedGenresText = Set.from(widget.initialGenres);
    _selectedActors = List.from(widget.initialActors ?? []);
    _isGenreAndLogic = widget.initialGenreLogic;
    _isCastAndLogic = widget.initialCastLogic;
    _runtime = widget.initialRuntime ?? const RangeValues(40.0, 240.0);
    _contentType = widget.initialContentType;
  }

  @override
  void dispose() {
    _actorSearchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Умный маппинг жанров TMDB (у фильмов и сериалов разные ID)
  int _getGenreId(String name, String type) {
    if (type == 'movie') {
      return _genresMap[name] ?? 28;
    } else {
      switch (name) {
        case 'Экшен':
        case 'Приключения':
          return 10759; // Action & Adventure для сериалов
        case 'Анимация':
          return 16;
        case 'Комедия':
          return 35;
        case 'Криминал':
          return 80;
        case 'Документальный':
          return 99;
        case 'Драма':
          return 18;
        case 'Семейный':
          return 10751;
        case 'Фантастика':
        case 'Фэнтези':
          return 10765; // Sci-Fi & Fantasy для сериалов
        case 'Детектив':
          return 9648;
        case 'Ужасы':
          return 27;
        case 'Военный':
        case 'История':
          return 10768; // War & Politics для сериалов
        default:
          return _genresMap[name] ?? 35;
      }
    }
  }

void _onActorSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.length < 3) {
      setState(() { _actorSearchResults = []; _isSearchingActor = false; });
      return;
    }

    setState(() => _isSearchingActor = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _tmdbService.searchPerson(query);
      if (mounted) {
        setState(() { 
          _actorSearchResults = results; // ИСПРАВЛЕНО: убрали случайный бэкслеш
          _isSearchingActor = false; 
        });
      }
    });
  }

  Widget _buildLogicToggle(bool isAnd, ValueChanged<bool> onChanged) {
    return ToggleButtons(
      isSelected: [!isAnd, isAnd],
      onPressed: (index) => onChanged(index == 1),
      borderRadius: BorderRadius.circular(8),
      fillColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
      selectedColor: const Color(0xFF00E5FF),
      color: Colors.white54,
      constraints: const BoxConstraints(minHeight: 30, minWidth: 60),
      children: const [
        Text('ИЛИ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text('И', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Настройки подбора', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(color: Colors.white10, height: 30),

          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ТУМБЛЕР ВЫБОРА КОНТЕНТА ---
                  const Text('Тип контента', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ToggleButtons(
                          isSelected: [_contentType == 'movie', _contentType == 'tv'],
                          onPressed: (index) => setState(() {
                            _contentType = index == 0 ? 'movie' : 'tv';
                          }),
                          borderRadius: BorderRadius.circular(12),
                          fillColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                          selectedColor: const Color(0xFF00E5FF),
                          color: Colors.white54,
                          constraints: const BoxConstraints(minHeight: 45),
                          children: const [
                            Text('Фильмы', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Сериалы', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Рейтинг TMDB', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${_rating.start.toStringAsFixed(1)} - ${_rating.end.toStringAsFixed(1)}', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  RangeSlider(
                    values: _rating, min: 0, max: 10, divisions: 20,
                    activeColor: const Color(0xFF00E5FF), inactiveColor: Colors.grey[800],
                    onChanged: (values) => setState(() => _rating = values),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Год выпуска', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${_year.start.toInt()} - ${_year.end.toInt()}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  RangeSlider(
                    values: _year, min: 1950, max: 2026, divisions: 76,
                    activeColor: Colors.amber, inactiveColor: Colors.grey[800],
                    onChanged: (values) => setState(() => _year = values),
                  ),
                  const SizedBox(height: 24),

                  // Длительность имеет смысл выводить только для фильмов
                  if (_contentType == 'movie') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Длительность (мин)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${_runtime.start.toInt()} - ${_runtime.end.toInt()}${_runtime.end == 240 ? '+' : ''}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    RangeSlider(
                      values: _runtime, min: 40, max: 240, divisions: 20,
                      activeColor: Colors.greenAccent, inactiveColor: Colors.grey[800],
                      onChanged: (values) => setState(() => _runtime = values),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (widget.showGenres) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Жанры', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        _buildLogicToggle(_isGenreAndLogic, (val) => setState(() => _isGenreAndLogic = val)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _genresMap.keys.map((genre) {
                        final isSelected = _selectedGenresText.contains(genre);
                        return FilterChip(
                          label: Text(genre, style: TextStyle(color: isSelected ? Colors.black : Colors.white70)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00E5FF),
                          backgroundColor: Colors.black45,
                          checkmarkColor: Colors.black,
                          onSelected: (selected) {
                            setState(() {
                              selected ? _selectedGenresText.add(genre) : _selectedGenresText.remove(genre);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('С участием актеров', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (_selectedActors.length > 1) 
                        _buildLogicToggle(_isCastAndLogic, (val) => setState(() => _isCastAndLogic = val)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _actorSearchController,
                    onChanged: _onActorSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Введите имя (напр. Том Харди)',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      prefixIcon: const Icon(Icons.person_search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black45,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIcon: _isSearchingActor ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    ),
                  ),
                  
                  if (_actorSearchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _actorSearchResults.length,
                        itemBuilder: (context, index) {
                          final person = _actorSearchResults[index];
                          return ListTile(
                            leading: ClipOval(
                              child: person['profile_path'] != null 
                                  ? Image.network(_tmdbService.getImageUrl(person['profile_path']), width: 40, height: 40, fit: BoxFit.cover)
                                  : Container(width: 40, height: 40, color: Colors.grey[800], child: const Icon(Icons.person, color: Colors.white54)),
                            ),
                            title: Text(person['name'] ?? ''),
                            onTap: () {
                              setState(() {
                                if (!_selectedActors.any((a) => a['id'] == person['id'])) {
                                  _selectedActors.add(person);
                                }
                                _actorSearchController.clear();
                                _actorSearchResults.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),

                  if (_selectedActors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _selectedActors.map((actor) {
                        return InputChip(
                          label: Text(actor['name']),
                          avatar: ClipOval(
                            child: actor['profile_path'] != null
                                ? Image.network(_tmdbService.getImageUrl(actor['profile_path']), fit: BoxFit.cover)
                                : const Icon(Icons.person, size: 18),
                          ),
                          backgroundColor: Colors.amber.withValues(alpha: 0.2),
                          deleteIconColor: Colors.amber,
                          onDeleted: () {
                            setState(() => _selectedActors.removeWhere((a) => a['id'] == actor['id']));
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              onPressed: () {
                List<int> genreIds = _selectedGenresText.map((name) => _getGenreId(name, _contentType)).toList();
                
                Navigator.pop(context, {
                  'rating': _rating,
                  'year': _year,
                  'runtime': _runtime,
                  'genresText': _selectedGenresText,
                  'genresIds': genreIds,
                  'isGenreAndLogic': _isGenreAndLogic,
                  'selectedActors': _selectedActors,
                  'castIds': _selectedActors.map((a) => a['id'] as int).toList(),
                  'isCastAndLogic': _isCastAndLogic,
                  'contentType': _contentType,
                  'minRuntime': _runtime.start.toInt(),
                  'maxRuntime': _runtime.end == 240.0 ? null : _runtime.end.toInt(),
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('ПРИМЕНИТЬ ФИЛЬТРЫ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            ),
          ),
        ],
      ),
    );
  }
}