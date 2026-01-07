import 'dart:async';

import 'package:flutter/material.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';

class LoginShowcaseCarousel extends StatefulWidget {
  const LoginShowcaseCarousel({
    super.key,
    this.autoPlay = true,
    this.showSkip = true,
    this.onSkip,
    this.widthFactor = 1,
  }) : assert(widthFactor > 0 && widthFactor <= 1);

  final bool autoPlay;
  final bool showSkip;
  final VoidCallback? onSkip;
  final double widthFactor;

  @override
  State<LoginShowcaseCarousel> createState() => _LoginShowcaseCarouselState();
}

class _LoginShowcaseCarouselState extends State<LoginShowcaseCarousel> {
  static const _autoAdvanceInterval = Duration(seconds: 6);
  static const _slides = <_ShowcaseSlide>[
    _ShowcaseSlide(
      assetPath: 'assets/onboarding/home.png',
      headline: 'Scoring Engine',
      subtext: 'Instant AFT totals with profile-aware pass/fail validation.',
      chips: ['Latest Standards', 'Export to DA-705'],
    ),
    _ShowcaseSlide(
      assetPath: 'assets/onboarding/proctor.png',
      headline: 'Proctor Toolkit',
      subtext:
          'Run multi-soldier sessions with guided tools and workflow shortcuts.',
      chips: ['Grader Tools', 'Timing tools', 'Instructions'],
    ),
    _ShowcaseSlide(
      assetPath: 'assets/onboarding/standards.png',
      headline: 'Standards Matrix',
      subtext:
          'Precision lookups across ages, gender, events, and combat modifiers.',
      chips: ['Point tables', 'Combat rules'],
    ),
  ];

  final PageController _pageController = PageController();
  Timer? _autoTimer;
  DateTime _lastInteraction = DateTime.fromMillisecondsSinceEpoch(0);
  int _activePage = 0;
  bool _didPrecache = false;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(LoginShowcaseCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay != widget.autoPlay) {
      if (widget.autoPlay) {
        _startAutoPlay();
      } else {
        _autoTimer?.cancel();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    for (final slide in _slides) {
      precacheImage(AssetImage(slide.assetPath), context);
    }
    _didPrecache = true;
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    if (!widget.autoPlay) return;
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final now = DateTime.now();
      if (now.difference(_lastInteraction) < _autoAdvanceInterval) return;
      final nextPage = (_activePage + 1) % _slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _markInteraction() {
    _lastInteraction = DateTime.now();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is UserScrollNotification ||
        notification is ScrollEndNotification) {
      _markInteraction();
    }
    return false;
  }

  void _handleSkip() {
    _markInteraction();
    if (widget.onSkip != null) {
      widget.onSkip!();
      return;
    }
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      _slides.length - 1,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.widthFactor < 0.95;
    final radius = BorderRadius.circular(isCompact ? 18 : 20);
    final indicatorBottom = isCompact ? 10.0 : 14.0;
    final skipInset = isCompact ? 10.0 : 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * widget.widthFactor;
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: width,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ArmyNeutrals.bgDark,
                      border: Border.all(
                        color: ArmyColors.gold.withOpacity(0.45),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: _handleScrollNotification,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _slides.length,
                            onPageChanged: (index) {
                              setState(() => _activePage = index);
                              _markInteraction();
                            },
                            itemBuilder: (context, index) {
                              final slide = _slides[index];
                              return AnimatedBuilder(
                                animation: _pageController,
                                builder: (context, child) {
                                  double scale = 1;
                                  if (_pageController.hasClients &&
                                      _pageController.position.haveDimensions) {
                                    final page = _pageController.page ??
                                        _pageController.initialPage.toDouble();
                                    final delta = (page - index).abs();
                                    scale = (1 - delta * 0.06).clamp(0.94, 1.0);
                                  }
                                  return Transform.scale(
                                    scale: scale,
                                    child: child,
                                  );
                                },
                                child: _buildSlide(
                                  context,
                                  slide,
                                  compact: isCompact,
                                ),
                              );
                            },
                          ),
                        ),
                        if (widget.showSkip)
                          Positioned(
                            top: skipInset,
                            right: skipInset,
                            child: _SkipButton(
                              onPressed: _handleSkip,
                              compact: isCompact,
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: indicatorBottom,
                          child: Center(
                            child: _buildIndicator(compact: isCompact),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndicator({required bool compact}) {
    final dotSize = compact ? 7.0 : 8.0;
    final activeWidth = compact ? 16.0 : 18.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_slides.length, (index) {
        final isActive = index == _activePage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: isActive ? activeWidth : dotSize,
          height: dotSize,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? ArmyColors.gold : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildSlide(
    BuildContext context,
    _ShowcaseSlide slide, {
    required bool compact,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final contentInset = compact ? 12.0 : 16.0;
    final contentBottom = compact ? 36.0 : 42.0;
    final headlineStyle =
        compact ? textTheme.titleMedium : textTheme.titleLarge;
    final subtextStyle = compact ? textTheme.bodySmall : textTheme.bodyMedium;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          slide.assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.05),
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.75),
                Colors.black.withOpacity(0.92),
              ],
              stops: const [0.0, 0.45, 0.72, 1.0],
            ),
          ),
        ),
        Positioned(
          left: contentInset,
          right: contentInset,
          bottom: contentBottom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slide.headline,
                style: headlineStyle?.copyWith(
                  color: ArmyColors.gold,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                slide.subtext,
                style: subtextStyle?.copyWith(
                  color: ArmyNeutrals.gray100,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (slide.chips.isNotEmpty) ...[
                SizedBox(height: compact ? 8 : 10),
                Wrap(
                  spacing: compact ? 5 : 6,
                  runSpacing: compact ? 5 : 6,
                  children: [
                    for (final chip in slide.chips)
                      _SlideChip(label: chip, compact: compact),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShowcaseSlide {
  const _ShowcaseSlide({
    required this.assetPath,
    required this.headline,
    required this.subtext,
    required this.chips,
  });

  final String assetPath;
  final String headline;
  final String subtext;
  final List<String> chips;
}

class _SlideChip extends StatelessWidget {
  const _SlideChip({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ArmyNeutrals.gray050,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: ArmyColors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ArmyColors.gold.withOpacity(0.55),
          width: 0.8,
        ),
      ),
      child: Text(label, style: textStyle),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed, required this.compact});

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(compact ? 12 : 14);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onPressed,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: ArmyColors.black.withOpacity(0.45),
            borderRadius: borderRadius,
            border: Border.all(
              color: ArmyColors.gold.withOpacity(0.5),
              width: 0.8,
            ),
          ),
          child: Text(
            'Skip',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ArmyColors.gold,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
          ),
        ),
      ),
    );
  }
}
