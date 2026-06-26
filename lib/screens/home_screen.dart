import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../utils/extensions.dart';
import 'call_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: AppColors.surface.withOpacity(0.7),
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connect',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.primaryFixed,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout_rounded, color: AppColors.onSurfaceVariant, size: 20),
                    ],
                  ),
                  onPressed: () async => await AuthService.instance.signOut(),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Atmospheric Gradients
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ).blurred(100),
          ),
          
          SafeArea(
            child: StreamBuilder<List<UserModel>>(
              stream: AuthService.instance.otherUsersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final users = snapshot.data ?? [];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24).copyWith(bottom: 100),
                  child: CustomScrollView(
                    slivers: [
                    // Hero Section
                    SliverToBoxAdapter(
                      child: GlassPanel(
                        padding: const EdgeInsets.all(24),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -40,
                              top: -40,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              ).blurred(40),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recent Connections',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: AppColors.onSurface,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Stay engaged with your team and friends through high-fidelity video experiences.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    // Search and Filter
                    SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.outlineVariant),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  const Icon(Icons.search_rounded, color: AppColors.outline),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        hintText: 'Search contacts...',
                                        hintStyle: TextStyle(color: AppColors.outline.withOpacity(0.5)),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GlassPanel(
                            padding: const EdgeInsets.all(12),
                            borderRadius: BorderRadius.circular(12),
                            child: const Icon(Icons.filter_list_rounded, color: AppColors.secondary),
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    if (users.isEmpty)
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.onSurfaceVariant),
                                const SizedBox(height: 16),
                                Text(
                                  'No contacts found',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.zero,
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            mainAxisExtent: 88,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final user = users[index];
                              return GlassPanel(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: const BoxDecoration(
                                            color: AppColors.surfaceContainerHighest,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.person_rounded, color: AppColors.primary),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: user.isOnline ? AppColors.secondary : AppColors.outline,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppColors.surface, width: 2),
                                              boxShadow: user.isOnline
                                                  ? [BoxShadow(color: AppColors.secondary.withOpacity(0.5), blurRadius: 8)]
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            user.displayName,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            user.isOnline ? 'Active now' : 'Offline',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: AppColors.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) => CallScreen(
                                                targetUid: user.uid,
                                                targetName: user.displayName,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Ink(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: user.isOnline ? AppColors.secondaryContainer : AppColors.surfaceContainerHigh,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.videocam_rounded,
                                            size: 24,
                                            color: user.isOnline ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: users.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.secondary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.secondary : AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isActive ? AppColors.secondaryFixed : AppColors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
