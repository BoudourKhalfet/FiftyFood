import 'package:flutter/material.dart';
import '../../api/auth_storage.dart';
import '../../api/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PartnerProfileTab extends StatefulWidget {
  const PartnerProfileTab({Key? key}) : super(key: key);

  @override
  State<PartnerProfileTab> createState() => _PartnerProfileTabState();
}

class _PartnerProfileTabState extends State<PartnerProfileTab> {
  String restaurantName = "";
  String email = "";
  String phone = "";
  String address = "";
  String? businessRegistrationUrl;
  String? hygieneCertificateUrl;
  String? ownershipProofUrl;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => loading = true);
    try {
      final token = await getJwt();
      final profileResp = await ApiService.get(
        'auth/me',
        headers: {'Authorization': 'Bearer $token'},
      );
      final rest = profileResp['restaurantProfile'] ?? {};
      setState(() {
        restaurantName = rest['restaurantName'] ?? '';
        email = profileResp['email'] ?? '';
        phone = rest['phone'] ?? '';
        address = rest['address'] ?? '';
        businessRegistrationUrl = rest['businessRegistrationDocumentUrl'];
        hygieneCertificateUrl = rest['hygieneCertificateUrl'];
        ownershipProofUrl = rest['proofOfOwnershipOrLeaseUrl'];
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  void _viewLegalDoc(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch document!')));
    }
  }

  List<Map<String, dynamic>> get legalDocsDynamic => [
    {
      'name': 'Business Registration',
      'status': businessRegistrationUrl != null ? 'Verified' : 'Missing',
      'url': businessRegistrationUrl,
    },
    {
      'name': 'Hygiene Certificate',
      'status': hygieneCertificateUrl != null ? 'Verified' : 'Missing',
      'url': hygieneCertificateUrl,
    },
    {
      'name': 'Ownership/Rental Proof',
      'status': ownershipProofUrl != null ? 'Verified' : 'Missing',
      'url': ownershipProofUrl,
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Restaurant Profile',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 14),

          // -- Restaurant Info Card with Edit Button --
          _ProfileCard(
            icon: Icons.restaurant_menu,
            iconColor: Colors.teal,
            title: "Restaurant Information",
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.edit, size: 18, color: Colors.white),
              label: const Text(
                "Edit Profile",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF26C281),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () => _showEditProfileDialog(context),
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileField(label: "Restaurant Name", value: restaurantName),
                _ProfileField(label: "Email", value: email),
                _ProfileField(label: "Phone", value: phone),
                _ProfileField(label: "Address", value: address),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // -- Legal Documents Card --
          _ProfileCard(
            icon: Icons.description,
            iconColor: Colors.teal,
            title: "Legal Documents",
            content: Column(
              children: legalDocsDynamic.map((doc) {
                final hasUrl =
                    doc['url'] != null && doc['url'].toString().isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: doc['status'] == 'Verified'
                                  ? const Color(0xFF26C281)
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              doc['status'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            doc['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (hasUrl)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                            ),
                            child: OutlinedButton(
                              onPressed: () => _viewLegalDoc(doc['url']),
                              child: const Text("View"),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // -- Trust Score Card --
          _ProfileCard(
            icon: Icons.star,
            iconColor: const Color(0xFFFFB300),
            title: "Trust Score",
            content: Row(
              children: [
                Container(
                  width: 50,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    '0.0', // Replace with real trust score if available
                    style: TextStyle(
                      color: Color(0xFF1F9254),
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                const Expanded(
                  child: Text(
                    "Your trust score is based on document verification, customer ratings, and platform compliance.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // -- Change Password Card --
          _ProfileCard(
            icon: Icons.lock_outline_rounded,
            iconColor: Colors.teal,
            title: "Change Password",
            content: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 19, color: Colors.teal),
                label: const Text(
                  "Change Password",
                  style: TextStyle(color: Colors.teal),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(155, 42),
                  side: const BorderSide(color: Colors.teal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showChangePasswordDialog(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- EDIT PROFILE DIALOG -----
  void _showEditProfileDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: restaurantName);
    final emailCtrl = TextEditingController(text: email);
    final phoneCtrl = TextEditingController(text: phone);
    final addressCtrl = TextEditingController(text: address);
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Edit Profile"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Restaurant Name",
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "Email"),
                  enabled: false,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: "Phone"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: "Address"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final address = addressCtrl.text.trim();
                      if (name.isEmpty || phone.isEmpty || address.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Fields cannot be empty!"),
                          ),
                        );
                        return;
                      }
                      setStateDialog(() => saving = true);
                      try {
                        final token = await getJwt();
                        await ApiService.patch(
                          'restaurant/onboarding/identity',
                          {
                            'restaurantName': name,
                            'phone': phone,
                            'address': address,
                          },
                          headers: {'Authorization': 'Bearer $token'},
                        );
                        setState(() {
                          restaurantName = name;
                          this.phone = phone;
                          this.address = address;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Profile updated!")),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Profile update failed: $e")),
                        );
                      } finally {
                        setStateDialog(() => saving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF26C281),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- CHANGE PASSWORD DIALOG -----
  void _showChangePasswordDialog(BuildContext context) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool saving = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPassCtrl,
                  decoration: const InputDecoration(
                    labelText: "Current Password",
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: newPassCtrl,
                  decoration: const InputDecoration(labelText: "New Password"),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmPassCtrl,
                  decoration: const InputDecoration(
                    labelText: "Confirm New Password",
                  ),
                  obscureText: true,
                ),

                if (errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMsg!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setStateDialog(() => errorMsg = null);

                      final oldPass = oldPassCtrl.text.trim();
                      final newPass = newPassCtrl.text.trim();
                      final confirmPass = confirmPassCtrl.text.trim();

                      if (oldPass.isEmpty ||
                          newPass.isEmpty ||
                          confirmPass.isEmpty) {
                        setStateDialog(
                          () => errorMsg = "All fields are required!",
                        );
                        return;
                      }

                      if (newPass != confirmPass) {
                        setStateDialog(
                          () => errorMsg = "New passwords do not match!",
                        );
                        return;
                      }

                      setStateDialog(() => saving = true);

                      try {
                        final token = await getJwt();

                        await ApiService.patch(
                          'auth/change-password',
                          {'oldPassword': oldPass, 'newPassword': newPass},
                          headers: {'Authorization': 'Bearer $token'},
                        );

                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Password changed successfully!"),
                          ),
                        );
                      } catch (e) {
                        setStateDialog(() {
                          errorMsg = e.toString().replaceFirst(
                            "Exception: ",
                            "",
                          );
                        });
                      } finally {
                        setStateDialog(() => saving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Change Password',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget content;
  final Widget? trailing;

  const _ProfileCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: 6),
                  Flexible(child: trailing!),
                ],
              ],
            ),
            const SizedBox(height: 20),
            content,
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(value, style: const TextStyle(fontSize: 15.5)),
          ),
        ],
      ),
    );
  }
}
