import 'package:flutter/material.dart';
import '../models/translation_edition.dart';
import '../services/database_service.dart';

class TranslationSelectorSheet extends StatefulWidget {
  final String activeEditionId;
  final ValueChanged<TranslationEdition> onEditionSelected;

  const TranslationSelectorSheet({
    super.key,
    required this.activeEditionId,
    required this.onEditionSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required String activeEditionId,
    required ValueChanged<TranslationEdition> onEditionSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TranslationSelectorSheet(
        activeEditionId: activeEditionId,
        onEditionSelected: onEditionSelected,
      ),
    );
  }

  @override
  State<TranslationSelectorSheet> createState() => _TranslationSelectorSheetState();
}

class _TranslationSelectorSheetState extends State<TranslationSelectorSheet> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService.instance;
  late TabController _tabController;

  List<TranslationEdition> _downloadedEditions = [];
  List<TranslationEdition> _availableEditions = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _downloadingId;

  static const _prebundledIds = {
    'en.sahih',
    'ms.basmeih',
    'id.indonesian',
    'fr.hamidullah',
    'tr.diyanet',
    'ur.jalandhry',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEditions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEditions() async {
    setState(() => _isLoading = true);
    final all = await _db.getAllAvailableEditions();
    final downloaded = all.where((e) => e.isDownloaded).toList();
    final available = all.where((e) => !e.isDownloaded).toList();

    if (!mounted) return;
    setState(() {
      _downloadedEditions = downloaded;
      _availableEditions = available;
      _isLoading = false;
    });
  }

  Future<void> _downloadEdition(TranslationEdition edition) async {
    setState(() => _downloadingId = edition.identifier);
    try {
      await _db.downloadAndStoreEdition(edition);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded ${edition.englishName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadEditions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingId = null);
      }
    }
  }

  Future<void> _deleteEdition(TranslationEdition edition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Translation'),
        content: Text('Remove ${edition.englishName} from your offline storage?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.removeDownloadedEdition(edition.identifier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${edition.englishName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadEditions();
    }
  }

  List<TranslationEdition> _filter(List<TranslationEdition> list) {
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((e) {
      return e.englishName.toLowerCase().contains(q) ||
          e.name.toLowerCase().contains(q) ||
          e.languageCode.toLowerCase().contains(q) ||
          e.identifier.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.translate_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Translations Library',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: SearchBar(
              hintText: 'Search language or author...',
              leading: const Icon(Icons.search_rounded),
              trailing: _searchQuery.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      ),
                    ]
                  : null,
              onChanged: (val) => setState(() => _searchQuery = val),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            indicatorColor: theme.colorScheme.primary,
            tabs: [
              Tab(
                text: 'Downloaded (${_downloadedEditions.length})',
                icon: const Icon(Icons.offline_pin_rounded, size: 20),
              ),
              Tab(
                text: 'Available (${_availableEditions.length})',
                icon: const Icon(Icons.cloud_download_outlined, size: 20),
              ),
            ],
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Downloaded
                      _buildDownloadedList(theme),
                      // Tab 2: Available to Download
                      _buildAvailableList(theme),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadedList(ThemeData theme) {
    final filtered = _filter(_downloadedEditions);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? 'No matches found.' : 'No downloaded translations.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final edition = filtered[index];
        final isSelected = edition.identifier == widget.activeEditionId;
        final isPrebundled = _prebundledIds.contains(edition.identifier);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              edition.languageCode.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          title: Text(
            edition.englishName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            edition.name,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isPrebundled)
                IconButton(
                  tooltip: 'Delete offline file',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: () => _deleteEdition(edition),
                ),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                size: 22,
              ),
            ],
          ),
          onTap: () {
            widget.onEditionSelected(edition);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildAvailableList(ThemeData theme) {
    final filtered = _filter(_availableEditions);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? 'No matches found.' : 'All available translations are downloaded!',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final edition = filtered[index];
        final isDownloading = _downloadingId == edition.identifier;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              edition.languageCode.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          title: Text(
            edition.englishName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            edition.name,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: isDownloading
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : IconButton.filledTonal(
                  tooltip: 'Download offline translation (~1.5 MB)',
                  icon: const Icon(Icons.download_rounded, size: 20),
                  onPressed: () => _downloadEdition(edition),
                ),
        );
      },
    );
  }
}
