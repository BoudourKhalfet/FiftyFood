import 'package:flutter/material.dart';
import '../signin_page.dart';

class DelivererSignInPage extends StatelessWidget {
  const DelivererSignInPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const SignInPage(role: 'Deliverer');
}
