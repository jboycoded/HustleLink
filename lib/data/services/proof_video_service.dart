import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class ProofVideoService {
  ProofVideoService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('You must be signed in.');
    return uid;
  }

  Future<String?> pickAndUpload(ImageSource source) async {
    final selected = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 30),
    );
    if (selected == null) return null;

    final file = File(selected.path);
    final fileSize = await file.length();
    if (fileSize > 50 * 1024 * 1024) {
      throw StateError('The video must be smaller than 50 MB.');
    }

    final controller = VideoPlayerController.file(file);
    Duration duration;
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

    final reference =
        _storage.ref().child('workerProofVideos/$_uid/profileVideo');
    await reference.putFile(
      file,
      SettableMetadata(contentType: contentType),
    );
    return reference.getDownloadURL();
  }

  Future<void> deleteProfileVideo() async {
    final reference =
        _storage.ref().child('workerProofVideos/$_uid/profileVideo');
    try {
      await reference.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}
