import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'client/signup_step1.dart';
import 'deliverer/signup_step1.dart';
import 'partner/become_partner.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const Map<String, String> _initialStats = {
    'mealsSaved': '0',
    'activeUsers': '0',
    'partnerRestaurants': '0',
    'co2Reduced': '0',
  };

  late final AnimationController _ctrl;
  late final Animation<double> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _offsetAnim = Tween<double>(begin: -8.0, end: 8.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.eco, size: 14, color: Color(0xFF1F9D7A)),
                            SizedBox(width: 6),
                            Text(
                              'Fighting food waste together',
                              style: TextStyle(
                                color: Color(0xFF1F9D7A),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: MediaQuery.of(context).size.width > 768
                      ? Row(
                          children: [
                            Expanded(child: _buildHeroContent(context)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildAnimatedHeroImage(context)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildHeroContent(context),
                            const SizedBox(height: 24),
                            _buildAnimatedHeroImage(context),
                          ],
                        ),
                ),
                // Three-step feature cards (Browse, Reserve, Pick up)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return isWide
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: _buildStepCard(1, Icons.phone_android, 'Browse Nearby Offers', 'Discover delicious surplus food from restaurants near you at reduced prices.')),
                              const SizedBox(width: 20),
                              Expanded(child: _buildStepCard(2, Icons.access_time, 'Reserve Your Meal', 'Choose your pickup time slot and secure your order with quick, easy payment.')),
                              const SizedBox(width: 20),
                              Expanded(child: _buildStepCard(3, Icons.place, 'Pick Up & Enjoy', 'Show your QR code at the restaurant and enjoy your sustainable meal!')),
                            ],
                          )
                        : Column(
                            children: [
                              _buildStepCard(1, Icons.phone_android, 'Browse Nearby Offers', 'Discover delicious surplus food from restaurants near you at reduced prices.'),
                              const SizedBox(height: 12),
                              _buildStepCard(2, Icons.access_time, 'Reserve Your Meal', 'Choose your pickup time slot and secure your order with quick, easy payment.'),
                              const SizedBox(height: 12),
                              _buildStepCard(3, Icons.place, 'Pick Up & Enjoy', 'Show your QR code at the restaurant and enjoy your sustainable meal!'),
                            ],
                          );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: LayoutBuilder(builder: (context, constraints) {
                    // Use a horizontal row on wide screens, and a wrap (grid-like) on small screens
                    if (constraints.maxWidth > 600) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(child: _buildStatCard(icon: Icons.eco, number: _initialStats['mealsSaved']!, label: 'Meals Saved')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard(icon: Icons.people, number: _initialStats['activeUsers']!, label: 'Active Users')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard(icon: Icons.business, number: _initialStats['partnerRestaurants']!, label: 'Partner Restaurants')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard(icon: Icons.trending_down, number: _initialStats['co2Reduced']!, label: 'CO₂ Reduced')),
                        ],
                      );
                    }

                    final childWidth = math.max(140.0, (constraints.maxWidth / 2) - 24);
                    return Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 18,
                      children: [
                        SizedBox(width: childWidth, child: _buildStatCard(icon: Icons.eco, number: _initialStats['mealsSaved']!, label: 'Meals Saved')),
                        SizedBox(width: childWidth, child: _buildStatCard(icon: Icons.people, number: _initialStats['activeUsers']!, label: 'Active Users')),
                        SizedBox(width: childWidth, child: _buildStatCard(icon: Icons.business, number: _initialStats['partnerRestaurants']!, label: 'Partner Restaurants')),
                        SizedBox(width: childWidth, child: _buildStatCard(icon: Icons.trending_down, number: _initialStats['co2Reduced']!, label: 'CO₂ Reduced')),
                      ],
                    );
                  }),
                ),
                // Green CTA banner: Ready to Make a Difference?
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F9D7A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Ready to Make a Difference?',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Join the FiftyFood community today and start saving delicious meals while helping the planet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SignupStep1()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF1F9D7A),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/signin/client');
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white70, width: 1.5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Save Food, ', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 40, fontWeight: FontWeight.w900, height: 1.1)),
            const TextSpan(text: 'Save\nMoney', style: TextStyle(color: Color(0xFF1F9D7A), fontSize: 40, fontWeight: FontWeight.w900, height: 1.1)),
            const TextSpan(text: ',\nSave the Planet', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 40, fontWeight: FontWeight.w900, height: 1.1)),
          ]),
        ),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Join thousands of users who rescue delicious surplus meals from local restaurants at up to ', style: TextStyle(color: Color(0xFF5F6F6B), fontSize: 14, fontWeight: FontWeight.w400, height: 1.6)),
            const TextSpan(text: '70% off', style: TextStyle(color: Color(0xFF1F9D7A), fontSize: 14, fontWeight: FontWeight.w700, height: 1.6)),
            const TextSpan(text: '. Good for you, great for the Earth.', style: TextStyle(color: Color(0xFF5F6F6B), fontSize: 14, fontWeight: FontWeight.w400, height: 1.6)),
          ]),
        ),
        const SizedBox(height: 20),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupStep1()),
                      );
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Join as Client', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F9D7A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BecomePartner()),
                      );
                    },
                    icon: const Icon(Icons.storefront),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Join as Partner', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F9D7A), width: 2), foregroundColor: const Color(0xFF1F9D7A), padding: const EdgeInsets.symmetric(vertical: 0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
                  child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DelivererSignupStep1()),
                  );
                },
                icon: const Icon(Icons.delivery_dining),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Join as Deliverer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F9D7A), width: 2), foregroundColor: const Color(0xFF1F9D7A), padding: const EdgeInsets.symmetric(vertical: 0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: const [
            Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, size: 16, color: Color(0xFF1F9D7A)), SizedBox(width: 6), Text('Verified Restaurants', style: TextStyle(color: Color(0xFF5F6F6B), fontSize: 12))]),
            Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lightbulb, size: 16, color: Color(0xFFFF9500)), SizedBox(width: 6), Text('AI-Powered Matching', style: TextStyle(color: Color(0xFF5F6F6B), fontSize: 12))]),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedHeroImage(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnim,
      builder: (ctx, child) {
        return Transform.translate(
          offset: Offset(0, _offsetAnim.value),
          child: child,
        );
      },
      child: _buildHeroImage(context),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final imgHeight = (width > 768) ? 300.0 : math.max(160.0, width * 0.55);
    return Stack(
      children: [
        Container(
          height: imgHeight,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), image: const DecorationImage(image: AssetImage('assets/images/home.jpg'), fit: BoxFit.cover)),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFF9500), borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: const [Text('-50%', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)), Text('Average savings', style: TextStyle(color: Colors.white, fontSize: 11))]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({required IconData icon, required String number, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFF1F9D7A), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 28)),
        const SizedBox(height: 12),
        Text(number, style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
      ],
    );
  }

  Widget _buildStepCard(int step, IconData icon, String title, String desc) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: const Color(0xFFE8F6F0), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: const Color(0xFF1F9D7A), size: 30),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 12),
              Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        Positioned(
          top: -16,
          left: 16,
          right: 16,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1F9D7A),
            child: Text(step.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
