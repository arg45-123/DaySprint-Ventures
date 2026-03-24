import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'job_application_form.dart';

class JobDetailsScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;

  const JobDetailsScreen({super.key, required this.jobId, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  bool _hasApplied = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  Future<void> _checkApplicationStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = "Please sign in to check application status";
          _isLoading = false;
        });
        return;
      }

      final jobDoc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .get();

      if (!jobDoc.exists) {
        setState(() {
          _errorMessage = "Job no longer exists";
          _isLoading = false;
        });
        return;
      }

      final hiredEmployees = List<String>.from(jobDoc.data()?['hired_employees'] ?? []);

      setState(() {
        _hasApplied = hiredEmployees.contains(user.uid);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error checking application: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApply() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please sign in to apply"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for same-day applications
    final workerDoc = await FirebaseFirestore.instance
        .collection('workers')
        .doc(user.uid)
        .get();

    final appliedDates = List<String>.from(workerDoc.data()?['applied_dates'] ?? []);
    final jobDate = DateFormat('yyyy-MM-dd').format(widget.job['start_date'].toDate());

    if (appliedDates.contains(jobDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can only apply for one job per day"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobApplicationForm(
          jobId: widget.jobId,
          job: widget.job,
        ),
      ),
    );

    if (result == true && mounted) {
      await _checkApplicationStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Application submitted successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final startDate = job['start_date']?.toDate();
    final endDate = job['end_date']?.toDate();
    final hiredCount = (job['hired_employees'] as List<dynamic>?)?.length ?? 0;
    final requiredEmployees = job['employees_required'] ?? 0;
    final vacancies = requiredEmployees - hiredCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(job['title'] ?? 'Job Details'),
        backgroundColor: const Color(0xFF6A11CB),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job['title'] ?? 'Untitled Job',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              job['company_name'] ?? 'Unknown Company',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Job Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
                Icons.money, "Pay: ₹${job['pay']?.toString() ?? 'Not specified'} per day"),
            _buildDetailRow(Icons.location_on,
                "Location: ${job['location'] ?? 'Not specified'}"),
            _buildDetailRow(
                Icons.people, "Vacancies: ${vacancies > 0 ? vacancies : 0} available"),
            if (startDate != null)
              _buildDetailRow(
                Icons.calendar_today,
                "Date: ${DateFormat('MMM dd, yyyy').format(startDate)}",
              ),
            if (job['start_time'] != null && job['end_time'] != null)
              _buildDetailRow(
                Icons.access_time,
                "Time: ${job['start_time']} - ${job['end_time']}",
              ),
            if (job['description'] != null) ...[
              const SizedBox(height: 20),
              const Text(
                "Description",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(job['description']),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasApplied || job['status'] != 'active'
                    ? null
                    : _handleApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasApplied
                      ? Colors.grey
                      : const Color(0xFF6A11CB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _hasApplied ? "ALREADY APPLIED" : "APPLY NOW",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6A11CB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
