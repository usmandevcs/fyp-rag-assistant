import 'package:flutter/material.dart';

const Color _deepGraphite = Color(0xFF2D2D34);
const Color _neonOrange = Color(0xFFFF5F1F);

class PremiumMicButton extends StatefulWidget {
  final bool isRecording;

  const PremiumMicButton({
    super.key,
    required this.isRecording,
  });

  @override
  State<PremiumMicButton> createState() => _PremiumMicButtonState();
}

class _PremiumMicButtonState extends State<PremiumMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    if (widget.isRecording) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(PremiumMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _animationController.repeat();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Animated ripples when recording
        if (widget.isRecording)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple 1
                  Transform.scale(
                    scale: 1 + (_animationController.value * 0.6),
                    child: Opacity(
                      opacity: 1 - (_animationController.value * 0.8),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _neonOrange,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Ripple 2 (offset delay)
                  Transform.scale(
                    scale: 1 +
                        ((_animationController.value - 0.3) % 1.0) * 0.6,
                    child: Opacity(
                      opacity: 1 -
                          ((_animationController.value - 0.3) % 1.0) *
                              0.8,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _neonOrange,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Ripple 3 (offset delay)
                  Transform.scale(
                    scale: 1 +
                        ((_animationController.value - 0.6) % 1.0) * 0.6,
                    child: Opacity(
                      opacity: 1 -
                          ((_animationController.value - 0.6) % 1.0) *
                              0.8,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _neonOrange,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

        // Central button (pure UI, no gesture handling)
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: _deepGraphite,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.mic,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }
}
