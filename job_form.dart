import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class JobForm extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic> jobData) onSubmit;
  final bool isEditing;

  const JobForm({
    super.key,
    this.initialData,
    required this.onSubmit,
    required this.isEditing,
  });

  @override
  State<JobForm> createState() => _JobFormState();
}

class _JobFormState extends State<JobForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _payController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _employeesRequiredController = TextEditingController();
  String? _totalPay;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedGender;
  List<String> _skills = [];
  List<DateTime> _selectedDays = [];
  bool _isLoadingLocation = false;
  double? _locationLat;
  double? _locationLong;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    // Listener for manual location typing to geocode
    _locationController.addListener(() {
      if (_locationController.text.isNotEmpty) {
        _geocodeAddress(_locationController.text);
      }
    });
  }

  void _initializeForm() {
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _locationController.text = data['location'] ?? '';
      _payController.text = data['pay']?.toString() ?? '';
      _companyNameController.text = data['company_name'] ?? '';
      _employeesRequiredController.text = data['employees_required']?.toString() ?? '';
      _totalPay = data['total_pay']?.toString();

      // Set lat/long from existing data
      _locationLat = data['location_lat']?.toDouble();
      _locationLong = data['location_long']?.toDouble();

      if (data['skills'] != null) {
        _skills = List<String>.from(data['skills']);
      }

      _selectedGender = data['gender_preference'] ?? 'Both';

      if (data['start_date'] != null) {
        _startDate = data['start_date'] is Timestamp
            ? data['start_date'].toDate()
            : data['start_date'] as DateTime;
      }

      if (data['end_date'] != null) {
        _endDate = data['end_date'] is Timestamp
            ? data['end_date'].toDate()
            : data['end_date'] as DateTime;
      }

      if (data['selected_days'] != null) {
        _selectedDays = (data['selected_days'] as List<dynamic>)
            .map((d) => d is Timestamp ? d.toDate() : d as DateTime)
            .toList();
      }

      if (_selectedDays.isEmpty && _startDate != null && _endDate != null) {
        _selectedDays = _getDaysInRange();
      }

      if (data['start_time'] != null) {
        final parts = data['start_time'].toString().split(':');
        if (parts.length >= 2) {
          _startTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1].split(' ')[0]),
          );
        }
      }

      if (data['end_time'] != null) {
        final parts = data['end_time'].toString().split(':');
        if (parts.length >= 2) {
          _endTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1].split(' ')[0]),
          );
        }
      }
    } else {
      _selectedGender = 'Both';
    }
  }

  List<DateTime> _getDaysInRange() {
    List<DateTime> days = [];
    if (_startDate != null && _endDate != null && !_endDate!.isBefore(_startDate!)) {
      for (DateTime d = _startDate!;
      d.isBefore(_endDate!) || d.isAtSameMomentAs(_endDate!);
      d = d.add(const Duration(days: 1))) {
        days.add(d);
      }
    }
    return days;
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location services are disabled. Please enable them."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Location permissions are denied."),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Location permissions are permanently denied. Please enable them in app settings.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _locationController.text = [
            place.street,
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((part) => part != null && part.isNotEmpty).join(', ');
          _locationLat = position.latitude;
          _locationLong = position.longitude;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not retrieve location."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error getting location: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  // Geocode manual address to lat/long
  Future<void> _geocodeAddress(String address) async {
    if (address.isEmpty) return;
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          _locationLat = locations.first.latitude;
          _locationLong = locations.first.longitude;
        });
      }
    } catch (e) {
      print('Geocoding error: $e');
      // Optional: Show snackbar if needed
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          if (_startDate == null || !picked.isBefore(_startDate!)) {
            _endDate = picked;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("End date cannot be before start date"),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
        if (_startDate != null && _endDate != null && _selectedDays.isEmpty) {
          _selectedDays = _getDaysInRange();
        } else if (_startDate != null && _endDate != null) {
          _selectedDays = _selectedDays
              .where((day) => !day.isBefore(_startDate!) && !day.isAfter(_endDate!))
              .toList();
        }
        _calculateTotalPay();
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime ?? TimeOfDay.now() : _endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _addSkill() {
    final skill = _skillsController.text.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() {
        _skills.add(skill);
        _skillsController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  void _calculateTotalPay() {
    final pay = double.tryParse(_payController.text);
    final employees = int.tryParse(_employeesRequiredController.text);
    if (pay != null && employees != null && _selectedDays.isNotEmpty) {
      final days = _selectedDays.length;
      setState(() {
        _totalPay = (pay * employees * days).toStringAsFixed(2);
      });
    } else {
      setState(() {
        _totalPay = null;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null || _selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select date range and specific days"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      // Validate location coords
      if (_locationLat == null || _locationLong == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select or enter a valid location to get coordinates."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      _calculateTotalPay();
      final jobData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'location_lat': _locationLat, // Added
        'location_long': _locationLong, // Added
        'pay': double.parse(_payController.text.trim()),
        'company_name': _companyNameController.text.trim(),
        'employees_required': int.parse(_employeesRequiredController.text),
        'skills': _skills,
        'gender_preference': _selectedGender,
        'start_date': Timestamp.fromDate(_startDate!),
        'end_date': Timestamp.fromDate(_endDate!),
        'start_time': _startTime != null ? '${_startTime!.hour}:${_startTime!.minute}' : null,
        'end_time': _endTime != null ? '${_endTime!.hour}:${_endTime!.minute}' : null,
        'total_pay': double.tryParse(_totalPay ?? '0') ?? 0,
        'selected_days': _selectedDays.map((d) => Timestamp.fromDate(d)).toList(),
      };

      widget.onSubmit(jobData);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _payController.dispose();
    _skillsController.dispose();
    _companyNameController.dispose();
    _employeesRequiredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? 'Edit Job' : 'Post a New Job',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyNameController,
                  decoration: InputDecoration(
                    labelText: 'Company Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the company name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Job Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the job title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Job Description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the job description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the location';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isLoadingLocation
                        ? const CircularProgressIndicator()
                        : IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.deepPurple),
                      onPressed: _getCurrentLocation,
                    ),
                  ],
                ),
                // Optional: Show coords below location (for debug)
                if (_locationLat != null && _locationLong != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Coords: Lat ${_locationLat!.toStringAsFixed(4)}, Long ${_locationLong!.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _payController,
                  decoration: InputDecoration(
                    labelText: 'Daily Pay (₹)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the daily pay';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Please enter a valid pay amount';
                    }
                    return null;
                  },
                  onChanged: (value) => _calculateTotalPay(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _employeesRequiredController,
                  decoration: InputDecoration(
                    labelText: 'Number of Employees Required',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the number of employees';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                  onChanged: (value) => _calculateTotalPay(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _skillsController,
                        decoration: InputDecoration(
                          labelText: 'Add Skill (e.g., Carpentry)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onFieldSubmitted: (value) => _addSkill(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addSkill,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                if (_skills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _skills.map((skill) {
                      return Chip(
                        label: Text(skill),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => _removeSkill(skill),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(
                    labelText: 'Gender Preference',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: ['Male', 'Female', 'Both'].map((gender) {
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a gender preference';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _startDate != null
                                ? DateFormat.yMMMd().format(_startDate!)
                                : 'Select Start Date',
                            style: TextStyle(
                              color: _startDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _endDate != null
                                ? DateFormat.yMMMd().format(_endDate!)
                                : 'Select End Date',
                            style: TextStyle(
                              color: _endDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_startDate != null && _endDate != null && !_endDate!.isBefore(_startDate!)) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Select specific days within the range (${_selectedDays.length} days selected):',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: _getDaysInRange().length,
                      itemBuilder: (context, index) {
                        final DateTime day = _getDaysInRange()[index];
                        final bool isSelected = _selectedDays.contains(day);
                        return CheckboxListTile(
                          title: Text(DateFormat('MMM d, EEEE').format(day)),
                          subtitle: day.day == 2 && day.month == 10 && day.year == 2025
                              ? const Text('(Dussehra)', style: TextStyle(fontSize: 12, color: Colors.orange))
                              : null,
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                if (!_selectedDays.contains(day)) {
                                  _selectedDays.add(day);
                                }
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                            _calculateTotalPay();
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Start Time',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _startTime != null
                                ? _startTime!.format(context)
                                : 'Select Start Time',
                            style: TextStyle(
                              color: _startTime != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'End Time',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _endTime != null
                                ? _endTime!.format(context)
                                : 'Select End Time',
                            style: TextStyle(
                              color: _endTime != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_totalPay != null)
                  Text(
                    'Total Pay: ₹$_totalPay',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.isEditing ? 'Update Job' : 'Post Job',
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
        ),
      ),
    );
  }
}
