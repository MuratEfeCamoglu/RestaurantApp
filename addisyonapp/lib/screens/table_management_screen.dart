import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';

/// Masa yönetimi — masa ekleme/düzenleme/silme ve yeni alan oluşturma.
/// Salon ekranındaki "Masalar" düğmesinden açılır.
class TableManagementScreen extends StatelessWidget {
  const TableManagementScreen({super.key});

  Future<void> _addTable(BuildContext context, RestaurantState state) async {
    if (state.areas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir alan oluşturmalısınız.')),
      );
      return;
    }
    final result = await showDialog<_TableFormResult>(
      context: context,
      builder: (_) => _TableFormDialog(
        title: 'Masa Ekle',
        initialName: state.suggestTableName(),
        areas: state.areas,
        initialAreaId: state.areas.first.id,
      ),
    );
    if (result == null) return;
    try {
      await state.createTable(name: result.name, areaId: result.areaId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.name} eklendi.')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _editTable(BuildContext context, RestaurantState state, RestaurantTable table) async {
    final result = await showDialog<_TableFormResult>(
      context: context,
      builder: (_) => _TableFormDialog(
        title: 'Masayı Düzenle',
        initialName: table.name,
        areas: state.areas,
        initialAreaId: table.areaId,
      ),
    );
    if (result == null) return;
    try {
      await state.updateTable(table, name: result.name, areaId: result.areaId);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteTable(BuildContext context, RestaurantState state, RestaurantTable table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masayı sil'),
        content: Text('${table.name} kalıcı olarak silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await state.deleteTable(table);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _addArea(BuildContext context, RestaurantState state) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Alan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'örn. Çatı Katı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await state.createArea(name);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MASA YÖNETİMİ', style: AppText.eyebrow()),
                        const SizedBox(height: 2),
                        Text('${state.tables.length} masa · ${state.areas.length} alan', style: AppText.heading(size: 22)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Yeni alan ekle',
                    onPressed: () => _addArea(context, state),
                    icon: const Icon(Icons.add_business_outlined, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.areas.isEmpty
                  ? Center(child: Text('Henüz alan yok', style: AppText.body(color: AppColors.textMuted)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      children: [
                        for (final area in state.areas) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(area.name, style: AppText.body(size: 13, weight: FontWeight.w700)),
                          ),
                          for (final table in state.tables.where((t) => t.areaId == area.id))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TableRow(
                                table: table,
                                onEdit: () => _editTable(context, state, table),
                                onDelete: () => _deleteTable(context, state, table),
                              ),
                            ),
                          if (state.tables.where((t) => t.areaId == area.id).isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('Bu alanda masa yok', style: AppText.body(size: 12, color: AppColors.textMuted)),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.textDark,
        onPressed: () => _addTable(context, state),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Masa Ekle', style: AppText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.table, required this.onEdit, required this.onDelete});

  final RestaurantTable table;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final canDelete = table.status == TableStatus.available || table.status == TableStatus.empty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(table.name, style: AppText.body(size: 13, weight: FontWeight.w700)),
                Text(table.label, style: AppText.body(size: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Düzenle',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textDark),
          ),
          IconButton(
            tooltip: canDelete ? 'Sil' : 'Açık hesabı olan masa silinemez',
            onPressed: canDelete ? onDelete : null,
            icon: Icon(Icons.delete_outline, size: 18, color: canDelete ? AppColors.red : AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

class _TableFormResult {
  _TableFormResult(this.name, this.areaId);
  final String name;
  final int areaId;
}

class _TableFormDialog extends StatefulWidget {
  const _TableFormDialog({
    required this.title,
    required this.initialName,
    required this.areas,
    required this.initialAreaId,
  });

  final String title;
  final String initialName;
  final List<RestaurantArea> areas;
  final int initialAreaId;

  @override
  State<_TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends State<_TableFormDialog> {
  late final TextEditingController _nameController;
  late int _areaId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _areaId = widget.initialAreaId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Masa adı'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _areaId,
            decoration: const InputDecoration(labelText: 'Alan'),
            items: [
              for (final area in widget.areas) DropdownMenuItem(value: area.id, child: Text(area.name)),
            ],
            onChanged: (v) => setState(() => _areaId = v ?? _areaId),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(_TableFormResult(name, _areaId));
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
