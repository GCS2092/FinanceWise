import 'package:flutter/material.dart';
import '../services/onboarding_tips_service.dart';

class TooltipItem {
  final IconData icon;
  final String title;
  final String description;

  const TooltipItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class OnboardingTooltip extends StatefulWidget {
  final String screenName;
  final String title;
  final String description;
  final Widget child;
  final List<TooltipItem>? additionalTips;
  final bool forceShow;
  final GlobalKey<OnboardingTooltipState>? tooltipKey;

  const OnboardingTooltip({
    super.key,
    required this.screenName,
    required this.title,
    required this.description,
    required this.child,
    this.additionalTips,
    this.forceShow = false,
    this.tooltipKey,
  });

  @override
  State<OnboardingTooltip> createState() => OnboardingTooltipState();
}

class OnboardingTooltipState extends State<OnboardingTooltip> {
  bool _showTooltip = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkIfShouldShow();
  }

  Future<void> _checkIfShouldShow() async {
    if (widget.forceShow) {
      setState(() {
        _showTooltip = true;
        _loading = false;
      });
      return;
    }

    final hasSeen = await OnboardingTipsService.hasSeenTip(widget.screenName);
    setState(() {
      _showTooltip = !hasSeen;
      _loading = false;
    });
  }

  Future<void> _markAsSeen() async {
    await OnboardingTipsService.markTipAsSeen(widget.screenName);
    setState(() => _showTooltip = false);
  }

  void showTooltip() {
    setState(() => _showTooltip = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_loading && _showTooltip)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lightbulb,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            if (widget.additionalTips != null && widget.additionalTips!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              ...widget.additionalTips!.map((tip) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          tip.icon,
                                          size: 20,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tip.title,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                tip.description,
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                            const SizedBox(height: 24),
                            Center(
                              child: ElevatedButton(
                                onPressed: _markAsSeen,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                ),
                                child: const Text('C\'est compris', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
