import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WorkerProfileScreen extends StatelessWidget {
  final String workerId;

  const WorkerProfileScreen({super.key, required this.workerId});

  Future<Map<String, dynamic>> _fetchWorkerDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('worker_data').doc(workerId).get();
      return doc.data() ?? {};
    } catch (e) {
      return {'error': 'Failed to fetch worker details: $e'};
    }
  }

  Future<void> _cancelHire(String workerId) async {
    try {
      final workerRef = FirebaseFirestore.instance.collection('worker_data').doc(workerId);

      // Update the status to 'waiting' and remove hired timestamp
      await workerRef.update({
        'status': 'waiting',
        'hiredAt': FieldValue.delete(),
      });

      // Optional: Remove from any hired workers collection if you have one
      await FirebaseFirestore.instance
          .collection('hired_workers')
          .doc(workerId)
          .delete();
    } catch (e) {
      print('Failed to cancel hire: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Profile'),
        backgroundColor: Colors.deepPurple,
        actions: [
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchWorkerDetails(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox();
              }
              if (snapshot.hasData && snapshot.data!['status'] == 'hired') {
                return IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () async {
                    try {
                      await _cancelHire(workerId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hire cancelled successfully')),
                      );
                      // Refresh the page
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkerProfileScreen(workerId: workerId),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to cancel hire: $e')),
                      );
                    }
                  },
                );
              }
              return const SizedBox();
            },
          ),
        ],
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
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.containsKey('error')) {
              return Center(
                child: Text(
                  'Error loading worker profile: ${snapshot.data?['error'] ?? snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final worker = snapshot.data!;
            final name = worker['name']?.toString() ?? 'Unknown';
            final rating = (worker['rating'] as num?)?.toStringAsFixed(1) ?? 'N/A';
            final skills = (worker['skills'] as List<dynamic>?)?.join(", ") ?? 'No skills listed';
            final age = worker['age']?.toString() ?? 'N/A';
            final about = worker['about']?.toString() ?? 'No description provided';
            final photoUrl = worker['photoUrl']?.toString();
            final transactions = List<Map<String, dynamic>>.from(worker['transactions'] ?? []);
            final status = worker['status']?.toString() ?? 'N/A';

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 60,
                        child: ClipOval(
                          child: photoUrl != null
                              ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person, size: 60, color: Colors.white70);
                            },
                          )
                              : const Icon(Icons.person, size: 60, color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        name,
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
                          const Icon(Icons.star, color: Colors.amber, size: 24),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'hired' ? Colors.green : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildProfileItem(Icons.construction, 'Skills:', skills),
                    _buildProfileItem(Icons.calendar_today, 'Age:', age),
                    _buildProfileItem(Icons.description, 'About:', about),
                    const SizedBox(height: 24),
                    const Text(
                      'Transaction History:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (transactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'No transactions yet',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          final amount = transaction['amount']?.toString() ?? '0.0';
                          final type = transaction['type']?.toString() ?? 'Unknown';
                          final status = transaction['status']?.toString() ?? 'Unknown';
                          final createdAt = (transaction['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                          final creditedAt = (transaction['creditedAt'] as Timestamp?)?.toDate();

                          return Card(
                            color: const Color.fromRGBO(255, 255, 255, 0.05),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Job: ${transaction['jobTitle'] ?? 'Untitled Job'}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Amount: ₹$amount',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Type: $type',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Status: $status',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: status == 'pending' ? Colors.orange : Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Created: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  if (creditedAt != null)
                                    Text(
                                      'Credited: ${DateFormat('yyyy-MM-dd HH:mm').format(creditedAt)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chat feature coming soon!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Message Worker',
                          style: TextStyle(color: Colors.white, fontSize: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
