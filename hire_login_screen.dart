import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'hire_dashboard_screen.dart';

class HireLoginScreen extends StatefulWidget {
  const HireLoginScreen({super.key});

  @override
  State<HireLoginScreen> createState() => _HireLoginScreenState();
}

class _HireLoginScreenState extends State<HireLoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      await FirebaseFirestore.instance.collection('employers').doc(userCredential.user!.uid).set({
        'name': googleUser.displayName ?? 'Unknown',
        'email': googleUser.email,
        'photoUrl': googleUser.photoUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'userId': userCredential.user!.uid,
      }, SetOptions(merge: true));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HireDashboardScreen(userId: userCredential.user!.uid),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -10 * _controller.value),
                    child: Icon(
                      Icons.person_add_alt_1,
                      size: 100,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              const Text(
                "Hire Top Talent",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.5, end: 0),
              const SizedBox(height: 10),
              const Text(
                "Sign in to post jobs and find employees",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 40),
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.white)
              else
                _buildGoogleButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return InkWell(
      onTap: _signInWithGoogle,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/google_image.png',
              height: 30,
            ),
            const SizedBox(width: 15),
            const Text(
              "Continue with Google",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(delay: 400.ms, duration: 500.ms).shake(hz: 3, curve: Curves.easeInOut);
  }
}
