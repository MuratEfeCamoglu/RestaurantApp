import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../navigation.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/common.dart';

/// Mutfak — o sırada hazırlanan siparişleri masa bazında gösterir.
/// Döngü: Masa → Mutfak → Hesap → Ödeme.
class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  static const _pollInterval = Duration(seconds: 10);

  Timer? _timer;
  bool _loading = true;
  String? _error;
  int? _busyOrderId;

  @override
  void initState() {
    super.initState();
    _load();
    // Başka bir cihazdan gönderilen siparişler de kendiliğinden düşsün.
    _timer = Timer.periodic(_pollInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final state = context.read<RestaurantState>();
    try {
      await state.loadKitchen();
      if (mounted) setState(() => _error = null);
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _markServed(KitchenOrder order) async {
    if (_busyOrderId != null) return;
    setState(() => _busyOrderId = order.id);
    try {
      await context.read<RestaurantState>().markOrderServed(order);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    final tickets = state.kitchen;
    final orderCount = tickets.fold<int>(0, (sum, t) => sum + t.orders.length);

    Widget body;
    if (_loading && tickets.isEmpty) {
      body = const Center(child: CircularProgressIndicator(color: AppColors.accent));
    } else if (_error != null && tickets.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: AppText.body(color: AppColors.textMuted)),
              const SizedBox(height: 12),
              SecondaryButton(label: 'Tekrar Dene', onTap: _load),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: tickets.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 360,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(color: AppColors.chipBg, shape: BoxShape.circle),
                            child: const Icon(Icons.soup_kitchen_outlined, size: 28, color: AppColors.copper),
                          ),
                          const SizedBox(height: 14),
                          Text('Mutfakta bekleyen sipariş yok', style: AppText.body(size: 15, weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            'Sipariş gönderildiğinde masa burada görünür.',
                            textAlign: TextAlign.center,
                            style: AppText.body(size: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: tickets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _KitchenTicketCard(
                  ticket: tickets[i],
                  busyOrderId: _busyOrderId,
                  onServed: _markServed,
                ),
              ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MUTFAK', style: AppText.eyebrow()),
                        const SizedBox(height: 2),
                        Text('Hazırlananlar', style: AppText.heading(size: 26)),
                        const SizedBox(height: 2),
                        Text(
                          '${tickets.length} masa · $orderCount sipariş hazırlanıyor',
                          style: AppText.body(size: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: AppTab.kitchen,
        onTap: (i) => goToTab(context, current: AppTab.kitchen, target: i),
      ),
    );
  }
}

class _KitchenTicketCard extends StatelessWidget {
  const _KitchenTicketCard({required this.ticket, required this.busyOrderId, required this.onServed});

  final KitchenTicket ticket;
  final int? busyOrderId;
  final ValueChanged<KitchenOrder> onServed;

  @override
  Widget build(BuildContext context) {
    final table = ticket.table;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(table.name, style: AppText.body(size: 15, weight: FontWeight.w700)),
                    Text(
                      '${table.area} · ${table.guests} kişi',
                      style: AppText.body(size: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const StatusBadge(label: 'HAZIRLANIYOR', fg: AppColors.accent, bg: AppColors.chipBg),
            ],
          ),
          for (final order in ticket.orders) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('#${order.orderNumber}', style: AppText.body(size: 12, weight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text(
                  '${order.ageLabel} önce · ${order.itemCount} ürün',
                  style: AppText.body(size: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${line.qty}×',
                        style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.accentDark),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.name, style: AppText.body(size: 13, weight: FontWeight.w600)),
                          if (line.note.trim().isNotEmpty)
                            Text(line.note.trim(), style: AppText.body(size: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            PrimaryButton(
              label: busyOrderId == order.id ? '…' : 'Hazır · Servis Edildi',
              icon: Icons.check,
              onTap: busyOrderId != null ? null : () => onServed(order),
            ),
          ],
        ],
      ),
    );
  }
}
