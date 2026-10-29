import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_app/core/widgets/state_views.dart';
import 'package:healthcare_app/core/widgets/status_badge.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';

void main() {
  group('Widget Component Tests (Design System & Reusable Elements)', () {
    testWidgets('StatusBadge renders correct labels for all appointment statuses', (tester) async {
      for (var status in AppointmentStatus.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatusBadge(status: status),
            ),
          ),
        );

        expect(find.text(status.displayName), findsOneWidget);
      }
    });

    testWidgets('EmptyStateView renders title, description and triggers action button', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              icon: Icons.calendar_today_rounded,
              title: 'No Appointments Found',
              description: 'You have no scheduled consultations at this time.',
              actionLabel: 'Book Doctor',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No Appointments Found'), findsOneWidget);
      expect(find.text('You have no scheduled consultations at this time.'), findsOneWidget);
      expect(find.text('Book Doctor'), findsOneWidget);

      await tester.tap(find.text('Book Doctor'));
      await tester.pump();

      expect(actionTapped, isTrue);
    });

    testWidgets('ErrorStateView displays error message and invokes retry callback', (tester) async {
      bool retryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateView(
              message: 'Failed to connect to consultation server.',
              onRetry: () => retryTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Something Went Wrong'), findsOneWidget);
      expect(find.text('Failed to connect to consultation server.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(retryTapped, isTrue);
    });

    testWidgets('OfflineBanner renders connectivity warning', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(),
          ),
        ),
      );

      expect(
        find.text('Viewing offline data. Reconnect to book or reschedule appointments.'),
        findsOneWidget,
      );
    });
  });
}
