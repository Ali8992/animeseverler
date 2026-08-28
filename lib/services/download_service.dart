import 'dart:io';

import 'package:extractor/extractor.dart';
import 'package:path_provider/path_provider.dart';

/// Format seçim kartında gösterilecek indirme seçeneği.
class DownloadOption {
  final String label;
  final String subtitle;
  final String format;
  final bool isAudio;
  final String type; // 'best' | 'video' | 'music'

  const DownloadOption({
    required this.label,
    required this.subtitle,
    required this.format,
    this.isAudio = false,
    required this.type,
  });

  factory DownloadOption.fromVideoFormat(VideoFormat f) {
    final res = f.resolution ?? 'Video';
    final ext = (f.ext ?? '').toUpperCase();
    final size = f.filesize != null
        ? _formatBytes(f.filesize!)
        : (f.tbr != null ? _formatTbr(f.tbr!) : '');
    return DownloadOption(
      label: res,
      subtitle: '$ext${size.isNotEmpty ? ' • $size' : ''}',
      format: '${f.formatId}',
      type: 'video',
    );
  }

  factory DownloadOption.best() => const DownloadOption(
        label: 'En İyi Kalite',
        subtitle: 'video + ses • MP4',
        format: 'bestvideo+bestaudio/best',
        type: 'best',
      );

  factory DownloadOption.video1080() => const DownloadOption(
        label: '1080p',
        subtitle: 'Full HD • MP4',
        format: 'bestvideo[height<=1080]+bestaudio/best[height<=1080]',
        type: 'video',
      );

  factory DownloadOption.video720() => const DownloadOption(
        label: '720p',
        subtitle: 'HD • MP4',
        format: 'bestvideo[height<=720]+bestaudio/best[height<=720]',
        type: 'video',
      );

  factory DownloadOption.audioMp3() => const DownloadOption(
        label: 'Ses (MP3)',
        subtitle: 'Yalnızca ses • 320kbps',
        format: 'bestaudio/best',
        isAudio: true,
        type: 'music',
      );

  factory DownloadOption.audioM4a() => const DownloadOption(
        label: 'Ses (M4A)',
        subtitle: 'Yalnızca ses • kayıpsız',
        format: 'bestaudio[ext=m4a]/bestaudio/best',
        isAudio: true,
        type: 'music',
      );
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}

String _formatTbr(int tbr) {
  if (tbr >= 1000) return '${(tbr / 1000).toStringAsFixed(1)} Mbps';
  return '$tbr kbps';
}

class DownloadService {
  static final DownloadService instance = DownloadService._();
  DownloadService._();

  final YoutubeDLFlutter _yt = YoutubeDLFlutter.instance;
  bool _initialized = false;

  Stream<DownloadProgress> get onProgress => _yt.onProgress;
  Stream<DownloadState> get onStateChanged => _yt.onStateChanged;
  Stream<DownloadError> get onError => _yt.onError;

  Future<String?> initialize() async {
    if (_initialized) return null;
    final result = await _yt.initialize(
      enableFFmpeg: true,
      enableAria2c: true,
    );
    _initialized = result.success;
    if (!result.success) {
      return result.errorMessage ?? 'Başlatma hatası';
    }
    return null;
  }

  /// Paylaşılan metinden geçerli bir YouTube / YouTube Music linki ayıklar.
  String? extractYouTubeUrl(String? shared) {
    if (shared == null || shared.trim().isEmpty) return null;
    final reg = RegExp(
      r'https?://[^\s"<>]+',
      caseSensitive: false,
    );
    final match = reg.firstMatch(shared);
    if (match == null) return null;
    final url = match.group(0)!;
    if (url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('music.youtube.com') ||
        url.contains('vnd.youtube')) {
      return url;
    }
    return null;
  }

  Future<VideoInfo?> getVideoInfo(String url) async {
    final init = await initialize();
    if (init != null) return null;
    try {
      return await _yt.getVideoInfo(url);
    } catch (_) {
      return null;
    }
  }

  /// İndirme klasörü yolunu döndürür.
  Future<Directory> getDownloadDir() async {
    final ext = await getExternalStorageDirectory();
    if (ext != null) {
      final dir = Directory('${ext.path}/Dompat');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final app = await getApplicationDocumentsDirectory();
    final dir = Directory('${app.path}/Dompat');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Seçili formatta indirme başlatır.
  Future<DownloadResult> download({
    required String url,
    required DownloadOption option,
    required String outputPath,
  }) async {
    final init = await initialize();
    if (init != null) {
      throw Exception(init);
    }
    final isAudio = option.isAudio;
    final audioExt = option.format.contains('m4a') ? 'm4a' : 'mp3';
    final request = DownloadRequest(
      url: url,
      outputPath: outputPath,
      outputTemplate: '%(title)s.%(ext)s',
      format: isAudio ? 'bestaudio/best' : option.format,
      noPlaylist: true,
      extractAudio: isAudio,
      audioFormat: isAudio ? audioExt : null,
      audioQuality: 0,
      embedThumbnail: isAudio,
      embedMetadata: isAudio,
      customOptions: {
        '--no-playlist': '',
        '--retries': '10',
        '--fragment-retries': '10',
        '--no-update': '',
      },
    );
    return await _yt.download(request);
  }
}
