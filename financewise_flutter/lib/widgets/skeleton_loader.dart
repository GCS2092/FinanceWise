import 'package:flutter/material.dart';

/// Widget shimmer réutilisable pour les états de chargement
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton pour une Card du dashboard (solde)
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card skeleton
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SkeletonLoader(width: 80, height: 14),
                    const SizedBox(height: 12),
                    const SkeletonLoader(width: 180, height: 28),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: SkeletonLoader(height: 40)),
                        const SizedBox(width: 12),
                        const Expanded(child: SkeletonLoader(height: 40)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Quick actions skeleton
            Row(
              children: [
                Expanded(child: SkeletonLoader(height: 80, borderRadius: 12)),
                const SizedBox(width: 12),
                Expanded(child: SkeletonLoader(height: 80, borderRadius: 12)),
              ],
            ),
            const SizedBox(height: 20),
            // Section skeleton
            const SkeletonLoader(width: 120, height: 16),
            const SizedBox(height: 12),
            ...List.generate(3, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SkeletonLoader(height: 64, borderRadius: 12),
            )),
          ],
        ),
      ),
    );
  }
}

/// Skeleton pour une liste d'items (transactions, wallets, etc.)
class ListSkeleton extends StatelessWidget {
  final int itemCount;
  const ListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SkeletonLoader(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonLoader(width: 140, height: 14),
                    SizedBox(height: 8),
                    SkeletonLoader(width: 90, height: 12),
                  ],
                ),
              ),
              const SkeletonLoader(width: 70, height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
