import 'dart:ui';
import 'package:flutter/material.dart';
import './mobile_input_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Immediately redirect to the new OTP-based authentication
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MobileInputScreen(),
        ),
      );
    });

    // Show a loading screen while redirecting
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0F),
              Color(0xFF1A1A2E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D4FF),
          ),
        ),
      ),
    );
  }
} 