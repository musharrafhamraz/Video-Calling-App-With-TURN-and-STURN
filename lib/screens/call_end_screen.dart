import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../utils/extensions.dart';

class CallEndScreen extends StatelessWidget {
  final String peerName;
  final Duration duration;

  const CallEndScreen({
    super.key,
    required this.peerName,
    required this.duration,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Atmospheric Gradients
          Positioned(
            top: 80,
            left: 40,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ).blurred(100),
          ),
          Positioned(
            bottom: 80,
            right: 40,
            child: Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ).blurred(120),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar & Indicator
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                              color: AppColors.surfaceContainerHigh.withOpacity(0.7),
                            ),
                            child: const Center(
                              child: Icon(Icons.person, size: 80, color: AppColors.primary),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            child: Icon(
                              Icons.call_end_rounded,
                              color: AppColors.secondaryFixed,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Title
                      Text(
                        'Call Ended',
                        style: textTheme.displayLarge?.copyWith(
                          fontSize: 36,
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Duration
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule_rounded, color: AppColors.outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Duration: ',
                            style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.primaryFixed,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Stats Grid
                      Row(
                        children: [
                          Expanded(
                            child: GlassPanel(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.signal_cellular_alt_rounded, color: AppColors.primary),
                                  const SizedBox(height: 8),
                                  Text(
                                    'CONNECTION',
                                    style: textTheme.labelSmall?.copyWith(
                                          color: AppColors.outline,
                                          letterSpacing: 2,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Excellent',
                                    style: textTheme.headlineMedium?.copyWith(
                                          color: AppColors.onSurface,
                                          fontSize: 20,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GlassPanel(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.high_quality_rounded, color: AppColors.secondary),
                                  const SizedBox(height: 8),
                                  Text(
                                    'QUALITY',
                                    style: textTheme.labelSmall?.copyWith(
                                          color: AppColors.outline,
                                          letterSpacing: 2,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'HD Video',
                                    style: textTheme.headlineMedium?.copyWith(
                                          color: AppColors.onSurface,
                                          fontSize: 20,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Actions
                      PrimaryButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        text: 'Back to Home',
                        icon: Icons.home_rounded,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              onPressed: () {},
                              text: 'View History',
                              icon: Icons.history_rounded,
                              isSecondary: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: PrimaryButton(
                              onPressed: () {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                                // Initiating a call from here would require pushing CallScreen again
                              },
                              text: 'Call Again',
                              icon: Icons.videocam_rounded,
                              isSecondary: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  peerName,
                                  style: textTheme.labelMedium?.copyWith(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, size: 16, color: AppColors.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Verified Sync',
                                  style: textTheme.labelMedium?.copyWith(color: AppColors.secondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
