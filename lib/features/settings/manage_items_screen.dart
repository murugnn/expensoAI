import 'package:flutter/material.dart';

class ManageItemsScreen extends StatefulWidget {
  final String title;
  final List<String> items;
  final Function(String) onAdd;
  final Function(String) onDelete;

  const ManageItemsScreen({
    super.key,
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<ManageItemsScreen> createState() => _ManageItemsScreenState();
}

class _ManageItemsScreenState extends State<ManageItemsScreen> {
  final _controller = TextEditingController();

  void _addItem() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onAdd(_controller.text.trim());
      _controller.clear();
      Navigator.pop(context);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add New ${widget.title}"),
        content: TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: "Enter ${widget.title} name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(onPressed: _addItem, child: const Text("Add")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage ${widget.title}s")),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              title: Text(item,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => widget.onDelete(item),
              ),
            ),
          );
        },
      ),
    );
  }
}
