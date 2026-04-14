import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

enum NivaOrbState { idle, listening, thinking, speaking }

class NivaOrbWidget extends StatefulWidget {
  final NivaOrbState state;
  final double size;
  final Color? primaryColor;

  const NivaOrbWidget({
    super.key,
    this.state = NivaOrbState.idle,
    this.size = 120,
    this.primaryColor,
  });

  @override
  State<NivaOrbWidget> createState() => _NivaOrbWidgetState();
}

class _NivaOrbWidgetState extends State<NivaOrbWidget> {
  Artboard? _riveArtboard;
  StateMachineController? _controller;
  SMIBool? _listeningInput;
  SMIBool? _thinkingInput;
  SMIBool? _speakingInput;
  SMIBool? _asleepInput;

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
  }

  Future<void> _loadRiveFile() async {
    try {
      final data = await rootBundle.load('assets/rive/obsidian.riv');
      final file = RiveFile.import(data);
      final artboard = file.mainArtboard;

      _controller = StateMachineController.fromArtboard(artboard, 'default');
      if (_controller != null) {
        artboard.addController(_controller!);
        _listeningInput = _controller!.findInput<bool>('listening') as SMIBool?;
        _thinkingInput = _controller!.findInput<bool>('thinking') as SMIBool?;
        _speakingInput = _controller!.findInput<bool>('speaking') as SMIBool?;
        _asleepInput = _controller!.findInput<bool>('asleep') as SMIBool?;
        _updateRiveInputs();
      }

      setState(() => _riveArtboard = artboard);
    } catch (e) {
      debugPrint("Failed to load Rive file: \$e");
    }
  }

  @override
  void didUpdateWidget(covariant NivaOrbWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateRiveInputs();
    }
  }

  void _updateRiveInputs() {
    if (_controller == null) return;
    
    _listeningInput?.value = widget.state == NivaOrbState.listening;
    _thinkingInput?.value = widget.state == NivaOrbState.thinking;
    _speakingInput?.value = widget.state == NivaOrbState.speaking;
    _asleepInput?.value = widget.state == NivaOrbState.idle; // or you can leave false depending on design
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _riveArtboard == null
          ? const SizedBox() // the rive file hasn't loaded yet
          : Rive(
              artboard: _riveArtboard!,
              fit: BoxFit.contain,
            ),
    );
  }
}
