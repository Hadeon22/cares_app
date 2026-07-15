import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cares_app/data/session.dart';
import 'package:cares_app/main.dart';

void main() {
  tearDown(() {
    // Reset the singleton session between tests.
    if (AppSession.instance.isSignedIn) AppSession.instance.signOut();
  });

  testWidgets('renders the public resident portal by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CaresApp());
    await tester.pump(const Duration(seconds: 1));

    // Branded shell + Sign In entry point (signed-out state).
    expect(find.text('C.A.R.E.S.'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
  });

  testWidgets('staff sign-in routes to the MIS dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CaresApp());
    await tester.pump(const Duration(seconds: 1));

    AppSession.instance.debugSignIn(
        UserRole.admin, 'Juan D. Administrator', 'admin@condelabac.gov.ph');
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.textContaining('Good day'), findsOneWidget);
  });

  testWidgets('resident sign-in stays on the portal with a welcome',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CaresApp());
    await tester.pump(const Duration(seconds: 1));

    AppSession.instance
        .debugSignIn(UserRole.resident, 'Pedro S. Santos', 'pedro@example.com');
    await tester.pumpAndSettle();

    // Still on the portal (bottom navigation present, Sign In gone).
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);

    // The welcome banner sits below the hero — scroll it into view.
    await tester.scrollUntilVisible(
      find.textContaining('Mabuhay'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Mabuhay'), findsOneWidget);
  });
}
