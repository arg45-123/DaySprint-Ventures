import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'wallet_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'employee_profile_screen.dart';
import 'submit_application.dart';
import 'applied_jobs_screen.dart';
import 'job_application_form.dart';
import 'get_job_login_screen.dart'; // Make sure to import your login screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const _HomeTab(),
    const AppliedJobsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "One Day Employees",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          _buildAppBarIcon(Icons.person, 20, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()),
            );
          }),
          _buildAppBarIcon(Icons.account_balance_wallet, 20, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WalletScreen()),
            );
          }),
          _buildAppBarIcon(Icons.search, 20, () {}),
          _buildAppBarIcon(Icons.notifications, 20, () {}),
        ],
      ),
      drawer: _buildDrawer(user),
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildAppBarIcon(IconData icon, double size, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: size, color: Colors.white),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36),
    );
  }

  Widget _buildDrawer(User? user) {
    return Drawer(
      child: ListView(
        children: [
          Container(
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.transparent],
                ),
              ),
              accountName: Text(
                user?.displayName ?? "Guest",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              accountEmail: Text(
                user?.email ?? "",
                style: const TextStyle(color: Colors.white70),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, size: 36, color: Color(0xFF6A11CB))
                    : null,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF6A11CB)),
            title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout Confirmation'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true) {
                await FirebaseAuth.instance.signOut();
                // Navigate to login screen and remove all previous routes
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const GetJobLoginScreen()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedItemColor: const Color(0xFF6A11CB),
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.work), label: "Applied Jobs"),
      ],
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  String _formatTimeTo12Hour(String timeString) {
    try {
      // Handle case where time is already in 12-hour format
      if (timeString.contains('AM') || timeString.contains('PM')) {
        return timeString;
      }

      // Parse 24-hour format (e.g., "17:00" or "17:00:00")
      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];

      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : hour == 0 ? 12 : hour;

      return '$hour12:$minute $period';
    } catch (e) {
      return timeString; // Return original if parsing fails
    }
  }

  Future<void> _viewJobDetails(BuildContext context, String jobId, Map<String, dynamic> job) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsScreen(jobId: jobId, job: job),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You have successfully applied and are hired"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    text: "Welcome, ",
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: FirebaseAuth.instance.currentUser?.displayName ?? "Guest",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const TextSpan(text: " 👋"),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Find your one day job today!",
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Available Jobs",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No jobs available',
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }

              final jobs = snapshot.data!.docs;

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final jobDoc = jobs[index];
                  final job = jobDoc.data() as Map<String, dynamic>;
                  final hiredCount = (job['hired_employees'] as List<dynamic>?)?.length ?? 0;
                  final requiredEmployees = job['employees_required'] ?? 0;
                  final vacancies = requiredEmployees - hiredCount;

                  return _JobCard(
                    jobId: jobDoc.id,
                    jobData: job,
                    title: job['title']?.toString() ?? 'Untitled Job',
                    company: job['company_name']?.toString() ?? 'Unknown Company',
                    pay: '₹${job['pay']?.toString() ?? 'Not specified'}/day',
                    location: job['location']?.toString() ?? 'No location',
                    vacancies: vacancies > 0 ? vacancies : 0,
                    startDate: job['start_date'] as Timestamp?,
                    startTime: _formatTimeTo12Hour(job['start_time'] ?? 'Not specified'),
                    endTime: _formatTimeTo12Hour(job['end_time'] ?? 'Not specified'),
                    onViewDetails: () => _viewJobDetails(context, jobDoc.id, job),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class JobDetailsScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;

  const JobDetailsScreen({super.key, required this.jobId, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  bool _hasApplied = false;

  String _formatTimeTo12Hour(String timeString) {
    try {
      if (timeString.contains('AM') || timeString.contains('PM')) {
        return timeString;
      }

      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];

      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : hour == 0 ? 12 : hour;

      return '$hour12:$minute $period';
    } catch (e) {
      return timeString;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  Future<void> _checkApplicationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final jobDoc = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .get();
    final hiredEmployees = List<String>.from(jobDoc.data()?['hired_employees'] ?? []);
    setState(() {
      _hasApplied = hiredEmployees.contains(user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final startDate = widget.job['start_date']?.toDate();
    final endDate = widget.job['end_date']?.toDate();
    final hiredCount = (widget.job['hired_employees'] as List<dynamic>?)?.length ?? 0;
    final requiredEmployees = widget.job['employees_required'] ?? 0;
    final vacancies = requiredEmployees - hiredCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job['title'] ?? 'Job Details'),
        backgroundColor: const Color(0xFF6A11CB),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.job['title'] ?? 'Untitled Job',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.job['company_name'] ?? 'Unknown Company',
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
            _buildDetailRow(Icons.money, "Pay: ₹${widget.job['pay'] ?? 'Not specified'} per day"),
            _buildDetailRow(Icons.location_on, "Location: ${widget.job['location'] ?? 'Not specified'}"),
            _buildDetailRow(Icons.people, "Vacancies: $vacancies available"),
            if (startDate != null)
              _buildDetailRow(Icons.calendar_today,
                  "Date: ${DateFormat('MMM dd, yyyy').format(startDate)}"),
            if (widget.job['start_time'] != null && widget.job['end_time'] != null)
              _buildDetailRow(Icons.access_time,
                  "Time: ${_formatTimeTo12Hour(widget.job['start_time'])} - ${_formatTimeTo12Hour(widget.job['end_time'])}"),
            if (widget.job['description'] != null) ...[
              const SizedBox(height: 20),
              const Text(
                "Description",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(widget.job['description']),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasApplied
                    ? null
                    : () async {
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

                  final workerDoc = await FirebaseFirestore.instance
                      .collection('workers')
                      .doc(user.uid)
                      .get();
                  final appliedDates = List<String>.from(workerDoc.data()?['applied_dates'] ?? []);
                  final jobDate = DateFormat('yyyy-MM-dd').format(widget.job['start_date'].toDate());

                  if (appliedDates.contains(jobDate)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("You cannot apply for multiple jobs on the same date!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final jobDoc = await FirebaseFirestore.instance
                      .collection('jobs')
                      .doc(widget.jobId)
                      .get();
                  final hiredEmployees = List<String>.from(jobDoc.data()?['hired_employees'] ?? []);
                  if (hiredEmployees.contains(user.uid)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("You have already applied for this job!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobApplicationForm(
                        jobId: widget.jobId,
                        job: widget.job,
                      ),
                    ),
                  ).then((value) {
                    if (value == true) {
                      setState(() {
                        _hasApplied = true;
                      });
                      Navigator.pop(context, true);
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasApplied ? Colors.grey : const Color(0xFF6A11CB),
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

class _JobCard extends StatelessWidget {
  final String jobId;
  final Map<String, dynamic> jobData;
  final String title;
  final String company;
  final String pay;
  final String location;
  final int vacancies;
  final Timestamp? startDate;
  final String startTime;
  final String endTime;
  final VoidCallback? onViewDetails;
  final String? status;

  const _JobCard({
    required this.jobId,
    required this.jobData,
    required this.title,
    required this.company,
    required this.pay,
    required this.location,
    required this.vacancies,
    this.startDate,
    required this.startTime,
    required this.endTime,
    this.onViewDetails,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width - 24;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.work, color: Color(0xFF6A11CB), size: 18),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        company,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.bookmark_border, color: Colors.grey, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildDetailChip(Icons.money, pay, maxWidth / 3.5),
                _buildDetailChip(Icons.location_on, location, maxWidth / 3.5),
                _buildDetailChip(Icons.people, '$vacancies Vacancies', maxWidth / 3.5),
                _buildDetailChip(Icons.access_time, '$startTime - $endTime', maxWidth),
                if (status != null)
                  _buildDetailChip(
                    Icons.info,
                    status!,
                    maxWidth / 3.5,
                    chipColor: status == 'Hired'
                        ? Colors.green[50]
                        : status == 'Waiting'
                        ? Colors.orange[50]
                        : Colors.grey[50],
                    textColor: status == 'Hired'
                        ? Colors.green[700]
                        : status == 'Waiting'
                        ? Colors.orange[700]
                        : Colors.grey[700],
                  ),
              ],
            ),
            if (onViewDetails != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onViewDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "View Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text, double maxWidth, {Color? chipColor, Color? textColor}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          color: chipColor ?? Colors.grey[50],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor ?? Colors.grey[700]),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                style: TextStyle(fontSize: 11, color: textColor ?? Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
