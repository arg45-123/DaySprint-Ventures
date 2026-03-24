import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TaskScreen extends StatefulWidget {
  final String userId;

  const TaskScreen({super.key, required this.userId});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> _tasks = [
    {
      'title': 'Hire 10 Employees',
      'description': 'Hire at least 10 employees across all jobs.',
      'target': 10,
      'reward': '₹500 Bonus Credit',
      'progressField': 'total_hired_employees',
    },
    {
      'title': 'Post 5 Jobs',
      'description': 'Post at least 5 job openings.',
      'target': 5,
      'reward': 'Free Premium Feature for 1 Month',
      'progressField': 'total_posted_jobs',
    },
    {
      'title': 'Complete 3 Payments',
      'description': 'Successfully complete payments for 3 jobs.',
      'target': 3,
      'reward': '₹200 Discount on Next Payment',
      'progressField': 'total_completed_payments',
    },
  ];

  Future<int> _getProgress(String field) async {
    try {
      final doc = await _firestore.collection('employers').doc(widget.userId).get();
      if (!doc.exists) return 0;

      if (field == 'total_hired_employees') {
        final jobsSnapshot = await _firestore
            .collection('jobs')
            .where('employer_id', isEqualTo: widget.userId)
            .get();
        int totalHired = 0;
        for (var job in jobsSnapshot.docs) {
          final hiredEmployees = List<String>.from(job['hired_employees'] ?? []);
          totalHired += hiredEmployees.length;
        }
        await _firestore.collection('employers').doc(widget.userId).update({
          'total_hired_employees': totalHired,
        });
        return totalHired;
      } else if (field == 'total_posted_jobs') {
        final jobsSnapshot = await _firestore
            .collection('jobs')
            .where('employer_id', isEqualTo: widget.userId)
            .get();
        final totalJobs = jobsSnapshot.docs.length;
        await _firestore.collection('employers').doc(widget.userId).update({
          'total_posted_jobs': totalJobs,
        });
        return totalJobs;
      } else if (field == 'total_completed_payments') {
        final paymentsSnapshot = await _firestore
            .collection('payment_history')
            .where('employer_id', isEqualTo: widget.userId)
            .get();
        final totalPayments = paymentsSnapshot.docs.length;
        await _firestore.collection('employers').doc(widget.userId).update({
          'total_completed_payments': totalPayments,
        });
        return totalPayments;
      }
      return doc.data()?[field] ?? 0;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching progress: $e'), backgroundColor: Colors.red),
      );
      return 0;
    }
  }

  Future<void> _claimReward(Map<String, dynamic> task) async {
    try {
      await _firestore.collection('employers').doc(widget.userId).update({
        'rewards': FieldValue.arrayUnion([
          {
            'task_title': task['title'],
            'reward': task['reward'],
            'claimed_at': FieldValue.serverTimestamp(),
          }
        ]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reward claimed: ${task['reward']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to claim reward: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks & Rewards'),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return FutureBuilder<int>(
                future: _getProgress(task['progressField']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Card(
                      color: const Color.fromRGBO(255, 255, 255, 0.05),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                      ),
                    );
                  }
                  final progress = snapshot.data ?? 0;
                  final isCompleted = progress >= task['target'];
                  return Card(
                    color: const Color.fromRGBO(255, 255, 255, 0.05),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            task['description'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Progress: $progress / ${task['target']}',
                            style: TextStyle(
                              fontSize: 16,
                              color: isCompleted ? Colors.green : Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reward: ${task['reward']}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.yellow,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isCompleted)
                            ElevatedButton(
                              onPressed: () => _claimReward(task),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('Claim Reward'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
