import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:extractor/extractor.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'services/download_service.dart';
import 'screens/download_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const DompatApp());
}

class DompatApp extends StatelessWidget {
  const DompatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dompat İndirici',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0033),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0033),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  StreamSubscription<List<SharedMediaFile>>? _intentSub;
  bool _loading = false;
  String? _error;
  VideoInfoData? _info;

  @override
  void initState() {
    super.initState();
    _listenForSharedLinks();
    _checkInitialSharedLink();
  }

  void _listenForSharedLinks() {
    _intentSub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((files) {
      final url = DownloadService.instance
          .extractYouTubeUrl(files.isEmpty ? null : files.first.path);
      if (url != null) {
        _loadUrl(url);
      }
    }, onError: (err) {
      debugPrint('share error: $err');
    });
  }

  Future<void> _checkInitialSharedLink() async {
    final files = await ReceiveSharingIntent.instance.getInitialMedia();
    final url = DownloadService.instance
        .extractYouTubeUrl(files.isEmpty ? null : files.first.path);
    if (url != null && mounted) {
      _urlController.text = url;
      _loadUrl(url);
    }
    ReceiveSharingIntent.instance.reset();
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadUrl(String url) async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    FocusScope.of(context).unfocus();
    final service = DownloadService.instance;
    final info = await service.getVideoInfo(url);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (info == null) {
        _error = 'Video bilgisi alınamadı. Linki kontrol edin veya yt-dlp '
            'güncel olmayabilir.';
      } else {
        _info = VideoInfoData(
          url: url,
          title: info.title ?? 'Bilinmeyen başlık',
          duration: Duration(seconds: info.duration ?? 0),
          uploader: info.uploader ?? '',
          thumbnail: info.thumbnail,
          formats: info.formats,
        );
      }
    });
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    final text = data?.text;
    final url =
        DownloadService.instance.extractYouTubeUrl(text);
    if (url != null) {
      _urlController.text = url;
      _loadUrl(url);
    } else if (text != null && text.trim().isNotEmpty) {
      _urlController.text = text.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir YouTube linki bulunamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dompat İndirici'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildUrlInput(),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Video bilgileri yükleniyor...'),
                      ],
                    ),
                  ),
                ),
              if (_error != null && !_loading)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
              if (_info != null && !_loading) _buildInfoAndOptions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrlInput() {
    return TextField(
      controller: _urlController,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.go,
      onSubmitted: (v) => _loadFromText(v),
      decoration: InputDecoration(
        hintText: 'YouTube veya YouTube Music linki yapıştırın',
        prefixIcon: const Icon(Icons.link),
        suffixIcon: IconButton(
          icon: const Icon(Icons.content_paste),
          tooltip: 'Panodan yapıştır',
          onPressed: _pasteFromClipboard,
        ),
      ),
    );
  }

  void _loadFromText(String text) {
    final url = DownloadService.instance.extractYouTubeUrl(text);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir YouTube linki bulunamadı.')),
      );
      return;
    }
    _urlController.text = url;
    _loadUrl(url);
  }

  Widget _buildInfoAndOptions() {
    final info = _info!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.thumbnail != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  info.thumbnail!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.movie, size: 48),
                  ),
                ),
              ),
              if (info.thumbnail != null) const SizedBox(height: 12),
            Text(
              info.title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person, size: 16,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    info.uploader,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.schedule, size: 16,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Text(_formatDuration(info.duration),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
            const Divider(height: 24),
            Text('İndirme Seçenekleri',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            _buildOptionTile(
                DownloadOption.best(),
                icon: Icons.high_quality,
                color: Colors.red),
            _buildOptionTile(
                DownloadOption.video1080(),
                icon: Icons.movie,
                color: Colors.deepPurple),
            _buildOptionTile(
                DownloadOption.video720(),
                icon: Icons.movie,
                color: Colors.indigo),
            _buildOptionTile(
                DownloadOption.audioMp3(),
                icon: Icons.music_note,
                color: Colors.green),
            _buildOptionTile(
                DownloadOption.audioM4a(),
                icon: Icons.audiotrack,
                color: Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(DownloadOption option,
      {required IconData icon, required Color color}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(option.label),
        subtitle: Text(option.subtitle),
        trailing: const Icon(Icons.download_outlined),
        onTap: () => _startDownload(option),
      ),
    );
  }

  void _startDownload(DownloadOption option) {
    final url = _info!.url;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DownloadScreen(
          url: url,
          option: option,
          title: _info!.title,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${_p2(m)}:${_p2(s)}';
    return '${_p2(m)}:${_p2(s)}';
  }

  String _p2(int v) => v.toString().padLeft(2, '0');
}

class VideoInfoData {
  final String url;
  final String title;
  final Duration duration;
  final String uploader;
  final String? thumbnail;
  final List<VideoFormat?>? formats;

  VideoInfoData({
    required this.url,
    required this.title,
    required this.duration,
    required this.uploader,
    this.thumbnail,
    this.formats,
  });
}
