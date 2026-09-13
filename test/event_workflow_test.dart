import 'package:flutter_test/flutter_test.dart';
import 'package:vibe/models/event_model.dart';
import 'package:vibe/services/event_service.dart';

void main() {
  group('EventModel workflow fields', () {
    test('parses isPaid / price / visibilityRadiusM', () {
      final e = EventModel.fromJson({
        'id': 'e1',
        'creatorId': 'u1',
        'title': 'Sunset Meetup',
        'description': 'By the lake',
        'mode': 'offline',
        'category': 'meetup',
        'eventDate': DateTime.now().toIso8601String(),
        'participantCount': 3,
        'maxParticipants': 50,
        'isPaid': true,
        'price': 199,
        'visibilityRadiusM': 25000,
      });
      expect(e.isPaid, true);
      expect(e.price, 199);
      expect(e.visibilityRadiusM, 25000);
      expect(e.maxParticipants, 50);
    });

    test('defaults free/5km when fields are absent', () {
      final e = EventModel.fromJson({
        'id': 'e2',
        'creatorId': 'u1',
        'title': 'Free jam',
        'description': 'Online music jam',
        'mode': 'online',
        'category': 'music_jam',
        'eventDate': DateTime.now().toIso8601String(),
        'participantCount': 0,
      });
      expect(e.isPaid, false);
      expect(e.price, isNull);
      expect(e.visibilityRadiusM, 5000);
    });

    test('round-trips through toJson', () {
      final e = EventModel.fromJson({
        'id': 'e3',
        'creatorId': 'u1',
        'title': 'Paid workshop',
        'description': 'Hands-on',
        'mode': 'offline',
        'category': 'workshop',
        'eventDate': DateTime.now().toIso8601String(),
        'participantCount': 1,
        'isPaid': true,
        'price': 500,
        'visibilityRadiusM': 50000,
      });
      final again = EventModel.fromJson(e.toJson());
      expect(again.isPaid, true);
      expect(again.price, 500);
      expect(again.visibilityRadiusM, 50000);
    });
  });

  group('PremiumPlan', () {
    test('parses the plan catalog shape', () {
      final p = PremiumPlan.fromJson(
          {'code': 'quarterly', 'label': '3 months', 'priceInr': 219, 'days': 90});
      expect(p.code, 'quarterly');
      expect(p.priceInr, 219);
      expect(p.days, 90);
    });
  });

  group('EventQuota', () {
    test('reads premium + reset fields', () {
      final q = EventQuota.fromJson({
        'used': 3,
        'limit': 3,
        'remaining': 0,
        'isPremium': true,
        'canCreate': true,
        'premiumUntil': '2026-10-13T00:00:00.000Z',
      });
      expect(q.isPremium, true);
      expect(q.canCreate, true);
      expect(q.remaining, 0);
      expect(q.premiumUntil, isNotNull);
    });
  });
}
