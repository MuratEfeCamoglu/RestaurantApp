import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// HTML prototipindeki `repeating-linear-gradient(45deg, ...)` ürün fotoğrafı
/// yer tutucusunun karşılığı: çapraz çizgili desen + ortada etiket.
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({
    super.key,
    required this.colorA,
    required this.colorB,
    this.stripeWidth = 10,
    this.borderRadius = BorderRadius.zero,
    this.label = 'ürün fotoğrafı',
    this.showLabel = true,
  });

  final Color colorA;
  final Color colorB;
  final double stripeWidth;
  final BorderRadius borderRadius;
  final String label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _StripePainter(colorA, colorB, stripeWidth)),
          if (showLabel)
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppColors.textDark.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.colorA, this.colorB, this.stripeWidth);

  final Color colorA;
  final Color colorB;
  final double stripeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colorA);
    final paintB = Paint()..color = colorB;
    canvas.save();
    canvas.rotate(45 * math.pi / 180);
    final diag = (size.width + size.height) * 1.5;
    var x = -diag;
    while (x < diag) {
      canvas.drawRect(Rect.fromLTWH(x + stripeWidth, -diag, stripeWidth, diag * 2), paintB);
      x += stripeWidth * 2;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      oldDelegate.colorA != colorA || oldDelegate.colorB != colorB || oldDelegate.stripeWidth != stripeWidth;
}

/// Koyu zeminli birincil aksiyon butonu (örn. "Siparişi Gönder").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.textDark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(label, style: AppText.body(size: 14, weight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Açık zeminli ikincil aksiyon butonu (örn. "Menüye Dön").
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(label, style: AppText.body(size: 14, weight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// -/+ dairesel adet düğmeleri.
class RoundStepButton extends StatelessWidget {
  const RoundStepButton({super.key, required this.icon, this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.textDark : AppColors.chipBg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(icon, size: 15, color: filled ? Colors.white : AppColors.textDark),
        ),
      ),
    );
  }
}

/// Kategori/filtre çipi.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.active, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.textDark : AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: active ? null : Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: AppText.body(
              size: 12,
              weight: FontWeight.w600,
              color: active ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// Durum rozeti (örn. "AÇIK", "ÖDEME BEKLİYOR").
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: AppText.body(size: 10, weight: FontWeight.w700, color: fg)),
    );
  }
}
