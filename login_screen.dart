import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _showWorkAnimation = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeftWithFade,
        duration: const Duration(milliseconds: 800),
        // child: const HomeScreen(),
      ),
          (route) => false,
    );
  }

  // 🔥 GOOGLE SIGN-IN UPDATED
  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);

      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await _auth.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        final doc =
        await _firestore.collection('users').doc(user.uid).get();

        if (!doc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': user.displayName ?? 'User',
            'email': user.email ?? '',
            'phone': user.phoneNumber ?? '',
            'photoURL': user.photoURL,
            'role': 'both', // 🔥 single system
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await _startWorkAnimation();
      }
    } catch (e) {
      _showErrorDialog("Login failed: $e");
      setState(() => _isLoading = false);
    }
  }

  // 🔥 NEW ANIMATION (Worker style instead of car)
  Future<void> _startWorkAnimation() async {
    setState(() {
      _showWorkAnimation = true;
    });

    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) _navigateToHome();
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showWorkAnimation
          ? _buildWorkAnimation()
          : Stack(
        children: [
          // 🔥 GREEN GRADIENT
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF16A34A),
                  Color(0xFF22C55E),
                ],
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white),
                      ),

                      const Spacer(),

                      // 🔥 TITLE UPDATED
                      const Text(
                        'Welcome to\nRozgarSaathi',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Find daily work or hire workers instantly near you.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 70),

                      _buildGoogleButton(),

                      const SizedBox(height: 20),

                      Text(
                        'No middleman. No commission.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🔥 BUTTON SAME BUT CLEAN
  Widget _buildGoogleButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _signInWithGoogle,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🅶', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Text(
            'Continue with Google',
            style: TextStyle(fontSize: 17),
          ),
        ],
      ),
    );
  }

  // 🔥 WORKER ANIMATION
  Widget _buildWorkAnimation() {
    return Container(
      color: const Color(0xFFF0FDF4),
      child: Stack(
        children: [
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              color: Colors.grey.shade400,
            ),
          ),

          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 2000),
            tween: Tween<double>(begin: -100, end: 500),
            builder: (context, value, child) {
              return Positioned(
                left: value,
                bottom: 80,
                child: const Icon(
                  Icons.work,
                  size: 70,
                  color: Color(0xFF16A34A),
                ),
              );
            },
          ),

          const Positioned(
            bottom: 200,
            left: 0,
            right: 0,
            child: Text(
              'Connecting you to work...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16A34A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
