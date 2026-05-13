enum PaymentMode {
  cash('Cash', 'नकद'),
  upi('UPI', 'UPI'),
  cheque('Cheque', 'चेक'),
  neft('NEFT', 'NEFT'),
  rtgs('RTGS', 'RTGS');

  final String label;
  final String hindiLabel;
  const PaymentMode(this.label, this.hindiLabel);

  String get display => '$label ($hindiLabel)';
}
