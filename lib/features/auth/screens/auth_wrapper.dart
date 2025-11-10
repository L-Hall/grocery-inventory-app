import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../onboarding/screens/onboarding_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, OnboardingProvider>(
      builder: (context, authProvider, onboardingProvider, _) {
        if (!onboardingProvider.hasCompletedOnboarding) {
          return const OnboardingScreen();
        }

        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
