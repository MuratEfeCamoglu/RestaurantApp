import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../navigation.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/common.dart';
import 'cart_screen.dart';

/// 2. Menü — seçili masa için ürünlerin listelendiği ekran.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _selectedCategory = 'Popüler';
  String _query = '';

  void _goToTab(int index) => goToTab(context, current: AppTab.menu, target: index);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    final table = state.selectedTable;
    final query = _query.trim().toLowerCase();
    final items = state.menu.where((m) {
      // Arama yapılırken kategori filtresi yok sayılır; aksi halde
      // "Popüler" seçiliyken popüler olmayan ürünler bulunamaz.
      if (query.isNotEmpty) return m.name.toLowerCase().contains(query);
      return _selectedCategory == 'Popüler' ? m.popular : m.category == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(table == null ? 'MENÜ' : 'AKTİF SİPARİŞ', style: AppText.eyebrow()),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    table?.name ?? 'Menü',
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.heading(size: 24),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (table != null)
                                  table.status == TableStatus.billPending
                                      ? const StatusBadge(label: 'HESAP', fg: AppColors.red, bg: AppColors.redBg)
                                      : const StatusBadge(label: 'AÇIK', fg: AppColors.green, bg: AppColors.greenBg),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              table == null
                                  ? 'Masa seçmeden menüye göz atabilirsiniz'
                                  : '${table.guests} kişi · ${table.timeLabel}',
                              style: AppText.body(size: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sync_alt, size: 14, color: AppColors.textDark),
                                const SizedBox(width: 6),
                                Text(table == null ? 'Masa Seç' : 'Masa Değiştir', style: AppText.body(size: 12, weight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Menüde ara',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            style: AppText.body(size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: state.categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final category = state.categories[i];
                      return AppChip(
                        label: category,
                        active: category == _selectedCategory,
                        onTap: () => setState(() => _selectedCategory = category),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text('Ürün bulunamadı', style: AppText.body(color: AppColors.textMuted)),
                        )
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(20, 4, 20, state.cartItemCount > 0 ? 100 : 20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            // Kart içeriği sabit yükseklikte; oran kullanmak dar
                            // ekranlarda (320 px) taşmaya yol açıyordu.
                            mainAxisExtent: 190,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, i) => _MenuItemCard(item: items[i]),
                        ),
                ),
              ],
            ),
            if (state.cartItemCount > 0)
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: Material(
                  color: AppColors.textDark,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.shopping_basket_outlined, size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${state.cartItemCount} ürün · ${formatTL(state.cartSubtotal)}',
                                    style: AppText.body(size: 12, weight: FontWeight.w700, color: Colors.white),
                                  ),
                                  Text(
                                    table == null ? 'Sipariş için masa seçilecek' : '${table.name} sipariş özeti',
                                    style: AppText.body(size: 10, color: Colors.white.withValues(alpha: 0.55)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Sepeti Gör', style: AppText.body(size: 12, weight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: AppTab.menu, onTap: _goToTab),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.read<RestaurantState>();
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductDetailScreen(item: item)),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 88,
                width: double.infinity,
                child: StripedPlaceholder(colorA: item.stripeA, colorB: item.stripeB),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 34,
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 13, weight: FontWeight.w600, height: 1.3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatTL(item.price), style: AppText.body(size: 14, weight: FontWeight.w700)),
                        RoundStepButton(
                          icon: Icons.add,
                          filled: true,
                          onTap: () => state.addToCart(item),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3. Ürün Detayı — bir ürüne not ekleyip sepete eklemek için kullanılır.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.item});

  final MenuItem item;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<RestaurantState>();
    final item = widget.item;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 240,
                    width: double.infinity,
                    child: StripedPlaceholder(colorA: item.stripeA, colorB: item.stripeB, stripeWidth: 12),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20, top: 8),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(),
                            child: const SizedBox(
                              width: 38,
                              height: 38,
                              child: Icon(Icons.arrow_back, size: 18, color: AppColors.textDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.category.toUpperCase(), style: AppText.eyebrow()),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(item.name, style: AppText.heading(size: 24))),
                          Text(formatTL(item.price), style: AppText.heading(size: 20)),
                        ],
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          item.description,
                          style: AppText.body(size: 13, color: AppColors.textMuted, height: 1.6),
                        ),
                      ],
                      if (item.tags.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in item.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(tag, style: AppText.body(size: 11, color: AppColors.textMuted)),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Text('Not ekle', style: AppText.body(size: 13, weight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _noteController,
                          minLines: 2,
                          maxLines: 4,
                          style: AppText.body(size: 12),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                            hintText: 'örn. az pişmiş, truf yağı ekstra…',
                            hintStyle: AppText.body(size: 12, color: AppColors.placeholder),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      RoundStepButton(
                        icon: Icons.remove,
                        onTap: () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '$_qty',
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 14, weight: FontWeight.w700),
                        ),
                      ),
                      RoundStepButton(
                        icon: Icons.add,
                        filled: true,
                        onTap: () => setState(() => _qty++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Sepete Ekle · ${formatTL(item.price * _qty)}',
                    onTap: () {
                      state.addToCart(item, qty: _qty, note: _noteController.text);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
