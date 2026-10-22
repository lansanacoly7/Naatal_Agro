import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceService {
  VoiceService() {
    _initTts();
  }

  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();

  bool _isRecording = false;
  bool _isSpeaking = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;
  bool get isSpeaking => _isSpeaking;

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((dynamic msg) {
        _isSpeaking = false;
      });
    } catch (e) {
      debugPrint('[VoiceService] Erreur initialisation TTS: $e');
    }
  }

  /// Vérifie si l'application a la permission d'enregistrer avec le micro.
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Démarre l'enregistrement audio depuis le microphone physique.
  Future<bool> startRecording() async {
    try {
      if (_isRecording) return true;
      final hasPerm = await hasPermission();
      if (!hasPerm) return false;

      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath = '${tempDir.path}/naatal_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      );

      await _recorder.start(config, path: _currentRecordingPath!);
      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('[VoiceService] Échec démarrage enregistrement: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Arrête l'enregistrement audio et renvoie les octets réels du fichier micro.
  Future<Uint8List?> stopRecording() async {
    try {
      if (!_isRecording) return null;
      final path = await _recorder.stop();
      _isRecording = false;

      final effectivePath = path ?? _currentRecordingPath;
      if (effectivePath == null) return null;

      final file = File(effectivePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        try {
          await file.delete();
        } catch (_) {}
        return bytes;
      }
      return null;
    } catch (e) {
      debugPrint('[VoiceService] Échec arrêt enregistrement: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Lit à haute voix le texte donné via le moteur de synthèse vocale.
  Future<void> speak(String text, {String lang = 'fr-FR'}) async {
    try {
      if (text.trim().isEmpty) return;
      await stopSpeaking();
      await _tts.setLanguage(lang);
      _isSpeaking = true;
      // Nettoyer les balises Markdown et URL pour une diction fluide
      final clean = text
          .replaceAll(RegExp(r'[*_#`\[\]]'), ' ')
          .replaceAll(RegExp(r'https?://\S+'), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      await _tts.speak(clean);
    } catch (e) {
      debugPrint('[VoiceService] Échec lecture vocale: $e');
      _isSpeaking = false;
    }
  }

  /// Interrompt immédiatement toute lecture audio en cours.
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (_) {}
  }

  void dispose() {
    _recorder.dispose();
    _tts.stop();
  }
}

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});
