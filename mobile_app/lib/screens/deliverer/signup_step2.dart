import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'signup_step3.dart';
import 'package:file_picker/file_picker.dart';
import '../../api/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class DelivererSignupStep2 extends StatefulWidget {
  const DelivererSignupStep2({Key? key}) : super(key: key);

  @override
  State<DelivererSignupStep2> createState() => _DelivererSignupStep2State();
}

class _DelivererSignupStep2State extends State<DelivererSignupStep2> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedVehicle;
  String? _selectedZone;

  // Photo for both mobile/desktop and web
  String? _photoLocalPath;
  Uint8List? _photoBytes;
  String? _photoFileName;

  String? _error;
  bool _loading = false;

  final List<String> _vehicles = [
    'Car',
    'Motorcycle',
    'Bicycle',
    'Electric Scooter',
  ];
  final List<String> _zones = [
    'Tunis Centre',
    'Ariana',
    'La Marsa',
    'Carthage',
    'Gammarth',
    'Le Kram',
    'La Goulette',
    'Le Bardo',
    'Manouba',
    'El Menzah',
    'Ennasr',
    'Lac 1',
    'Lac 2',
    'Charguia',
    'Ben Arous',
    'Ezzahra',
    'Rades',
    'Hammam Lif',
    'Hammam Chatt',
    'Nabeul',
    'Hammamet',
    'Sousse',
    'Kairouan',
    'Sfax',
    'Gabes',
    'Djerba',
    'Bizerte',
    'Kef',
    'Monastir',
    'Mahdia',
    'Jandouba',
    'Zarzis',
    'Tozeur',
    'Kasserine',
    'Beja',
    'Siliana',
    'Gafsa',
    'Sidi Bouzid',
    // Add/edit as needed!
  ];

  Future<void> _pickPhoto() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) {
      if (kIsWeb) {
        setState(() {
          _photoLocalPath = null;
          _photoBytes = result.files.single.bytes;
          _photoFileName = result.files.single.name;
        });
        print(
          "Web picked photo: $_photoFileName, ${_photoBytes?.length ?? 0} bytes",
        );
      } else {
        setState(() {
          _photoLocalPath = result.files.single.path;
          _photoBytes = null;
          _photoFileName = result.files.single.name;
        });
        print("Mobile picked photo: $_photoLocalPath");
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  Future<void> _onContinue() async {
    if (_formKey.currentState?.validate() == true &&
        _selectedVehicle != null &&
        _selectedZone != null) {
      setState(() {
        _loading = true;
        _error = null;
      });
      String? photoUrl;
      try {
        if (_photoLocalPath != null || _photoBytes != null) {
          final prefs = await SharedPreferences.getInstance();
          final jwt = prefs.getString('jwt');
          if (jwt == null) throw "Not logged in.";
          final res = await ApiService.uploadFile(
            'livreur/onboarding/upload/photo',
            'file',
            _photoLocalPath ?? '',
            path: _photoLocalPath,
            bytes: _photoBytes,
            fileName: _photoFileName,
            headers: {'Authorization': 'Bearer $jwt'},
          );
          if (res['message'] != null &&
              res['message'].toString().toLowerCase().contains(
                'unsupported file type',
              )) {
            setState(() {
              _error = "Not supported file type. Allowed: jpg, jpeg, png, pdf.";
            });
            return;
          }
          photoUrl = res['photoUrl'] ?? res['url'];
        }
        final prefs = await SharedPreferences.getInstance();
        final jwt = prefs.getString('jwt');
        if (jwt == null) throw "Not logged in.";

        // Build your payload
        final body = {
          "fullName": _fullNameController.text.trim(),
          "phone": _phoneController.text.trim(),
          "zone": _selectedZone,
          "vehicleType": _selectedVehicle,
          if (photoUrl != null) "photoUrl": photoUrl,
        };

        // PATCH call to backend to save info:
        await ApiService.patch(
          'livreur/onboarding/profile',
          {
            "fullName": _fullNameController.text.trim(),
            "phone": _phoneController.text.trim(),
            "zone": _selectedZone,
            "vehicleType": _selectedVehicle,
          },
          headers: {'Authorization': 'Bearer $jwt'},
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DelivererSignupStep3(
              fullName: _fullNameController.text.trim(),
              phone: _phoneController.text.trim(),
              vehicleType: _selectedVehicle!,
              zone: _selectedZone!,
              photoUrl: photoUrl,
            ),
          ),
        );
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        setState(() {
          _error = errorStr.contains('unsupported file type')
              ? "Not supported file type. Allowed: jpg, jpeg, png, pdf."
              : "Photo upload failed: $e";
        });
      } finally {
        setState(() {
          _loading = false;
        });
      }
    } else {
      setState(() {
        _error = "Please fill all fields.";
      });
    }
  }

  String get _photoDisplayName {
    if (_photoLocalPath != null) {
      return _photoLocalPath!.split('/').last;
    }
    if (_photoFileName != null) {
      return _photoFileName!;
    }
    return 'Upload Your Photo (Optional)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 180,
                      height: 90,
                      errorBuilder: (context, error, stack) =>
                          const Icon(Icons.fastfood, size: 64),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      "Step 2 of 4",
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      "Personal & Vehicle Info",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3D9176), Color(0xFF2D8066)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      "Tell us about yourself and your vehicle",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.photo_camera),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _photoDisplayName,
                              style: TextStyle(
                                color:
                                    (_photoLocalPath != null ||
                                        _photoFileName != null)
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          const Icon(Icons.upload_outlined),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12, top: 2),
                    child: Text(
                      "Allowed formats: jpg, jpeg, png, pdf",
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Phone",
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),

                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedVehicle,
                    items: _vehicles
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedVehicle = v),
                    decoration: const InputDecoration(
                      labelText: "Vehicle Type",
                      prefixIcon: Icon(Icons.directions_car),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedZone,
                    items: _zones
                        .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedZone = v),
                    decoration: const InputDecoration(
                      labelText: "Preferred Zone",
                      prefixIcon: Icon(Icons.map),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F9D7A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Continue"),
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
