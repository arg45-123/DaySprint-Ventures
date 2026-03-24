import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double walletBalance = 0.0;
  List<Map<String, dynamic>> upcomingPayments = [];
  List<Map<String, dynamic>> transactionHistory = [];
  DateTime? lastCreditDate;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final jobsSnapshot = await FirebaseFirestore.instance
        .collection('jobs')
        .where('hired_employees', arrayContains: user.uid)
        .get();

    final now = DateTime.now();
    List<Map<String, dynamic>> upcoming = [];
    List<Map<String, dynamic>> history = [];
    double balance = 0.0;
    DateTime? lastCredit;

    for (var doc in jobsSnapshot.docs) {
      final data = doc.data();
      final endDate = data['end_date']?.toDate();
      final payAmount = double.tryParse(data['pay'].toString()) ?? 0.0;
      final companyName = data['company_name'] ?? "Unknown Company";

      if (endDate != null) {
        // Adjust time to 5 PM
        final adjustedDate = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          21, // 5 PM
        );

        if (now.isBefore(adjustedDate)) {
          // Upcoming payment
          upcoming.add({
            'company': companyName,
            'amount': payAmount,
            'date': adjustedDate,
          });
        } else {
          // Job completed -> Add to balance and history
          balance += payAmount;
          history.add({
            'company': companyName,
            'amount': payAmount,
            'date': adjustedDate,
          });

          // Track last credit date
          if (lastCredit == null || adjustedDate.isAfter(lastCredit)) {
            lastCredit = adjustedDate;
          }
        }
      }
    }

    setState(() {
      walletBalance = balance;
      upcomingPayments = upcoming;
      transactionHistory = history;
      lastCreditDate = lastCredit;
    });
  }

  bool get canWithdraw {
    if (lastCreditDate == null) return false;
    return DateTime.now().isAfter(lastCreditDate!.add(const Duration(hours: 24)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Wallet"),
        backgroundColor: const Color(0xFF6A11CB),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Balance Card - Made bigger
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.purple[50],
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        "Wallet Balance",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "₹${walletBalance.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canWithdraw
                              ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Withdraw successful!")),
                            );
                          }
                              : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Withdraw only after 24 hours after credit"),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A11CB),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Withdraw",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Upcoming Payments
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                "Upcoming Payments",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (upcomingPayments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("No upcoming payments."),
              ),
            ...upcomingPayments.map((payment) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.access_time, color: Colors.orange, size: 28),
                title: Text(
                  payment['company'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  DateFormat('MMM dd, yyyy – hh:mm a').format(payment['date']),
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Text(
                  "₹${payment['amount']}",
                  style: const TextStyle(  // Sabhi upcoming payments green honge
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            )),

            const SizedBox(height: 24),

            // Transaction History
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                "Transaction History",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (transactionHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("No transactions yet."),
              ),
            ...transactionHistory.map((tx) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                title: Text(
                  tx['company'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  DateFormat('MMM dd, yyyy – hh:mm a').format(tx['date']),
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Text(
                  "₹${tx['amount']}",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
