import 'package:flutter/material.dart';

/// סמל מסך הפתיחה, באטימות 70%. החלון הראשי מוסתר לכל אורך שלב ה-splash —
/// הסמל שנראה למשתמש הוא חלון ה-splash הנייטיבי הנפרד (ראה runner).
class SplashIcon extends StatelessWidget {
  const SplashIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: 0.70,
        child: Image.asset(
          'assets/icon/iconnew_256.png',
          width: 128,
          height: 128,
        ),
      ),
    );
  }
}

/// מסך פתיחה מוצג בזמן האתחול לפני שה-App נטען
class SplashApp extends StatelessWidget {
  const SplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    // הרקע חייב להיות אטום (נצבע): סצנה שקופה מייצרת פריימים ריקים, ופריים ריק
    // בזמן resize משכלף את ה-surface בגלל באג מנוע (flutter#187922) — זום מוזר.
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SplashIcon(),
      ),
    );
  }
}
