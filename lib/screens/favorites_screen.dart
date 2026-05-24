import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import 'movie_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseService db = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'МОЁ ИЗБРАННОЕ', 
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.getFavorites(),
        builder: (context, snapshot) {
          // Состояние загрузки
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }
          
          // Если список пуст
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  const Text(
                    'Тут пока пусто 📭\nДобавляйте фильмы, которые вам понравились!', 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white54, height: 1.5),
                  ),
                ],
              ),
            );
          }

          final movies = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index].data() as Map<String, dynamic>;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Dismissible(
                  key: Key(movie['id'].toString()),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    db.removeFavorite(movie['id']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${movie['title']} удален из избранного'),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  // Фон при свайпе (удаление)
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 25),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.delete_sweep, color: Colors.white, size: 32),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          // Постер фильма
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                            child: movie['poster_path'] != null
                                ? Image.network(
                                    'https://image.tmdb.org/t/p/w200${movie['poster_path']}',
                                    width: 100, height: 150, fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 100, height: 150, 
                                    color: Colors.grey[800], 
                                    child: const Icon(Icons.movie, color: Colors.white24, size: 40)
                                  ),
                          ),
                          
                          // Информация о фильме
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie['title'] ?? 'Без названия',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Плашка с рейтингом и годом
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              movie['vote_average'].toString(),
                                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        movie['release_date']?.split('-')[0] ?? '----',
                                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Кнопка быстрого перехода
                                  const Row(
                                    children: [
                                      Text('Подробнее', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.w600)),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward, color: Color(0xFF00E5FF), size: 14),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}