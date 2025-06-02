import 'package:flutter/material.dart';
import '../models/workshop.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkshopDetailModal extends StatelessWidget {
  final WorkshopSession workshop;

  const WorkshopDetailModal({super.key, required this.workshop});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A2436),
      title: const Text(
        'Workshop Details',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text('Date: ${workshop.date}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Time: ${workshop.time}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Instructor: ${workshop.artist ?? 'TBA'}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Song: ${workshop.song ?? 'TBA'}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Studio: ${workshop.studioId ?? 'TBA'}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Pricing: ${workshop.pricingInfo ?? 'TBA'}', style: const TextStyle(color: Colors.greenAccent)),
            const SizedBox(height: 12),
            if (workshop.paymentLink.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    final url = Uri.parse(workshop.paymentLink);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not launch ${workshop.paymentLink}'),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Register'),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Close', style: TextStyle(color: Colors.blueAccent)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
} 