import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'add_worker_screen.dart';
import 'add_worker_screen.dart';
import 'add_job_screen.dart';
import 'chat/chat_list_screen.dart';
import 'chat/chat_screen.dart';
import 'chat/services/chat_service.dart';
import 'my_rentals_screen.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'subscription.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _selectedCategory = 0; // 0: Workers, 1: Jobs (changed from Cars/Bikes)
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();

  String _userName = 'User';
  String _userEmail = '';
  String _userProfileInitial = 'U';
  Position? _currentPosition;
  bool _isLocationLoading = false;
  String _locationError = '';
  String _currentCity = 'Loading...';
  String _userCity = '';

  final Color _primaryColor = const Color(0xFF667EEA);
  final Color _secondaryColor = const Color(0xFF764BA2);
  final Color _accentColor = const Color(0xFFFF6B35);
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _cardColor = Colors.white;
  final Color _textPrimary = const Color(0xFF2D3748);
  final Color _textSecondary = const Color(0xFF718096);

  bool _showFilters = false;
  String _priceFilter = 'all'; // For workers: wage filter, for jobs: pay filter
  String _experienceFilter = 'all'; // New filter for experience level
  String _categoryFilter = 'all'; // New filter for job/worker category
  String _locationFilter = 'all';

  // Cache for city coordinates
  Map<String, LatLng> _cityCoordinatesCache = {};

  @override
  void initState() {
    super.initState();
    _getUserData();
    _getCurrentLocationWithCity();
  }

  void _getUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        setState(() {
          _userName = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? user.displayName ?? 'User';
          _userEmail = (userDoc.data() as Map<String, dynamic>?)?['email'] ?? user.email ?? '';
          _userProfileInitial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _getCurrentLocationWithCity() async {
    setState(() {
      _isLocationLoading = true;
      _currentCity = 'Getting location...';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Permission denied';
            _currentCity = 'Location access denied';
            _isLocationLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Enable from settings';
          _currentCity = 'Enable location in settings';
          _isLocationLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String cityName = await _getCityNameFromCoordinates(position);

      setState(() {
        _currentPosition = position;
        _currentCity = cityName;
        _userCity = cityName.split(',').first.trim();
        _isLocationLoading = false;
        _locationError = '';
      });

      _cityCoordinatesCache[_userCity] = LatLng(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _locationError = 'Error: $e';
        _currentCity = 'Unable to get location';
        _isLocationLoading = false;
      });
    }
  }

  Future<String> _getCityNameFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String city = place.locality ?? '';
        String state = place.administrativeArea ?? '';
        return city.isNotEmpty ? '$city, $state' : 'Your City';
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return 'Current Location';
  }

  Future<LatLng?> _getCoordinatesForCity(String cityName) async {
    if (_cityCoordinatesCache.containsKey(cityName)) {
      return _cityCoordinatesCache[cityName];
    }

    try {
      List<Location> locations = await locationFromAddress(cityName);
      if (locations.isNotEmpty) {
        LatLng coordinates = LatLng(locations.first.latitude, locations.first.longitude);
        _cityCoordinatesCache[cityName] = coordinates;
        return coordinates;
      }
    } catch (e) {
      print('Error getting coordinates for $cityName: $e');
    }
    return null;
  }

  Future<double> _calculateDistanceBetweenCities(String city1, String city2) async {
    if (city1 == city2) return 0.0;

    var coords1 = await _getCoordinatesForCity(city1);
    var coords2 = await _getCoordinatesForCity(city2);

    if (coords1 != null && coords2 != null) {
      return Geolocator.distanceBetween(
        coords1.latitude,
        coords1.longitude,
        coords2.latitude,
        coords2.longitude,
      ) / 1000;
    }
    return double.infinity;
  }

  Future<String> _getOwnerMobileNumber(String ownerId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(ownerId).get();
      if (userDoc.exists) {
        String mobile = (userDoc.data() as Map<String, dynamic>)['mobile'] ?? 'Not available';
        return mobile;
      }
      return 'Not available';
    } catch (e) {
      debugPrint('Error fetching mobile: $e');
      return 'Not available';
    }
  }

  void _showCallDialog(String mobileNumber, String itemName, String ownerName) {
    showDialog(
      context: context,
      builder: (context) => _buildCallDialog(mobileNumber, itemName, ownerName),
    );
  }

  Widget _buildCallDialog(String mobileNumber, String itemName, String ownerName) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_backgroundColor, Colors.white],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.phone_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Contact Provider',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                itemName,
                style: TextStyle(
                  fontSize: 16,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              Text(
                'Provider: $ownerName',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _textSecondary.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: _textSecondary.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Mobile Number',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      mobileNumber,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: mobileNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied: $mobileNumber'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Copy Number',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: _textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _textSecondary.withOpacity(0.3)),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Number copied to clipboard',
                style: TextStyle(
                  fontSize: 12,
                  color: _textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryColor, _secondaryColor],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout, size: 50, color: Colors.white),
                const SizedBox(height: 15),
                Text('Logout?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                Text('Are you sure you want to logout?', style: TextStyle(fontSize: 16, color: Colors.white70)),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _auth.signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Logout', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_cardColor, _backgroundColor],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: _textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _selectedCategory == 0 ? 'Add Worker' : 'Add Job',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textPrimary),
              ),
              const SizedBox(height: 25),
              _buildAddOption(
                _selectedCategory == 0 ? '👨‍🔧' : '💼',
                _selectedCategory == 0 ? 'Add Worker Profile' : 'Post a Job',
                _selectedCategory == 0
                    ? 'Share your skills and availability'
                    : 'Hire workers for your needs',
                    () {
                  Navigator.pop(context);
                  if (_selectedCategory == 0) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWorkerScreen()));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddJobScreen()));
                  }
                },
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: _textSecondary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption(String emoji, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_cardColor, _backgroundColor],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _textSecondary.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: _textSecondary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_primaryColor, _secondaryColor]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: _textSecondary)),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_forward_ios, color: _primaryColor, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const ChatListScreen();
      case 2:
        return const MyRentalsScreen();
      case 3:
        return _buildPremiumProfileScreen();
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: _getCurrentScreen(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
        onPressed: _showAddOptions,
        backgroundColor: _primaryColor,
        elevation: 10,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      )
          : null,
      bottomNavigationBar: _buildPremiumBottomNavigationBar(),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        _buildPremiumLocationStatus(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPremiumHeader(),
                  const SizedBox(height: 20),
                  _buildPremiumCategorySelector(),
                  const SizedBox(height: 20),
                  _buildFilterRow(),
                  const SizedBox(height: 20),
                  if (_showFilters) _buildFilterPanel(),
                  const SizedBox(height: 20),
                  _buildItemsFromFirebase(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumLocationStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor.withOpacity(0.05), _secondaryColor.withOpacity(0.02)],
        ),
        border: Border(bottom: BorderSide(color: _textSecondary.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _currentPosition != null ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on, size: 16, color: _currentPosition != null ? Colors.green : Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _isLocationLoading
                ? Text('Getting your location...', style: TextStyle(fontSize: 14, color: _textSecondary, fontWeight: FontWeight.w500))
                : _locationError.isNotEmpty
                ? GestureDetector(
              onTap: _getCurrentLocationWithCity,
              child: Text('Tap to enable location', style: TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.w500)),
            )
                : Text('$_currentCity', style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w600)),
          ),
          if (_currentPosition != null)
            GestureDetector(
              onTap: _getCurrentLocationWithCity,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.refresh, size: 16, color: _primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedCategory == 0 ? 'Find Workers' : 'Find Jobs',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _textPrimary, height: 1.1),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedCategory == 0
                  ? 'Skilled workers for your needs'
                  : 'Daily wage jobs available',
              style: TextStyle(fontSize: 14, color: _textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => setState(() => _currentIndex = 3),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_primaryColor, _secondaryColor]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Center(
              child: Text(_userProfileInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumCategorySelector() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _textSecondary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: _textSecondary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: _selectedCategory == 0 ? LinearGradient(colors: [_primaryColor, _secondaryColor]) : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Workers',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _selectedCategory == 0 ? Colors.white : _textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: _selectedCategory == 1 ? LinearGradient(colors: [_primaryColor, _secondaryColor]) : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Jobs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _selectedCategory == 1 ? Colors.white : _textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    bool hasActiveFilters = _priceFilter != 'all' || _experienceFilter != 'all' || _categoryFilter != 'all';

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _cardColor,
              foregroundColor: _textPrimary,
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              side: BorderSide(
                color: hasActiveFilters ? _accentColor : _textSecondary.withOpacity(0.1),
                width: hasActiveFilters ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  color: hasActiveFilters ? _accentColor : _textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: hasActiveFilters ? _accentColor : _textPrimary,
                  ),
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 15),
        if (hasActiveFilters)
          GestureDetector(
            onTap: () {
              setState(() {
                _priceFilter = 'all';
                _experienceFilter = 'all';
                _categoryFilter = 'all';
                _showFilters = false;
              });
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primaryColor.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFF667EEA),
                size: 22,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _textSecondary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: _textSecondary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showFilters = false),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _textSecondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            _selectedCategory == 0 ? 'Daily Wage' : 'Pay Range',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('All', _priceFilter == 'all', () => setState(() => _priceFilter = 'all')),
              _buildFilterChip('Under ₹500', _priceFilter == 'under500', () => setState(() => _priceFilter = 'under500')),
              _buildFilterChip('₹500-₹1000', _priceFilter == '500-1000', () => setState(() => _priceFilter = '500-1000')),
              _buildFilterChip('₹1000-₹2000', _priceFilter == '1000-2000', () => setState(() => _priceFilter = '1000-2000')),
              _buildFilterChip('Above ₹2000', _priceFilter == 'above2000', () => setState(() => _priceFilter = 'above2000')),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            _selectedCategory == 0 ? 'Experience Level' : 'Job Type',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('All', _experienceFilter == 'all', () => setState(() => _experienceFilter = 'all')),
              if (_selectedCategory == 0) ...[
                _buildFilterChip('Fresher', _experienceFilter == 'fresher', () => setState(() => _experienceFilter = 'fresher')),
                _buildFilterChip('1-3 Years', _experienceFilter == '1-3', () => setState(() => _experienceFilter = '1-3')),
                _buildFilterChip('3-5 Years', _experienceFilter == '3-5', () => setState(() => _experienceFilter = '3-5')),
                _buildFilterChip('5+ Years', _experienceFilter == '5+', () => setState(() => _experienceFilter = '5+')),
              ] else ...[
                _buildFilterChip('Full Time', _experienceFilter == 'fulltime', () => setState(() => _experienceFilter = 'fulltime')),
                _buildFilterChip('Part Time', _experienceFilter == 'parttime', () => setState(() => _experienceFilter = 'parttime')),
                _buildFilterChip('Contract', _experienceFilter == 'contract', () => setState(() => _experienceFilter = 'contract')),
                _buildFilterChip('Temporary', _experienceFilter == 'temporary', () => setState(() => _experienceFilter = 'temporary')),
              ],
            ],
          ),
          const SizedBox(height: 20),

          Text(
            _selectedCategory == 0 ? 'Skill Category' : 'Job Category',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('All', _categoryFilter == 'all', () => setState(() => _categoryFilter = 'all')),
              if (_selectedCategory == 0) ...[
                _buildFilterChip('Construction', _categoryFilter == 'construction', () => setState(() => _categoryFilter = 'construction')),
                _buildFilterChip('Plumbing', _categoryFilter == 'plumbing', () => setState(() => _categoryFilter = 'plumbing')),
                _buildFilterChip('Electrician', _categoryFilter == 'electrician', () => setState(() => _categoryFilter = 'electrician')),
                _buildFilterChip('Carpentry', _categoryFilter == 'carpentry', () => setState(() => _categoryFilter = 'carpentry')),
                _buildFilterChip('Painting', _categoryFilter == 'painting', () => setState(() => _categoryFilter = 'painting')),
                _buildFilterChip('Driving', _categoryFilter == 'driving', () => setState(() => _categoryFilter = 'driving')),
                _buildFilterChip('Cleaning', _categoryFilter == 'cleaning', () => setState(() => _categoryFilter = 'cleaning')),
                _buildFilterChip('Gardening', _categoryFilter == 'gardening', () => setState(() => _categoryFilter = 'gardening')),
              ] else ...[
                _buildFilterChip('Driver', _categoryFilter == 'driver', () => setState(() => _categoryFilter = 'driver')),
                _buildFilterChip('Construction', _categoryFilter == 'construction', () => setState(() => _categoryFilter = 'construction')),
                _buildFilterChip('Household', _categoryFilter == 'household', () => setState(() => _categoryFilter = 'household')),
                _buildFilterChip('Office', _categoryFilter == 'office', () => setState(() => _categoryFilter = 'office')),
                _buildFilterChip('Event', _categoryFilter == 'event', () => setState(() => _categoryFilter = 'event')),
              ],
            ],
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _showFilters = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primaryColor : _textSecondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _primaryColor : _textSecondary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildItemsFromFirebase() {
    String collection = _selectedCategory == 0 ? 'workers' : 'jobs';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(collection)
          .where('isAvailable', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              strokeWidth: 2,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildPremiumEmptyState();
        }

        var items = snapshot.data!.docs;

        var filteredItems = items.where((doc) {
          var data = doc.data() as Map<String, dynamic>;

          int wage = int.tryParse(data['wagePerDay']?.toString() ?? '0') ?? 0;
          bool wageMatch = false;
          switch (_priceFilter) {
            case 'all':
              wageMatch = true;
              break;
            case 'under500':
              wageMatch = wage < 500;
              break;
            case '500-1000':
              wageMatch = wage >= 500 && wage <= 1000;
              break;
            case '1000-2000':
              wageMatch = wage >= 1000 && wage <= 2000;
              break;
            case 'above2000':
              wageMatch = wage > 2000;
              break;
            default:
              wageMatch = true;
          }

          bool experienceMatch = true;
          if (_experienceFilter != 'all') {
            if (_selectedCategory == 0) {
              String experience = (data['experience'] as String? ?? '').toLowerCase();
              experienceMatch = experience == _experienceFilter;
            } else {
              String jobType = (data['jobType'] as String? ?? '').toLowerCase();
              experienceMatch = jobType == _experienceFilter;
            }
          }

          bool categoryMatch = true;
          if (_categoryFilter != 'all') {
            String category = (data['category'] as String? ?? '').toLowerCase();
            categoryMatch = category == _categoryFilter;
          }

          return wageMatch && experienceMatch && categoryMatch;
        }).toList();

        if (filteredItems.isEmpty) {
          return _buildNoResultsState();
        }

        return FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _sortItemsByDistance(filteredItems),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sorting by distance...',
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildNoResultsState();
            }

            var sortedItems = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_userCity.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedCategory == 0 ? 'Workers' : 'Jobs'} in $_userCity',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedItems.length,
                  itemBuilder: (context, index) {
                    var data = sortedItems[index].data() as Map<String, dynamic>;
                    var id = sortedItems[index].id;

                    String itemCity = (data['location'] as String? ?? '').split(',').first.trim();
                    bool isLocal = _userCity.isNotEmpty &&
                        itemCity.toLowerCase() == _userCity.toLowerCase();

                    bool showDivider = false;
                    if (index > 0) {
                      var prevData = sortedItems[index - 1].data() as Map<String, dynamic>;
                      String prevCity = (prevData['location'] as String? ?? '').split(',').first.trim();
                      bool prevWasLocal = _userCity.isNotEmpty &&
                          prevCity.toLowerCase() == _userCity.toLowerCase();
                      showDivider = prevWasLocal && !isLocal;
                    }

                    return Column(
                      children: [
                        if (showDivider)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: _textSecondary.withOpacity(0.3),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'Other Cities (by distance)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: _textSecondary.withOpacity(0.3),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildItemCard(data, id, isLocal),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<QueryDocumentSnapshot>> _sortItemsByDistance(List<QueryDocumentSnapshot> items) async {
    if (_userCity.isEmpty || _currentPosition == null) {
      return items;
    }

    List<Map<String, dynamic>> itemWithDistance = [];

    for (var item in items) {
      var data = item.data() as Map<String, dynamic>;
      String itemCity = (data['location'] as String? ?? '').split(',').first.trim();

      double distance = 0;
      if (itemCity.toLowerCase() == _userCity.toLowerCase()) {
        distance = 0;
      } else {
        distance = await _calculateDistanceBetweenCities(_userCity, itemCity);
      }

      itemWithDistance.add({
        'item': item,
        'distance': distance,
        'isLocal': itemCity.toLowerCase() == _userCity.toLowerCase(),
      });
    }

    itemWithDistance.sort((a, b) {
      if (a['isLocal'] && !b['isLocal']) return -1;
      if (!a['isLocal'] && b['isLocal']) return 1;
      return (a['distance'] as double).compareTo(b['distance'] as double);
    });

    return itemWithDistance.map((e) => e['item'] as QueryDocumentSnapshot).toList();
  }

  Widget _buildItemCard(Map<String, dynamic> item, String itemId, [bool isLocal = false]) {
    String providerName = item['providerName'] ?? (_selectedCategory == 0 ? 'Worker' : 'Employer');
    String itemCity = (item['location'] as String? ?? '').split(',').first.trim();

    if (_selectedCategory == 0) {
      // Worker Card
      return GestureDetector(
        onTap: () => _showWorkerDetail(item, itemId),
        child: Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _textSecondary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
            border: Border.all(
              color: isLocal ? Colors.green.withOpacity(0.3) : _textSecondary.withOpacity(0.05),
              width: isLocal ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_primaryColor, _secondaryColor],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item['name']?.isNotEmpty == true ? item['name'][0].toUpperCase() : '👨‍🔧',
                        style: const TextStyle(fontSize: 40, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'Worker Name',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _accentColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['skills'] ?? 'No skills listed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _primaryColor.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['experience'] ?? 'Fresher'} • ${item['category'] ?? 'General'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: isLocal ? Colors.green : _accentColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                itemCity,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isLocal ? Colors.green[700] : _textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${item['wagePerDay']}/day',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_accentColor, const Color(0xFFFF8C42)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Hire Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isLocal)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Nearby',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      // Job Card
      return GestureDetector(
        onTap: () => _showJobDetail(item, itemId),
        child: Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _textSecondary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
            border: Border.all(
              color: isLocal ? Colors.green.withOpacity(0.3) : _textSecondary.withOpacity(0.05),
              width: isLocal ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_primaryColor, _secondaryColor],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item['jobTitle']?.isNotEmpty == true ? item['jobTitle'][0].toUpperCase() : '💼',
                        style: const TextStyle(fontSize: 40, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['jobTitle'] ?? 'Job Title',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _accentColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'By: ${item['employerName'] ?? 'Employer'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _primaryColor.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['jobType'] ?? 'Full Time'} • ${item['category'] ?? 'General'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: isLocal ? Colors.green : _accentColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                itemCity,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isLocal ? Colors.green[700] : _textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${item['wagePerDay']}/day',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_accentColor, const Color(0xFFFF8C42)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Apply Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isLocal)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Nearby',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildPremiumEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _selectedCategory == 0 ? '👨‍🔧' : '💼',
                style: const TextStyle(fontSize: 50),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Text(
            _selectedCategory == 0 ? 'No workers available' : 'No jobs available',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedCategory == 0
                ? 'Be the first to list your services!'
                : 'Be the first to post a job!',
            style: TextStyle(fontSize: 16, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            size: 80,
            color: _textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 20),
          Text(
            'No items match your filters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Try adjusting your filter settings',
            style: TextStyle(fontSize: 16, color: _textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _priceFilter = 'all';
                _experienceFilter = 'all';
                _categoryFilter = 'all';
                _showFilters = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: const Text(
              'Reset Filters',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showWorkerDetail(Map<String, dynamic> worker, String workerId) {
    final ownerId = worker['providerId'];
    final ownerName = worker['providerName'] ?? worker['name'] ?? 'Worker';
    final skills = worker['skills'] ?? '';
    final experience = worker['experience'] ?? 'Fresher';
    final category = worker['category'] ?? 'General';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
