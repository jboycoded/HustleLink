/// Shared currency formatting for all HustleLink screens.
String formatNaira(int amount) {
  final digits = amount.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${amount < 0 ? '-₦' : '₦'}$digits';
}
