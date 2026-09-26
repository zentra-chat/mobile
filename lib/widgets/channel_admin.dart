import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart' show Channel, ChannelCategory;
import '../providers/api_provider.dart';
import '../providers/data_providers.dart';

Future<String?> promptForName(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String confirmLabel = 'Create',
}) async {
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return name;
}

/// Menu offering the two things an owner can add to a community.
Future<void> showCreateMenu(
  BuildContext context,
  WidgetRef ref,
  String communityId,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Create Channel'),
              onTap: () => Navigator.of(sheetContext).pop('channel'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Create Folder'),
              onTap: () => Navigator.of(sheetContext).pop('folder'),
            ),
          ],
        ),
      );
    },
  );

  if (!context.mounted || action == null) return;
  if (action == 'channel') {
    await createChannel(context, ref, communityId);
  } else if (action == 'folder') {
    await createFolder(context, ref, communityId);
  }
}

Future<void> createFolder(
  BuildContext context,
  WidgetRef ref,
  String communityId,
) async {
  final name = await promptForName(
    context,
    title: 'Create Folder',
    label: 'Name',
  );
  if (name == null || name.isEmpty || !context.mounted) return;
  await _run(context, () async {
    await ref.read(apiClientProvider).createCategory(communityId, name);
    ref.invalidate(categoriesProvider(communityId));
  }, failureMessage: 'Failed to create folder');
}

Future<void> createChannel(
  BuildContext context,
  WidgetRef ref,
  String communityId, {
  String? folderId,
}) async {
  final name = await promptForName(
    context,
    title: 'New Channel',
    label: 'Name',
  );
  if (name == null || name.isEmpty || !context.mounted) return;
  await _run(context, () async {
    await ref
        .read(apiClientProvider)
        .createChannel(communityId, name: name, categoryId: folderId);
    ref.invalidate(channelsProvider(communityId));
  }, failureMessage: 'Failed to create channel');
}

/// Long press actions for a folder: add to it, rename it or delete it.
Future<void> showFolderActions(
  BuildContext context,
  WidgetRef ref,
  String communityId,
  ChannelCategory category,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(category.name)),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create Channel'),
              onTap: () => Navigator.of(sheetContext).pop('create-channel'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename Folder'),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Folder'),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      );
    },
  );

  if (!context.mounted || action == null) return;
  switch (action) {
    case 'create-channel':
      await createChannel(context, ref, communityId, folderId: category.id);
    case 'rename':
      await renameFolder(context, ref, communityId, category);
    case 'delete':
      await deleteFolder(context, ref, communityId, category);
  }
}

Future<void> renameFolder(
  BuildContext context,
  WidgetRef ref,
  String communityId,
  ChannelCategory category,
) async {
  final name = await promptForName(
    context,
    title: 'Rename Folder',
    label: 'Name',
    initial: category.name,
    confirmLabel: 'Rename',
  );
  if (name == null || name.isEmpty || !context.mounted) return;
  await _run(context, () async {
    await ref.read(apiClientProvider).updateCategory(category.id, name);
    ref.invalidate(categoriesProvider(communityId));
  }, failureMessage: 'Failed to rename folder');
}

Future<void> deleteFolder(
  BuildContext context,
  WidgetRef ref,
  String communityId,
  ChannelCategory category,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Delete "${category.name}"? Channels inside it will no longer be in a folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;
  await _run(context, () async {
    await ref.read(apiClientProvider).deleteCategory(category.id);
    ref.invalidate(categoriesProvider(communityId));
    ref.invalidate(channelsProvider(communityId));
  }, failureMessage: 'Failed to delete folder');
}

/// Moves a channel into a folder, offering to create a new folder inline.
Future<void> moveChannel(
  BuildContext context,
  WidgetRef ref,
  String communityId,
  Channel channel,
) async {
  final categories = await ref.read(categoriesProvider(communityId).future);
  if (!context.mounted) return;

  final selected = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                'Move "#${channel.name}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...categories.map((category) {
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(category.name),
                selected: channel.categoryId == category.id,
                onTap: () => Navigator.of(sheetContext).pop(category.id),
              );
            }),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New Folder'),
              onTap: () => Navigator.of(sheetContext).pop('__new__'),
            ),
          ],
        ),
      );
    },
  );

  String? targetFolderId = selected;
  if (selected == '__new__') {
    if (!context.mounted) return;
    final name = await promptForName(
      context,
      title: 'New Folder',
      label: 'Name',
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    targetFolderId = await _run(context, () async {
      final folder = await ref
          .read(apiClientProvider)
          .createCategory(communityId, name);
      ref.invalidate(categoriesProvider(communityId));
      return folder.id;
    }, failureMessage: 'Failed to create folder');
  }

  if (targetFolderId == null || !context.mounted) return;
  await _run(context, () async {
    await ref
        .read(apiClientProvider)
        .updateChannel(channel.id, categoryId: targetFolderId);
    ref.invalidate(channelsProvider(communityId));
  }, failureMessage: 'Failed to move channel');
}

/// Runs a mutation, reporting failures with a log line and a snack bar.
Future<T?> _run<T>(
  BuildContext context,
  Future<T> Function() action, {
  required String failureMessage,
}) async {
  try {
    return await action();
  } catch (e) {
    debugPrint('$failureMessage: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
    return null;
  }
}
