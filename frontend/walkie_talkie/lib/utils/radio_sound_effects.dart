import 'dart:math';
import 'dart:typed_data';

/// Generates authentic, tactical Walkie-Talkie radio tones in raw PCM16 16kHz mono.
/// 1. Opening Key-Up Chirp: Ascending dual-tone played right as an incoming voice starts.
/// 2. Ending Roger Beep & Squelch: Classic end-of-transmission beep with subtle static squelch tail.
class RadioSoundEffects {
  static const int sampleRate = 16000;

  // Cached pre-generated PCM16 buffers to eliminate latency
  static Uint8List? _cachedStartChirp;
  static Uint8List? _cachedEndRogerBeep;

  /// Classic Walkie-Talkie Opening Tone / Talk-Permit Chirp
  /// Ascending 2-tone frequency burst: ~900 Hz -> ~1250 Hz (total duration: ~105ms)
  static Uint8List generateStartChirp() {
    if (_cachedStartChirp != null) return _cachedStartChirp!;

    final samples = <int>[];

    // Tone 1: 900 Hz for 45ms
    _appendTone(
      samples: samples,
      frequency: 900.0,
      durationMs: 45,
      volume: 0.38,
      fadeInMs: 4,
      fadeOutMs: 4,
    );

    // Tone 2: 1250 Hz for 60ms
    _appendTone(
      samples: samples,
      frequency: 1250.0,
      durationMs: 60,
      volume: 0.42,
      fadeInMs: 4,
      fadeOutMs: 12,
    );

    _cachedStartChirp = _samplesToPcm16(samples);
    return _cachedStartChirp!;
  }

  /// Classic Roger Beep + Squelch Tail ("BEEP - ksh")
  /// 1. Crisp 1180 Hz tone (65ms)
  /// 2. Brief pause (10ms)
  /// 3. Soft squelch static burst (40ms)
  static Uint8List generateEndRogerBeep() {
    if (_cachedEndRogerBeep != null) return _cachedEndRogerBeep!;

    final samples = <int>[];

    // Roger Beep: 1180 Hz for 65ms
    _appendTone(
      samples: samples,
      frequency: 1180.0,
      durationMs: 65,
      volume: 0.38,
      fadeInMs: 4,
      fadeOutMs: 10,
    );

    // Brief silence gap: 10ms
    final gapSamples = (sampleRate * 0.010).round();
    samples.addAll(List.filled(gapSamples, 0));

    // Squelch tail: 40ms of soft decaying filtered white noise
    final squelchSamples = (sampleRate * 0.040).round();
    final random = Random(12345);
    double lastNoise = 0.0;
    for (int i = 0; i < squelchSamples; i++) {
      // Exponential decay envelope from 0.18 down to 0
      final progress = i / squelchSamples;
      final decay = pow(1.0 - progress, 2.2) * 0.18;
      // Single-pole low-pass filter for realistic radio static
      final rawNoise = (random.nextDouble() * 2.0 - 1.0);
      lastNoise = lastNoise * 0.4 + rawNoise * 0.6;
      final sampleVal = (lastNoise * decay * 32767).round().clamp(-32768, 32767);
      samples.add(sampleVal);
    }

    _cachedEndRogerBeep = _samplesToPcm16(samples);
    return _cachedEndRogerBeep!;
  }

  static void _appendTone({
    required List<int> samples,
    required double frequency,
    required int durationMs,
    required double volume,
    required int fadeInMs,
    required int fadeOutMs,
  }) {
    final totalSamples = (sampleRate * (durationMs / 1000.0)).round();
    final fadeInSamples = (sampleRate * (fadeInMs / 1000.0)).round();
    final fadeOutSamples = (sampleRate * (fadeOutMs / 1000.0)).round();

    for (int i = 0; i < totalSamples; i++) {
      double envelope = 1.0;
      if (i < fadeInSamples && fadeInSamples > 0) {
        envelope = i / fadeInSamples;
      } else if (i > totalSamples - fadeOutSamples && fadeOutSamples > 0) {
        envelope = (totalSamples - i) / fadeOutSamples;
      }

      final phase = 2 * pi * frequency * (i / sampleRate);
      final val = sin(phase) * envelope * volume;
      final sampleInt = (val * 32767).round().clamp(-32768, 32767);
      samples.add(sampleInt);
    }
  }

  static Uint8List _samplesToPcm16(List<int> samples) {
    final bytes = Uint8List(samples.length * 2);
    final byteData = bytes.buffer.asByteData();
    for (int i = 0; i < samples.length; i++) {
      byteData.setInt16(i * 2, samples[i], Endian.little);
    }
    return bytes;
  }
}
