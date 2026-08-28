import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:extractor/extractor.dart';
import 'package:share_plus/share_plus.dart';

import '../services/download_service.dart';

class DownloadScreen extends StatefulWidget {
  final String url;
  final DownloadOption option;
  final String title;

  const DownloadScreen({
    super.key,
    required this.url,
    required this.option,
    required this.title,
  });

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _service = DownloadService.instance;

  StreamSubscription<DownloadProgress>? _progressSub;
  StreamSubscription<DownloadState>? _stateSub;
  StreamSubscription<DownloadError>? _errorSub;

  bool _downloading = false;
  bool _finished = false;
  double _progress = 0;
  int? _eta;
  String? _savePath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0;
    });

    _progressSub = _service.onProgress.listen((p) {
      if (!mounted) return;
      setState(() {
        _progress = p.progress;
        _eta = p.etaInSeconds;
      });
    });

    _stateSub = _service.onStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state.state == DownloadStateType.completed) {
          _downloading = false;
          _finished = true;
        }
      });
    });

    _errorSub = _service.onError.listen((e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.error;
      });
    });

    try {
      final dir = await _service.getDownloadDir();
      final result = await _service.download(
        url: widget.url,
        option: widget.option,
        outputPath: dir.path,
      );
      if (!mounted) return;
      if (result.status == OperationStatus.success) {
        setState(() {
          _downloading = false;
          _finished = true;
          _progress = 1;
          _savePath = result.outputPath;
        });
      } else {
        setState(() {
          _downloading = false;
          _error = result.errorMessage ?? 'İndirme başarısız oldu.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString();
      });
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _shareFile(File file) async {
    if (!await file.exists()) return;
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (_) {
      // paylaşım başarısız oldu
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAudio = widget.option.isAudio;
    return Scaffold(
      appBar: AppBar(title: Text(isAudio ? 'Ses İndirme' : 'Video İndirme')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                isAudio ? Icons.music_note : Icons.movie,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                widget.option.label,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                )
              else if (_finished)
                Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 72),
                    const SizedBox(height: 16),
                    Text('İndirme tamamlandı!',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (_savePath != null)
                      Text(
                        _savePath!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 12),
                      ),
                  ],
                )
              else if (_downloading)
                Column(
                  children: [
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _eta != null && _eta! > 0
                          ? '%${(_progress * 100).toStringAsFixed(0)} • '
                              'kalan ${_formatDuration(_eta!)}'
                          : '%${(_progress * 100).toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'İlk kullanımda yt-dlp çalışma zamanı hazırlanır, '
                      'birkaç saniye sürebilir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 12),
                    ),
                  ],
                )
              else
                const Text('Başlatılıyor...'),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _finished && _savePath != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('Paylaş'),
                        onPressed: () =>
                            _shareFile(File(_savePath!)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Tamam'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
