import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class StaffEmailService {
  // USE THE SAME CREDENTIALS AS MEMBER EMAIL (or a different one)
  static const String senderEmail = 'fitnophedia@gmail.com';
  static const String senderName = 'Fitnophedia Admin';
  static const String appPassword = 'gqqa paph ktep gguj';
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;

  static SmtpServer get smtpServer => SmtpServer(
    'smtp.gmail.com',
    port: smtpPort,
    username: senderEmail,
    password: appPassword,
    ignoreBadCertificate: false,
  );

  /// Send welcome email to new staff member
  static Future<void> sendStaffWelcomeEmail({
    required String staffName,
    required String staffEmail,
    required String role,
    required String gymName,
  }) async {
    final message = Message()
      ..from = Address(senderEmail, senderName)
      ..recipients.add(staffEmail)
      ..subject = 'Welcome to $gymName, $staffName! 🎉'
      ..html = '''
        <html>
          <body style="font-family: 'Segoe UI', sans-serif; background:#0f0f0f; color:#fff; padding:24px;">
            <div style="max-width:600px; margin:auto; background:#1a1a1a; border-radius:16px; padding:32px; box-shadow:0 10px 30px rgba(255,77,77,0.2);">
              <h1 style="color:#ff4d4d; text-align:center;">Welcome to the Team!</h1>
              <h2 style="color:#fff;">Hey $staffName</h2>
              <p style="font-size:16px; line-height:1.6;">
                Congratulations! You've been added as a <strong>$role</strong> at <strong>$gymName</strong> on <strong>Fitnophedia</strong>.
              </p>
              <p style="font-size:16px; line-height:1.6;">
                We're excited to have you on board! You can now access your staff dashboard, track attendance, manage schedules, and more.
              </p>
              <div style="text-align:center; margin:30px 0;">
                <a href="https://fitnophedia.app/staff-login" 
                   style="background:#ff4d4d; color:white; padding:16px 32px; text-decoration:none; border-radius:50px; font-weight:bold; font-size:16px;">
                   Login to Staff Portal
                </a>
              </div>
              <hr style="border: 1px solid #333; margin:40px 0;">
              <p style="font-size:12px; color:#888; text-align:center;">
                © 2025 Fitnophedia • Empowering Fitness Teams<br>
                This is an automated message from $gymName
              </p>
            </div>
          </body>
        </html>
      ''';

    try {
      final sendReport = await send(message, smtpServer);
      print('STAFF WELCOME EMAIL SENT to $staffEmail: $sendReport');
    } on MailerException catch (e) {
      print('STAFF EMAIL FAILED: $e');
      print('Failed messages: ${e.message}');
    } catch (e) {
      print('UNEXPECTED STAFF EMAIL ERROR: $e');
    }
  }
}