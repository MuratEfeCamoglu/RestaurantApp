import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../navigation.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/common.dart';

/// Hesaplar — açık/ödeme bekleyen masaların listelendiği ekran.
class BillListScreen extends StatelessWidget {
  const BillListScreen({super.key});

  void _goToTab(BuildContext context, int index) => goToTab(context, current: AppTab.bills, target: index);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    final tables = state.tablesWithOpenBill;
    final pendingCount = tables.where((t) => t.status == TableStatus.billPending).length;
    final totalAmount = tables.fold<int>(0, (sum, t) => sum + t.billGrandTotal);

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
                  Text('HESAPLAR', style: AppText.eyebrow()),
                  const SizedBox(height: 2),
                  Text('Açık Hesaplar', style: AppText.heading(size: 26)),
                ],
              ),
            ),
            if (tables.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.table_bar_outlined,
                        dotColor: AppColors.accent,
                        value: '${tables.length}',
                        label: 'Açık masa',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.hourglass_bottom,
                        dotColor: AppColors.red,
                        value: '$pendingCount',
                        label: 'Ödeme bekliyor',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.payments_outlined,
                        dotColor: AppColors.green,
                        value: formatTL(totalAmount),
                        label: 'Toplam tutar',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                onRefresh: state.refresh,
                child: tables.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 400,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: const BoxDecoration(
                                      color: AppColors.chipBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 28,
                                      color: AppColors.copper,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text('Açık hesap yok', style: AppText.body(size: 15, weight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bir masa açtığınızda hesabı burada görünür.',
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
                        itemCount: tables.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _BillTile(table: tables[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: AppTab.bills, onTap: (i) => _goToTab(context, i)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.dotColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color dotColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: dotColor),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 15, weight: FontWeight.w700),
          ),
          Text(label, style: AppText.body(size: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.table});

  final RestaurantTable table;

  @override
  Widget build(BuildContext context) {
    final isPending = table.status == TableStatus.billPending;
    final accentColor = isPending ? AppColors.red : AppColors.green;
    final accentBg = isPending ? AppColors.redBg : AppColors.greenBg;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BillDetailScreen(table: table)),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: isPending ? AppColors.red.withValues(alpha: 0.35) : AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: accentBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  isPending ? Icons.receipt_long : Icons.table_restaurant,
                  size: 20,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            table.name,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 14, weight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: isPending ? 'ÖDEME BEKLİYOR' : (table.kitchenCount > 0 ? 'MUTFAKTA' : 'AÇIK'),
                          fg: accentColor,
                          bg: accentBg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${table.area} · ${table.guests} kişi · ${table.timeLabel}',
                      style: AppText.body(size: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatTL(table.billGrandTotal),
                    style: AppText.body(size: 15, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textFaint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 6. Hesap Detayı — bir masanın hesabının detayı ve ödeme alma aksiyonu.
class BillDetailScreen extends StatefulWidget {
  const BillDetailScreen({super.key, required this.table});

  final RestaurantTable table;

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  late Future<BillDetail> _billFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _billFuture = _load();
  }

  Future<BillDetail> _load() {
    return context.read<RestaurantState>().fetchBill(widget.table);
  }

  void _reload() {
    // Blok gövde şart: ok fonksiyonu Future döndürürse setState assert atar
    // ve "Tekrar Dene" ekranı yenilemez.
    setState(() {
      _billFuture = _load();
    });
  }

  Future<void> _requestBill() async {
    setState(() => _busy = true);
    try {
      await context.read<RestaurantState>().requestBill(widget.table);
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settle() async {
    setState(() => _busy = true);
    try {
      await context.read<RestaurantState>().settleBill(widget.table);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Salon ekranındaki liste güncellendiğinde başlıktaki durum da tazelensin.
    final table = context.watch<RestaurantState>().tables.firstWhere(
          (t) => t.id == widget.table.id,
          orElse: () => widget.table,
        );
    final isPending = table.status == TableStatus.billPending;
    final isOccupied = table.status == TableStatus.occupied;

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
                        Text('HESAP DETAYI', style: AppText.eyebrow()),
                        const SizedBox(height: 2),
                        Text(table.name, style: AppText.heading(size: 24)),
                        const SizedBox(height: 2),
                        Text(
                          '${table.guests} kişi · ${table.timeLabel} · ${table.area}',
                          style: AppText.body(size: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: isPending ? 'ÖDEME BEKLİYOR' : (table.kitchenCount > 0 ? 'MUTFAKTA' : 'AÇIK'),
                    fg: isPending ? AppColors.red : AppColors.green,
                    bg: isPending ? AppColors.redBg : AppColors.greenBg,
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<BillDetail>(
                future: _billFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                  }
                  if (snapshot.hasError) {
                    final message = snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : 'Hesap yüklenemedi.';
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(message, textAlign: TextAlign.center, style: AppText.body(color: AppColors.textMuted)),
                            const SizedBox(height: 12),
                            SecondaryButton(label: 'Tekrar Dene', onTap: _reload),
                          ],
                        ),
                      ),
                    );
                  }
                  final bill = snapshot.data!;
                  if (bill.items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(color: AppColors.chipBg, shape: BoxShape.circle),
                            child: const Icon(Icons.restaurant_menu, size: 24, color: AppColors.copper),
                          ),
                          const SizedBox(height: 12),
                          Text('Bu masada sipariş yok', style: AppText.body(size: 13, color: AppColors.textMuted)),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          for (final li in bill.items)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.border)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.chipBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${li.qty}',
                                      style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.accentDark),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(li.name, style: AppText.body(size: 13, weight: FontWeight.w600)),
                                        if (li.note.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              li.note.trim(),
                                              style: AppText.body(size: 11, color: AppColors.textMuted),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(formatTL(li.lineTotal), style: AppText.body(size: 13, weight: FontWeight.w700)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            FutureBuilder<BillDetail>(
              future: _billFuture,
              builder: (context, snapshot) {
                final bill = snapshot.data;
                final subtotal = bill?.subtotal ?? table.billTotal;
                final serviceFee = bill?.serviceFee ?? table.billServiceFee;
                final total = bill?.total ?? table.billGrandTotal;
                final hasItems = (bill?.items.isNotEmpty ?? false) || table.billTotal > 0;
                return Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(label: 'Ara toplam', value: formatTL(subtotal)),
                      const SizedBox(height: 4),
                      _SummaryRow(label: 'Servis bedeli (%10)', value: formatTL(serviceFee)),
                      const SizedBox(height: 10),
                      _SummaryRow(label: 'Toplam', value: formatTL(total), big: true),
                      const SizedBox(height: 14),
                      // Döngü: Masa → Mutfak → Hesap → Ödeme. Ödeme yalnızca hesap
                      // istendikten (masa "ödeme bekliyor" olduktan) sonra alınabilir.
                      if (isPending)
                        PrimaryButton(
                          // Hiç sipariş girilmemiş (yanlışlıkla açılmış) bir masa da
                          // kapatılabilmeli; yoksa masa sonsuza dek açık kalır.
                          label: _busy ? '…' : (hasItems ? 'Ödemeyi Al' : 'Masayı Kapat'),
                          onTap: _busy ? null : _settle,
                        )
                      else
                        PrimaryButton(
                          label: _busy ? '…' : 'Hesap İste',
                          onTap: (_busy || !isOccupied) ? null : _requestBill,
                        ),
                    ],
                  ),
                );
              },
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
