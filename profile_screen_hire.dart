import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  Map<String, dynamic>? _employerData;
  bool _isLoading = false;
  String? _selectedIdType;
  File? _idProofImage;
  String? _idProofImageUrl;

  // ID types for dropdown
  final List<String> _idTypes = ['Aadhar Card', 'PAN Card', 'Voter ID', 'Driving License'];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('employers').doc(widget.userId).get();
      setState(() {
        _employerData = doc.data();
        _nameController.text = _employerData?['name'] ?? '';
        _emailController.text = _employerData?['email'] ?? _auth.currentUser?.email ?? '';
        _phoneController.text = _employerData?['phone'] ?? '';
        _companyNameController.text = _employerData?['company_name'] ?? '';
        _idNumberController.text = _employerData?['id_number'] ?? '';
        _selectedIdType = _employerData?['id_type'] ?? _idTypes[0];
        _idProofImageUrl = _employerData?['id_proof_image_url'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("प्रोफाइल लोड करने में त्रुटि: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _idProofImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_idProofImage == null) return null;
    try {
      final ref = _storage.ref().child('id_proofs/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}');
      await ref.putFile(_idProofImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("ID प्रूफ अपलोड करने में त्रुटि: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _companyNameController.text.isEmpty ||
        _idNumberController.text.isEmpty ||
        _selectedIdType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fill the required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final imageUrl = await _uploadImage();
      final profileData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'company_name': _companyNameController.text,
        'id_type': _selectedIdType,
        'id_number': _idNumberController.text,
        'id_proof_image_url': imageUrl ?? _idProofImageUrl,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('employers').doc(widget.userId).set(
        profileData,
        SetOptions(merge: true),
      );

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your Profile has been updated"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("प्रोफाइल सहेजने में त्रुटि: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'प्रोफाइल संपादित करें',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'email',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'phone',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _companyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Name of the company',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedIdType,
                    decoration: const InputDecoration(
                      labelText: 'ID Type',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: Colors.deepPurple,
                    items: _idTypes.map((String idType) {
                      return DropdownMenuItem<String>(
                        value: idType,
                        child: Text(idType, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedIdType = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _idNumberController,
                    decoration: const InputDecoration(
                      labelText: 'ID number*',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _pickImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Upload your ID proof',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_idProofImage != null)
                    Image.file(
                      _idProofImage!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    )
                  else if (_idProofImageUrl != null)
                    Image.network(
                      _idProofImageUrl!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Update Profile',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
