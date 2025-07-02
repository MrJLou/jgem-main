import 'package:flutter/material.dart';
import 'dart:math' as math;

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  AboutScreenState createState() => AboutScreenState();
}

class AboutScreenState extends State<AboutScreen>
    with TickerProviderStateMixin {
  late AnimationController _continuousRotationController;
  late Animation<double> _continuousRotationAnimation;

  @override
  void initState() {
    super.initState();
    
    _continuousRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25), // Slower rotation
    );

    _continuousRotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_continuousRotationController)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

    _continuousRotationController.repeat();
  }

  @override
  void dispose() {
    _continuousRotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About This App'),
        automaticallyImplyLeading:
            false, // No back button if it's a main screen section
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Rotating App Logo (smaller than login screen)
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(_continuousRotationAnimation.value),
                child: Container(
                  width: 120, // Smaller than login screen (was 200)
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(242),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Image.asset(
                        'assets/images/slide1.png',
                        fit: BoxFit.contain,
                        errorBuilder: (BuildContext context, Object exception,
                            StackTrace? stackTrace) {
                          return Icon(
                            Icons.medical_services_rounded,
                            size: 60,
                            color: Theme.of(context).primaryColor,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'J-Gem Patient Record Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Version 1.0.0', // Replace with your app's version
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'This application is designed to manage patient records, appointments, and other clinical data efficiently for J-Gem Medical and Diagnostic Clinic.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Development Team Panel
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Development Team',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        // Left side - UI/UX Designer
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Theme.of(context).primaryColor.withAlpha(20),
                                child: Icon(
                                  Icons.design_services,
                                  size: 30,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Garcia, Louie Eydrian C.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const Text(
                                '(UI/UX Designer)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        // Middle - Lead Programmer
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 35, // Slightly larger for lead
                                backgroundColor: Theme.of(context).primaryColor.withAlpha(20),
                                child: Icon(
                                  Icons.code,
                                  size: 35,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tuplano, Bien Jester O.',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const Text(
                                '(Lead Programmer)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        // Right side - Assistant Programmer
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Theme.of(context).primaryColor.withAlpha(20),
                                child: Icon(
                                  Icons.computer,
                                  size: 30,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Lapitan, Lance Bryan A.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const Text(
                                '(Assistant Programmer)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                '© ${DateTime.now().year} J-Gem Medical Clinic. All rights reserved.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
