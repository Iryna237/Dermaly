import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/auth_gate.dart';
import 'package:ziskin/landing_page.dart';
import 'package:ziskin/main.dart';
import 'package:ziskin/pages/auth/login.dart';
import 'package:ziskin/pages/auth/register.dart';
import 'package:ziskin/services/auth_service.dart';
import 'package:ziskin/splash_screen.dart';

const phone = Size(360, 780);

// The test font draws every glyph as a full square, so text runs much wider
// than on a device: the login and verification pages only fit at a tablet width here.
const tablet = Size(800, 1280);

void main() {
  late FakeFirebaseFirestore firestore;

  /// Plugs the app into a simulated Firebase, with or without a session.
  void simulateFirebase({MockUser? signedInAs}) {
    firestore = FakeFirebaseFirestore();
    AuthService.useForTesting(
      auth: MockFirebaseAuth(signedIn: signedInAs != null, mockUser: signedInAs),
      firestore: firestore,
    );
  }

  final dermatologist = MockUser(
    uid: 'derma-1',
    email: 'dr.ndiaye@example.com',
    displayName: 'Awa Ndiaye',
  );

  Future<void> open(WidgetTester tester, Widget screen, {Size size = phone}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen);
  }

  /// Lets the simulated Firestore answer; screens with endless animations
  /// never settle, so this pumps a few frames instead of pumpAndSettle.
  Future<void> letFirestoreAnswer(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('without a session, the splash leads to the landing page',
      (tester) async {
    simulateFirebase();
    await open(tester, const MyApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LandingPage), findsNothing);

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LandingPage), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.text('ALREADY HAVE AN ACCOUNT'), findsOneWidget);
  });

  testWidgets('an account with no saved profile goes back to the landing page',
      (tester) async {
    simulateFirebase(signedInAs: dermatologist);
    await open(tester, const MaterialApp(home: AuthGate(skipSplash: true)));
    await letFirestoreAnswer(tester);

    expect(find.byType(LandingPage), findsOneWidget);
  });

  testWidgets('a rejected dermatologist goes back to the landing page',
      (tester) async {
    simulateFirebase(signedInAs: dermatologist);
    await firestore.collection('users').doc('derma-1').set({
      'role': 'dermatologist',
      'status': 'rejected',
    });
    await open(tester, const MaterialApp(home: AuthGate(skipSplash: true)));
    await letFirestoreAnswer(tester);

    expect(find.byType(LandingPage), findsOneWidget);
    expect(find.byType(PendingVerificationPage), findsNothing);
  });

  testWidgets('a pending dermatologist sees their file under verification',
      (tester) async {
    simulateFirebase(signedInAs: dermatologist);
    await firestore.collection('users').doc('derma-1').set({
      'role': 'dermatologist',
      'status': 'pending',
      'onmcNumber': 'ONMC-4521',
      'establishment': 'Hopital Principal',
    });
    await open(tester, const MaterialApp(home: AuthGate(skipSplash: true)),
        size: tablet);
    await letFirestoreAnswer(tester);

    expect(find.byType(PendingVerificationPage), findsOneWidget);
    expect(find.text('Account Under Verification'), findsOneWidget);
    expect(find.textContaining('ONMC-4521'), findsOneWidget);
    expect(find.textContaining('Hopital Principal'), findsOneWidget);
    expect(find.text('Document not available'), findsOneWidget);
  });

  testWidgets('logging out from verification leads back to the login page',
      (tester) async {
    simulateFirebase(signedInAs: dermatologist);
    await firestore.collection('users').doc('derma-1').set({
      'role': 'dermatologist',
      'status': 'pending',
    });
    await open(tester, const MaterialApp(home: AuthGate(skipSplash: true)),
        size: tablet);
    await letFirestoreAnswer(tester);

    await tester.tap(find.text('LOGOUT'));
    await letFirestoreAnswer(tester);

    expect(AuthService().isAuthenticated, isFalse);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(PendingVerificationPage), findsNothing);
  });
}
