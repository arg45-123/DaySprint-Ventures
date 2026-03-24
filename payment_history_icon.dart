import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final String userId;

  const PaymentHistoryScreen({super.key, required this.userId});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isLoading = false;
  final Map<String, String> _jobTitleCache = {};

  Future<void> _refreshPayments() async {
    setState(() {
      _isLoading = true;
    });
    // Simulate a delay to ensure StreamBuilder refreshes
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    print('PaymentHistoryScreen initialized with userId: ${widget.userId}');
  }

  // Function to fetch job title from job_id
  Future<String> _getJobTitle(String jobId) async {
    if (_jobTitleCache.containsKey(jobId)) {
      return _jobTitleCache[jobId]!;
    }

    if (jobId.isEmpty) {
      return 'No Job ID';
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .get();

      if (doc.exists) {
        final title = doc.data()?['title'] ?? 'Unknown Job';
        _jobTitleCache[jobId] = title; // Cache the result
        return title;
      }
      return 'Job Not Found';
    } catch (e) {
      print('Error fetching job title for $jobId: $e');
      return 'Error Loading Job';
    }
  }

  // Helper function to safely convert amount to double
  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) {
      try {
        return double.parse(amount);
      } catch (e) {
        print('Error parsing amount: $e');
        return 0.0;
      }
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshPayments,
            tooltip: 'Refresh Payments',
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('payment_history')
              .where('employer_id', isEqualTo: widget.userId)
              .orderBy('payment_date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white70, size: 50),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshPayments,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payment, color: Colors.white70, size: 50),
                    const SizedBox(height: 16),
                    const Text(
                      'No payment history found',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your payments will appear here',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshPayments,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              );
            }

            final payments = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index].data() as Map<String, dynamic>;
                final paymentDate = payment['payment_date'] != null
                    ? (payment['payment_date'] is Timestamp
                    ? (payment['payment_date'] as Timestamp).toDate()
                    : payment['payment_date'] as DateTime)
                    : null;

                final String jobId = payment['job_id']?.toString() ?? '';
                final double amount = _parseAmount(payment['amount']);
                final String status = payment['status']?.toString() ?? 'N/A';

                return FutureBuilder<String>(
                  future: _getJobTitle(jobId),
                  builder: (context, jobSnapshot) {
                    final String jobTitle = jobSnapshot.data ?? 'Loading...';

                    return Card(
                      color: const Color.fromRGBO(255, 255, 255, 0.08),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jobTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Job ID: ${jobId.isEmpty ? 'N/A' : jobId}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: Colors.white54),
                                  const SizedBox(width: 4),
                                  Text(
                                    paymentDate != null
                                        ? DateFormat('MMM dd, yyyy - hh:mm a').format(paymentDate)
                                        : 'Date: N/A',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet, size: 14, color: Colors.white54),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Status: $status',
                                    style: TextStyle(
                                      color: status.toLowerCase() == 'completed'
                                          ? Colors.green[300]
                                          : status.toLowerCase() == 'failed'
                                          ? Colors.red[300]
                                          : Colors.orange[300],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '₹${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.greenAccent[400],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
