import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'employee_profile_screen.dart';
import 'submit_application.dart';
import 'package:intl/intl.dart';

class JobApplicationForm extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;

  const JobApplicationForm({super.key, required this.jobId, required this.job});

  @override
  State<JobApplicationForm> createState() => _JobApplicationFormState();
}

class _JobApplicationFormState extends State<JobApplicationForm> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _profileData;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
  GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar("Please sign in to apply");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final profileDoc = await FirebaseFirestore.instance
          .collection('worker_data')
          .doc(user.uid)
          .get();

      if (profileDoc.exists) {
        if (mounted) {
          setState(() {
            _profileData = profileDoc.data();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EmployeeProfileScreen(),
            ),
          ).then((_) => _checkProfile());
        }
      }
    } catch (e) {
      _showSnackBar("Error checking profile: ${e.toString()}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return; // Avoid calling after dispose
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Confirm Application"),
          content: const Text("Are you sure you want to apply for this job?"),
          actions: [
            TextButton(
              onPressed: () {
                if (Navigator.canPop(dialogContext)) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (Navigator.canPop(dialogContext)) {
                  Navigator.pop(dialogContext); // Close dialog
                }

                if (_profileData == null) {
                  _showSnackBar("Please complete your profile first");
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  _showSnackBar("Please sign in to apply");
                  return;
                }

                final jobDate = DateFormat('yyyy-MM-dd')
                    .format(widget.job['start_date'].toDate());

                final existingApplications = await FirebaseFirestore.instance
                    .collection('jobs')
                    .where('hired_employees', arrayContains: user.uid)
                    .where(
                  'start_date',
                  isEqualTo: Timestamp.fromDate(DateTime.parse(jobDate)),
                )
                    .get();

                if (existingApplications.docs.isNotEmpty) {
                  _showSnackBar("You can only apply for one job per day");
                  return;
                }

                if (mounted) setState(() => _isSubmitting = true);

                try {
                  final result = await submitApplication(
                    jobId: widget.jobId,
                    job: widget.job,
                    profileData: _profileData!,
                  );

                  if (result['success'] == true) {
                    _showSnackBar("Applied successfully!", isError: false);

                    // Wait a bit so snackbar is visible before popping
                    await Future.delayed(const Duration(milliseconds: 500));

                    if (mounted && Navigator.canPop(context)) {
                      Navigator.pop(context, true);
                    }
                  } else {
                    _showSnackBar(result['error'] ?? "Application failed");
                  }
                } catch (e) {
                  _showSnackBar("Error applying: ${e.toString()}");
                } finally {
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                  }
                }
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Job Application"),
          backgroundColor: const Color(0xFF6A11CB),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _profileData == null
            ? const Center(child: Text("Please create your profile first"))
            : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Your profile is ready!",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                  _isSubmitting ? null : _showConfirmationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                      : const Text(
                    "APPLY NOW",
                    style: TextStyle(
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
      ),
    );
  }
}
