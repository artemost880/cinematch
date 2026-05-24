import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // Для функции max()
import '../services/room_service.dart';
import 'filters_sheet.dart';
import 'room_session_screen.dart';

class RoomWaitingScreen extends StatefulWidget {
  final String roomCode;

  const RoomWaitingScreen({super.key, required this.roomCode});

  @override
  State<RoomWaitingScreen> createState() => _RoomWaitingScreenState();
}

class _RoomWaitingScreenState extends State<RoomWaitingScreen> {
  final RoomService _roomService = RoomService();
  bool _isLoading = false;

  // Локальные фильтры для поиска в TMDB
  RangeValues _currentRating = const RangeValues(6.0, 10.0);
  RangeValues _currentYear = RangeValues(1990.0, 2026.0);
  Set<String> _currentGenresText = {};
  List<int> _currentGenresIds = [];
  
  // Дополнительные параметры фильтрации
  RangeValues _currentRuntime = const RangeValues(40.0, 240.0);
  bool _isGenreAndLogic = false;
  List<Map<String, dynamic>> _selectedActors = [];
  bool _isCastAndLogic = false;
  String _currentContentType = 'movie'; // 'movie' или 'tv'

  void _showFiltersBottomSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => FiltersSheet(
        initialRating: _currentRating, initialYear: _currentYear,
        initialGenres: _currentGenresText, showGenres: true,
        initialActors: _selectedActors,
        initialGenreLogic: _isGenreAndLogic,
        initialCastLogic: _isCastAndLogic,
        initialRuntime: _currentRuntime,
        initialContentType: _currentContentType,
      ),
    );

    if (result != null) {
      setState(() {
        _currentRating = result['rating'];
        _currentYear = result['year'];
        _currentGenresText = result['genresText'];
        _currentGenresIds = result['genresIds'];
        _currentRuntime = result['runtime'];
        _isGenreAndLogic = result['isGenreAndLogic'];
        _selectedActors = result['selectedActors'];
        _isCastAndLogic = result['isCastAndLogic'];
        _currentContentType = result['contentType'];
      });
    }
  }

  void _startSession(int deckSize) async {
    setState(() => _isLoading = true);
    try {
      await _roomService.startRoom(
        widget.roomCode,
        minRating: _currentRating.start, 
        maxRating: _currentRating.end,
        minYear: _currentYear.start.toInt(), 
        maxYear: _currentYear.end.toInt(),
        genreIds: _currentGenresIds,
        deckSize: deckSize,
        isGenreAndLogic: _isGenreAndLogic,
        castIds: _selectedActors.map((a) => a['id'] as int).toList(),
        isCastAndLogic: _isCastAndLogic,
        minRuntime: _currentRuntime.start.toInt(),
        maxRuntime: _currentRuntime.end == 240.0 ? null : _currentRuntime.end.toInt(),
        contentType: _currentContentType, // Передаем тип контента в сервис комнат
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при запуске подбора')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Покинуть лобби?'),
        content: const Text('Если вы выйдете, комната может быть закрыта.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ОТМЕНА', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ВЫЙТИ', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await _roomService.leaveRoom(widget.roomCode);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Лобби', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _roomService.listenToRoom(widget.roomCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              });
              return const Center(child: Text('Комната закрыта...'));
            }

            final roomData = snapshot.data!.data() as Map<String, dynamic>;
            final List<dynamic> participants = roomData['participants'] ?? [];
            final bool isCreator = roomData['creator'] == _roomService.uid;
            final String status = roomData['status'] ?? 'waiting';
            
            final int minLikes = roomData['min_likes'] ?? 2;
            final int deckSize = roomData['deck_size'] ?? 20;

            if (status == 'active') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomSessionScreen(roomCode: widget.roomCode),
                    ),
                  );
                }
              });
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Код комнаты', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(widget.roomCode, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 8, color: Color(0xFF00E5FF))),
                  const SizedBox(height: 32),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Участников: ${participants.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (isCreator) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Настройки комнаты:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Мэтч от:', style: TextStyle(fontSize: 16)),
                        Text('$minLikes чел.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
                      ],
                    ),
                    Slider(
                      value: minLikes.toDouble(),
                      min: 1, 
                      max: max(2.0, participants.length.toDouble()),
                      divisions: max(1, participants.length - 1),
                      activeColor: const Color(0xFF00E5FF),
                      inactiveColor: Colors.grey[800],
                      onChanged: participants.length > 1 
                        ? (val) => _roomService.updateSettings(widget.roomCode, minLikes: val.toInt(), deckSize: deckSize)
                        : null,
                    ),
                    if (participants.length == 1)
                      const Text('Ожидайте других игроков, чтобы настроить мэтч', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Размер колоды:', style: TextStyle(fontSize: 16)),
                        Text('$deckSize ${_currentContentType == 'tv' ? 'сериалов' : 'фильмов'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
                      ],
                    ),
                    Slider(
                      value: deckSize.toDouble(),
                      min: 5, max: 50, divisions: 9,
                      activeColor: Colors.amber,
                      inactiveColor: Colors.grey[800],
                      onChanged: (val) => _roomService.updateSettings(widget.roomCode, minLikes: minLikes, deckSize: val.toInt()),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity, height: 55,
                      child: OutlinedButton.icon(
                        onPressed: _showFiltersBottomSheet,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.tune), label: const Text('ФИЛЬТРЫ ДЛЯ TMDB', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _startSession(deckSize),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Text('НАЧАТЬ ПОДБОР', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(color: Color(0xFF00E5FF)),
                    const SizedBox(height: 24),
                    const Text('Ожидаем создателя...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Создатель настраивает колоду и скоро запустит подбор.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}