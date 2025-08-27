import 'package:flutter/material.dart';
import 'package:fyp_project/Screens/Auth/SignIn.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class SplashScreen1 extends StatefulWidget {
  const SplashScreen1({super.key});

  @override
  State<SplashScreen1> createState() => _SplashScreen1State();
}

class _SplashScreen1State extends State<SplashScreen1> {
  final PageController _controller = PageController();
  bool onLastPage = false;

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() => onLastPage = index == 2);
            },
            children: const [
              SplashPage(
                image: 'Assets/16.png',
                text: 'Find nearby Charging Stations',
                subtitle:
                'Easily locate the nearest EV charging points around you, navigate with confidence, and enjoy a smooth, worry-free journey.',
              ),
              SplashPage(
                image: 'Assets/20.png',
                text: 'Get Direction',
                subtitle:
                'Find the best route to your nearest charging station with real-time navigation.',
              ),
              SplashPage(
                image: 'Assets/17.png',
                text: 'Plug and Start Charging',
                subtitle:
                'Simply connect your electric vehicle to the charging port and power up instantly.',
              ),
            ],
          ),

          // Dot Indicator
          Positioned(
            bottom: 60,
            child: SmoothPageIndicator(
              controller: _controller,
              count: 3,
              effect: WormEffect(
                activeDotColor: Colors.blue,
                dotColor: Colors.grey.shade300,
                dotHeight: 10,
                dotWidth: 10,
                spacing: 16,
              ),
            ),
          ),

          // Get Started button
          if (onLastPage)
            Positioned(
              left: 330,
              bottom: 40,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => SignInScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: Colors.green,
                ),
                child: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
class SplashPage extends StatelessWidget {
  final String image;
  final String text;
  final String subtitle;

  const SplashPage({
    super.key,
    required this.image,
    required this.text,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 100,
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).orientation == Orientation.portrait
                    ? 250
                    : 150, // smaller in landscape
              ),
              child: Image.asset(image, fit: BoxFit.contain),
            ),
            const SizedBox(height: 30),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

