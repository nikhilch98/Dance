import 'package:flutter/material.dart';
import '../models/workshop.dart';
import '../utils/payment_link_utils.dart';
import 'bundle_suggestion_modal.dart';

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
            Text('Date: ${workshop.date ?? 'TBA'}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Time: ${workshop.time ?? 'TBA'}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Instructor: ${workshop.artist ?? 'TBA'}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Song: ${workshop.song ?? 'TBA'}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Studio: ${workshop.studioId ?? 'TBA'}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Pricing: ${workshop.pricingInfo ?? 'TBA'}', style: const TextStyle(color: Colors.greenAccent)),
            const SizedBox(height: 12),
            if ((workshop.paymentLink?.isNotEmpty ?? false) || workshop.paymentLinkType?.toLowerCase() == 'nachna')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    // Ensure workshop UUID or timestamp is available before proceeding
                    final workshopIdentifier = workshop.uuid?.isNotEmpty == true
                        ? workshop.uuid!
                        : workshop.timestampEpoch?.toString();

                    if (workshopIdentifier == null || workshopIdentifier.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Workshop information not available'),
                          backgroundColor: Colors.red.withOpacity(0.8),
                        ),
                      );
                      return;
                    }
                    
                    await PaymentLinkUtils.launchPaymentLink(
                      paymentLink: workshop.paymentLink,
                      paymentLinkType: workshop.paymentLinkType,
                      context: context,
                      workshopDetails: {
                        'song': workshop.song,
                        'artist': workshop.artist,
                        'studio': workshop.studioId, // Note: WorkshopSession uses studioId, not studioName
                        'date': workshop.date,
                        'time': workshop.time,
                        'pricing': workshop.pricingInfo,
                      },
                      workshopUuid: workshopIdentifier, // Use either UUID or timestamp as identifier
                      workshop: workshop, // Pass workshop object for rewards integration
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: workshop.paymentLinkType?.toLowerCase() == 'nachna'
                      ? const Color(0xFF00D4FF)
                      : Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: workshop.paymentLinkType?.toLowerCase() == 'nachna' ? 8 : 2,
                    shadowColor: workshop.paymentLinkType?.toLowerCase() == 'nachna'
                      ? const Color(0xFF00D4FF).withOpacity(0.5)
                      : null,
                  ),
                  child: Text(
                    workshop.paymentLinkType?.toLowerCase() == 'nachna'
                      ? 'Register with nachna'
                      : 'Register',
                  ),
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