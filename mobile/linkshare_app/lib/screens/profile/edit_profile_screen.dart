import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/profile.dart';
import '../../providers/service_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final Profile profile;

  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String? _currentProfilePictureUrl;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.profile.displayName);
    _bioController = TextEditingController(text: widget.profile.bio);
    _currentProfilePictureUrl = widget.profile.profilePictureUrl;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      // Show options: Camera or Gallery
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Pick image
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      // Upload to server
      final profileService = ref.read(profileServiceProvider);
      final updatedProfile = await profileService.uploadProfilePicture(
        File(pickedFile.path),
      );

      if (mounted) {
        setState(() {
          _currentProfilePictureUrl = updatedProfile.profilePictureUrl;
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteProfilePicture() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final profileService = ref.read(profileServiceProvider);
      final updatedProfile = await profileService.deleteProfilePicture();

      if (mounted) {
        setState(() {
          _currentProfilePictureUrl = updatedProfile.profilePictureUrl;
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profileService = ref.read(profileServiceProvider);
      await profileService.updateMyProfile(
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blue,
                    child: _isUploadingPhoto
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _currentProfilePictureUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  _currentProfilePictureUrl!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      widget.profile.displayName.isNotEmpty
                                          ? widget.profile.displayName[0].toUpperCase()
                                          : widget.profile.username[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 48,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Text(
                                widget.profile.displayName.isNotEmpty
                                    ? widget.profile.displayName[0].toUpperCase()
                                    : widget.profile.username[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 48,
                                  color: Colors.white,
                                ),
                              ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: PopupMenuButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'change',
                            child: Row(
                              children: [
                                Icon(Icons.photo_library),
                                SizedBox(width: 8),
                                Text('Change Photo'),
                              ],
                            ),
                          ),
                          if (_currentProfilePictureUrl != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete Photo', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                        ],
                        onSelected: (value) {
                          if (value == 'change') {
                            _pickAndUploadImage();
                          } else if (value == 'delete') {
                            _deleteProfilePicture();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a display name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info_outline),
                hintText: 'Tell us about yourself...',
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Username',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${widget.profile.username}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Username cannot be changed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
