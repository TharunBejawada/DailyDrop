// lib/features/checkout/razorpay_service.dart
//
// Simple client-side checkout: no server-side order-creation step, so
// Razorpay's Key Secret never needs to exist anywhere near this app — only
// the public Key ID is used, same trust model as the Supabase anon key.
//
// Honest trade-off: without a server creating a Razorpay Order first, this
// can't be cryptographically verified server-side after the fact. That's an
// acceptable starting point for a single-store launch — a hardened version
// (Supabase Edge Function creates the order + verifies the signature) is a
// good upgrade once volume justifies the extra moving part.

import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/env.dart';

class RazorpayService {
  final Razorpay _razorpay = Razorpay();

  void open({
    required double amountRupees,
    required String contactPhone,
    String? contactEmail,
    required void Function(PaymentSuccessResponse) onSuccess,
    required void Function(PaymentFailureResponse) onError,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);

    final options = {
      'key': Env.razorpayKeyId,
      'amount': (amountRupees * 100).round(), // Razorpay expects paise
      'name': 'Your Store',
      'description': 'Order payment',
      'prefill': {
        'contact': contactPhone,
        if (contactEmail != null) 'email': contactEmail,
      },
      // Nudges the checkout sheet toward UPI first, matching how your
      // customers actually prefer to pay.
      'method': {'upi': true, 'card': true, 'netbanking': true, 'wallet': false},
    };

    _razorpay.open(options);
  }

  void dispose() => _razorpay.clear();
}