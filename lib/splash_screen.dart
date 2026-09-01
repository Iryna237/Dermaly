import 'package:flutter/material.dart';
import 'package:ziskin/app_colors.dart';
import 'package:ziskin/spinking/spinking.dart';

const Color _green1 = Color(0xFF944E66);
const Color _green4 = Color(0xFF6E2E51);
const Color _blue1  = Color(0xFFE99AA0);



class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _masterCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _contentFade;
  late final Animation<double> _dotsFade;

  @override
  void initState() {
    super.initState();
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _masterCtrl, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(
            parent: _masterCtrl, curve: const Interval(0.0, 0.45, curve: Curves.elasticOut)));
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _masterCtrl, curve: const Interval(0.35, 0.62, curve: Curves.easeOut)));
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _masterCtrl, curve: const Interval(0.35, 0.62, curve: Curves.easeOut)));
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _masterCtrl, curve: const Interval(0.55, 0.85, curve: Curves.easeOut)));
    _dotsFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _masterCtrl, curve: const Interval(0.78, 1.0, curve: Curves.easeOut)));

    _masterCtrl.forward();
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.15, 0.5, 0.72, 0.88, 1.0],
                  colors: [
                    Color(0x00ffffff),
                    Color(0xC8E8EAE9),
                    Color(0xFFFFFFFF),
                    Color(0xEEFFFFFF),
                    Color(0x94FFFFFF),
                    Color(0x00ffffff),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),

                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: SizedBox(
                            width: 250,
                            //height: 170,
                            child: Image.asset('assets/images/logo_s.png'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      FadeTransition(
                        opacity: _titleFade,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'DERM',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 45,
                                    fontWeight: FontWeight.w800,
                                    color: _green1,
                                    letterSpacing: 3.5,
                                  ),
                                ),
                                TextSpan(
                                  text: 'ALY',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 45,
                                    fontWeight: FontWeight.w800,
                                    color: _blue1,
                                    letterSpacing: 3.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      FadeTransition(
                        opacity: _titleFade,
                        child: const Text(
                          'Skin Disease Detection & Dermatological Care',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: _green4,
                            height: 1.55,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      FadeTransition(
                        opacity: _contentFade,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _FeatureItem(
                                painter: Image.asset("assets/images/logo_s.png"),
                                label1: 'Smart',
                                label2: 'Scanning',
                              ),
                              SizedBox(height: 90, width: 0, child: VerticalDivider( color: Colors.grey.shade300,)),
                              _FeatureItem(
                                painter: Image.asset("assets/images/logo_s.png"),
                                label1: 'Accurate',
                                label2: 'Diagnosis',
                              ),
                              SizedBox(height: 90, width: 0, child: VerticalDivider( color: Colors.grey.shade300,)),
                              _FeatureItem(
                                painter: Image.asset("assets/images/logo_s.png"),
                                label1: 'Expert',
                                label2: 'Advice',
                              ),
                              SizedBox(height: 90, width: 0, child: VerticalDivider( color: Colors.grey.shade300,)),
                              _FeatureItem(
                                painter: Image.asset("assets/images/logo_s.png"),
                                label1: 'Skin',
                                label2: 'Tracking',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      FadeTransition(
                        opacity: _contentFade,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: _green1,
                                height: 1.55,
                                letterSpacing: 1.5,
                                wordSpacing: 2.5,
                              ),
                              children: [
                                TextSpan(text: 'Take care of your skin\n'),
                                TextSpan(text: 'we take care of your health.'),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      FadeTransition(
                        opacity: _dotsFade,
                        child: Column(
                          children: [
                            //CircularProgressIndicator(),
                            /*const SizedBox(height: 14),
                            const Text(
                              'Loading...',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: _green4,
                                letterSpacing: 0.2,
                              ),
                            ),*/
                            const SizedBox(height: 14),

                            //SpinKitWaveSpinner(color: AppColors.primary),
                            SpinKitCubeGrid(size: 70.0, color: AppColors.primary),


                          ],
                        ),
                      ),
                    ],
                  ),
                ),


                // ── DOTS + LOADING ─────────────────────────────────────────

              ],
            ),
          ),

        ],
      ),
    );
  }
}



class _FeatureItem extends StatelessWidget {
  final Widget painter;
  final String label1;
  final String label2;

  const _FeatureItem({required this.painter, required this.label1, required this.label2});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: painter,
        ),
        const SizedBox(height: 8),
        RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
                style: const TextStyle(
                  color: _green4,
                  height: 1.35,
                ),

                children: [
                  TextSpan(
                    text: "$label1 \n",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: label2,style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  )
                ]
            ))
      ],
    );
  }
}