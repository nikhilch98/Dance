import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../services/api_service.dart';
import '../models/workshop.dart';
import '../widgets/workshop_detail_modal.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late Future<List<WorkshopSession>> futureWorkshops;

  @override
  void initState() {
    super.initState();
    futureWorkshops = ApiService().fetchWorkshopsByArtist(widget.artist.id);
  }

  void _showWorkshopDetails(WorkshopSession workshop) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return WorkshopDetailModal(workshop: workshop);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artist.name),
        backgroundColor: const Color(0xFF121824),
      ),
      backgroundColor: const Color(0xFF121824),
      body: FutureBuilder<List<WorkshopSession>>(
        future: futureWorkshops,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No workshops found for this artist.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          } else {
            // Sort workshops by timestamp before displaying
            final sortedWorkshops = snapshot.data!;
            sortedWorkshops.sort((a, b) => a.timestampEpoch.compareTo(b.timestampEpoch));

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: sortedWorkshops.length,
              itemBuilder: (context, index) {
                final workshop = sortedWorkshops[index];
                 return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    color: const Color(0xFF1A2436),
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: InkWell(
                      onTap: () => _showWorkshopDetails(workshop),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${workshop.date} at ${workshop.time}',
                              style: const TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                             Text(
                              'Studio: ${workshop.studioId ?? 'TBA'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
              },
            );
          }
        },
      ),
    );
  }
} 