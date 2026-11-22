import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class ProfilePhotoService {
  ProfilePhotoService({
    FirebaseAuth? auth,
    ImagePicker? picker,
    SupabaseClient? supabase,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _picker = picker ?? ImagePicker(),
        _supabase = supabase;

  final FirebaseAuth _auth;
  final ImagePicker _picker;
  final SupabaseClient? _supabase;

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured && _supabase == null) {
      throw StateError('Profile photo storage is not configured.');
    }
    return _supabase ?? Supabase.instance.client;
  }

  Future<Map<String, dynamic>> _invoke(String action) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Unable to verify your account. Please sign in again.');
    }
    final response = await _client.functions.invoke(
      'proof-video',
      headers: {'Authorization': 'Bearer $token'},
      body: {'action': action},
    );
    if (response.data is! Map) {
      throw StateError('The photo service returned an invalid response.');
    }
    return Map<String, dynamic>.from(response.data);
  }

  Future<String?> pickAndUpload() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (selected == null) return null;
    final file = File(selected.path);
    if (await file.length() > 8 * 1000 * 1000) {
      throw StateError('Choose an image smaller than 8 MB.');
    }
    final extension = selected.path.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final permission = await _invoke('create-profile-photo-upload');
    final path = permission['path'] as String?;
    final token = permission['token'] as String?;
    if (path == null || token == null) {
      throw StateError('The photo service did not provide upload permission.');
    }
    await _client.storage
        .from(SupabaseConfig.profilePhotoBucketName)
        .uploadToSignedUrl(
          path,
          token,
          file,
          FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage
        .from(SupabaseConfig.profilePhotoBucketName)
        .getPublicUrl(path);
  }

  Future<void> deletePhoto() async {
    await _invoke('delete-profile-photo');
  }
}
