import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import '../models/version_model.dart';
import '../services/update_service.dart';

enum UpdateState { available, downloading, error }

class UpdateDialog extends StatefulWidget {
  final VersionModel versionModel;

  const UpdateDialog({super.key, required this.versionModel});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with TickerProviderStateMixin {
  final UpdateService _updateService = UpdateService();
  CancelToken? _cancelToken;
  
  UpdateState _state = UpdateState.available;
  double _progress = 0.0;
  String _currentVersion = "v...";
  
  // Animations
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    
    // Entrance Animation (Slide up + Scale)
    _entranceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
        
    _scaleAnimation = CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOutBack);
        
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutQuart,
    ));

    // Pulse Animation for the icon background
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
        
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );

    _entranceController.forward();
  }

  Future<void> _loadCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentVersion = packageInfo.version;
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    if (mounted) {
      setState(() {
        _state = UpdateState.available;
        _progress = 0.0;
      });
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = UpdateState.downloading;
      _progress = 0.0;
    });

    _cancelToken = CancelToken();

    final String? apkPath = await _updateService.downloadApk(
      url: widget.versionModel.downloadUrl,
      onReceiveProgress: (count, total) {
        if (total != -1 && mounted) {
          setState(() {
             _progress = count / total;
          });
        }
      },
      cancelToken: _cancelToken,
    );

    if (_cancelToken?.isCancelled == true) {
      return;
    }

    if (apkPath != null) {
      final success = await _updateService.installApk(apkPath);
      if (!success && mounted) {
        setState(() => _state = UpdateState.error);
      }
    } else if (mounted) {
      setState(() => _state = UpdateState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !widget.versionModel.forceUpdate && _state != UpdateState.downloading,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.6 : 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   _buildHeader(cs),
                   const SizedBox(height: 24),
                   _buildVersionInfo(cs, isDark),
                   const SizedBox(height: 24),
                   _buildChangelog(cs, isDark),
                   const SizedBox(height: 32),
                   _buildFooterActions(cs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (_state == UpdateState.downloading)
               SizedBox(
                 width: 80,
                 height: 80,
                 child: TweenAnimationBuilder<double>(
                   tween: Tween<double>(begin: 0, end: _progress),
                   duration: const Duration(milliseconds: 300),
                   builder: (context, value, _) => CircularProgressIndicator(
                     value: value,
                     strokeWidth: 4,
                     backgroundColor: cs.primary.withAlpha(30),
                     valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                   ),
                 ),
               ),
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withOpacity(0.15),
                      cs.primary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 56,
              height: 56,
              child: Image.asset(
                'assets/icons/login.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _state == UpdateState.downloading 
              ? (_progress == 1.0 ? "Installing..." : "Downloading... ${(_progress * 100).toInt()}%") 
              : "Update Available",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _state == UpdateState.downloading
              ? "Please don't close the app"
              : "A new version of Expenso is ready",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: cs.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVersionInfo(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(isDark ? 0.1 : 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _VersionBadge(label: "Current", version: "v$_currentVersion", color: cs.onSurface.withOpacity(0.6)),
          Icon(Icons.arrow_forward_rounded, size: 16, color: cs.onSurface.withOpacity(0.3)),
          _VersionBadge(label: "Latest", version: "v${widget.versionModel.version}", color: cs.primary),
        ],
      ),
    );
  }

  Widget _buildChangelog(ColorScheme cs, bool isDark) {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.white.withOpacity(0.0)],
            stops: const [0.0, 0.8, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: MarkdownBody(
            data: widget.versionModel.releaseNotes.isEmpty
                ? "• Premium improvements\n• Bug fixes and optimisations"
                : widget.versionModel.releaseNotes,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                fontSize: 14, 
                color: cs.onSurface.withOpacity(0.8),
                height: 1.6,
              ),
              listBullet: TextStyle(
                color: cs.primary, 
                fontSize: 16,
              ),
              h3: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions(ColorScheme cs) {
    if (_state == UpdateState.error) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: cs.error, size: 18),
              const SizedBox(width: 8),
              Text("Download failed. Please try again.",
                  style: TextStyle(color: cs.error, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          _buildPrimaryButton(cs, "Retry", _startDownload),
        ],
      );
    }

    if (_state == UpdateState.downloading) {
      return SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _cancelDownload,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            "Cancel Download",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPrimaryButton(cs, "Update Now", _startDownload),
        if (!widget.versionModel.forceUpdate) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                "Later",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrimaryButton(ColorScheme cs, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final String label;
  final String version;
  final Color color;

  const _VersionBadge({
    required this.label,
    required this.version,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        ),
        const SizedBox(height: 4),
        Text(
          version,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

