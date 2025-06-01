import 'package:flutter/material.dart';
import '../models/studio.dart';
import '../services/api_service.dart';
import '../widgets/workshop_detail_modal.dart';
import '../models/workshop.dart';
import 'package:url_launcher/url_launcher.dart';

class StudioDetailScreen extends StatefulWidget {
  final Studio studio;

  const StudioDetailScreen({Key? key, required this.studio}) : super(key: key);

  @override
  _StudioDetailScreenState createState() => _StudioDetailScreenState();
}

class _StudioDetailScreenState extends State<StudioDetailScreen> {
  late Future<CategorizedWorkshopResponse> futureWorkshops;

  @override
  void initState() {
    super.initState();
    futureWorkshops = ApiService().fetchWorkshopsByStudio(widget.studio.id);
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
        title: Text(widget.studio.name),
        backgroundColor: const Color(0xFF121824),
      ),
      backgroundColor: const Color(0xFF121824),
      body: FutureBuilder<CategorizedWorkshopResponse>(
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
          } else if (!snapshot.hasData || (snapshot.data!.thisWeek.isEmpty && snapshot.data!.postThisWeek.isEmpty)) {
            return const Center(
              child: Text(
                'No workshops found for this studio.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          } else {
            final response = snapshot.data!;
            final hasThisWeek = response.thisWeek.isNotEmpty;
            final hasPostThisWeek = response.postThisWeek.isNotEmpty;

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // This Week section
                if (hasThisWeek)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This Week',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: response.thisWeek.length,
                        itemBuilder: (context, index) {
                          final daySchedule = response.thisWeek[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  daySchedule.day,
                                  style: const TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: daySchedule.workshops.length,
                                itemBuilder: (context, workshopIndex) {
                                  final workshop = daySchedule.workshops[workshopIndex];
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
                                              'Instructor: ${workshop.artist ?? 'TBA'}',
                                              style: const TextStyle(color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                // Divider if both sections exist
                if (hasThisWeek && hasPostThisWeek)
                  const SizedBox(height: 24.0),

                // Upcoming Workshops section
                if (hasPostThisWeek)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcoming Workshops',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                       ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: response.postThisWeek.length,
                        itemBuilder: (context, index) {
                          final workshop = response.postThisWeek[index];
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
                                              'Instructor: ${workshop.artist ?? 'TBA'}',
                                              style: const TextStyle(color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                        },
                      ),
                    ],
                  ),
              ],
            );
          }
        },
      ),
    );
  }
} 