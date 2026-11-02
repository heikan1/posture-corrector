import 'dart:io';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  File? _selectedImage;
  String? _currentPhotoBase64;
  String? _googlePhotoURL;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      _nameController.text = data['displayName'] ?? '';
      _bioController.text = data['bio'] ?? '';
      _currentPhotoBase64 = data['photoBase64'];
      _googlePhotoURL = data['photoURL'];
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 256,
      maxHeight: 256,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (currentUser == null) return;

    if (_nameController.text.trim().isEmpty) {
      SmartDialog.showToast("nameCannotBeEmpty".tr());
      return;
    }

    setState(() {
      _isLoading = true;
    });
    SmartDialog.showLoading(msg: "Profil güncelleniyor...");

    try {
      String? base64String = _currentPhotoBase64;

      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        base64String = base64Encode(bytes);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
            'displayName': _nameController.text.trim(),
            'bio': _bioController.text.trim(),
            // ignore: use_null_aware_elements
            if (base64String != null) 'photoBase64': base64String,
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                "Firebase günlük kullanım kotanız dolduğundan işlem yapılamadı (Quota Exceeded).",
              );
            },
          );

      await currentUser!.updateDisplayName(_nameController.text.trim());

      SmartDialog.dismiss();
      SmartDialog.showToast("profileUpdated".tr());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast("Hata oluştu: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'editProfile'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: _isLoading && _nameController.text.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: colors.primaryContainer,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!) as ImageProvider
                                : (_currentPhotoBase64 != null &&
                                          _currentPhotoBase64!.isNotEmpty
                                      ? MemoryImage(
                                          base64Decode(_currentPhotoBase64!),
                                        )
                                      : (_googlePhotoURL != null &&
                                                _googlePhotoURL!.isNotEmpty
                                            ? NetworkImage(_googlePhotoURL!)
                                            : null)),
                            child:
                                (_selectedImage == null &&
                                    (_currentPhotoBase64 == null ||
                                        _currentPhotoBase64!.isEmpty) &&
                                    (_googlePhotoURL == null ||
                                        _googlePhotoURL!.isEmpty))
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: colors.primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.surface,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: colors.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'nameSurname'.tr(),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: colors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 150,
                    decoration: InputDecoration(
                      labelText: 'bioLabel'.tr(),
                      hintText: 'bioHint'.tr(),
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 50.0),
                        child: Icon(Icons.info_outline, color: colors.primary),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveProfile,
                      child: _isLoading
                          ? CircularProgressIndicator(color: colors.onPrimary)
                          : Text(
                              'saveChanges'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
