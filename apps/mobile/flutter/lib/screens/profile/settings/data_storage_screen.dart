import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../services/settings_service.dart';
import '../widgets/profile_widgets.dart';

class DataStorageScreen extends StatelessWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F121F) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left_rounded, 
            color: Theme.of(context).colorScheme.onSurface, 
            size: 32
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
          ).createShader(bounds),
          child: const Text(
            'Data & Storage',
            style: TextStyle(
              fontFamily: 'Outfit', 
              fontWeight: FontWeight.w900, 
              fontSize: 22, 
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const BouncingScrollPhysics(),
        children: [
          const SectionLabel(label: 'Node Memory'),
          MenuCard(
            icon: Icons.delete_sweep_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
            title: 'Clear Cache',
            subtitle: 'Purge temporary data (79.4 MB)',
            onTap: () => _showClearCacheDialog(context),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Auto-Download Streams'),
          _SelectionCard(
            icon: Icons.wifi_rounded,
            iconColor: const Color(0xFF06B6D4),
            iconBgColor: const Color(0xFF06B6D4).withValues(alpha: 0.1),
            title: 'Wi-Fi Networks',
            subtitle: 'Data reception on high-bandwidth nodes',
            value: settings.autoDownloadWifi,
            options: const ['all', 'photos', 'none'],
            labels: const ['All Media', 'Photos Only', 'Deactivated'],
            onChanged: (v) => settings.setAutoDownloadWifi(v),
          ),
          _SelectionCard(
            icon: Icons.cell_tower_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            title: 'Cellular Nodes',
            subtitle: 'Data reception on mobile streams',
            value: settings.autoDownloadMobile,
            options: const ['all', 'photos', 'none'],
            labels: const ['All Media', 'Photos Only', 'Deactivated'],
            onChanged: (v) => settings.setAutoDownloadMobile(v),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Transmission Quality'),
          _SelectionCard(
            icon: Icons.high_quality_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            title: 'Media Fidelity',
            subtitle: 'Fineness of transmitted visual nodes',
            value: settings.photoQuality,
            options: const ['high', 'medium', 'low'],
            labels: const ['Ultra (Lossless)', 'Balanced', 'Data Saver'],
            onChanged: (v) => settings.setPhotoQuality(v),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Storage Distribution'),
          _StorageInfoCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: isDark 
              ? const Color(0xFF1A1D2B).withValues(alpha: 0.9) 
              : Colors.white.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Text(
            'Purge Cache?',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900),
          ),
          content: Text(
            'This will clear temporary artifacts and cached nodes. Your encrypted messages will remain intact.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Node cache purged successfully'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              child: const Text(
                'Purge',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final List<String> labels;
  final ValueChanged<String> onChanged;

  const _SelectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = options.indexOf(value);
    final currentLabel = currentIndex >= 0 ? labels[currentIndex] : labels[0];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark 
            ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
            : Colors.white.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              _showSelectionDialog(context);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: iconColor.withValues(alpha: 0.1)),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currentLabel,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7C6FF7),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded, 
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), 
                        size: 20
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSelectionDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: isDark 
              ? const Color(0xFF1A1D2B).withValues(alpha: 0.9) 
              : Colors.white.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            title,
            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final label = labels[index];
              final isSelected = value == option;
              
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF7C6FF7) : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: isSelected 
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C6FF7)) 
                    : null,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onChanged(option);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _StorageInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark 
            ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
            : Colors.white.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: Color(0xFF7C6FF7), size: 24),
              const SizedBox(width: 12),
              Text(
                'Storage Breakdown',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _StorageItem(
            label: 'Encrypted Messages',
            size: '45.2 MB',
            color: Color(0xFF7C6FF7),
            percentage: 0.6,
          ),
          const _StorageItem(
            label: 'Visual Artifacts',
            size: '23.8 MB',
            color: Color(0xFF10B981),
            percentage: 0.3,
          ),
          const _StorageItem(
            label: 'Neural Stream Buffers',
            size: '8.1 MB',
            color: Color(0xFFF59E0B),
            percentage: 0.1,
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Node Usage',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '79.4 MB',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF7C6FF7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorageItem extends StatelessWidget {
  final String label;
  final String size;
  final Color color;
  final double percentage;

  const _StorageItem({
    required this.label,
    required this.size,
    required this.color,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              Text(
                size,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}