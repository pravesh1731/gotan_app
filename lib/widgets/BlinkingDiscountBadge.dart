import 'package:flutter/material.dart';

class BlinkingDiscountBadge extends StatefulWidget {
  final double price;
  final double discountPrice;

  const BlinkingDiscountBadge({
    Key? key,
    required this.price,
    required this.discountPrice,
  }) : super(key: key);

  @override
  State<BlinkingDiscountBadge> createState() => _BlinkingDiscountBadgeState();
}

class _BlinkingDiscountBadgeState extends State<BlinkingDiscountBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double price = widget.price;
    final double discountPrice = widget.discountPrice;

    final int discount =
    (((price - discountPrice) / price) * 100).round();

    return Positioned(
      right: 8,
      top: 8,
      child: FadeTransition(
        opacity: _animation,
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$discount% OFF',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      ),
    );
  }
}
