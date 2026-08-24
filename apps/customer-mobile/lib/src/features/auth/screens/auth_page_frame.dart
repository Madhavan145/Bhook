import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/widgets.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= CustomerBreakpoints.tablet;
    final form = CustomerContentBound(maxWidth: 520, child: child);
    return Scaffold(
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  const Expanded(flex: 5, child: _AuthBrandPanel()),
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(BhookSpacing.xl),
                      child: form,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(BhookSpacing.screenPad,
                    BhookSpacing.xl, BhookSpacing.screenPad, BhookSpacing.xxl),
                child: Column(
                  children: [
                    const PlayfulBanner(
                      title: 'WELCOME TO BHOOK',
                      subtitle: 'Your campus, your cravings, your crew.',
                      icon: Icons.restaurant_rounded,
                      color: BhookColors.mustard,
                      margin: EdgeInsets.zero,
                    ),
                    const SizedBox(height: BhookSpacing.xl),
                    form,
                  ],
                ),
              ),
      ),
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(BhookSpacing.lg),
      padding: const EdgeInsets.all(BhookSpacing.xxl),
      decoration: BoxDecoration(
        color: BhookColors.mustard,
        borderRadius: BorderRadius.circular(BhookRadius.xl),
        border: Border.all(color: BhookColors.inkStrong, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: BhookColors.inkStrong,
            offset: Offset(6, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: BhookColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: BhookSpacing.xl),
          Text('Bhook', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: BhookSpacing.sm),
          const Text(
            'Campus food, made social.',
            style: TextStyle(
              color: BhookColors.inkStrong,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: BhookSpacing.md),
          const Text(
            'Find the kitchens around you, share the good stuff, and make your next meal feel like yours.',
            style: TextStyle(
              color: BhookColors.ink,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const Spacer(),
          const Row(
            children: [
              Icon(Icons.local_fire_department_outlined, size: 18),
              SizedBox(width: 6),
              Text('Good food is better together',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
