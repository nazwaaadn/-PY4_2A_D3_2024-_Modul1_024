import 'package:flutter/material.dart';
import 'package:logbook_app_024/features/auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Data konten onboarding
  final List<Map<String, String>> _onboardingData = [
    {
      "title": "Selamat Datang",
      "subtitle":
          "Aplikasi Logbook membantu Anda mencatat, memantau, dan mengelola aktivitas harian dengan lebih terstruktur dan efisien.",
      "image": "assets/images/onboarding1.png",
    },
    {
      "title": "Kelola Aktivitas Anda",
      "subtitle":
          "Catat setiap kegiatan dengan mudah, pantau progres Anda, dan pastikan semua tugas terdokumentasi dengan rapi.",
      "image": "assets/images/onboarding2.png",
    },
    {
      "title": "Mulai Perjalanan Anda",
      "subtitle":
          "Tingkatkan produktivitas dan disiplin Anda mulai hari ini. Semua aktivitas Anda kini dalam satu genggaman.",
      "image": "assets/images/onboarding3.png",
    },
  ];

  void _onNext() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color.fromARGB(255, 0, 38, 77);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Tombol Skip
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginView()),
                ),
                child: Text("Skip", style: TextStyle(color: Colors.grey[600])),
              ),
            ),

            // Content Slider
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _onboardingData.length,

                // Ganti bagian itemBuilder di dalam PageView.builder Anda dengan kode ini:
                itemBuilder: (context, index) {
                  return SingleChildScrollView(
                    // Tambahkan ini agar konten bisa di-scroll jika layar kekecilan
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60), // Beri jarak atas
                          Image.asset(
                            _onboardingData[index]["image"]!,
                            // Gunakan tinggi relatif terhadap layar agar tidak overflow
                            height: MediaQuery.of(context).size.height * 0.3,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 40),
                          Text(
                            _onboardingData[index]["title"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize:
                                  24, // Sedikit diperkecil agar lebih aman
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _onboardingData[index]["subtitle"]!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20), // Jarak aman bawah
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Indicator & Button Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicator (Dots)
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                      (index) => _buildDot(index, primaryColor),
                    ),
                  ),

                  // Circular Progress Button / Next Button
                  ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                    ),
                    child: Icon(
                      _currentPage == _onboardingData.length - 1
                          ? Icons.check
                          : Icons.arrow_forward_ios,
                      size: 20,
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

  // Widget untuk titik indikator
  Widget _buildDot(int index, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: _currentPage == index ? 24 : 8, // Titik aktif lebih panjang
      decoration: BoxDecoration(
        color: _currentPage == index ? color : color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
