import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SmtpEmailService {
  // Load credentials from environment variables
  static String get senderEmail => dotenv.env['SMTP_SENDER_EMAIL'] ?? 'fitnophedia@gmail.com';
  static String get senderName => dotenv.env['SMTP_SENDER_NAME'] ?? 'Fitnophedia Admin';
  static String get appPassword => dotenv.env['SMTP_APP_PASSWORD'] ?? '';
  static String get smtpHost => dotenv.env['SMTP_HOST'] ?? 'smtp.gmail.com';
  static int get smtpPort => int.tryParse(dotenv.env['SMTP_PORT'] ?? '587') ?? 587;

  // Local logo path (will be transformed to a public URL by your tooling)
  static const String logoPath = '/mnt/data/e080713e-6dbd-423e-8318-188b74f96d8b.png';

  // Theme color (green)
  static const String primaryGreen = '#35A972';

  static SmtpServer _buildSmtpServer() {
    if (appPassword.isEmpty) {
      throw Exception('SMTP_APP_PASSWORD not configured in .env file');
    }
    return SmtpServer(
      smtpHost,
      port: smtpPort,
      username: senderEmail,
      password: appPassword,
      ignoreBadCertificate: true,
    );
  }

  // Onboarding success (Gym owner verified)
  static Future<void> sendOnboardingSuccessEmail({
    required String ownerName,
    required String ownerEmail,
    required String gymName,
    String dashboardUrl = 'https://fitnophedia.app/login',
  }) async {
    final smtpServer = _buildSmtpServer();

    final html = '''
    <html>
      <body style="font-family: Poppins, sans-serif; background:#f6fbf9; color:#0b2a1f; padding:20px;">
        <div style="max-width:700px;margin:auto;background:#ffffff;border-radius:12px;padding:28px;border:1px solid #eef6f3;">
          <div style="display:flex;align-items:center;gap:12px;">
            <img src="$logoPath" alt="Fitnophedia" style="width:72px;height:72px;object-fit:contain;">
            <div>
              <h1 style="margin:0;color:$primaryGreen;">Welcome to Fitnophedia, $ownerName!</h1>
              <p style="margin:6px 0 0;color:#3a5a4b;">Your gym <strong>$gymName</strong> has been verified ✅</p>
            </div>
          </div>

          <hr style="border:none;border-top:1px solid #e6f2ec;margin:20px 0;">

          <p>Congratulations — your gym is now live on <strong>Fitnophedia</strong>. You can manage staff, members, subscriptions and analytics directly from your dashboard.</p>

          <div style="text-align:center;margin:22px 0;">
            <a href="$dashboardUrl" style="background:$primaryGreen;color:#fff;padding:12px 20px;border-radius:8px;text-decoration:none;display:inline-block;font-weight:600;">
              Go to Dashboard
            </a>
          </div>

          <p style="color:#6b6b6b;font-size:13px;">If you didn't expect this email, please contact support.</p>
          <p style="font-size:12px;color:#8b8b8b;margin-top:18px;">© 2025 Fitnophedia | Empowering Fitness Communities</p>
        </div>
      </body>
    </html>
    ''';

    final message = Message()
      ..from = Address(senderEmail, senderName)
      ..recipients.add(ownerEmail)
      ..subject = '🎉 $gymName is live on Fitnophedia — Welcome, $ownerName!'
      ..html = html;

    try {
      final sendReport = await send(message, smtpServer);
      print('✅ Onboarding email sent: $sendReport');
    } catch (e) {
      print('❌ Failed to send onboarding email: $e');
    }
  }

  // Team invite template (handles Member or Staff)
  static Future<void> sendTeamInviteEmail({
    required String recipientName,
    required String recipientEmail,
    required String gymName,
    required String role, // 'Member' or 'Staff'
    required String inviteUrl, // link for sign-up / app download
    String? inviterName,
  }) async {
    final smtpServer = _buildSmtpServer();

    final roleTitle = role.toLowerCase() == 'staff' ? 'Staff' : 'Member';
    final intro = inviterName != null
        ? '$inviterName has added you as $roleTitle at'
        : 'You have been added as $roleTitle at';

    final html = '''
    <html>
      <body style="font-family: Poppins, sans-serif; background:#f6fbf9; color:#073626; padding:20px;">
        <div style="max-width:700px;margin:auto;background:#fff;border-radius:12px;padding:24px;border:1px solid #eef6f3;">
          <div style="display:flex;align-items:center;gap:12px;">
            <img src="$logoPath" alt="Fitnophedia" style="width:64px;height:64px;object-fit:contain;">
            <div>
              <h2 style="margin:0;color:$primaryGreen;">Hello $recipientName 👋</h2>
              <p style="margin:6px 0 0;color:#3a5a4b;">$intro <strong>$gymName</strong>.</p>
            </div>
          </div>

          <div style="margin-top:18px;">
            <p>Role: <strong>$roleTitle</strong></p>
            <p>Next steps:</p>
            <ol>
              <li>Click the button below</li>
              <li>Create your account or sign in</li>
              <li>Start using Fitnophedia for $gymName</li>
            </ol>

            <div style="text-align:center;margin:18px 0;">
              <a href="$inviteUrl" style="background:$primaryGreen;color:#fff;padding:10px 16px;border-radius:8px;text-decoration:none;font-weight:600;display:inline-block;">
                Accept Invite & Get Started
              </a>
            </div>

            <p style="font-size:13px;color:#6b6b6b;">If you weren't expecting this invite, please contact the gym admin.</p>
            <p style="font-size:12px;color:#8b8b8b;margin-top:14px;">© 2025 Fitnophedia</p>
          </div>
        </div>
      </body>
    </html>
    ''';

    final message = Message()
      ..from = Address(senderEmail, senderName)
      ..recipients.add(recipientEmail)
      ..subject = '💪 You’ve been added to $gymName as $roleTitle'
      ..html = html;

    try {
      final sendReport = await send(message, smtpServer);
      print('✅ Team invite sent: $sendReport');
    } catch (e) {
      print('❌ Failed to send team invite email: $e');
    }
  }

  // Backwards-compatible wrapper matching existing call-site (memberName/memberEmail)
  static Future<void> sendMemberInviteEmail({
    required String memberName,
    required String memberEmail,
    required String gymName,
    String role = 'Member',
    String inviteUrl = 'https://fitnophedia.app/download',
    String? inviterName,
  }) async {
    await sendTeamInviteEmail(
      recipientName: memberName,
      recipientEmail: memberEmail,
      gymName: gymName,
      role: role,
      inviteUrl: inviteUrl,
      inviterName: inviterName,
    );
  }

  // Payment success + subscription details
  static Future<void> sendPaymentSuccessEmail({
    required String ownerName,
    required String ownerEmail,
    required String gymName,
    required String planName,
    required double price,
    required DateTime startDate,
    required DateTime endDate,
    required String paymentId,
    String? receiptUrl,
    String dashboardUrl = 'https://fitnophedia.app/subscription',
  }) async {
    final smtpServer = _buildSmtpServer();

    String formatDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final html = '''
    <html>
      <body style="font-family: Poppins, sans-serif; background:#f6fbf9; color:#0b2a1f; padding:20px;">
        <div style="max-width:720px;margin:auto;background:#fff;border-radius:12px;padding:26px;border:1px solid #eaf6f1;">
          <div style="display:flex;align-items:center;gap:12px;">
            <img src="$logoPath" alt="Fitnophedia" style="width:70px;height:70px;object-fit:contain;">
            <div>
              <h2 style="margin:0;color:$primaryGreen;">Payment Received — Thank you, $ownerName!</h2>
              <p style="margin:6px 0 0;color:#3a5a4b;">Your subscription for <strong>$gymName</strong> is now active.</p>
            </div>
          </div>

          <hr style="border:none;border-top:1px solid #e6f2ec;margin:18px 0;">

          <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse:collapse;">
            <tr>
              <td style="font-weight:600;color:#234832;">Plan</td>
              <td>$planName</td>
            </tr>
            <tr>
              <td style="font-weight:600;color:#234832;">Amount Paid</td>
              <td>₹${price.toStringAsFixed(2)}</td>
            </tr>
            <tr>
              <td style="font-weight:600;color:#234832;">Start Date</td>
              <td>${formatDate(startDate)}</td>
            </tr>
            <tr>
              <td style="font-weight:600;color:#234832;">End Date</td>
              <td>${formatDate(endDate)}</td>
            </tr>
            <tr>
              <td style="font-weight:600;color:#234832;">Payment ID</td>
              <td>$paymentId</td>
            </tr>
          </table>

          <div style="text-align:center;margin:20px 0;">
            <a href="$dashboardUrl" style="background:$primaryGreen;color:#fff;padding:12px 18px;border-radius:8px;text-decoration:none;font-weight:600;">
              Manage Subscription
            </a>
            ${receiptUrl != null ? '<a href="$receiptUrl" style="margin-left:10px;display:inline-block;padding:12px 18px;border-radius:8px;border:1px solid #dfeee6;text-decoration:none;color:$primaryGreen;">View Receipt</a>' : ''}
          </div>

          <p style="font-size:13px;color:#6b6b6b;">Need help? Reply to this email or contact our support.</p>
          <p style="font-size:12px;color:#8b8b8b;margin-top:12px;">© 2025 Fitnophedia</p>
        </div>
      </body>
    </html>
    ''';

    final message = Message()
      ..from = Address(senderEmail, senderName)
      ..recipients.add(ownerEmail)
      ..subject = '✅ Payment received — Your $planName subscription is active'
      ..html = html;

    try {
      final sendReport = await send(message, smtpServer);
      print('✅ Payment success email sent: $sendReport');
    } catch (e) {
      print('❌ Failed to send payment success email: $e');
    }
  }
}
