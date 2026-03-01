import 'package:flutter/material.dart';
import '../signin_page.dart';

class PartnerSignInPage extends StatelessWidget {
  const PartnerSignInPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const SignInPage(role: 'Partner');
}
