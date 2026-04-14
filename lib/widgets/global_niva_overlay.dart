import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/niva_voice_provider.dart';
import 'package:expenso/widgets/niva_orb_widget.dart';

class GlobalNivaOverlay extends StatelessWidget {
  const GlobalNivaOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NivaVoiceProvider>(
      builder: (context, provider, child) {
        final isActive = provider.status != NivaStatus.idle;
        if (!isActive) return const SizedBox.shrink();

        final transcript = provider.liveTranscript?.content ?? 
            (provider.messages.isNotEmpty ? provider.messages.last.content : '');

        return Stack(
          children: [
            if (transcript.isNotEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 120, // firmly above the centered docked FAB
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Text(
                        transcript,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 22, // corresponds exactly to the notch floating action button location
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    provider.endCall();
                  },
                  child: SizedBox(
                    height: 80,
                    width: 80,
                    child: NivaOrbWidget(
                      state: provider.isSpeaking ? NivaOrbState.speaking :
                             (provider.status == NivaStatus.connecting ? NivaOrbState.thinking : NivaOrbState.listening),
                      size: 80,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
