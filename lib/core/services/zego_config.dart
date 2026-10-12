/// ZEGOCLOUD project configuration.
///
/// Note: unlike Supabase's anon key, ZEGOCLOUD's AppSign is meant to be
/// used directly in client apps for this UIKit approach — this is
/// ZEGOCLOUD's own documented pattern for this SDK, not a shortcut we're
/// taking. If ChatFlow ever needed stronger security (e.g. tokens that
/// expire), ZEGOCLOUD supports a server-generated token approach instead —
/// worth revisiting in a "Production" pass if this app ever went further
/// than a portfolio project.
class ZegoConfig {
  ZegoConfig._();


  static const int appID = 138428324; // PASTE YOUR NUMERIC AppID HERE
  static const String appSign = 'c5d72e3368c13763ae1ecc05af4b7bc2ee8d96190e6dce110f375c5688cbd7a6';
}