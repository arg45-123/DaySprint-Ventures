import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

// Replace these import paths with the actual paths in your project
import 'job_form.dart';
import 'profile_screen_hire.dart';
import 'payment_history_icon.dart';
import 'worker_profile_screen.dart';
import 'hire_login_screen.dart';
import 'task_screen.dart';
import 'payment_screen.dart';

class HireDashboardScreen extends StatefulWidget {
  final String userId;

  const HireDashboardScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<HireDashboardScreen> createState() => _HireDashboardScreenState();
}

class _HireDashboardScreenState extends State<HireDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _employerData;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadEmployerData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEmployerData() async {
    try {
      final doc = await _firestore.collection('employers').doc(widget.userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _employerData = data;
          });
          await _updateEmployerRating(data);
        } else {
          _showErrorSnackBar('Employer data is empty');
        }
      } else {
        _showErrorSnackBar('Employer data not found');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading employer data: $e');
    }
  }

  Future<void> _updateEmployerRating(Map<String, dynamic> employerData) async {
    try {
      final hiredEmployees = (employerData['total_hired_employees'] as num?)?.toInt() ?? 0;
      final completedPayments = (employerData['total_completed_payments'] as num?)?.toInt() ?? 0;
      final postedJobs = (employerData['total_posted_jobs'] as num?)?.toInt() ?? 0;

      int rating = 1;
      if (hiredEmployees >= 10 && completedPayments >= 10 && postedJobs >= 20) {
        rating = 2;
      }

      await _firestore.collection('employers').doc(widget.userId).update({
        'rating': rating,
      });

      if (mounted) {
        setState(() {
          _employerData?['rating'] = rating;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error updating rating: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Stream<QuerySnapshot> _getActiveJobs() {
    return _firestore
        .collection('jobs')
        .where('employer_id', isEqualTo: widget.userId)
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<void> _deleteJob(String jobId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      await _firestore.collection('jobs').doc(jobId).delete();
      await _firestore.collection('employers').doc(widget.userId).update({
        'total_posted_jobs': FieldValue.increment(-1),
      });
      await _loadEmployerData();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Job deleted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar("Delete failed: $error");
      }
    }
  }

  void _showApplicants(String jobId, Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplicantsScreen(jobId: jobId, job: job),
      ),
    );
  }

  Future<void> _openLocationInMaps(String address) async {
    try {
      final query = Uri.encodeComponent(address);
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showErrorSnackBar('Could not open Google Maps');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening maps: $e');
    }
  }

  Future<void> _handleJobSubmission(Map<String, dynamic> jobData, {String? jobId}) async {
    try {
      if (jobId == null) {
        jobData['created_at'] = FieldValue.serverTimestamp();
        jobData['status'] = 'active';
        jobData['employer_id'] = widget.userId;
        jobData['hired_employees'] = [];
        jobData['waiting_list'] = [];
        jobData['total_pay'] = ((double.tryParse(jobData['pay']?.toString() ?? '0.0') ?? 0.0) * (jobData['employees_required']?.toInt() ?? 1)).toString();

        await _firestore.collection('jobs').add(jobData);
        await _firestore.collection('employers').doc(widget.userId).update({
          'total_posted_jobs': FieldValue.increment(1),
        });
        await _loadEmployerData();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Job posted successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        jobData['total_pay'] = ((double.tryParse(jobData['pay']?.toString() ?? '0.0') ?? 0.0) * (jobData['employees_required']?.toInt() ?? 1)).toString();
        await _firestore.collection('jobs').doc(jobId).update(jobData);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Job updated successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Job submission failed: $e");
      }
    }
  }

  void _showJobPostModal(BuildContext context, {String? jobId, Map<String, dynamic>? job}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => JobForm(
        initialData: job,
        onSubmit: (jobData) => _handleJobSubmission(jobData, jobId: jobId),
        isEditing: jobId != null,
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() {
    _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HireLoginScreen(),
      ),
    );
  }

  void _navigateToPaymentHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentHistoryScreen(userId: widget.userId),
      ),
    );
  }

  void _navigateToTasks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskScreen(userId: widget.userId),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: widget.userId),
      ),
    );
  }

  void _viewAllJobs(BuildContext context) {
    // Implement view all jobs if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Hire Dashboard'),
        backgroundColor: Colors.deepPurple,
      ),
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _employerData?['name']?.toString() ?? 'User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${_employerData?['phone']?.toString() ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Employees Hired: ${_employerData?['total_hired_employees']?.toString() ?? '0'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Payments Done: ${_employerData?['total_completed_payments']?.toString() ?? '0'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Jobs Posted: ${_employerData?['total_posted_jobs']?.toString() ?? '0'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Rating: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      ...List.generate(2, (index) {
                        return Icon(
                          index < (_employerData?['rating']?.toInt() ?? 1)
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.yellow,
                          size: 18,
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showJobPostModal(context),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_employerData != null)
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Hi, ${_employerData!['name']?.split(" ").first ?? 'User'}!',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.person, color: Colors.white, size: 20),
                              onPressed: () => _navigateToProfile(context),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.history, color: Colors.white, size: 20),
                              onPressed: _navigateToPaymentHistory,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.assignment, color: Colors.white, size: 20),
                              onPressed: _navigateToTasks,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                              onPressed: _confirmLogout,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Jobs',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _viewAllJobs(context),
                      child: const Text(
                        'View All',
                        style: TextStyle(color: Colors.deepPurpleAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getActiveJobs(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No active jobs',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      final jobs = snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final jobDoc = jobs[index];
                          final job = jobDoc.data() as Map<String, dynamic>;
                          return _buildJobCard(jobDoc.id, job, context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(String jobId, Map<String, dynamic> job, BuildContext context) {
    final isPaymentActive = _isPaymentButtonActive(job);
    final hiredCount = (job['hired_employees'] as List<dynamic>?)?.length ?? 0;
    final waitingCount = (job['waiting_list'] as List<dynamic>?)?.length ?? 0;
    final requiredEmployees = (job['employees_required'] as num?)?.toInt() ?? 0;
    final vacancies = requiredEmployees - hiredCount;

    return Dismissible(
      key: Key(jobId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 40),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Job?"),
            content: const Text("This job will be permanently deleted"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteJob(jobId),
      child: Card(
        color: const Color.fromRGBO(255, 255, 255, 0.05),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job['company_name']?.toString() ?? 'Unknown Company',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                job['title']?.toString() ?? 'Untitled Job',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openLocationInMaps(job['location']?.toString() ?? ''),
                      child: Text(
                        job['location']?.toString() ?? 'No location',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.payments, size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    'Pay: ₹${job['pay']?.toString() ?? 'Not specified'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (job['start_date'] != null)
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      job['start_date'] is Timestamp
                          ? DateFormat.yMMMd().format((job['start_date'] as Timestamp).toDate())
                          : DateFormat.yMMMd().format(job['start_date'] as DateTime),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.people, size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    '$hiredCount/$requiredEmployees Hired ($vacancies Vacancies, $waitingCount Waiting)',
                    style: TextStyle(
                      color: hiredCount >= requiredEmployees ? Colors.green : Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (job['total_pay'] != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isPaymentActive
                        ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(
                          jobId: jobId,
                          job: job,
                          userId: widget.userId,
                        ),
                      ),
                    )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPaymentActive ? Colors.blue : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isPaymentActive ? 'Make Payment' : 'Payment Pending',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: ListTile(
                        leading: Icon(Icons.remove_red_eye),
                        title: Text("View Applicants"),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text("Edit Job"),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text("Delete Job", style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'view') {
                      _showApplicants(jobId, job);
                    } else if (value == 'edit') {
                      _showJobPostModal(context, jobId: jobId, job: job);
                    } else if (value == 'delete') {
                      _confirmDeleteJob(context, jobId);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPaymentButtonActive(Map<String, dynamic> job) {
    if (job['end_date'] == null || job['end_time'] == null || job['is_paid'] == true) {
      return false;
    }

    try {
      final endDate = (job['end_date'] is Timestamp)
          ? job['end_date'].toDate()
          : job['end_date'] as DateTime;
      final endTimeStr = (job['end_time']?.toString() ?? '').trim();
      final endTimeParts = endTimeStr.split(':');
      if (endTimeParts.length < 2) {
        return false;
      }
      final endHour = int.tryParse(endTimeParts[0]) ?? 0;
      final endMinute = int.tryParse(endTimeParts[1].split(' ')[0]) ?? 0;
      final endDateTime = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        endHour,
        endMinute,
      );

      final now = DateTime.now();
      return now.isAfter(endDateTime);
    } catch (e) {
      return false;
    }
  }

  void _confirmDeleteJob(BuildContext context, String jobId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this job post?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteJob(jobId);
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class ApplicantsScreen extends StatelessWidget {
  final String jobId;
  final Map<String, dynamic> job;

  const ApplicantsScreen({Key? key, required this.jobId, required this.job}) : super(key: key);

  Future<void> _cancelHire(BuildContext context, String applicantId) async {
    try {
      final jobDoc = await FirebaseFirestore.instance.collection('jobs').doc(jobId).get();
      final jobData = jobDoc.data();
      if (jobData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Job not found"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final hiredEmployees = List<String>.from(jobData['hired_employees'] ?? []);
      final waitingList = List<String>.from(jobData['waiting_list'] ?? []);

      if (!hiredEmployees.contains(applicantId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This applicant is not hired"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      hiredEmployees.remove(applicantId);

      String? newHiredId;
      if (waitingList.isNotEmpty) {
        newHiredId = waitingList.first;
        waitingList.removeAt(0);
        hiredEmployees.add(newHiredId);

        await FirebaseFirestore.instance
            .collection('applications')
            .doc('${newHiredId}_$jobId')
            .update({'status': 'Hired'});

        final workerRef = FirebaseFirestore.instance.collection('workers').doc(newHiredId);
        final workerDoc = await workerRef.get();
        if (workerDoc.exists) {
          final workerData = workerDoc.data()!;
          final transactions = List<Map<String, dynamic>>.from(workerData['transactions'] ?? []);
          transactions.add({
            'jobId': jobId,
            'jobTitle': jobData['title']?.toString() ?? 'Untitled Job',
            'type': 'credit',
            'status': 'pending',
            'amount': jobData['pay']?.toString() ?? '0.0',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await workerRef.update({
            'applied_jobs': FieldValue.arrayUnion([jobId]),
            'applied_dates': FieldValue.arrayUnion([
              DateFormat('yyyy-MM-dd').format(
                jobData['start_date'] is Timestamp
                    ? (jobData['start_date'] as Timestamp).toDate()
                    : jobData['start_date'] as DateTime,
              ),
            ]),
            'transactions': transactions,
          });
        }

        await FirebaseFirestore.instance.collection('employers').doc(jobData['employer_id']).update({
          'total_hired_employees': FieldValue.increment(1),
        });
      }

      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'hired_employees': hiredEmployees,
        'waiting_list': waitingList,
      });

      await FirebaseFirestore.instance.collection('applications').doc('${applicantId}_$jobId').delete();

      final workerRef = FirebaseFirestore.instance.collection('workers').doc(applicantId);
      final workerDoc = await workerRef.get();
      if (workerDoc.exists) {
        final workerData = workerDoc.data()!;
        final appliedJobs = List<String>.from(workerData['applied_jobs'] ?? []);
        final transactions = List<Map<String, dynamic>>.from(workerData['transactions'] ?? []);
        final jobDate = DateFormat('yyyy-MM-dd').format(
          job['start_date'] is Timestamp
              ? (job['start_date'] as Timestamp).toDate()
              : job['start_date'] as DateTime,
        );

        final transactionToRemove = transactions.firstWhere(
              (t) => t['jobId'] == jobId && t['type'] == 'credit' && t['status'] == 'pending',
          orElse: () => <String, dynamic>{},
        );

        await workerRef.update({
          'applied_jobs': FieldValue.arrayRemove([jobId]),
          'applied_dates': FieldValue.arrayRemove([jobDate]),
          'transactions': transactionToRemove.isNotEmpty
              ? FieldValue.arrayRemove([transactionToRemove])
              : FieldValue.arrayRemove([]),
        });
      }

      await FirebaseFirestore.instance.collection('employers').doc(jobData['employer_id']).update({
        'total_hired_employees': FieldValue.increment(-1),
      });

      final employerDoc = await FirebaseFirestore.instance.collection('employers').doc(jobData['employer_id']).get();
      if (employerDoc.exists) {
        final employerData = employerDoc.data();
        if (employerData != null) {
          int rating = 1;
          final hiredEmployeesCount = (employerData['total_hired_employees'] as num?)?.toInt() ?? 0;
          final completedPayments = (employerData['total_completed_payments'] as num?)?.toInt() ?? 0;
          final postedJobs = (employerData['total_posted_jobs'] as num?)?.toInt() ?? 0;
          if (hiredEmployeesCount >= 10 && completedPayments >= 10 && postedJobs >= 20) {
            rating = 2;
          }
          await FirebaseFirestore.instance.collection('employers').doc(jobData['employer_id']).update({
            'rating': rating,
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hire cancelled${newHiredId != null ? ' and new applicant hired from waiting list' : ''}!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to cancel hire: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _fetchWorkerDetails(String workerId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('workers').doc(workerId).get();
      return doc.data() ?? <String, dynamic>{};
    } catch (e) {
      return {'error': 'Failed to fetch worker details: $e'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Applicants for ${job['title']?.toString() ?? 'Untitled Job'}"),
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
                  job['company_name']?.toString() ?? 'Unknown Company',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  job['title']?.toString() ?? 'Untitled Job',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Applicants:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('applications')
                      .where('jobId', isEqualTo: jobId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error fetching applicants: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final applications = snapshot.data?.docs ?? [];

                    if (applications.isEmpty) {
                      return const Center(
                        child: Text(
                          'No applicants yet',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: applications.length,
                      itemBuilder: (context, index) {
                        final application = applications[index].data() as Map<String, dynamic>;
                        final applicantId = application['userId'] as String;

                        return FutureBuilder<Map<String, dynamic>>(
                          future: _fetchWorkerDetails(applicantId),
                          builder: (context, workerSnapshot) {
                            if (workerSnapshot.connectionState == ConnectionState.waiting) {
                              return const ListTile(
                                title: Text("Loading...", style: TextStyle(color: Colors.white)),
                              );
                            }

                            if (workerSnapshot.hasError || !workerSnapshot.hasData || workerSnapshot.data!.containsKey('error')) {
                              return ListTile(
                                title: Text(
                                  "Error loading worker: ${workerSnapshot.data?['error'] ?? workerSnapshot.error}",
                                  style: const TextStyle(color: Colors.red),
                                ),
                              );
                            }

                            final worker = workerSnapshot.data!;
                            final isHired = application['status'] == 'Hired';
                            final isWaiting = application['status'] == 'Waiting';

                            return Card(
                              color: const Color.fromRGBO(255, 255, 255, 0.05),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundImage: worker['photoUrl'] != null
                                              ? NetworkImage(worker['photoUrl'] as String)
                                              : null,
                                          child: worker['photoUrl'] == null
                                              ? const Icon(Icons.person, size: 30, color: Colors.white70)
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                worker['name']?.toString() ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Rating: ${(worker['rating'] as num?)?.toStringAsFixed(1) ?? 'N/A'}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              Text(
                                                'Status: ${application['status']?.toString() ?? 'Pending'}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: isHired
                                                      ? Colors.green
                                                      : isWaiting
                                                      ? Colors.orange
                                                      : Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Skills: ${(worker['skills'] as List<dynamic>?)?.join(", ") ?? 'No skills listed'}',
                                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Experience: ${worker['experience']?.toString() ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_red_eye, color: Colors.white70),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => WorkerProfileScreen(workerId: applicantId),
                                              ),
                                            );
                                          },
                                        ),
                                        if (isHired)
                                          IconButton(
                                            icon: const Icon(Icons.cancel, color: Colors.red),
                                            onPressed: () => _cancelHire(context, applicantId),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.message, color: Colors.white70),
                                          onPressed: () {
                                            // Navigate to chat screen
                                          },
                                        ),
                                      ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
