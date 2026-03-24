import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart'; // ✅ Razorpay import

class PaymentScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;
  final String userId;

  const PaymentScreen({
    Key? key,
    required this.jobId,
    required this.job,
    required this.userId,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Razorpay _razorpay; // ✅ Razorpay instance

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    // ✅ Razorpay callbacks
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear(); // ✅ Memory leak na ho isliye
  }

  void _openRazorpayCheckout(double finalAmount) {
    var options = {
      'key': 'rzp_test_iuJhjfnElRGKSI', // 🔑 Yaha tumhari Razorpay API Key ayegi
      'amount': (finalAmount * 100).toInt(), // paise me dena padta hai (₹10 => 1000)
      'name': widget.job['Onr_day (Employees)'] ?? 'Unknown Company',
      'description': widget.job['title'] ?? 'Job Payment',
      'prefill': {
        'contact': '9359046139', // 🔑 Yaha tum employer ka mobile dal sakte ho
        'email': 'arpangohatre@gmail.com' // 🔑 Yaha tum employer ka email dal sakte ho
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // ✅ Successful payment ke baad Firestore update
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final jobDoc = await _firestore.collection('jobs').doc(widget.jobId).get();
      final job = jobDoc.data();
      if (job == null) {
        _showErrorSnackBar("Job not found");
        return;
      }

      final hiredEmployees = List<String>.from(job['hired_employees'] ?? []);
      final payPerEmployee = double.tryParse(job['pay']?.toString() ?? '0.0') ?? 0.0;

      final workerUpdates = hiredEmployees.map((userId) async {
        final workerRef = _firestore.collection('workers').doc(userId);
        final workerDoc = await workerRef.get();
        if (!workerDoc.exists) return;

        final workerData = workerDoc.data()!;
        final transactions = List<Map<String, dynamic>>.from(workerData['transactions'] ?? []);

        final transactionIndex = transactions.indexWhere((t) => t['jobId'] == widget.jobId && t['status'] == 'pending');
        if (transactionIndex != -1) {
          transactions[transactionIndex] = {
            ...transactions[transactionIndex],
            'status': 'credited',
            'creditedAt': FieldValue.serverTimestamp(),
          };
        }

        await workerRef.update({
          'balance': FieldValue.increment(payPerEmployee),
          'transactions': transactions,
        });
      });

      await Future.wait(workerUpdates);

      final totalPay = double.tryParse(widget.job['total_pay']?.toString() ?? '0.0') ?? 0.0;
      final platformFee = totalPay * 0.02;
      final finalAmount = totalPay + platformFee;

      await _firestore.collection('payment_history').add({
        'job_id': widget.jobId,
        'employer_id': widget.userId,
        'amount': finalAmount.toStringAsFixed(2),
        'platform_fee': platformFee.toStringAsFixed(2),
        'payment_date': FieldValue.serverTimestamp(),
        'payment_id': response.paymentId, // ✅ Razorpay payment ID store kar rahe
      });

      await _firestore.collection('jobs').doc(widget.jobId).update({
        'is_paid': true,
      });

      await _firestore.collection('employers').doc(widget.userId).update({
        'total_completed_payments': FieldValue.increment(1),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment Successful! ID: ${response.paymentId}"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar("Payment failed: $e");
    }
  }

  // ✅ Agar payment fail ho jaye
  void _handlePaymentError(PaymentFailureResponse response) {
    _showErrorSnackBar("Payment Failed: ${response.message}");
  }

  // ✅ Agar user wallet (Paytm, PhonePe etc.) use kare
  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet Selected: ${response.walletName}")),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hiredCount = (widget.job['hired_employees'] as List<dynamic>?)?.length ?? 0;
    final payPerEmployee = double.tryParse(widget.job['pay']?.toString() ?? '0.0') ?? 0.0;
    final totalPay = hiredCount * payPerEmployee;
    final platformFee = totalPay * 0.02;
    final finalAmount = totalPay + platformFee;

    return Scaffold(
      appBar: AppBar(
        title: Text("Payment for ${widget.job['title']?.toString() ?? 'Untitled Job'}"),
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.job['company_name']?.toString() ?? 'Unknown Company',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.job['title']?.toString() ?? 'Untitled Job',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Payment Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: const Color.fromRGBO(255, 255, 255, 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Employees Hired: $hiredCount',
                            style: const TextStyle(fontSize: 16, color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text('Pay per Employee: ₹${payPerEmployee.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16, color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text('Calculation: $hiredCount × ₹${payPerEmployee.toStringAsFixed(2)} = ₹${totalPay.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16, color: Colors.white70)),
                        const SizedBox(height: 8),
                        const Divider(color: Colors.white54),
                        const SizedBox(height: 8),
                        Text('Total Payment: ₹${totalPay.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text('Platform Fee (2%): ₹${platformFee.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16, color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text('Final Amount: ₹${finalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openRazorpayCheckout(finalAmount), // ✅ Razorpay checkout open hoga
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Confirm Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: Confirming payment will proceed to Razorpay.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
