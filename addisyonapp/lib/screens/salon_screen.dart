import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../navigation.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/common.dart';
import 'menu_screen.dart';
import 'table_management_screen.dart';

/// 1. Salon — masa durumlarının görüldüğü ana ekran.
class SalonScreen extends StatefulWidget {
  const SalonScreen({super.key});

  @override
  State<SalonScreen> createState() => _SalonScreenState();
}

class _SalonScreenState extends State<SalonScreen> {
  String? _selectedArea;
  bool _opening = false;

  void _goToTab(int index) => goToTab(context, current: AppTab.salon, target: index);

  Future<void> _openTable(RestaurantState state, RestaurantTable table) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await state.selectTable(table);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MenuScreen()));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();

    if (state.isLoading && state.tables.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (state.error != null && state.tables.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 40, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text('Sunucuya bağlanılamadı', style: AppText.heading(size: 18)),
                const SizedBox(height: 6),
                Text(
                  state.error!,
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                PrimaryButton(label: 'Tekrar Dene', onTap: () => state.refresh()),
              ],
            ),
          ),
        ),
      );
    }

    final areaNames = state.areas.map((a) => a.name).toList();
    final currentArea =
        (_selectedArea != null && areaNames.contains(_selectedArea)) ? _selectedArea! : (areaNames.isNotEmpty ? areaNames.first : '');
    final visibleTables = state.tables.where((t) => t.area == currentArea).toList();
    final now = TimeOfDay.now();
    final timeLabel =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LİMON & ZEYTİN', style: AppText.eyebrow()),
                            const SizedBox(height: 2),
                            Text('Akşam Servisi', style: AppText.heading(size: 28)),
                          ],
                        ),
                      ),
                      Material(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TableManagementScreen()),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.table_restaurant_outlined, size: 15, color: AppColors.textDark),
                                const SizedBox(width: 6),
                                Text('Masalar', style: AppText.body(size: 13, weight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const _StatusDot(color: AppColors.green),
                      const SizedBox(width: 6),
                      Text(
                        '$timeLabel · ${state.openTableCount} açık masa · ${state.tables.length} masa',
                        style: AppText.body(size: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(dotColor: AppColors.green, value: state.availableCount, label: 'Müsait'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(dotColor: AppColors.accent, value: state.occupiedCount, label: 'Dolu'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      dotColor: AppColors.red,
                      value: state.billPendingCount,
                      label: 'Hesap Bekliyor',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: areaNames.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final area = areaNames[i];
                  return AppChip(
                    label: area,
                    active: area == currentArea,
                    onTap: () => setState(() => _selectedArea = area),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                onRefresh: state.refresh,
                child: visibleTables.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 240,
                            child: Center(
                              child: Text(
                                areaNames.isEmpty ? 'Henüz alan yok' : 'Bu alanda masa yok',
                                style: AppText.body(color: AppColors.textMuted),
                              ),
                            ),
                          ),
                        ],
                      )
                    : GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.7,
                        ),
                        itemCount: visibleTables.length,
                        itemBuilder: (context, i) => _TableCard(
                          table: visibleTables[i],
                          onTap: () => _openTable(state, visibleTables[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: AppTab.salon, onTap: _goToTab),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.dotColor, required this.value, required this.label});

  final Color dotColor;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(height: 8),
          Text('$value', style: AppText.body(size: 18, weight: FontWeight.w700)),
          Text(label, style: AppText.body(size: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table, required this.onTap});

  final RestaurantTable table;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOccupied = table.status == TableStatus.occupied;
    final Color bg;
    final Color textColor;
    final Color subTextColor;
    final Color tagColor;
    final Color tagBg;
    Border? border;

    switch (table.status) {
      case TableStatus.occupied:
        bg = AppColors.accent;
        textColor = Colors.white;
        subTextColor = Colors.white.withValues(alpha: 0.75);
        tagColor = Colors.white;
        tagBg = Colors.white.withValues(alpha: 0.2);
        break;
      case TableStatus.available:
        bg = AppColors.card;
        textColor = AppColors.textDark;
        subTextColor = AppColors.textMuted;
        tagColor = AppColors.green;
        tagBg = AppColors.greenBg;
        border = Border.all(color: AppColors.green, width: 1.5);
        break;
      case TableStatus.billPending:
        bg = AppColors.card;
        textColor = AppColors.textDark;
        subTextColor = AppColors.textMuted;
        tagColor = AppColors.red;
        tagBg = AppColors.redBg;
        border = Border.all(color: AppColors.red, width: 1.5);
        break;
      case TableStatus.empty:
        bg = AppColors.card;
        textColor = AppColors.placeholder;
        subTextColor = AppColors.textFaint;
        tagColor = AppColors.placeholder;
        tagBg = AppColors.placeholderBg;
        border = Border.all(color: AppColors.border);
        break;
    }
    if (!isOccupied) border ??= Border.all(color: AppColors.border);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: border),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      table.name,
                      style: AppText.body(size: 14, weight: FontWeight.w700, color: textColor),
                    ),
                  ),
                  StatusBadge(label: table.label, fg: tagColor, bg: tagBg),
                ],
              ),
              Text(
                table.status == TableStatus.available || table.status == TableStatus.empty
                    ? '—'
                    : '${table.guests} kişi · ${table.timeLabel}',
                style: AppText.body(size: 11, color: subTextColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
