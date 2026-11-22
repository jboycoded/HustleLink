import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:tus_client/tus_client.dart';

import '../../core/config/supabase_config.dart';

class ProofVideoService {
  ProofVideoService({
    FirebaseAuth? auth,
    ImagePicker? picker,
    SupabaseClient? supabase,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _picker = picker ?? ImagePicker(),
        _supabase = supabase;

  static const String _bucket = SupabaseConfig.bucketName;

  final FirebaseAuth _auth;
  final ImagePicker _picker;
  final SupabaseClient? _supabase;
  final TusMemoryStore _uploadStore = TusMemoryStore();

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured && _supabase == null) {
      throw StateError(
        'Profile video storage has not been configured for this build.',
      );
    }
    return _supabase ?? Supabase.instance.client;
  }

  Future<Map<String, dynamic>> _invokeFunction(String action) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Unable to obtain your sign-in token. Please sign in again.',
      );
    }

    final response = await _client.functions.invoke(
      'proof-video',
      headers: {'Authorization': 'Bearer $idToken'},
      body: {'action': action},
    );

    final data = response.data;
    if (data is! Map) {
      throw StateError('The video service returned an invalid response.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<String?> pickAndUpload(ImageSource source) async {
    final selected = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 30),
    );
    if (selected == null) return null;

    final file = File(selected.path);
    final fileSize = await file.length();
    if (fileSize > 50 * 1000 * 1000) {
      throw StateError('The video must be smaller than 50 MB.');
    }

    final controller = VideoPlayerController.file(file);
    late final Duration duration;
    try {
      await controller.initialize();
      duration = controller.value.duration;
    } finally {
      await controller.dispose();
    }

    if (duration <= Duration.zero) {
      throw StateError('The selected video could not be read.');
    }
    if (duration > const Duration(seconds: 30)) {
      throw StateError('Your profile video must be 30 seconds or shorter.');
    }

    final extension = selected.path.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'mov' => 'video/quicktime',
      '3gp' => 'video/3gpp',
      'webm' => 'video/webm',
      _ => 'video/mp4',
    };

    final permission = await _invokeFunction('create-upload');
    final path = permission['path'] as String?;
    final token = permission['token'] as String?;
    if (path == null || token == null) {
      throw StateError('The video service did not provide upload permission.');
    }

    final projectUri = Uri.parse(SupabaseConfig.url);
    final storageHost = projectUri.host.replaceFirst(
      '.supabase.co',
      '.storage.supabase.co',
    );
    final tusClient = TusClient(
      Uri.https(storageHost, '/storage/v1/upload/resumable'),
      selected,
      headers: {
        'apikey': SupabaseConfig.anonKey,
        'x-signature': token,
        'x-upsert': 'true',
      },
      metadata: {
        'bucketName': _bucket,
        'objectName': path,
        'contentType': contentType,
      },
      maxChunkSize: 6 * 1024 * 1024,
      store: _uploadStore,
    );

    await tusClient.upload();

    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> deleteProfileVideo() async {
    // The server derives the storage path from the verified Firebase UID.
    // No client-supplied path is accepted by the Edge Function.
    await _invokeFunction('delete');
  }
}
