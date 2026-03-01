import 'package:flutter/material.dart';

class AvailableOffersPage extends StatelessWidget {
  const AvailableOffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const textPrimary = Color(0xFF1A1A1A);
    const textSecondary = Color(0xFF6B7280);
    const border = Color(0xFFE5E7EB);
    const accent = Color(0xFF3D9176);
    
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final horizontalPadding = isSmallScreen ? 14.0 : 24.0;
    final titleFontSize = isSmallScreen ? 32.0 : 36.0;
    final searchHeight = isSmallScreen ? 34.0 : 40.0;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            toolbarHeight: 70,
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 56,
                    ),
                  ],
                ),
                const Icon(Icons.menu, color: Color(0xFF1A1A1A)),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Offers',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: titleFontSize,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Location selector - responsive
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Wrap(
                            direction: Axis.horizontal,
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Flexible(
                                child: Text(
                                  'Showing offers near Paris, France',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: isSmallScreen ? 12 : 14,
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // TODO: open location picker later
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Change location',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: isSmallScreen ? 12 : 14,
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Search and filter row - responsive
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Row(
                            children: [
                              // Search box
                              Expanded(
                                child: Container(
                                  height: searchHeight,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: border, width: 2),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 10),
                                      const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Search restaurants or dishes.',
                                          style: TextStyle(
                                            color: const Color(0xFF757575),
                                            fontSize: isSmallScreen ? 11 : 12,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Filter button
                              InkWell(
                                onTap: () {
                                  // TODO: open filters later
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 37,
                                  height: searchHeight.toInt().toDouble(),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: accent, width: 2),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.tune, size: 18, color: accent),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      Text(
                        '0 offers available',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: isSmallScreen ? 13 : 14.8,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Empty state instead of offer cards (backend will fill later)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 12,
                              offset: Offset(0, 2),
                            )
                          ],
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No offers yet',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: isSmallScreen ? 16 : 18,
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Offers will appear here once the backend is connected.',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: isSmallScreen ? 12 : 14,
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: () {
                                // Optional: refresh action later
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Refresh',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
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