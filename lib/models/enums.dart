enum PaymentMode {
  cash('Cash'),
  upi('UPI'),
  cheque('Cheque'),
  neft('NEFT'),
  rtgs('RTGS');

  final String label;
  const PaymentMode(this.label);

  String get display => label;
}
