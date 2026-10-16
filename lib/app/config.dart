/// Values that differ per deployment rather than per build.
abstract final class AppConfig {
  /// Where "Raportează o greșeală" sends its pre-filled email.
  ///
  /// Empty on purpose: every user sees this address, so it must be a mailbox
  /// made for the app, chosen deliberately — never a personal one by default.
  /// While it is empty the button is not shown at all, rather than offering an
  /// action that goes nowhere.
  ///
  ///   static const String supportEmail = 'troita.app@example.com';
  static const String supportEmail = '';

  static bool get canReport => supportEmail.contains('@');
}
