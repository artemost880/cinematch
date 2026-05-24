import 'package:flutter/material.dart';
import '../services/room_service.dart';
import 'room_waiting_screen.dart'; 

class RoomsLobbyScreen extends StatefulWidget {
  const RoomsLobbyScreen({super.key});

  @override
  State<RoomsLobbyScreen> createState() => _RoomsLobbyScreenState();
}

class _RoomsLobbyScreenState extends State<RoomsLobbyScreen> {
  final RoomService _roomService = RoomService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  // Функция создания комнаты
  void _createRoom() async {
    setState(() => _isLoading = true);
    try {
      final code = await _roomService.createRoom();
      if (mounted) {
        setState(() => _isLoading = false);
        _openRoomSession(code);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка создания комнаты')));
    }
  }

  // Функция присоединения
  void _joinRoom() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Код должен состоять из 6 цифр')));
      return;
    }

    setState(() => _isLoading = true);
    final success = await _roomService.joinRoom(code);
    setState(() => _isLoading = false);

    if (success && mounted) {
      _openRoomSession(code);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Комната не найдена!')));
    }
  }

void _openRoomSession(String roomCode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RoomWaitingScreen(roomCode: roomCode)), // ИДЕМ В ЛОББИ!
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Киновечер', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_alt_outlined, size: 80, color: Color(0xFF00E5FF)),
                  const SizedBox(height: 24),
                  const Text(
                    'Выбирайте фильмы вместе!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Создайте комнату и поделитесь кодом с другом, чтобы найти идеальный мэтч на вечер.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Кнопка создать
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _createRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('СОЗДАТЬ КОМНАТУ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('ИЛИ', style: TextStyle(color: Colors.white54))),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Поле для ввода кода
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Кнопка присоединиться
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: _joinRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('ПРИСОЕДИНИТЬСЯ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}