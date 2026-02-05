class PaymentResponse {
  final String? redirectUrl;
  final int? paymentGroupId;

  PaymentResponse({
    this.redirectUrl,
    this.paymentGroupId,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>?;
    return PaymentResponse(
      redirectUrl: item?['redirect_url'] as String?,
      paymentGroupId: item?['payment_group_id'] as int?,
    );
  }
}
