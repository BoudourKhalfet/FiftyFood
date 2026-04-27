import 'package:flutter/material.dart';

enum AppPaymentMethod { card, eDinar, paypal }

class PaymentMethodSelector extends StatefulWidget {
  final Function(AppPaymentMethod) onMethodSelected;
  final VoidCallback onPayNow;
  final bool isLoading;

  const PaymentMethodSelector({
    Key? key,
    required this.onMethodSelected,
    required this.onPayNow,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  AppPaymentMethod? _selectedMethod;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Text(
          'Select Payment Method',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),

        // Payment Method Options
        _buildPaymentOption(
          method: AppPaymentMethod.card,
          title: 'Pay with Card',
          description: 'Visa, Mastercard, American Express',
          icon: Icons.credit_card,
          iconColor: Colors.blue,
        ),
        const SizedBox(height: 12),

        _buildPaymentOption(
          method: AppPaymentMethod.eDinar,
          title: 'Pay with e-Dinar / D17',
          description: 'Konnect Payment Gateway',
          icon: Icons.account_balance_wallet,
          iconColor: const Color(0xFF1F9D7A),
        ),
        const SizedBox(height: 12),

        _buildPaymentOption(
          method: AppPaymentMethod.paypal,
          title: 'Pay with PayPal',
          description: 'Fast and secure PayPal checkout',
          icon: Icons.payment,
          iconColor: Colors.amber,
        ),

        const SizedBox(height: 24),

        // Pay Now Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                _selectedMethod != null && !widget.isLoading
                    ? () {
                      widget.onMethodSelected(_selectedMethod!);
                      widget.onPayNow();
                    }
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _selectedMethod != null && !widget.isLoading
                      ? const Color(0xFF1F9D7A)
                      : Colors.grey,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
                : const Text(
                  'Pay Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
          ),
        ),

        const SizedBox(height: 8),

        if (_selectedMethod == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select a payment method',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required AppPaymentMethod method,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _selectedMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = method;
        });
        widget.onMethodSelected(method);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1F9D7A) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? const Color(0xFF1F9D7A).withOpacity(0.05)
              : Colors.white,
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),

            const SizedBox(width: 14),

            // Title & Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Radio Button
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1F9D7A)
                      : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1F9D7A),
                      ),
                    ),
                  )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
