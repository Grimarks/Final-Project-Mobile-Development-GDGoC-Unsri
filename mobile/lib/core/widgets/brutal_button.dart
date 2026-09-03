import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/brutal_decorations.dart';
import '../theme/text_styles.dart';

// tombol brutalist, pas dipencet geser dikit + shadow ngecil, efek kaya di-stempel
class BrutalButton extends StatefulWidget {
  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fill = AppColors.primary,
    this.labelColor = Colors.white,
    this.shadowColor = AppColors.ink,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    this.fontSize = 13,
    this.expand = true,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color fill;
  final Color labelColor;
  final Color shadowColor;
  final EdgeInsets padding;
  final double fontSize;
  final bool expand;
  final bool enabled;
  final bool loading;

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _pressed = false;

  bool get _active => widget.enabled && !widget.loading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final offset = _pressed ? 2.0 : 4.0;
    final child = Container(
      width: widget.expand ? double.infinity : null,
      padding: widget.padding,
      decoration: Brutal.box(
        fill: _active ? widget.fill : widget.fill.withOpacity(0.45),
        shadowOffset: offset,
        shadowColor: widget.shadowColor,
      ),
      alignment: Alignment.center,
      child: widget.loading
          ? SizedBox(
              height: widget.fontSize + 4,
              width: widget.fontSize + 4,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.labelColor),
            )
          : Text(
              widget.label.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppText.label(widget.fontSize, color: widget.labelColor),
            ),
    );

    return GestureDetector(
      onTapDown: _active
          ? (_) {
              HapticFeedback.lightImpact(); // biar getarnya nyambung sama animasi stempel
              setState(() => _pressed = true);
            }
          : null,
      onTapUp: _active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _active ? () => setState(() => _pressed = false) : null,
      onTap: _active ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(_pressed ? 2 : 0, _pressed ? 2 : 0, 0),
        child: child,
      ),
    );
  }
}
