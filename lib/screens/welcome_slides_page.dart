import 'package:flutter/material.dart';

// =====================================================
// MODEL SLIDE
// =====================================================

class IntroSlide {
  const IntroSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.label,
  });

  final String title;
  final String description;
  final IconData icon;
  final String label;
}

// =====================================================
// WELCOME SLIDES
// =====================================================

class WelcomeSlidesPage extends StatefulWidget {
  const WelcomeSlidesPage({
    super.key,
    required this.onContinue,
  });

  final VoidCallback onContinue;

  @override
  State<WelcomeSlidesPage> createState() =>
      _WelcomeSlidesPageState();
}

class _WelcomeSlidesPageState
    extends State<WelcomeSlidesPage> {
  static const Color darkGreen = Color(0xFF064E3B);
  static const Color green = Color(0xFF10B981);
  static const Color softGreen = Color(0xFFE9F8F0);
  static const Color background = Color(0xFFF8FBF9);
  static const Color textDark = Color(0xFF172820);
  static const Color muted = Color(0xFF7C9186);

  final PageController _pageController = PageController();

  int _currentPage = 0;
  bool _completed = false;

  final List<IntroSlide> _slides = const [
    IntroSlide(
      title: 'Keuangan lebih\ntertata.',
      description:
          'Pantau uangmu dengan mudah, semuanya dalam satu tempat.',
      icon: Icons.account_balance_wallet_rounded,
      label: 'KELOLA KEUANGAN',
    ),
    IntroSlide(
      title: 'Semua pemasukan,\nsatu tujuan.',
      description:
          'Atur gaji dan penghasilan tambahan dengan lebih praktis.',
      icon: Icons.payments_rounded,
      label: 'PEMASUKAN',
    ),
    IntroSlide(
      title: 'Anggaran yang\nfleksibel.',
      description:
          'Sesuaikan kebutuhan harian dengan rutinitasmu.',
      icon: Icons.calendar_month_rounded,
      label: 'RENCANA ANGGARAN',
    ),
    IntroSlide(
      title: 'Wujudkan target\nimpianmu.',
      description:
          'Bangun kebiasaan menabung, selangkah demi selangkah.',
      icon: Icons.savings_rounded,
      label: 'TARGET TABUNGAN',
    ),
  ];

  bool get _isLastPage =>
      _currentPage == _slides.length - 1;

  void _finish() {
    if (_completed) return;

    _completed = true;
    widget.onContinue();
  }

  Future<void> _next() async {
    if (_completed) return;

    if (_isLastPage) {
      _finish();
      return;
    }

    if (!_pageController.hasClients) return;

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // =====================================================
  // MAIN PAGE
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final horizontalPadding =
        screenWidth < 360 ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              _buildHeader(),

              const SizedBox(height: 8),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildSlide(
                      _slides[index],
                      index,
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),

              _buildIndicators(),

              const SizedBox(height: 18),

              _buildButton(),

              const SizedBox(height: 11),

              Text(
                '${_currentPage + 1} / ${_slides.length}',
                style: const TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // HEADER
  // =====================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: darkGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),

        const SizedBox(width: 10),

        const Expanded(
          child: Text(
            'FinPlan',
            style: TextStyle(
              color: darkGreen,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
        ),

        if (!_isLastPage)
          TextButton(
            onPressed: _finish,
            style: TextButton.styleFrom(
              foregroundColor: muted,
            ),
            child: const Text(
              'Lewati',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // =====================================================
  // RESPONSIVE SLIDE
  // =====================================================

  Widget _buildSlide(IntroSlide slide, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final compact = availableHeight < 510;

        final illustrationHeight =
            (availableHeight * 0.53)
                .clamp(185.0, 290.0)
                .toDouble();

        final titleSize = compact ? 26.0 : 30.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: availableHeight,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIllustration(
                  index,
                  illustrationHeight,
                ),

                SizedBox(
                  height: compact ? 10 : 20,
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: softGreen,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        slide.icon,
                        size: 13,
                        color: darkGreen,
                      ),

                      const SizedBox(width: 7),

                      Text(
                        slide.label,
                        style: const TextStyle(
                          color: darkGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: compact ? 12 : 17,
                ),

                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textDark,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    height: 1.13,
                    letterSpacing: -0.9,
                  ),
                ),

                const SizedBox(height: 12),

                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 285,
                  ),
                  child: Text(
                    slide.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 15),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // RESPONSIVE ILLUSTRATION
  // =====================================================

  Widget _buildIllustration(
    int index,
    double height,
  ) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 15,
            left: 5,
            child: Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: Color(0xFFDEF7E9),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            bottom: 8,
            right: 0,
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFE7F7EF),
                shape: BoxShape.circle,
              ),
            ),
          ),

          const Positioned(
            top: 12,
            right: 12,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF9ADCB8),
              size: 19,
            ),
          ),

          const Positioned(
            bottom: 24,
            left: 9,
            child: Icon(
              Icons.circle,
              color: Color(0xFFA2E7C3),
              size: 10,
            ),
          ),

          // Bagian penting:
          // seluruh ilustrasi menyesuaikan ruang.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 292,
                  child: _buildGraphic(index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphic(int index) {
    switch (index) {
      case 0:
        return _overviewGraphic();
      case 1:
        return _incomeGraphic();
      case 2:
        return _budgetGraphic();
      default:
        return _savingsGraphic();
    }
  }

  // =====================================================
  // CARD COMPONENTS
  // =====================================================

  Widget _whiteCard({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.all(17),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: const Color(0xFFE9F2EC),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10064E3B),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconBox(
    IconData icon, {
    Color boxColor = softGreen,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        color: darkGreen,
        size: 18,
      ),
    );
  }

  // =====================================================
  // SLIDE 1 - FINANCIAL OVERVIEW
  // =====================================================

  Widget _overviewGraphic() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF087657),
                darkGreen,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Saldo',
                    style: TextStyle(
                      color: Color(0xFFC6E9D8),
                      fontSize: 11,
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const Text(
                'Rp 8.750.000',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  _balanceInfo(
                    Icons.arrow_downward_rounded,
                    'Masuk',
                    'Rp 6,5 jt',
                  ),

                  const SizedBox(width: 10),

                  _balanceInfo(
                    Icons.arrow_upward_rounded,
                    'Keluar',
                    'Rp 2,1 jt',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 11),

        _whiteCard(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              _iconBox(Icons.trending_up_rounded),

              const SizedBox(width: 10),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keuangan sehat',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Pengeluaran terkontrol',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.check_circle_rounded,
                color: green,
                size: 21,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _balanceInfo(
    IconData icon,
    String label,
    String value,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF9EE8C1),
              size: 16,
            ),

            const SizedBox(width: 7),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFC6E9D8),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // SLIDE 2 - INCOME
  // =====================================================

  Widget _incomeGraphic() {
    return _whiteCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.payments_rounded),

              const SizedBox(width: 10),

              const Expanded(
                child: Text(
                  'Pemasukan',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const Icon(
                Icons.add_circle_rounded,
                color: green,
                size: 23,
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Text(
            'Rp 7.850.000',
            style: TextStyle(
              color: darkGreen,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),

          const SizedBox(height: 17),

          _incomeRow(
            Icons.work_outline_rounded,
            'Gaji utama',
            'Rp 5.500.000',
          ),

          const SizedBox(height: 11),

          _incomeRow(
            Icons.laptop_mac_rounded,
            'Freelance',
            'Rp 1.500.000',
          ),

          const SizedBox(height: 11),

          _incomeRow(
            Icons.storefront_rounded,
            'Usaha',
            'Rp 850.000',
          ),
        ],
      ),
    );
  }

  Widget _incomeRow(
    IconData icon,
    String name,
    String amount,
  ) {
    return Row(
      children: [
        _iconBox(icon),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: textDark,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        const SizedBox(width: 7),

        Text(
          amount,
          style: const TextStyle(
            color: darkGreen,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // SLIDE 3 - WEEKLY BUDGET
  // =====================================================

  Widget _budgetGraphic() {
    return _whiteCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.calendar_month_rounded),

              const SizedBox(width: 10),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anggaran Mingguan',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sesuai kebutuhanmu',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          _weeklyChart(),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: softGreen,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: darkGreen,
                  size: 18,
                ),

                SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'Bebas atur setiap harinya',
                    style: TextStyle(
                      color: darkGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                Icon(
                  Icons.check_circle_rounded,
                  color: green,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyChart() {
    const days = [
      'S',
      'S',
      'R',
      'K',
      'J',
      'S',
      'M',
    ];

    const barHeights = [
      45.0,
      65.0,
      37.0,
      72.0,
      55.0,
      68.0,
      30.0,
    ];

    return SizedBox(
      height: 106,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          days.length,
          (index) {
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 20,
                    height: barHeights[index],
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          green,
                          darkGreen,
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(6),
                    ),
                  ),

                  const SizedBox(height: 6),

                  SizedBox(
                    height: 16,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        days[index],
                        style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // =====================================================
  // SLIDE 4 - SAVINGS
  // =====================================================

  Widget _savingsGraphic() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            color: softGreen,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFBDEBD4),
            ),
          ),
          child: const Icon(
            Icons.savings_rounded,
            color: darkGreen,
            size: 34,
          ),
        ),

        const SizedBox(height: 13),

        _whiteCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    '🏡',
                    style: TextStyle(fontSize: 22),
                  ),

                  SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      'Rumah Impian',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  Icon(
                    Icons.more_horiz_rounded,
                    color: muted,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              const Text(
                'Rp 35.000.000',
                style: TextStyle(
                  color: darkGreen,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Target Rp 50.000.000',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 15),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(
                  value: 0.7,
                  minHeight: 9,
                  backgroundColor: Color(0xFFE7F2EC),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(
                    green,
                  ),
                ),
              ),

              const SizedBox(height: 11),

              const Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '70% tercapai',
                    style: TextStyle(
                      color: darkGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  Text(
                    'Sisa Rp 15 juta',
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =====================================================
  // INDICATORS
  // =====================================================

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _slides.length,
        (index) {
          final selected = index == _currentPage;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: selected ? 27 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(
              horizontal: 4,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? darkGreen
                  : const Color(0xFFD8E6DC),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  // =====================================================
  // CONTINUE BUTTON
  // =====================================================

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: _next,
        style: FilledButton.styleFrom(
          backgroundColor: darkGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLastPage
                  ? 'Mulai Sekarang'
                  : 'Lanjut',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(width: 9),

            Icon(
              _isLastPage
                  ? Icons.check_circle_outline_rounded
                  : Icons.arrow_forward_rounded,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}