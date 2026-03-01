import 'package:flutter/material.dart';
import '../signin_page.dart';

class ClientSignInPage extends StatelessWidget {
  const ClientSignInPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const SignInPage(role: 'Client');
}
