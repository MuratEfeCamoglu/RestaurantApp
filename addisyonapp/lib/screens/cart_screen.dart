import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'bill_list_screen.dart';

/// 4. Sepet — seçili masanın gönderilmeyi bekleyen ürünleri.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _submitting = false;

  /// Menü masa seçmeden de gezilebildiği için sepet masasız dolmuş olabilir;
  /// sipariş gönderilirken masa burada seçilir.
  Future<RestaurantTable?> _pickTable(RestaurantState state) {
    return showModalBottomSheet<RestaurantTable>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) {
        final tables = state.tables;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text('Sipariş hangi masaya?', style: AppText.heading(size: 20)),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: tables.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final t = tables[i];
                      return Material(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(sheetContext).pop(t),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.name, style: AppText.body(size: 14, weight: FontWeight.w700)),
                                      Text(t.area, style: AppText.body(size: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  label: t.label,
                                  fg: t.status == TableStatus.available ? AppColors.green : AppColors.accent,
                                  bg: t.status == TableStatus.available ? AppColors.greenBg : AppColors.chipBg,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit(RestaurantState state) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      if (state.selectedTable == null) {
        final picked = await _pickTable(state);
        if (picked == null) return;
        // Boş masa seçildiyse burada açılır (masa → mutfak adımının başı).
        await state.selectTable(picked);
        if (!mounted) return;
      }
      final order = await state.submitOrder();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderConfirmationScreen(order: order)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sipariş göndermek için önce bir masa seçin.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    final table = state.selectedTable;
    final cart = state.cart;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sepetiniz', style: AppText.heading(size: 26)),
                        const SizedBox(height: 2),
                        Text(
                          table == null
                              ? 'Masa seçilmedi'
                              : '${table.name} · ${table.guests} kişi',
                          style: AppText.body(size: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: cart.isEmpty
                  ? Center(
                      child: Text('Sepetiniz boş', style: AppText.body(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      itemCount: cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _CartTile(item: cart[i]),
                    ),
            ),
            if (cart.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    _SummaryRow(label: 'Ara toplam', value: formatTL(state.cartSubtotal)),
                    const SizedBox(height: 4),
                    _SummaryRow(label: 'Servis bedeli (%10)', value: formatTL(state.cartServiceFee)),
                    const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'Toplam',
                      value: formatTL(state.cartTotal),
                      big: true,
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: _submitting ? 'Gönderiliyor…' : (table == null ? 'Masa Seç ve Gönder' : 'Siparişi Gönder'),
                      onTap: _submitting ? null : () => _submit(state),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.big = false});

  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final style = big
        ? AppText.body(size: 16, weight: FontWeight.w700)
        : AppText.body(size: 12, color: AppColors.textMuted);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.read<RestaurantState>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: StripedPlaceholder(
                colorA: item.item.stripeA,
                colorB: item.item.stripeB,
                showLabel: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.item.name,
                        style: AppText.body(size: 13, weight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      formatTL(item.lineTotal),
                      style: AppText.body(size: 13, weight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(item.noteLabel, style: AppText.body(size: 11, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    RoundStepButton(
                      icon: Icons.remove,
                      onTap: () => state.decrementCartItem(item),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${item.qty}',
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 13, weight: FontWeight.w700),
                      ),
                    ),
                    RoundStepButton(
                      icon: Icons.add,
                      filled: true,
                      onTap: () => state.incrementCartItem(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 5. Sipariş Onayı — sipariş mutfağa iletildikten sonra gösterilen ekran.
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key, required this.order});

  final SubmittedOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sipariş Mutfağa İletildi',
                      textAlign: TextAlign.center,
                      style: AppText.heading(size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${order.table.name} için siparişiniz alındı.\nTahmini hazırlanma süresi 18 dakika.',
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 13, color: AppColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(label: 'Sipariş No', value: '#${order.orderNumber}'),
                          const SizedBox(height: 10),
                          _InfoRow(label: 'Masa', value: order.table.name),
                          const SizedBox(height: 10),
                          _InfoRow(
                            label: 'Ürün Sayısı',
                            value: '${order.itemCount} ürün · ${formatTL(order.total)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  PrimaryButton(
                    label: 'Siparişi Görüntüle',
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.popUntil((route) => route.isFirst);
                      navigator.push(MaterialPageRoute(builder: (_) => BillDetailScreen(table: order.table)));
                    },
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: 'Menüye Dön',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.body(size: 12, color: AppColors.textMuted)),
        Text(value, style: AppText.body(size: 12, weight: FontWeight.w600)),
      ],
    );
  }
}
