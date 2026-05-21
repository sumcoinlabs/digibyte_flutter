import 'package:flutter/material.dart';

class SignupClaim extends StatelessWidget {
  final double balance;
  final VoidCallback onClaim;
  final VoidCallback onShare;

  const SignupClaim({
    Key? key,
    required this.balance,
    required this.onClaim,
    required this.onShare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 10,
      child: Column(
        children: [
          GestureDetector(
            onTap: balance == 0 ? onClaim : onShare,
            child: Icon(
              balance == 0 ? Icons.attach_money : Icons.share,
              size: 40,
              color: Colors.white,
            ),
          ),
          Text(
            balance == 0 ? 'Claim Signup Coin' : 'Share so friends get \$5 too',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
