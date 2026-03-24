import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerProfileScreen extends StatelessWidget {
  final String workerId;

  const WorkerProfileScreen({super.key, required this.workerId});

  Future<Map<String, dynamic>> _fetchWorkerDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('worker_data')
        .doc(workerId)
        .get();
    return doc.data() ?? {};
  }

  // 🔥 RANDOM WHATSAPP FUNCTION
  Future<void> _openWhatsApp() async {
    List<String> numbers = [
      "919921485238", // +91 add karo
      "919359046139"
    ];

    final random = Random();
    String selectedNumber = numbers[random.nextInt(numbers.length)];

    String message = "Hello, mujhe worker ke baare me info chahiye";

    final url = Uri.parse(
        "https://wa.me/$selectedNumber?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw "WhatsApp open nahi ho raha";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Profile'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _fetchWorkerDetails(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Text(
                  'Error loading worker profile',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final worker = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: worker['photoUrl'] != null
                            ? NetworkImage(worker['photoUrl'].toString())
                            : null,
                        child: worker['photoUrl'] == null
                            ? const Icon(Icons.person,
                            size: 60, color: Colors.white70)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Center(
                      child: Text(
                        worker['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star,
                              color: Colors.amber, size: 24),
                          const SizedBox(width: 4),
                          Text(
                            worker['rating'] != null
                                ? worker['rating'].toString()
                                : 'N/A',
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildProfileItem(Icons.work, 'Experience:',
                        worker['experience'] ?? 'N/A'),
                    _buildProfileItem(Icons.location_city, 'Location:',
                        worker['location'] ?? 'N/A'),
                    _buildProfileItem(
                        Icons.construction,
                        'Skills:',
                        worker['skills'] != null
                            ? (worker['skills'] as List).join(", ")
                            : 'No skills'),
                    _buildProfileItem(Icons.description, 'About:',
                        worker['about'] ?? 'No description'),

                    const SizedBox(height: 30),

                    // 🔥 WHATSAPP BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openWhatsApp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Message on WhatsApp',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$label $value",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
