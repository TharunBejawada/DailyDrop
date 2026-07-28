// lib/features/checkout/delivery_slot.dart
//
// Grocery and fruit/veg both fulfill on the same same-day schedule — there
// used to be a separate next-morning pre-order slot for fruit/veg, but that
// distinction has been dropped in favor of a single unified delivery model.

class DeliverySlot {
  final String code;   // stored in orders.delivery_slot
  final String label;  // shown to the customer
  DeliverySlot({required this.code, required this.label});
}

DeliverySlot deliverySlot() {
  return DeliverySlot(code: 'today_30_45min', label: 'Delivered today in 30–45 minutes');
}
