import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:app_links/app_links.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'dart:convert' show base64, utf8;
import 'package:crypto/crypto.dart' as crypto;

// ═══════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════
const String webClientId = '96139047750-5ooi0pbvch98qu447somuurh6k6fmhcj.apps.googleusercontent.com';
const String oneSignalAppId = '06b99c2b-b3b4-413b-b6cc-480a624f4e25';
const String kBackendBaseUrl = 'https://www.mayajaal.online';
const int kAppCurrentVersionCode = 2;

const List<String> kAllowedEmailDomains = [
  '@gmail.com',
  '@googlemail.com',
];

const int kMinAccountAgeSeconds = 60;
const int kMaxLoginAttempts = 5;
const int kLoginWindowMinutes = 10;
const String _kHmacSecret = 'MJ_HMAC_v1_a7f3b92e_d4c8_11ef_9b8a_00ff_secret_2026';

const Color kGreen = Color(0xFF00FF66);
const Color kNeonCyan = Color(0xFF00F0FF);
const Color kNeonPurple = Color(0xFF9D00FF);
const Color kBg = Color(0xFF000000);
const Color kCardBg = Color(0xFF031408);
const Color kDimGreen = Color(0xFF4FBF8B);
const Color kGold = Color(0xFFFFD700);
const Color kSilver = Color(0xFFC0C0C0);
const Color kBronze = Color(0xFFCD7F32);
const Color kRed = Color(0xFFFF3B3B);

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<String> languageNotifier = ValueNotifier('English');
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ═══════════════════════════════════════════════════════
// HELPER: AUTO THUMBNAIL GENERATOR
// ═══════════════════════════════════════════════════════
Widget buildAutoThumbnail(String title, {bool isSmall = false}) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.black, kGreen.withOpacity(0.3), Colors.black],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: kGreen.withOpacity(0.3)),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 4,
          left: 4,
          right: 4,
          child: Text(
            'MAYAJAAL',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: isSmall ? 6 : 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          width: isSmall ? 24 : 48,
          height: isSmall ? 24 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.7),
            border: Border.all(color: kGreen, width: 1.5),
            boxShadow: [BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 10)],
          ),
          child: Icon(Icons.play_arrow_rounded, color: kGreen, size: isSmall ? 16 : 28),
        ),
        Positioned(
          left: 6,
          bottom: 6,
          right: 6,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isSmall ? 8 : 11,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildMediaThumbnail(String? thumb, String title, {bool isSmall = false}) {
  if (thumb != null && thumb.isNotEmpty) {
    if (thumb.startsWith('http')) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => buildAutoThumbnail(title, isSmall: isSmall),
      );
    } else {
      try {
        return Image.memory(
          base64Decode(thumb),
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => buildAutoThumbnail(title, isSmall: isSmall),
        );
      } catch (_) {
        return buildAutoThumbnail(title, isSmall: isSmall);
      }
    }
  }
  return buildAutoThumbnail(title, isSmall: isSmall);
}

// ═══════════════════════════════════════════════════════
// IN-APP LEGAL & POLICY DIALOG (Exact Text from User)
// ═══════════════════════════════════════════════════════
class LegalPolicyDialog {
  static const Color kGreen = Color(0xFF00FF66);
  static const Color kDimGreen = Color(0xFF4FBF8B);
  static const Color kCardBg = Color(0xFF031408);
  static const Color kNeonCyan = Color(0xFF00F0FF);

  static void showPolicy(BuildContext context, String type) {
    String title = '';
    String subtitle = '';
    Color accentColor = kGreen;
    List<Widget> sections = [];

    switch (type) {
      case 'privacy':
        title = 'PRIVACY POLICY';
        subtitle = 'Effective Date: October 2026 | Cloud Edge & Streaming Network';
        accentColor = kGreen;
        sections = [
          _buildSection('Introduction', 
            'Thank you for choosing MayaJaal ("Platform", "App", "we", "us"). This Privacy Policy is engineered to help you understand how we collect, process, utilize, disclose, and safeguard your personal data and technical telemetry when accessing our web dashboard, Android streaming application, Cloudflare R2 media caches, and official Telegram automation bots (@Mayajaalfilebot, @MayaJaalBulkConverterbot, @MayaJaalExpiryBot). By creating an account or using the platform, you agree to the terms outlined herein.'),
          _buildSection('1. Information We Collect', 
            '1.1 User & Creator Provided Information: When registering an account or initiating monetization, we collect your verified email address, cryptographically hashed passwords, and payout identifiers (including UPI IDs and Bank account records) strictly for processing withdrawals.\n\n1.2 Media & Video Assets: Utilizing our streaming pipelines involves ingesting, transcoding, and storing video files, stream manifests, and technical duration metadata across Cloudflare edge storage.\n\n1.3 In-App Interactions: The MayaJaal mobile app collects and stores your Recent Watch History, Liked/Disliked video records, and Saved Video Library to ensure a personalized streaming experience.'),
          _buildSection('2. Automatically Collected Telemetry & Cookies', 
            '2.1 Device & Network Telemetry: We automatically log unique device identifiers, IP addresses, operating system types, browser fingerprints, and playback resolution metrics to detect proxy loops and optimize streaming throughput.\n\n2.2 Cookies & Local Tokens: The platform utilizes encrypted session cookies, authentication tokens, and local cache entries to maintain creator logins and remember player settings.'),
          _buildSection('3. How We Use Your Information', 
            '3.1 Service Delivery & Streaming: To provide low-latency, hardware-accelerated 4K playback and maintain instant video conversion via Telegram bots.\n\n3.2 28-Day Lifecycle Automated Notifications: To track the 28-day validity of active links and dispatch automated renewal reminders via @MayaJaalExpiryBot 24 hours prior to link expiration.\n\n3.3 Payout Verification: To validate authentic human views, evaluate referral commissions, and disburse earnings through verified payment channels.'),
          _buildSection('4. Information Sharing & Non-Disclosure', 
            '4.1 Commercial Non-Disclosure: We do not sell, rent, broker, or trade personal creator data, media viewing logs, or platform engagement records to external advertising syndicates.\n\n4.2 Legal Compliance: We may disclose records solely in response to verified statutory demands, judicial subpoenas, or valid law enforcement inquiries concerning cyber attacks or unlawful material.'),
          _buildSection('5. Video Viewing & Interactive Functionality', 
            '5.1 Creator Responsibility: Users are solely accountable for the media files uploaded and converted through the service, ensuring compliance with intellectual property standards.\n\n5.2 Sharing & Distribution: Creators exercise direct discretion over the distribution of their converted stream links across social networks or websites.'),
          _buildSection('6. Advertisements & Monetization Delivery', 
            'MayaJaal may display programmatic advertising banners or native video interstitials. Third-party ad networks may capture non-personally identifiable telemetry to serve relevant ads. We do not transmit confidential creator account credentials to external advertising networks.'),
          _buildSection('7. Data Security Measures', 
            '7.1 Cryptographic Controls: We deploy end-to-end TLS 1.3 encryption, Cloudflare security firewalls, and restricted database permissions to protect your account against unauthorized access, alteration, or disclosure.\n\n7.2 Transmission Disclaimer: While we enforce enterprise-grade security protocols, no method of transmission over the internet or cloud storage can be guaranteed 100% impenetrable.'),
          _buildSection('8. User Rights & Account Choices', 
            '8.1 Account Management: Creators may review, modify, or update their payout parameters and account settings directly through the web dashboard.\n\n8.2 Data Purge: You may request the permanent deletion of your account and associated media links by submitting a verified request to our compliance desk.'),
          _buildSection('9. Strict 18+ Age Restriction & Children\'s Privacy', 
            'The MayaJaal platform and its automation suite are strictly intended for individuals aged eighteen (18) years or older. We do not knowingly collect or maintain data from minors. Any discovered minor records or Child Sexual Abuse Material (CSAM) will be permanently purged immediately, with related IP telemetry escalated to Cyber Crime authorities.'),
          _buildSection('10. Policy Modifications & Contact', 
            'We reserve the right to revise this Privacy Policy periodically. Continued use of the platform following published amendments constitutes acceptance of the modified terms.\n\nOfficial Compliance Desk: mayajaalsupport@gmail.com'),
        ];
        break;

      case 'terms':
        title = 'TERMS & CONDITIONS';
        subtitle = 'Effective Date: October 2026 | Operating Governance & Creator Agreement';
        accentColor = kGreen;
        sections = [
          _buildSection('Introduction', 
            'By creating an account, accessing the MayaJaal web dashboard, utilizing our Telegram automation suite (@Mayajaalfilebot, @MayaJaalBulkConverterbot, @MayaJaalExpiryBot), or downloading the official MayaJaal Android Streaming APK, you acknowledge that you have read, understood, and agreed to be legally bound by these Terms and Conditions.'),
          _buildSection('1. Use of Services & Platform Architecture', 
            'MayaJaal provides a hardware-accelerated video streaming network, link conversion engine, and media delivery platform. Users and creators are solely responsible for all content uploaded, converted, or streamed through the service.\n\nUsers shall not upload, transcode, or share any media that infringes intellectual property rights, privacy rights, or statutory laws. Any attempt to disrupt network performance, exploit APIs, or inject malicious payloads is strictly prohibited.'),
          _buildSection('2. User Accounts & Strict 18+ Eligibility', 
            'The platform is strictly authorized for verified individuals aged eighteen (18) years or older. Minor onboarding is completely prohibited.\n\nCreators are responsible for maintaining the confidentiality of their credentials and all activities occurring under their accounts. MayaJaal reserves the absolute right to suspend or terminate accounts that breach platform standards or engage in deceptive conduct.'),
          _buildSection('3. Privacy & Telemetry Isolation', 
            'Your privacy is protected in strict accordance with the MayaJaal Privacy Policy. Creator analytics, financial settlement records, and viewing histories are never brokered or sold to external data syndicates.'),
          _buildSection('4. Advertisements, Promotions & Third-Party Services', 
            'The platform and mobile streaming application may display third-party advertisements. Users acknowledge that MayaJaal does not control, endorse, or assume legal liability for third-party ad creatives, external landing pages, or advertiser representations.\n\nAny business dealings, transactions, or interactions with third-party advertisers appearing on the platform are strictly between the user and such third parties.'),
          _buildSection('5. Media Validity, 28-Day Expiration & Renewal Protocol', 
            '5.1 28-Day Default Lifecycle: All converted streamable media links are provisioned with an automated twenty-eight (28) day active routing lifecycle on our edge storage clusters.\n\n5.2 Automated Warning Alerts: Automated renewal notifications are dispatched via @MayaJaalExpiryBot 24 hours prior to link expiration.\n\n5.3 Multi-Channel Renewal: Creators may renew active links within the 24-hour expiration window directly via the Web Dashboard 28-Day Renewal Manager or within the MayaJaal mobile app to maintain uninterrupted streaming delivery.\n\n5.4 Dormant Media Purge: Links that are not renewed within the designated alert window, or media assets exceeding cloud storage allocations without active viewing traffic, are automatically decommissioned and permanently purged under our Fair Use Storage Policy.'),
          _buildSection('6. App Features & User Interactive Functionality', 
            'The MayaJaal streaming APK offers integrated playback history, personal library video saving, like/dislike interactions, and social sharing to ensure optimal viewer experience.\n\nAny manipulation of player telemetry, simulated engagement metrics, or automated script queries directed at these interactive features constitutes a material breach.'),
          _buildSection('7. Intellectual Property', 
            'The MayaJaal platform, trademarks, logos, custom streaming software, and proprietary dashboard architectures are the intellectual property of MayaJaal and are protected by applicable copyright and international property laws.'),
          _buildSection('8. Copyright Complaints & DMCA Procedure', 
            'If you believe that any material made available via MayaJaal infringes upon a copyright you own or represent, you may file a formal notification with our Designated Agent in full compliance with the statutory provisions of our DMCA Policy.'),
          _buildSection('9. Child Abuse & CSAM Zero-Tolerance Protocol', 
            'MayaJaal maintains an absolute Zero-Tolerance policy against Child Sexual Abuse Material (CSAM), non-consensual sexual exploitation, and underage explicit media. Upon receipt of notice or automated telemetry detection, our compliance desk acts immediately to remove the content and permanently terminate the offending user\'s account.\n\nWe actively cooperate with law enforcement authorities, including Indian child protection units and Cyber Crime Police departments, providing forensic IP logs to assist in criminal prosecution.\n\nUrgent CSAM Reports: mayajaalsupport@gmail.com'),
          _buildSection('10. Traffic Integrity, Anti-Fraud & Balance Forfeiture', 
            'Monetization accounts generating views via automated headless bots, click farms, proxy networks, emulators, or deceptive traffic exchanges will be immediately demonetized, with pending balances permanently forfeited.'),
          _buildSection('11. Limitation of Liability', 
            'In no event shall MayaJaal, its operators, or affiliates be held liable for any indirect, incidental, consequential, special, or punitive damages, including loss of profits, data, or platform availability resulting from service interruptions or third-party infrastructure failures.'),
          _buildSection('12. Governing Law, Modifications & Contact', 
            'These Terms and Conditions shall be governed by and construed in accordance with the laws of India. MayaJaal reserves the operational right to update or modify these Terms at any time.\n\nOfficial Compliance Inquiries: mayajaalsupport@gmail.com'),
        ];
        break;

      case 'dmca':
        title = 'DMCA & COPYRIGHT POLICY';
        subtitle = 'Online Service Provider Notification & Takedown Framework | Title II 17 U.S.C. § 512';
        accentColor = const Color(0xFFFB7185);
        sections = [
          _buildSection('Introduction', 
            'MayaJaal ("Platform", "we", "us") functions as an intermediary and online content routing provider under Title II of the Digital Millennium Copyright Act, 17 U.S.C. Section 512 ("DMCA"). This document formalizes the statutory notice-and-takedown procedures established by MayaJaal to enforce the intellectual property rights of copyright holders, as well as counter-notification protocols for restoring mistakenly disabled streams.\n\nWe strictly comply with prevailing standards under international intellectual property frameworks. MayaJaal accommodates and does not interfere with standard technical protection measures deployed by rights holders, and maintains an active procedure for disabling access to or permanently removing media assets confirmed to infringe third-party copyrights.'),
          _buildSection('1. Absence of Search Index & Directory', 
            'MayaJaal operates as a high-throughput edge delivery network, hardware-accelerated video streaming engine, and Telegram automation converter pipeline (@Mayajaalfilebot, @MayaJaalBulkConverterbot). The platform is technically incapable of maintaining a public search directory or index of private content uploaded or streamed through automated bot endpoints.'),
          _buildSection('2. Privacy of Streamed Payloads', 
            'Unless an authenticated creator elects to share or distribute converted media streams across public channels or websites, all ingested file objects and manifests are treated as confidential, private transmissions.'),
          _buildSection('3. Absence of Pre-Upload Adjudication Authority', 
            'In the absence of a verified notification submitted by an authenticated copyright holder or their lawful representative, MayaJaal possesses neither the statutory authority nor the technical capacity to determine whether an individual creator owns, holds a valid distribution proxy for, or is legally entitled to share specific media under the doctrines of fair use or the public domain. In accordance with applicable intermediary liability laws, all transmitted content is presumed compliant with our Terms of Service unless and until a formal written infringement claim is received.'),
          _buildSection('4. Requirements for Submitting a Legitimate DMCA Takedown Notice', 
            'To submit an actionable, legally binding takedown notification under 17 U.S.C. § 512(c)(3), the copyright owner or their designated legal agent must transmit a written communication containing all of the following criteria:\n\nLegal Authority & Signature: Identification of yourself as the verified owner of an exclusive right that is allegedly infringed, or as an authorized agent operating on behalf of such owner, accompanied by a valid physical or electronic signature.\n\nIdentification of Protected Asset: Specific identification and clear description of the copyrighted work claimed to have been infringed.\n\nExact Infringing URLs: Identification of the material that is claimed to be infringing, providing the direct, exact web URLs (e.g., https://mayajaal.online/... or associated streaming manifest endpoints) hosted on our routing infrastructure. Generalized domain references or unverified filenames are insufficient.\n\nContact Details & Affiliation: Comprehensive contact details for the notifying party, including full legal name, physical address, direct telephone number, and verifiable email address. If acting as an external vendor or legal counsel, indicate the corporate relationship to the rights holder.\n\nGood Faith Representation: An unambiguous statement that: "I have a good faith belief that use of the aforementioned material in the manner complained of is not authorized by the copyright owner, its agent, or the law."\n\nPenalty of Perjury Certification: An express declaration that: "I swear, under penalty of perjury, that the information in this notification is accurate and that I am the copyright owner, or authorized to act on behalf of the owner of an exclusive right that is allegedly infringed."\n\nDesignated DMCA Compliance Desk\nTo exercise statutory DMCA rights, all notices conforming to the requirements above must be transmitted directly to our designated copyright enforcement desk:\nEmail: mayajaalsupport@gmail.com'),
          _buildSection('5. Notice & Takedown Protocol (Rapid Purge)', 
            'Upon receipt of a valid, fully executed DMCA notification meeting the statutory standards above, MayaJaal will act expeditiously to remove or permanently disable access to the designated infringing materials from our Cloudflare edge routing layers. Formal confirmation of removal is dispatched once the link has been disconnected from the routing tables.'),
          _buildSection('6. Plain Text Requirement & Attachment Protocol', 
            'In accordance with cyber security safeguards, all takedown communications, statements, and URL indices must be delivered directly within the body of the message as plain text. Enclosed executable files, encrypted archives, ZIP folders, or unsolicited external download links will not be opened or examined due to malicious payload prevention protocols. Documentary attachments will be processed solely upon direct request by the compliance desk.'),
          _buildSection('7. Repeat Infringer Policy & Banishment', 
            'MayaJaal maintains an active termination policy for accounts that repeatedly infringe intellectual property rights. Creators who accumulate verified copyright complaints will face immediate revocation of streaming link privileges, forfeiture of account access, and permanent blacklisting of associated Telegram bot endpoints.'),
        ];
        break;

      case 'partner':
        title = 'PARTNER AGREEMENT';
        subtitle = 'Effective Date: October 2026 | Creator Revenue Share & Anti-Fraud Governance';
        accentColor = kNeonCyan;
        sections = [
          _buildSection('Introduction', 
            'This Agreement governs creator monetization, traffic integrity, referral commissions, and wallet settlements across the MayaJaal network. Compliance with these security and anti-abuse protocols is strictly mandatory.'),
          _buildSection('1. Qualified Views & Streaming Monetization', 
            '1.1 Human Initiation: A Qualified View is recorded solely when a genuine, authenticated human end-user initiates real-time playback through the hardware-accelerated MayaJaal player.\n\n1.2 Server-Side Verification: Views are validated server-side. Embedded automated loops, auto-refresh iframes, or headless browser scripts will not be counted toward creator earnings.'),
          _buildSection('2. Strict Account Ban Triggers & Multi-Account Fraud', 
            '2.1 1 Device = 1 Account Policy (Hardware Device Lock): Only one authenticated MayaJaal account is permitted per physical hardware device. Creating or rotating multiple accounts on a single mobile device will trigger an automated hardware lock and permanent account termination.\n\n2.2 Self-Referral & App Share Fraud: Creating multiple fake Gmail accounts on the same phone to exploit app share links or referral rewards is strictly detected by our device telemetry. Any account engaging in fake self-referral cloning will face instant permanent ban and complete forfeiture of all balances.\n\n2.3 Prohibited Environments (Emulators & Rooted Phones): Operating the MayaJaal App via virtual emulators (e.g., BlueStacks, LDPlayer, Nox), rooted Android builds, or jailbroken devices is strictly blocked. Ingestion from virtualized environments results in immediate security suspension.'),
          _buildSection('3. Authentication & Sign-Up Protocols', 
            '3.1 Verified Gmail OAuth Only: Account creation is restricted exclusively to verified @gmail.com addresses authenticated via official Google OAuth. Disposable, temporary, or unauthorized domains are automatically rejected.\n\n3.2 Brute-Force Rate Limiting: Repetitive authentication attacks or credential stuffing will trigger an automated 10-minute firewall lockout against the offending IP and device signature.'),
          _buildSection('4. Cryptographic Security & Private Telemetry', 
            '4.1 Military-Grade HMAC & TLS 1.3: Communications between mobile APKs, server endpoints, and cloud object caches are secured via HTTPS and military-grade HMAC tokenization, preventing Man-in-the-Middle (MITM) attacks.\n\n4.2 Private API Keys: Creator API tokens allocated for Telegram automation bots (@Mayajaalfilebot, @MayaJaalBulkConverterbot) are cryptographically isolated and visible solely to the account holder.'),
          _buildSection('5. 28-Day Link Renewal Lifecycle', 
            'Monetization is directly linked to active media assets. Converted video links maintain a 28-day lifecycle. Automated renewal alerts are transmitted via @MayaJaalExpiryBot 24 hours prior to expiration; non-renewed links cease to accumulate views upon deactivation.'),
          _buildSection('6. Payout Rules & Thresholds', 
            '6.1 Threshold & Verification: Withdrawal requests may be submitted once the verified Available Balance reaches $5.00 USD (or INR equivalent).\n\n6.2 Verified Rails: Disbursements are cleared via direct UPI and verified Bank Transfer within 24 to 72 business hours following anti-fraud telemetry screening.\n\n6.3 Reversals: Disputed, bot-manipulated, or fraudulent traffic balances will be permanently voided.'),
          _buildSection('7. Independent Relationship', 
            'Creators operate as independent contractors. Participation establishes no employment, franchise, or agency relationship with MayaJaal.'),
        ];
        break;

      case 'support':
        title = 'HELP & SUPPORT';
        subtitle = 'For platform troubleshooting, Telegram bot configurations, link renewal assistance, or withdrawal verification, reach out through our official channels:';
        accentColor = Colors.amberAccent;
        sections = [
          _buildSection('Official Compliance Email', 
            'mayajaalsupport@gmail.com\n\nDirect Email'),
          _buildSection('Telegram Official Helpdesk', 
            '@MayaJaalSupport'),
          _buildSection('Official Instagram Desk', 
            '@maya_jaal_official'),
          _buildSection('Response Times', 
            'Automated bots operate 24/7. Support inquiries are reviewed and resolved within 12–24 business hours.'),
        ];
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF030804),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: accentColor.withOpacity(0.5), width: 1.5),
      ),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.55,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withOpacity(0.5)),
                    ),
                    child: Icon(Icons.verified_user_rounded, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: accentColor.withOpacity(0.2), height: 1),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ...sections,
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Center(
                        child: Text(
                          '© 2026 MayaJaal Network. All Rights Reserved.',
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(c),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSection(String heading, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF07120A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGreen.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11.5,
              height: 1.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TRANSLATIONS
// ═══════════════════════════════════════════════════════
final Map<String, Map<String, String>> localizedStrings = {
  'English': {
    'app_title': 'MAYA JAAL',
    'paste_hint': 'Paste Stream URL',
    'watch_history': '> WATCH HISTORY',
    'no_history': 'no history yet',
    'settings': 'SETTINGS',
    'dark_theme': 'Dark Theme',
    'language': 'Language',
    'download_location': 'Download Location',
    'clear_history': 'Clear History',
    'logout': 'Logout',
    'uploader': 'UPLOADER',
    'filename': 'FILE NAME',
  },
  'Hindi': {
    'app_title': 'माया जाल',
    'paste_hint': 'यहाँ लिंक पेस्ट करें...',
    'watch_history': '> देखने का इतिहास',
    'no_history': 'अभी कोई इतिहास नहीं है',
    'settings': 'सेटिंग्स',
    'dark_theme': 'डार्क थीम',
    'language': 'भाषा (Language)',
    'download_location': 'डाउनलोड स्थान',
    'clear_history': 'इतिहास साफ़ करें',
    'logout': 'लॉग आउट',
    'uploader': 'अपलोडर',
    'filename': 'फ़ाइल का नाम',
  },
};

String tr(String key) {
  final lang = languageNotifier.value;
  return localizedStrings[lang]?[key] ?? localizedStrings['English']?[key] ?? key;
}

// ═══════════════════════════════════════════════════════
// HAPTIC HELPER
// ═══════════════════════════════════════════════════════
class Haptic {
  static Future<void> light() async {
    try { await HapticFeedback.lightImpact(); } catch (_) {}
  }
  static Future<void> medium() async {
    try { await HapticFeedback.mediumImpact(); } catch (_) {}
  }
  static Future<void> heavy() async {
    try { await HapticFeedback.heavyImpact(); } catch (_) {}
  }
  static Future<void> selection() async {
    try { await HapticFeedback.selectionClick(); } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════
// SECURITY GUARD
// ═══════════════════════════════════════════════════════
class SecurityGuard {
  static bool isGmailOnly(String? email) {
    if (email == null || email.isEmpty) return false;
    final lower = email.trim().toLowerCase();
    return kAllowedEmailDomains.any((d) => lower.endsWith(d));
  }

  static bool isGoogleProvider(User user) {
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  static bool isEmailVerified(User user) {
    return user.emailVerified == true;
  }

  static bool isAccountOldEnough(User user, {int seconds = kMinAccountAgeSeconds}) {
    final created = user.metadata.creationTime;
    if (created == null) return false;
    return DateTime.now().difference(created).inSeconds >= seconds;
  }

  static Future<String?> validateUser(User user) async {
    if (!isGoogleProvider(user)) {
      return 'Only Google sign-in is allowed.';
    }
    if (!isGmailOnly(user.email)) {
      return 'Only @gmail.com accounts are supported.';
    }
    if (!isEmailVerified(user)) {
      return 'Your Gmail is not verified by Google. Please verify and retry.';
    }
    if (!isAccountOldEnough(user)) {
      return 'This account is too new. Please wait a minute and try again.';
    }
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        return 'Session token invalid. Please re-login.';
      }
    } catch (_) {
      return 'Session validation failed. Please retry.';
    }
    return null;
  }

  static Future<Map<String, dynamic>> validateAndBindDevice(
    String uid,
    String email,
  ) async {
    try {
      final deviceId = await DeviceIdHelper.get();
      final ref = FirebaseDatabase.instance.ref('deviceBindings/$deviceId');
      final snap = await ref.once();
      final data = snap.snapshot.value as Map?;

      if (data == null) {
        await ref.set({
          'uid': uid,
          'email': email,
          'boundAt': DateTime.now().millisecondsSinceEpoch,
        });
        return {'ok': true, 'firstBind': true};
      }

      final existingUid = data['uid']?.toString() ?? '';
      if (existingUid == uid) {
        await ref.update({
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        return {'ok': true, 'firstBind': false};
      }

      return {
        'ok': false,
        'reason': 'This device is already linked to a different MayaJaal account.',
        'existingEmail': data['email']?.toString() ?? 'unknown',
        'hint': 'Use the original account or contact support.',
      };
    } catch (e) {
      debugPrint('Device bind error: $e');
      return {'ok': true, 'warning': 'binding_skipped'};
    }
  }

  static Future<Map<String, dynamic>> detectRootOrEmulator() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final isEmulator =
            a.model.toLowerCase().contains('sdk') ||
            a.model.toLowerCase().contains('emulator') ||
            a.model.toLowerCase().contains('android sdk built for') ||
            a.manufacturer.toLowerCase().contains('genymotion') ||
            a.manufacturer.toLowerCase().contains('unknown') ||
            a.product.toLowerCase().contains('sdk') ||
            a.hardware.toLowerCase().contains('goldfish') ||
            a.hardware.toLowerCase().contains('ranchu');

        bool rooted = false;
        try {
          final suPaths = [
            '/system/app/Superuser.apk',
            '/sbin/su',
            '/system/bin/su',
            '/system/xbin/su',
            '/data/local/xbin/su',
            '/data/local/bin/su',
            '/system/sd/xbin/su',
            '/system/bin/failsafe/su',
            '/data/local/su',
            '/su/bin/su',
          ];
          for (final p in suPaths) {
            if (File(p).existsSync()) { rooted = true; break; }
          }
        } catch (_) {}

        return {
          'emulator': isEmulator,
          'rooted': rooted,
          'isPhysical': a.isPhysicalDevice,
          'brand': a.brand,
          'model': a.model,
          'sdk': a.version.sdkInt,
        };
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        final isJailbroken = i.isPhysicalDevice == false;
        return {
          'emulator': isJailbroken,
          'rooted': isJailbroken,
          'isPhysical': i.isPhysicalDevice,
          'brand': 'Apple',
          'model': i.utsname.machine,
        };
      }
    } catch (e) {
      debugPrint('device detect err: $e');
    }
    return {'emulator': false, 'rooted': false, 'isPhysical': true};
  }

  static Future<bool> isPackageIntact() async {
    try {
      if (Platform.isAndroid) {
        return true; 
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> checkLoginRateLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final windowMs = kLoginWindowMinutes * 60 * 1000;
      final raw = prefs.getString('mj_login_attempts');
      List<int> attempts = [];
      if (raw != null) {
        attempts = (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList();
      }
      attempts = attempts.where((t) => now - t < windowMs).toList();
      if (attempts.length >= kMaxLoginAttempts) return false;
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> recordLoginAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final raw = prefs.getString('mj_login_attempts');
      List<int> attempts = [];
      if (raw != null) {
        attempts = (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList();
      }
      attempts.add(now);
      final windowMs = kLoginWindowMinutes * 60 * 1000;
      attempts = attempts.where((t) => now - t < windowMs).toList();
      await prefs.setString('mj_login_attempts', jsonEncode(attempts));
    } catch (_) {}
  }

  static Future<void> clearLoginAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mj_login_attempts');
    } catch (_) {}
  }

  static String signRequest(String method, String path, String body) {
    final payload = '$method\n$path\n$body';
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(_kHmacSecret));
    final digest = hmac.convert(utf8.encode(payload));
    return digest.toString();
  }

  static Map<String, String> signedHeaders({
    required String method,
    required String path,
    required String body,
    required String deviceId,
    String? uid,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final sig = signRequest(method, path, '$ts.$body');
    return {
      'Content-Type': 'application/json',
      'X-MJ-Timestamp': ts,
      'X-MJ-Device': deviceId,
      'X-MJ-Uid': uid ?? '',
      'X-MJ-Signature': sig,
    };
  }

  static Future<bool> validateSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (!isGmailOnly(user.email)) return false;
    if (!isEmailVerified(user)) return false;
    if (!isGoogleProvider(user)) return false;
    try {
      await user.reload();
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh == null) return false;
      final token = await fresh.getIdToken(false);
      if (token == null || token.isEmpty) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> fullGate(User user) async {
    final userErr = await validateUser(user);
    if (userErr != null) return userErr;

    final device = await detectRootOrEmulator();
    if (device['emulator'] == true) {
      return 'Emulator detected. MayaJaal requires a physical device.';
    }
    if (device['rooted'] == true) {
      return 'Rooted/jailbroken device detected. Please use a secure device.';
    }

    final intact = await isPackageIntact();
    if (!intact) return 'App integrity check failed. Please reinstall from official source.';

    final bind = await validateAndBindDevice(user.uid, user.email ?? '');
    if (bind['ok'] != true) {
      return bind['reason']?.toString() ?? 'Device binding failed. Contact support.';
    }

    final sessOk = await validateSession();
    if (!sessOk) return 'Session invalid. Please login again.';

    return null;
  }
}

// ═══════════════════════════════════════════════════════
// CYBER RANK SYSTEM
// ═══════════════════════════════════════════════════════
class CyberRank {
  static const List<Map<String, dynamic>> ranks = [
    {'name': 'Neon Rookie', 'emoji': '🥉', 'color': kSilver, 'min': 0},
    {'name': 'Cyber Trader', 'emoji': '🥈', 'color': kNeonCyan, 'min': 1000},
    {'name': 'Matrix Master', 'emoji': '🥇', 'color': kGreen, 'min': 10000},
    {'name': 'Quantum Elite', 'emoji': '💎', 'color': kNeonPurple, 'min': 100000},
    {'name': 'MayaJaal Legend', 'emoji': '👑', 'color': kGold, 'min': 1000000},
  ];

  static Map<String, dynamic> get(int views) {
    Map<String, dynamic> current = ranks[0];
    for (final r in ranks) {
      if (views >= (r['min'] as int)) current = r;
    }
    return current;
  }

  static Map<String, dynamic>? next(int views) {
    for (final r in ranks) {
      if (views < (r['min'] as int)) return r;
    }
    return null;
  }

  static int getIndex(int views) {
    int idx = 0;
    for (int i = 0; i < ranks.length; i++) {
      if (views >= (ranks[i]['min'] as int)) idx = i;
    }
    return idx;
  }
}

// ═══════════════════════════════════════════════════════
// AD TRACKER
// ═══════════════════════════════════════════════════════
class AdTracker {
  static const String _kCountKey = 'ads_watched_count';
  static const String _kLastTimeKey = 'ads_last_reset_time';

  static Future<int> getWatchedCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kCountKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> increment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_kCountKey) ?? 0;
      final newCount = current + 1;
      if (newCount >= 7) {
        await prefs.setInt(_kCountKey, 0);
        await prefs.setInt(_kLastTimeKey, DateTime.now().millisecondsSinceEpoch);
      } else {
        await prefs.setInt(_kCountKey, newCount);
      }
    } catch (_) {}
  }

  static Future<bool> isAdFreeWindow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt(_kLastTimeKey) ?? 0;
      if (lastTime == 0) return false;
      final diff = DateTime.now().millisecondsSinceEpoch - lastTime;
      return diff < 24 * 60 * 60 * 1000;
    } catch (_) {
      return false;
    }
  }

  static Future<int> hoursRemaining() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt(_kLastTimeKey) ?? 0;
      if (lastTime == 0) return 0;
      final diff = DateTime.now().millisecondsSinceEpoch - lastTime;
      final remaining = 24 * 60 * 60 * 1000 - diff;
      return remaining > 0 ? (remaining / (60 * 60 * 1000)).ceil() : 0;
    } catch (_) {
      return 0;
    }
  }
}

// ═══════════════════════════════════════════════════════
// MAYAJAAL FIREBASE ACCOUNT SERVICE
// ═══════════════════════════════════════════════════════
class MayaJaalAccount {
  static String? cachedUid;
  static String? cachedEmail;
  static String? cachedName;
  static String? cachedPhoto;
  static String? cachedApiKey;

  static DatabaseReference get _rtdb => FirebaseDatabase.instance.ref();

  static Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final err = await SecurityGuard.validateUser(user);
      if (err != null) {
        debugPrint('🚫 init rejected: $err');
        await signOut();
        return;
      }
      cachedUid = user.uid;
      cachedEmail = user.email;
      cachedName = user.displayName;
      cachedPhoto = user.photoURL;
      await syncUserToRTDB(user);
      await loadApiKey();
    }
  }

  static bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  static Future<void> syncUserToRTDB(User user) async {
    try {
      if (!SecurityGuard.isGmailOnly(user.email)) {
        debugPrint('🚫 RTDB sync blocked: non-gmail');
        return;
      }
      final ref = _rtdb.child('users/${user.uid}');
      final snap = await ref.once();
      final data = snap.snapshot.value as Map?;

      final updates = <String, dynamic>{
        'email': (user.email ?? '').toLowerCase(),
        'name': user.displayName ?? 'User',
        'photoURL': user.photoURL ?? '',
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'emailVerified': user.emailVerified,
        'provider': 'google.com',
        'deviceHash': await DeviceIdHelper.getHash(),
      };

      if (data == null) {
        updates['createdAt'] = DateTime.now().millisecondsSinceEpoch;
        updates['subscribersCount'] = 0;
        updates['dashboard'] = {
          'totalLinks': 0,
          'totalViews': 0,
          'todayViews': 0,
          'todayConversions': 0,
          'totalIncome': 0,
          'todayIncome': 0,
          'viewsByDay': {},
          'linksByDay': {},
        };
        updates['withdrawal'] = {
          'upi': '',
          'bank_account': '',
          'ifsc': '',
          'gmail': '',
          'enabled': false,
        };
      }

      await ref.update(updates);
      debugPrint('✅ User synced to RTDB: ${user.uid}');
    } catch (e) {
      debugPrint('RTDB sync error: $e');
    }
  }

  static Future<String> loadApiKey() async {
    if (cachedUid == null) return '';
    try {
      final ref = _rtdb.child('users/$cachedUid/apiKey');
      final snap = await ref.once();
      var key = snap.snapshot.value as String?;

      if (key == null || key.length < 12) {
        key = _generateKey();
        await ref.set(key);
      }
      cachedApiKey = key;
      return key;
    } catch (e) {
      debugPrint('API key error: $e');
      return '';
    }
  }

  static String _generateKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = math.Random.secure();
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static Future<UserCredential?> signInWithGoogle() async {
    final allowed = await SecurityGuard.checkLoginRateLimit();
    if (!allowed) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Too many login attempts. Try again in 10 minutes.',
      );
    }
    await SecurityGuard.recordLoginAttempt();

    final googleSignIn = GoogleSignIn(serverClientId: webClientId);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    if (!SecurityGuard.isGmailOnly(googleUser.email)) {
      await googleSignIn.signOut();
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Only @gmail.com accounts are allowed.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);

    final user = result.user;
    if (user == null) throw FirebaseAuthException(code: 'unknown', message: 'No user returned.');

    final err = await SecurityGuard.validateUser(user);
    if (err != null) {
      await FirebaseAuth.instance.signOut();
      await googleSignIn.signOut();
      throw FirebaseAuthException(code: 'invalid-credential', message: err);
    }

    final bind = await SecurityGuard.validateAndBindDevice(user.uid, user.email ?? '');
    if (bind['ok'] != true) {
      await FirebaseAuth.instance.signOut();
      await googleSignIn.signOut();
      throw FirebaseAuthException(
        code: 'device-locked',
        message: bind['reason']?.toString() ?? 'Device locked to another account.',
      );
    }

    await SecurityGuard.clearLoginAttempts();
    return result;
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    cachedUid = null;
    cachedEmail = null;
    cachedName = null;
    cachedPhoto = null;
    cachedApiKey = null;
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    if (cachedUid == null) return {};
    try {
      final snap = await _rtdb.child('users/$cachedUid/dashboard').once();
      return Map<String, dynamic>.from((snap.snapshot.value ?? {}) as Map);
    } catch (e) {
      return {};
    }
  }

  static Stream<Map<String, dynamic>> getDashboardStream() {
    if (cachedUid == null) return const Stream.empty();
    return _rtdb.child('users/$cachedUid/dashboard').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null || val is! Map) return <String, dynamic>{};
      return Map<String, dynamic>.from(val);
    });
  }

  static Future<Map<String, dynamic>> getWithdrawalInfo() async {
    if (cachedUid == null) return {};
    try {
      final snap = await _rtdb.child('users/$cachedUid/withdrawal').once();
      final val = snap.snapshot.value;
      if (val == null || val is! Map) return {};
      return Map<String, dynamic>.from(val);
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveWithdrawalInfo(Map<String, dynamic> data) async {
    if (cachedUid == null) return;
    try {
      await _rtdb.child('users/$cachedUid/withdrawal').update(data);
    } catch (e) {
      debugPrint('Save withdrawal info error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getUserLinks({int limit = 20}) async {
    if (cachedUid == null) return [];
    try {
      final snap = await _rtdb.child('links').orderByChild('ownerUid').equalTo(cachedUid!).once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      final map = Map<String, dynamic>.from(val as Map);
      final arr = map.entries.map((e) {
        final d = Map<String, dynamic>.from(e.value as Map);
        d['id'] = e.key;
        return d;
      }).toList();
      arr.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
      return arr.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  static double calcEarnings(int views) {
    views = math.max(0, views);
    if (views <= 0) return 0;
    if (views <= 1000) return _r2(views * 0.0015);
    if (views <= 2000) return _r2(1.50 + (views - 1000) * 0.0025);
    return _r2(4.00 + (views - 2000) * 0.002);
  }

  static Map<String, dynamic> getTierInfo(int views) {
    views = math.max(0, views);
    if (views < 1000) {
      return {'tier': 1, 'rate': 1.50, 'next': 1000 - views};
    }
    if (views < 2000) {
      return {'tier': 2, 'rate': 2.50, 'next': 2000 - views};
    }
    return {
      'tier': 3 + (views ~/ 2000),
      'rate': 2.00,
      'next': 2000 - (views % 2000),
    };
  }

  static double _r2(num n) => (n * 100).round() / 100;
}

// ═══════════════════════════════════════════════════════
// FIREBASE SERVICE
// ═══════════════════════════════════════════════════════
class FirebaseService {
  static DatabaseReference get _rtdb => FirebaseDatabase.instance.ref();

  static Future<void> sendNotification({
    required String toUid,
    required String title,
    required String message,
    String type = 'general',
  }) async {
    try {
      final id = _rtdb.child('users/$toUid/notifications').push().key;
      if (id == null) return;
      await _rtdb.child('users/$toUid/notifications/$id').set({
        'title': title,
        'message': message,
        'type': type,
        'time': DateTime.now().millisecondsSinceEpoch,
        'read': false,
      });
    } catch (e) {
      debugPrint('sendNotification error: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> getNotifications(String uid) {
    return _rtdb.child('users/$uid/notifications').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null) return <Map<String, dynamic>>[];
      final map = Map<String, dynamic>.from(val as Map);
      final list = map.entries.map((e) {
        final d = Map<String, dynamic>.from(e.value as Map);
        d['id'] = e.key;
        return d;
      }).toList();
      list.sort((a, b) => (b['time'] ?? 0).compareTo(a['time'] ?? 0));
      return list;
    });
  }

  static Future<void> markNotificationRead(String uid, String notifId) async {
    try {
      await _rtdb.child('users/$uid/notifications/$notifId/read').set(true);
    } catch (_) {}
  }

  static Future<void> markAllRead(String uid) async {
    try {
      final snap = await _rtdb.child('users/$uid/notifications').once();
      final val = snap.snapshot.value as Map?;
      if (val == null) return;
      final updates = <String, dynamic>{};
      for (final id in val.keys) {
        updates['$id/read'] = true;
      }
      if (updates.isNotEmpty) {
        await _rtdb.child('users/$uid/notifications').update(updates);
      }
    } catch (_) {}
  }

  static Stream<int> getUnreadCount(String uid) {
    return _rtdb.child('users/$uid/notifications').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null) return 0;
      final map = Map<String, dynamic>.from(val as Map);
      int count = 0;
      for (final v in map.values) {
        if (v is Map && v['read'] != true) count++;
      }
      return count;
    });
  }

  static Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      final snap = await _rtdb.child('users/$uid').once();
      final val = snap.snapshot.value;
      if (val == null) return null;
      return Map<String, dynamic>.from(val as Map);
    } catch (e) {
      return null;
    }
  }

  static Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _rtdb.child('users/$uid').update(data);
    } catch (e) {
      debugPrint('updateProfile error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();

    try {
      final snap = await _rtdb.child('users').once();
      final val = snap.snapshot.value;
      if (val == null) return [];

      final users = Map<String, dynamic>.from(val as Map);
      final results = <Map<String, dynamic>>[];

      users.forEach((uid, data) {
        if (data is! Map) return;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        if (name.contains(q) || email.contains(q)) {
          final d = Map<String, dynamic>.from(data);
          d['uid'] = uid;
          results.add(d);
        }
      });

      return results.take(30).toList();
    } catch (e) {
      debugPrint('searchUsers error: $e');
      return [];
    }
  }

  static Future<bool> isSubscribed(String subscriberUid, String channelUid) async {
    try {
      final snap = await _rtdb.child('subscriptions/$channelUid/$subscriberUid').once();
      return snap.snapshot.value != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> toggleSubscription(String subscriberUid, String channelUid) async {
    try {
      final ref = _rtdb.child('subscriptions/$channelUid/$subscriberUid');
      final snap = await ref.once();
      final isSubbed = snap.snapshot.value != null;

      if (isSubbed) {
        await ref.remove();
        await _rtdb.child('userSubs/$subscriberUid/$channelUid').remove();

        await _rtdb.child('users/$channelUid').runTransaction((data) {
          if (data == null) return Transaction.success(null);
          final map = Map<String, dynamic>.from(data as Map);
          final subs = (map['subscribersCount'] ?? 0) as int;
          map['subscribersCount'] = math.max(0, subs - 1);
          return Transaction.success(map);
        });

        return false;
      } else {
        await ref.set(DateTime.now().millisecondsSinceEpoch);
        await _rtdb.child('userSubs/$subscriberUid/$channelUid').set(DateTime.now().millisecondsSinceEpoch);

        await _rtdb.child('users/$channelUid').runTransaction((data) {
          if (data == null) return Transaction.success(null);
          final map = Map<String, dynamic>.from(data as Map);
          final subs = (map['subscribersCount'] ?? 0) as int;
          map['subscribersCount'] = subs + 1;
          return Transaction.success(map);
        });

        await sendNotification(
          toUid: channelUid,
          title: '🔔 New Subscriber!',
          message: 'Someone subscribed to your channel.',
          type: 'subscribe',
        );

        return true;
      }
    } catch (e) {
      debugPrint('toggleSubscription error: $e');
      return false;
    }
  }

  static Stream<int> getSubscriberCount(String channelUid) {
    return _rtdb.child('users/$channelUid/subscribersCount').onValue.map((e) {
      return (e.snapshot.value ?? 0) as int;
    });
  }

  static Future<List<String>> getUserSubscriptions(String subscriberUid) async {
    try {
      final snap = await _rtdb.child('userSubs/$subscriberUid').once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      return (val as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUserVideos(String uid, {int limit = 30}) async {
    try {
      final snap = await _rtdb.child('links').orderByChild('ownerUid').equalTo(uid).once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      final map = Map<String, dynamic>.from(val as Map);
      final list = map.entries.map((e) {
        final d = Map<String, dynamic>.from(e.value as Map);
        d['id'] = e.key;
        return d;
      }).toList();
      list.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
      return list.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRelatedVideos({
    required String currentVideoId,
    String? currentOwnerUid,
    List<String> recentIds = const [],
    int limit = 10,
  }) async {
    try {
      final snap = await _rtdb.child('links').once();
      final val = snap.snapshot.value;
      if (val == null) return [];
      final map = Map<String, dynamic>.from(val as Map);
      final all = map.entries.map((e) {
        final d = Map<String, dynamic>.from(e.value as Map);
        d['id'] = e.key;
        return d;
      }).where((v) => v['id'] != currentVideoId).toList();

      final result = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      for (final id in recentIds) {
        if (result.length >= limit) break;
        try {
          final found = all.firstWhere((v) => v['id'] == id);
          if (!seenIds.contains(found['id'])) {
            result.add(found);
            seenIds.add(found['id'] as String);
          }
        } catch (_) {}
      }

      if (currentOwnerUid != null && currentOwnerUid.isNotEmpty) {
        for (final v in all) {
          if (result.length >= limit) break;
          if (v['ownerUid'] == currentOwnerUid && !seenIds.contains(v['id'])) {
            result.add(v);
            seenIds.add(v['id'] as String);
          }
        }
      }

      final sorted = List<Map<String, dynamic>>.from(all)
        ..sort((a, b) => ((b['views'] ?? 0) as int).compareTo((a['views'] ?? 0) as int));
      for (final v in sorted) {
        if (result.length >= limit) break;
        if (!seenIds.contains(v['id'])) {
          result.add(v);
          seenIds.add(v['id'] as String);
        }
      }

      return result.take(limit).toList();
    } catch (e) {
      debugPrint('getRelatedVideos error: $e');
      return [];
    }
  }

  static Stream<Map<String, int>> getVideoStatsStream(String videoId) {
    return _rtdb.child('links/$videoId').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null || val is! Map) {
        return {'views': 0, 'likes': 0, 'unlikes': 0, 'shares': 0};
      }

      int countMap(dynamic d) {
        if (d == null || d is! Map) return 0;
        return d.length;
      }

      return {
        'views': (val['views'] ?? 0) as int,
        'likes': countMap(val['likes']),
        'unlikes': countMap(val['unlikes']),
        'shares': countMap(val['shares']),
      };
    });
  }

  static Stream<bool> isLikedStream(String videoId, String uid) {
    return _rtdb.child('links/$videoId/likes/$uid').onValue.map((e) {
      return e.snapshot.value != null;
    });
  }

  static Stream<bool> isUnlikedStream(String videoId, String uid) {
    return _rtdb.child('links/$videoId/unlikes/$uid').onValue.map((e) {
      return e.snapshot.value != null;
    });
  }

  static Future<bool> toggleLike(String videoId, String uid, String ownerUid, String videoTitle) async {
    try {
      final likeRef = _rtdb.child('links/$videoId/likes/$uid');
      final unlikeRef = _rtdb.child('links/$videoId/unlikes/$uid');

      final likeSnap = await likeRef.once();
      final isLiked = likeSnap.snapshot.value != null;

      if (isLiked) {
        await likeRef.remove();
        return false;
      } else {
        await likeRef.set(DateTime.now().millisecondsSinceEpoch);
        await unlikeRef.remove();

        if (ownerUid.isNotEmpty && ownerUid != uid) {
          await sendNotification(
            toUid: ownerUid,
            title: '❤️ New Like!',
            message: 'Someone liked your video: $videoTitle',
            type: 'like',
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('toggleLike error: $e');
      return false;
    }
  }

  static Future<bool> toggleDislike(String videoId, String uid) async {
    try {
      final unlikeRef = _rtdb.child('links/$videoId/unlikes/$uid');
      final likeRef = _rtdb.child('links/$videoId/likes/$uid');

      final snap = await unlikeRef.once();
      final isUnliked = snap.snapshot.value != null;

      if (isUnliked) {
        await unlikeRef.remove();
        return false;
      } else {
        await unlikeRef.set(DateTime.now().millisecondsSinceEpoch);
        await likeRef.remove();
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<void> recordShare(String videoId) async {
    try {
      final id = _rtdb.child('links/$videoId/shares').push().key;
      if (id != null) {
        await _rtdb.child('links/$videoId/shares/$id').set(DateTime.now().millisecondsSinceEpoch);
      }
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════
// DEVICE ID HELPER
// ═══════════════════════════════════════════════════════
class DeviceIdHelper {
  static String? _cached;
  static String? _cachedHash;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    try {
      final prefs = await SharedPreferences.getInstance();
      String? stored = prefs.getString('mj_device_id');
      if (stored != null && stored.isNotEmpty) {
        _cached = stored;
        return stored;
      }
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        stored = 'and-${a.id}-${a.model}'.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        stored = 'ios-${i.identifierForVendor ?? 'unknown'}';
      } else {
        stored = 'dev-${DateTime.now().millisecondsSinceEpoch}';
      }
      await prefs.setString('mj_device_id', stored!);
      _cached = stored;
      return stored!;
    } catch (_) {
      _cached = 'dev-${DateTime.now().millisecondsSinceEpoch}';
      return _cached!;
    }
  }

  static Future<String> getHash() async {
    if (_cachedHash != null) return _cachedHash!;
    try {
      final raw = await get();
      final digest = crypto.sha256.convert(utf8.encode('mj_salt_2026_$raw'));
      _cachedHash = digest.toString().substring(0, 24);
      return _cachedHash!;
    } catch (_) {
      return 'unknown';
    }
  }
}

// ═══════════════════════════════════════════════════════
// WATCH HISTORY HELPER
// ═══════════════════════════════════════════════════════
class WatchHistory {
  static Future<List<String>> getRecentIds({int limit = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('watch_history_v2');
      if (raw == null) return [];
      final List decoded = jsonDecode(raw);
      return decoded
          .take(limit)
          .map((e) => (e['id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

// ═══════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDI5hgBbaUeTpXcPIlAnq5yDjIenfY-ylM",
        authDomain: "mayajaal-app.firebaseapp.com",
        databaseURL: "https://mayajaal-app-default-rtdb.asia-southeast1.firebasedatabase.app",
        projectId: "mayajaal-app",
        storageBucket: "mayajaal-app.firebasestorage.app",
        messagingSenderId: "96139047750",
        appId: "1:96139047750:android:7dbfb9487d023c20012b47",
      ),
    );
    debugPrint("✅ Firebase Initialized");
    await MayaJaalAccount.init();
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  try {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(oneSignalAppId);
    OneSignal.Notifications.requestPermission(true);
  } catch (e) {
    debugPrint("OneSignal Init Error: $e");
  }

  runApp(const MyApp());
}

// ═══════════════════════════════════════════════════════
// MATRIX RAIN
// ═══════════════════════════════════════════════════════
class MatrixRain extends StatefulWidget {
  final double opacity;
  const MatrixRain({super.key, this.opacity = 0.7});
  @override
  State<MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRain> {
  late Timer _timer;
  final List<double> _yPositions = [];
  final List<double> _speeds = [];
  final List<String> _letters = [];
  final math.Random _r = math.Random();
  static const _chars = 'アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789ABCDEFXYZ@#%&*';

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 32; i++) {
      _yPositions.add(-_r.nextInt(600).toDouble());
      _speeds.add(4 + _r.nextDouble() * 6);
      _letters.add(_chars[_r.nextInt(_chars.length)]);
    }
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _yPositions.length; i++) {
          _yPositions[i] += _speeds[i];
          if (_yPositions[i] > 950) {
            _yPositions[i] = -_r.nextInt(200).toDouble();
            _letters[i] = _chars[_r.nextInt(_chars.length)];
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(builder: (context, c) {
        final colWidth = c.maxWidth / _yPositions.length;
        return Stack(
          children: List.generate(_yPositions.length, (i) {
            return Positioned(
              left: i * colWidth,
              top: _yPositions[i],
              child: Text(
                _letters[i],
                style: TextStyle(
                  color: kGreen.withOpacity(widget.opacity),
                  fontSize: 13,
                  fontFamily: 'monospace',
                  shadows: const [Shadow(color: kGreen, blurRadius: 6)],
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PROFESSIONAL LOADING SCREEN
// ═══════════════════════════════════════════════════════
class ProfessionalLoader extends StatefulWidget {
  final String message;
  const ProfessionalLoader({super.key, this.message = 'LOADING...'});

  @override
  State<ProfessionalLoader> createState() => _ProfessionalLoaderState();
}

class _ProfessionalLoaderState extends State<ProfessionalLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _pulse;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulse = Tween<double>(begin: 0.85, end: 1.1)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    _rotate = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _c, curve: Curves.linear));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.35),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _rotate,
                      builder: (c, _) => Transform.rotate(
                        angle: _rotate.value * 2 * math.pi,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                kGreen.withOpacity(0.0),
                                kGreen,
                                kNeonCyan,
                                kGreen.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (c, _) => Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(color: kGreen, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: kGreen.withOpacity(0.6),
                                blurRadius: 25,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.change_history,
                                color: kGreen,
                                size: 50,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  widget.message,
                  style: const TextStyle(
                    color: kGreen,
                    fontSize: 14,
                    fontFamily: 'monospace',
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: kGreen, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(kGreen),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _a = Tween<double>(begin: 0.9, end: 1.1)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.65),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _a,
                  builder: (c, _) => Transform.scale(
                    scale: _a.value,
                    child: Container(
                      width: 125,
                      height: 125,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: kGreen.withOpacity(0.6),
                            blurRadius: 28,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/icon/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.black,
                            child: const Icon(
                              Icons.movie_filter,
                              size: 70,
                              color: kGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'MAYAJAAL LOADING...',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: kGreen,
                    fontFamily: 'monospace',
                    letterSpacing: 4,
                    shadows: [
                      Shadow(color: kGreen.withOpacity(0.85), blurRadius: 16)
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '> initializing quantum cipher...',
                  style: TextStyle(
                    fontSize: 11,
                    color: kGreen.withOpacity(0.7),
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MY APP
// ═══════════════════════════════════════════════════════
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static _MyAppState? instance;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  Uri? _initialLink;
  bool _linkReady = false;
  String? _pendingVideoTargetUrl;

  String? get pendingUrl => _pendingVideoTargetUrl;
  void clearPending() => _pendingVideoTargetUrl = null;

  @override
  void initState() {
    super.initState();
    instance = this;
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _initialLink = initial;
        final url = _buildUrlFromLink(initial);
        if (url.isNotEmpty) {
          _pendingVideoTargetUrl = url;
          debugPrint('📌 Initial deep link pending: $url');
        }
      }
    } catch (e) {
      debugPrint('Initial link error: $e');
    }
    if (mounted) setState(() => _linkReady = true);

    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Deep link received: $uri');
      if (!mounted) return;
      _handleDeepLink(uri);
    }, onError: (e) => debugPrint('Link stream error: $e'));
  }

  String _buildUrlFromLink(Uri uri) {
    String videoId = '';
    final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';

    if (uri.path.startsWith('/v/') || uri.path.startsWith('/s/')) {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    } else if (uri.queryParameters['v'] != null) {
      videoId = uri.queryParameters['v']!;
    }

    if (videoId.isEmpty) return '';

    return token.isNotEmpty
        ? 'https://www.mayajaal.online/v/$videoId?t=$token'
        : 'https://www.mayajaal.online/v/$videoId';
  }

  void _handleDeepLink(Uri uri) {
    final target = _buildUrlFromLink(uri);
    if (target.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _pendingVideoTargetUrl = target;
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: () {
            final pending = _pendingVideoTargetUrl;
            _pendingVideoTargetUrl = null;
            if (pending != null && pending.isNotEmpty) {
              navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(builder: (_) => StreamPreviewScreen(targetUrl: pending)),
              );
            }
          },
        ),
      ));
      return;
    }

    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => StreamPreviewScreen(targetUrl: target),
    ));
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    if (instance == this) instance = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_linkReady) {
      return const MaterialApp(
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'MayaJaal',
              debugShowCheckedModeBanner: false,
              themeMode: ThemeMode.dark,
              theme: _buildPureDarkTheme(),
              darkTheme: _buildPureDarkTheme(),
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }

  ThemeData _buildPureDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      dialogBackgroundColor: const Color(0xFF021206),
      colorScheme: const ColorScheme.dark(
        primary: kGreen,
        surface: Color(0xFF021206),
      ),
      useMaterial3: true,
      fontFamily: 'monospace',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: kGreen,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// AUTH GATE
// ═══════════════════════════════════════════════════════
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialCheckDone = false;
  String? _initialPendingUrl;
  bool _initialHandled = false;
  String? _blockingError;
  bool _gateChecked = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 500));

    _initialPendingUrl = _MyAppState.instance?.pendingUrl;
    debugPrint('🔍 AuthGate initial pending URL: $_initialPendingUrl');

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final err = await SecurityGuard.fullGate(user);
      if (err != null) {
        debugPrint('🚫 AuthGate gate failed: $err');
        await MayaJaalAccount.signOut();
        _blockingError = err;
      }
    }

    if (mounted) {
      setState(() {
        _initialCheckDone = true;
        _gateChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialCheckDone) {
      return const SplashScreen();
    }

    if (_blockingError != null) {
      return _SecurityBlockScreen(
        error: _blockingError!,
        onRetry: () async {
          setState(() {
            _blockingError = null;
            _initialCheckDone = false;
            _gateChecked = false;
          });
          await _initialize();
        },
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || !_gateChecked) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            MayaJaalAccount.cachedUid = user.uid;
            MayaJaalAccount.cachedEmail = user.email;
            MayaJaalAccount.cachedName = user.displayName;
            MayaJaalAccount.cachedPhoto = user.photoURL;
            await MayaJaalAccount.syncUserToRTDB(user);
            await MayaJaalAccount.loadApiKey();
          });

          if (!_initialHandled &&
              _initialPendingUrl != null &&
              _initialPendingUrl!.isNotEmpty) {
            _initialHandled = true;
            final url = _initialPendingUrl!;
            _initialPendingUrl = null;
            _MyAppState.instance?.clearPending();
            debugPrint('✅ AuthGate routing to 10sec page: $url');
            return StreamPreviewScreen(targetUrl: url);
          }

          return const MainNavigationHolder();
        }

        return const LoginScreen();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// SECURITY BLOCK SCREEN
// ═══════════════════════════════════════════════════════
class _SecurityBlockScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _SecurityBlockScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.25),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(color: kRed, width: 2.5),
                      boxShadow: [
                        BoxShadow(color: kRed.withOpacity(0.6), blurRadius: 30),
                      ],
                    ),
                    child: const Icon(Icons.gpp_bad, color: kRed, size: 48),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SECURITY BLOCK',
                    style: TextStyle(
                      color: kRed,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      shadows: [Shadow(color: kRed, blurRadius: 15)],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 220,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text(
                        'RETRY CHECK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: () async {
                      await MayaJaalAccount.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: kDimGreen, size: 18),
                    label: const Text(
                      'LOGOUT',
                      style: TextStyle(color: kDimGreen, letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// LOGIN SCREEN
// ═══════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const LoginScreen({super.key, this.onLoginSuccess});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String _error = '';

  late AnimationController _magicController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _magicController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 40.0).animate(
      CurvedAnimation(parent: _magicController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _magicController.dispose();
    super.dispose();
  }

  Future<void> _triggerMagic() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    await _magicController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _handleGoogle() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final result = await MayaJaalAccount.signInWithGoogle();
      if (result == null) {
        setState(() => _loading = false);
        return;
      }
      await _triggerMagic();
      if (!mounted) return;
      widget.onLoginSuccess?.call();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = '❌ ${e.message ?? _fbError(e.code)}');
    } catch (e) {
      setState(() => _error = '❌ $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fbError(String code) {
    switch (code) {
      case 'invalid-credential':
        return 'Only @gmail.com accounts are allowed';
      case 'too-many-requests':
        return 'Too many attempts, try again in 10 minutes';
      case 'network-request-failed':
        return 'Check your internet connection';
      case 'device-locked':
        return 'This device is locked to another account';
      default:
        return code.replaceAll('-', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.2),
          Positioned(
            bottom: 80,
            right: -40,
            child: Opacity(
              opacity: 0.6,
              child: Transform.rotate(
                angle: -0.05,
                child: Container(
                  width: 340,
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFF021206),
                    border: Border.all(color: kGreen.withOpacity(0.5), width: 2),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)
                    ]
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 22,
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: Colors.redAccent.withOpacity(0.8)),
                            const SizedBox(width: 6),
                            CircleAvatar(radius: 4, backgroundColor: Colors.amber.withOpacity(0.8)),
                            const SizedBox(width: 6),
                            CircleAvatar(radius: 4, backgroundColor: kGreen.withOpacity(0.8)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(Icons.play_circle_outline, color: kGreen.withOpacity(0.3), size: 80),
                            ),
                            Positioned(
                              bottom: 10,
                              left: 10,
                              right: 10,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(color: kGreen.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: 0.6,
                                  child: Container(
                                    decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(2)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kGreen, width: 2.5),
                          boxShadow: [
                            BoxShadow(color: kGreen.withOpacity(0.6), blurRadius: 20, spreadRadius: 2),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.change_history,
                              color: kGreen,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Maya',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'sans-serif',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Text(
                        'Jaal',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: kGreen,
                          fontFamily: 'sans-serif',
                          letterSpacing: 0.5,
                          shadows: [Shadow(color: kGreen, blurRadius: 15)],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Your Videos.\nYour Links.',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      fontFamily: 'sans-serif',
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'Your Earnings.',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: kGreen,
                      height: 1.1,
                      fontFamily: 'sans-serif',
                      letterSpacing: -0.5,
                      shadows: [Shadow(color: kGreen, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "World's Smartest Video Sharing\nPlatform",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.8),
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 10,
                        shadowColor: kGreen.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(31),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 3,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://developers.google.com/identity/images/g-logo.png',
                                  height: 28,
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.g_mobiledata,
                                    color: Colors.red,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Sign in with Google',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward, color: Colors.black, size: 24),
                                const SizedBox(width: 16),
                              ],
                            ),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        border: Border.all(color: Colors.redAccent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MAIN NAVIGATION HOLDER
// ═══════════════════════════════════════════════════════
class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});
  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  int _lastUnreadCount = 0;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
      const ChannelScreen(),
      const GalleryScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      drawer: const MoreDrawer(),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF000803),
          border: Border(
            top: BorderSide(color: kGreen.withOpacity(0.35), width: 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: kGreen.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: StreamBuilder<int>(
          stream: MayaJaalAccount.cachedUid != null
              ? FirebaseService.getUnreadCount(MayaJaalAccount.cachedUid!)
              : Stream.value(0),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? 0;

            if (unread > _lastUnreadCount && _lastUnreadCount != 0) {
              _shakeController.forward(from: 0);
              Haptic.heavy();
            }
            _lastUnreadCount = unread;

            return BottomNavigationBar(
              currentIndex: _currentIndex,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: kGreen,
              unselectedItemColor: Colors.white54,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 10,
              unselectedFontSize: 10,
              onTap: (index) {
                Haptic.selection();
                setState(() => _currentIndex = index);
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home, color: kGreen),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.ondemand_video_outlined),
                  activeIcon: Icon(Icons.ondemand_video, color: kGreen),
                  label: 'Channel',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.photo_library_outlined),
                  activeIcon: Icon(Icons.photo_library, color: kGreen),
                  label: 'Gallery',
                ),
                BottomNavigationBarItem(
                  icon: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (c, _) => Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            color: unread > 0 ? Colors.redAccent : Colors.white54,
                          ),
                          if (unread > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                constraints: const BoxConstraints(minWidth: 14),
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  activeIcon: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (c, _) => Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications,
                            color: unread > 0 ? Colors.redAccent : kGreen,
                          ),
                          if (unread > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                constraints: const BoxConstraints(minWidth: 14),
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  label: 'Alerts',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// AD BANNER WIDGET
// ═══════════════════════════════════════════════════════
class AdBanner extends StatelessWidget {
  final String slot;
  final VoidCallback? onTap;
  const AdBanner({super.key, required this.slot, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        Haptic.medium();
        await AdTracker.increment();
        if (onTap != null) onTap!();
        if (!context.mounted) return;
        final count = await AdTracker.getWatchedCount();
        final remaining = 7 - count;
        if (remaining <= 0) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: kCardBg,
                content: Text(
                  '🎉 Ad-free unlocked for 24 hours!',
                  style: TextStyle(color: kGreen),
                ),
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: kCardBg,
                content: Text(
                  '✅ Ad watched! $remaining more for 24h ad-free',
                  style: const TextStyle(color: kGreen, fontSize: 12),
                ),
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF031408),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kGreen.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: kGreen,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AD',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR AD HERE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Ad Slot: $slot · Tap to watch',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.campaign_outlined, color: kGreen, size: 26),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// FIRST TIME ADS POPUP
// ═══════════════════════════════════════════════════════
class FirstTimeAdsPopup {
  static Future<void> show(BuildContext context) async {
    final count = await AdTracker.getWatchedCount();
    final remaining = 7 - count;
    if (remaining <= 0) return;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF021206),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kGreen, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: kGreen.withOpacity(0.3),
                    blurRadius: 25,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(color: kGold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: kGold.withOpacity(0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.workspace_premium,
                        color: kGold,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AD-FREE STREAMING',
                    style: TextStyle(
                      color: kGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      shadows: [Shadow(color: kGreen, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Watch $remaining ads to unlock 24 hours of ad-free streaming!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(7, (i) {
                      final watched = i < count;
                      return Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: watched ? kGreen : Colors.black,
                          border: Border.all(
                            color: watched ? kGreen : kGreen.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: watched
                              ? [BoxShadow(color: kGreen.withOpacity(0.5), blurRadius: 8)]
                              : null,
                        ),
                        child: watched
                            ? const Icon(Icons.check, color: Colors.black, size: 12)
                            : null,
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$count / 7 ads watched',
                    style: TextStyle(
                      color: kGreen.withOpacity(0.8),
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Haptic.medium();
                        await AdTracker.increment();
                        if (c.mounted) Navigator.pop(c);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                      ),
                      child: const Text(
                        '▶ WATCH AD NOW',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: GestureDetector(
                onTap: () {
                  Haptic.light();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ⏭️ END OF PART 1 — PART 2 CONTINUES (HomeScreen, Player, etc.)
// ═══════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const HomeScreen({super.key, this.onMenuTap});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _linkController = TextEditingController();
  final FocusNode _linkFocus = FocusNode();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _linkController.dispose();
    _linkFocus.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    Haptic.medium();
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: kCardBg,
            content: Text(
              '❌ Clipboard khaali hai',
              style: TextStyle(color: Colors.orangeAccent),
            ),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      _linkController.text = text;
      _linkController.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kCardBg,
          content: Text(
            '✅ Link pasted',
            style: TextStyle(color: kGreen),
          ),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('Paste error: $e');
    }
  }

  void _showNotificationsSheet(BuildContext context) {
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111714),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: kGreen),
                      const SizedBox(width: 8),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: kGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => FirebaseService.markAllRead(uid),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(color: kGreen, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseService.getNotifications(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: kGreen),
                        );
                      }
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 60,
                                color: kGreen.withOpacity(0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Koi notification nahi hai',
                                style: TextStyle(
                                  color: kGreen.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final n = list[i];
                          final isRead = n['read'] == true;
                          final time = n['time'] as int? ?? 0;
                          final dt = DateTime.fromMillisecondsSinceEpoch(time);
                          final ago = _timeAgo(dt);

                          return GestureDetector(
                            onTap: () {
                              if (!isRead) {
                                FirebaseService.markNotificationRead(
                                  uid,
                                  n['id'] as String,
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Colors.black.withOpacity(0.3)
                                    : const Color(0xFF03220E),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isRead
                                      ? kGreen.withOpacity(0.2)
                                      : kGreen.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: kGreen.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Icon(
                                      _notifIcon(
                                        n['type']?.toString() ?? 'general',
                                      ),
                                      color: kGreen,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n['title'] ?? '',
                                          style: TextStyle(
                                            color: kGreen,
                                            fontSize: 13.5,
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          n['message'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ago,
                                          style: TextStyle(
                                            color: kGreen.withOpacity(0.5),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'subscribe':
        return Icons.person_add;
      case 'share':
        return Icons.share;
      case 'upload':
        return Icons.upload;
      case 'expiry':
        return Icons.timer;
      default:
        return Icons.notifications;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _searchAndPlay() {
    final input = _linkController.text.trim();
    if (input.isEmpty) {
      Haptic.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste a stream URL first!'),
          backgroundColor: kCardBg,
        ),
      );
      return;
    }
    Haptic.medium();
    _linkController.clear();
    _linkFocus.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StreamPreviewScreen(targetUrl: input),
      ),
    );
  }

  Widget _catCard(IconData icon, String title, String subtitle) {
    return GestureDetector(
      onTap: () => Haptic.light(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kGreen.withOpacity(0.4), width: 1.2),
          boxShadow: [
            BoxShadow(color: kGreen.withOpacity(0.08), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kGreen, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: kGreen, size: 26),
                      onPressed: () {
                        Haptic.light();
                        widget.onMenuTap?.call();
                      },
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kGreen, width: 2),
                        boxShadow: [
                          BoxShadow(color: kGreen.withOpacity(0.5), blurRadius: 15),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/icon/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.change_history,
                            color: kGreen,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Maya',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'sans-serif',
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'Jaal',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: kGreen,
                        fontFamily: 'sans-serif',
                        letterSpacing: 0.5,
                        shadows: [Shadow(color: kGreen, blurRadius: 12)],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, color: kGreen, size: 24),
                      onPressed: () {
                        Haptic.light();
                        showSearch(context: context, delegate: UserSearchDelegate());
                      },
                    ),
                    StreamBuilder<int>(
                      stream: MayaJaalAccount.cachedUid != null
                          ? FirebaseService.getUnreadCount(MayaJaalAccount.cachedUid!)
                          : Stream.value(0),
                      builder: (context, snapshot) {
                        final unread = snapshot.data ?? 0;
                        return Stack(children: [
                          IconButton(
                            icon: Icon(
                              Icons.notifications_none,
                              color: unread > 0 ? Colors.redAccent : kGreen,
                              size: 24,
                            ),
                            onPressed: () {
                              Haptic.light();
                              _showNotificationsSheet(context);
                            },
                          ),
                          if (unread > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(minWidth: 18),
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ]);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: AdBanner(slot: 'home-top'),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 18,
                      child: Text(
                        'MOVIES\nWEB SERIES\nLIVE TV\n& MORE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      child: Text(
                        'Your\nStreaming\nUniverse',
                        style: TextStyle(
                          color: const Color(0xFF66FF99).withOpacity(0.85),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          height: 1.2,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (c, _) => Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: kGreen.withOpacity(0.25),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: kGreen.withOpacity(0.6),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: 95,
                                height: 95,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: kGreen, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kGreen.withOpacity(0.5),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'assets/icon/logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(
                                      color: Colors.black,
                                      child: const Icon(
                                        Icons.movie_filter,
                                        size: 50,
                                        color: kGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF011206),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: kGreen.withOpacity(0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 25),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 14, top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF03220E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kGreen.withOpacity(0.7)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, color: kGreen, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'MATRIX NEURAL STREAM NODE',
                                style: TextStyle(
                                  color: kGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF031A0B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kGreen.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                color: kGreen,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _linkController,
                                      focusNode: _linkFocus,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: 'Paste Stream URL',
                                        hintStyle: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap paste or enter link',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _pasteFromClipboard,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: kGreen.withOpacity(0.6),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.content_paste_rounded,
                                    color: kGreen,
                                    size: 20,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _searchAndPlay,
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: kGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: kGreen.withOpacity(0.6),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _catCard(
                        Icons.movie_creation_outlined,
                        'Movies',
                        'Latest',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _catCard(
                        Icons.live_tv_rounded,
                        'Web Series',
                        'Binge',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _catCard(Icons.tv_rounded, 'Live TV', 'Sports'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _catCard(Icons.star_rounded, 'Favorites', 'Saved'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: AdBanner(slot: 'home-middle'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF031A0B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGreen.withOpacity(0.55)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: kGreen,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Secure Quantum Stream Pipeline Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: kGreen, size: 14),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: AdBanner(slot: 'home-bottom'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  '>   CONNECT   •   STREAM   •   ENJOY   <',
                  style: TextStyle(
                    color: Color(0xBF00FF66),
                    fontSize: 10.5,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MORE DRAWER (SECURED)
// ═══════════════════════════════════════════════════════
class MoreDrawer extends StatefulWidget {
  const MoreDrawer({super.key});

  @override
  State<MoreDrawer> createState() => _MoreDrawerState();
}

class _MoreDrawerState extends State<MoreDrawer>
    with TickerProviderStateMixin {
  late AnimationController _snakeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _snakeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _snakeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    Haptic.heavy();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mj_login_attempts');
    } catch (_) {}
    await MayaJaalAccount.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _launchURL(String url, {bool inApp = false}) async {
    Haptic.light();
    try {
      final target = Uri.parse(url);
      if (inApp) {
        await launchUrl(target, mode: LaunchMode.inAppBrowserView);
      } else {
        if (!await launchUrl(target, mode: LaunchMode.externalApplication)) {
          await launchUrl(target, mode: LaunchMode.platformDefault);
        }
      }
    } catch (e) {
      debugPrint('Launch error: $e');
      try {
        await launchUrl(Uri.parse(url));
      } catch (_) {}
    }
  }

  void _shareApp() {
    Haptic.light();
    Share.share(
      '🚀 Experience Matrix-speed streaming on MayaJaal App!\nDownload: https://www.mayajaal.online',
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kGreen, width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: kGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'ABOUT MAYAJAAL',
              style: TextStyle(
                color: kGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MAYA JAAL',
                style: TextStyle(
                  color: kGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '— STREAM BEYOND LIMITS —',
                style: TextStyle(color: kDimGreen, fontSize: 10, letterSpacing: 2),
              ),
              SizedBox(height: 14),
              Text(
                'Version: v1.2.0 (Build 2)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              SizedBox(height: 6),
              Text(
                'MayaJaal is a next-generation video streaming and monetization platform for creators. Convert, share, and earn effortlessly with Matrix-grade encryption and quantum-speed streaming.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              ),
              SizedBox(height: 12),
              Text(
                '👥 18+ Platform · User-Generated Content',
                style: TextStyle(color: kGreen, fontSize: 11, height: 1.4),
              ),
              SizedBox(height: 14),
              Divider(color: Colors.white24),
              SizedBox(height: 8),
              Text(
                '© 2026 MayaJaal. All rights reserved.',
                style: TextStyle(color: kDimGreen, fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CLOSE', style: TextStyle(color: kGreen)),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kGreen, width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.vpn_key, color: kGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'YOUR API KEY',
              style: TextStyle(
                color: kGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ye API key Telegram bot me use karein — /api YOUR_KEY',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kGreen.withOpacity(0.5)),
                ),
                child: SelectableText(
                  MayaJaalAccount.cachedApiKey ?? 'Loading...',
                  style: const TextStyle(
                    color: kGreen,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Email: ${MayaJaalAccount.cachedEmail ?? 'N/A'}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Colors.lightBlueAccent, size: 12),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Keep this API key secret. Never share it publicly.',
                        style: TextStyle(color: Colors.lightBlueAccent, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final key = MayaJaalAccount.cachedApiKey ?? '';
              if (key.isNotEmpty) {
                Haptic.medium();
                await Clipboard.setData(ClipboardData(text: key));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: kCardBg,
                      content: Text(
                        '✅ API Key copied',
                        style: TextStyle(color: kGreen),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('COPY', style: TextStyle(color: kGreen)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showBotsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF021206),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.smart_toy, color: kGreen, size: 24),
                SizedBox(width: 10),
                Text(
                  'MAYAJAAL BOTS',
                  style: TextStyle(
                    color: kGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a bot to start earning',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
            ),
            const SizedBox(height: 18),
            _botCard(
              context,
              icon: Icons.upload_rounded,
              color: kNeonCyan,
              title: 'Upload Bot',
              subtitle: 'Upload videos & get your own link',
              url: 'https://t.me/Mayajaalfilebot',
            ),
            const SizedBox(height: 12),
            _botCard(
              context,
              icon: Icons.link_rounded,
              color: kNeonPurple,
              title: 'Converter Bot',
              subtitle: 'Convert links & earn from sharing',
              url: 'https://t.me/MayaJaalBulkConverterbot',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showReferralDialog(BuildContext context) {
    final myUid = MayaJaalAccount.cachedUid ?? '';
    final refLink = 'https://www.mayajaal.online?ref=$myUid';
    
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kGold, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.card_giftcard, color: kGold, size: 24),
            SizedBox(width: 8),
            Text('REFER & EARN', style: TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invite your friends to MayaJaal and earn exciting rewards on every successful signup!',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGold.withOpacity(0.5)),
              ),
              child: SelectableText(
                refLink,
                style: const TextStyle(color: kGold, fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Haptic.medium();
              await Clipboard.setData(ClipboardData(text: refLink));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: kCardBg, content: Text('✅ Referral link copied!', style: TextStyle(color: kGold))),
                );
              }
            },
            child: const Text('COPY LINK', style: TextStyle(color: kGold)),
          ),
          TextButton(
            onPressed: () {
              Share.share('Join MayaJaal and start earning! Use my link: $refLink');
            },
            child: const Text('SHARE', style: TextStyle(color: kGreen)),
          ),
        ],
      ),
    );
  }

  Widget _botCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return InkWell(
      onTap: () {
        Haptic.medium();
        Navigator.pop(context);
        _launchURL(url);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 1.5),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 12),
                ],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _staggered({required int index, required Widget child}) {
    final start = (index * 0.06).clamp(0.0, 0.6);
    return AnimatedBuilder(
      animation: _slideController,
      builder: (c, _) {
        final raw = (_slideController.value - start) / (1 - start);
        final v = raw.clamp(0.0, 1.0);
        final curve = Curves.easeOutCubic.transform(v);
        return Opacity(
          opacity: curve,
          child: Transform.translate(
            offset: Offset(-20 * (1 - curve), 0),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF011206),
                border: Border(
                  bottom: BorderSide(
                    color: kGreen.withOpacity(0.4),
                    width: 1.2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGreen, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: kGreen.withOpacity(0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/icon/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.change_history,
                          color: kGreen,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: const [
                            Text(
                              'Maya',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              'Jaal',
                              style: TextStyle(
                                color: kGreen,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                shadows: [Shadow(color: kGreen, blurRadius: 10)],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'MORE OPTIONS',
                          style: TextStyle(
                            color: kGreen.withOpacity(0.7),
                            fontSize: 8.5,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kGreen, size: 22),
                    onPressed: () {
                      Haptic.light();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _staggered(index: 0, child: _LivePulseCard()),
                  _staggered(
                    index: 1,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGreen.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: kGreen, width: 1.5),
                            ),
                            child: user?.photoURL != null
                                ? ClipOval(
                                    child: Image.network(
                                      user!.photoURL!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(
                                        Icons.person,
                                        color: kGreen,
                                        size: 22,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.person, color: kGreen, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? user?.email ?? 'User',
                                  style: const TextStyle(
                                    color: kGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      color: kGreen.withOpacity(0.7),
                                      size: 10,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'MayaJaal Verified',
                                      style: TextStyle(
                                        color: kGreen.withOpacity(0.7),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _staggered(
                    index: 2,
                    child: _snakeItem(
                      context,
                      icon: Icons.account_balance_wallet,
                      color: kGold,
                      title: 'Earnings Dashboard',
                      subtitle: 'View your earnings and links',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EarningsScreen()),
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 3,
                    child: _snakeItem(
                      context,
                      icon: Icons.account_balance,
                      color: kGreen,
                      title: 'Withdraw Earnings',
                      subtitle: 'Minimum $5 · Bank / UPI',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WithdrawScreen()),
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 4,
                    child: _snakeItem(
                      context,
                      icon: Icons.card_giftcard,
                      color: kGold,
                      title: 'Refer & Earn',
                      subtitle: 'Invite friends and earn rewards',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        _showReferralDialog(context);
                      },
                    ),
                  ),
                  _staggered(
                    index: 5,
                    child: _snakeItem(
                      context,
                      icon: Icons.bookmark,
                      color: kNeonCyan,
                      title: 'Saved Videos',
                      subtitle: 'Your bookmarked videos',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SavedVideosScreen()),
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 6,
                    child: _snakeItem(
                      context,
                      icon: Icons.vpn_key,
                      color: kNeonPurple,
                      title: 'My API Key',
                      subtitle: 'View & copy for bot',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        _showApiKeyDialog(context);
                      },
                    ),
                  ),
                  _staggered(
                    index: 7,
                    child: _snakeItem(
                      context,
                      icon: Icons.smart_toy,
                      color: Colors.amberAccent,
                      title: 'MayaJaal Bots',
                      subtitle: 'Upload & Converter bots',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        _showBotsDialog(context);
                      },
                    ),
                  ),
                  _staggered(
                    index: 8,
                    child: _snakeItem(
                      context,
                      icon: Icons.share,
                      color: kNeonCyan,
                      title: 'Share MayaJaal App',
                      subtitle: 'Invite your friends',
                      onTap: () {
                        Navigator.pop(context);
                        _shareApp();
                      },
                    ),
                  ),
                  _staggered(
                    index: 9,
                    child: _snakeItem(
                      context,
                      icon: Icons.settings,
                      color: kGreen,
                      title: 'App Settings',
                      subtitle: 'Customize your experience',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ),
                  _staggered(
                    index: 10,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 18, bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 14, height: 1.5, color: kGreen),
                          const SizedBox(width: 6),
                          const Text(
                            'JOIN US',
                            style: TextStyle(
                              color: kGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(height: 1, color: kGreen.withOpacity(0.3)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _staggered(
                    index: 11,
                    child: _socialItem(
                      context,
                      imageUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Instagram_logo_2016.svg/240px-Instagram_logo_2016.svg.png',
                      fallbackIcon: Icons.camera_alt,
                      color: const Color(0xFFE1306C),
                      title: 'Instagram Official',
                      subtitle: '@maya_jaal_official',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL('https://www.instagram.com/maya_jaal_official');
                      },
                    ),
                  ),
                  _staggered(
                    index: 12,
                    child: _socialItem(
                      context,
                      imageUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/240px-YouTube_full-color_icon_%282017%29.svg.png',
                      fallbackIcon: Icons.play_circle_fill,
                      color: Colors.redAccent,
                      title: 'YouTube Channel',
                      subtitle: '@MayaJaalOfficial00',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL('https://www.youtube.com/@MayaJaalOfficial00');
                      },
                    ),
                  ),
                  _staggered(
                    index: 13,
                    child: _socialItem(
                      context,
                      imageUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/82/Telegram_logo.svg/240px-Telegram_logo.svg.png',
                      fallbackIcon: Icons.send_rounded,
                      color: const Color(0xFF229ED9),
                      title: 'Telegram Channel',
                      subtitle: '@MayaJaalOfficial',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL('https://t.me/MayaJaalOfficial');
                      },
                    ),
                  ),
                  _staggered(
                    index: 14,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 18, bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 14, height: 1.5, color: kNeonCyan),
                          const SizedBox(width: 6),
                          const Text(
                            'INFORMATION & LEGAL',
                            style: TextStyle(
                              color: kNeonCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(height: 1, color: kNeonCyan.withOpacity(0.3)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _staggered(
                    index: 15,
                    child: _snakeItem(
                      context,
                      icon: Icons.dashboard,
                      color: kNeonCyan,
                      title: 'Web Dashboard',
                      subtitle: 'Open www.mayajaal.online/dashboard',
                      onTap: () {
                        Navigator.pop(context);
                        _launchURL('https://www.mayajaal.online/dashboard', inApp: false);
                      },
                    ),
                  ),
                  _staggered(
                    index: 16,
                    child: _snakeItem(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      color: kDimGreen,
                      title: 'Privacy Policy',
                      subtitle: 'Data protection & identifiers',
                      onTap: () {
                        Navigator.pop(context);
                        LegalPolicyDialog.showPolicy(context, 'privacy');
                      },
                    ),
                  ),
                  _staggered(
                    index: 17,
                    child: _snakeItem(
                      context,
                      icon: Icons.description_outlined,
                      color: kDimGreen,
                      title: 'Terms & Conditions',
                      subtitle: 'Operating rules & user agreement',
                      onTap: () {
                        Navigator.pop(context);
                        LegalPolicyDialog.showPolicy(context, 'terms');
                      },
                    ),
                  ),
                  _staggered(
                    index: 18,
                    child: _snakeItem(
                      context,
                      icon: Icons.copyright_outlined,
                      color: const Color(0xFFFB7185),
                      title: 'DMCA Policy',
                      subtitle: '17 U.S.C. § 512 Notice',
                      onTap: () {
                        Navigator.pop(context);
                        LegalPolicyDialog.showPolicy(context, 'dmca');
                      },
                    ),
                  ),
                  _staggered(
                    index: 19,
                    child: _snakeItem(
                      context,
                      icon: Icons.handshake_outlined,
                      color: kNeonCyan,
                      title: 'Partner Agreement',
                      subtitle: 'Monetization & dynamic CPM',
                      onTap: () {
                        Navigator.pop(context);
                        LegalPolicyDialog.showPolicy(context, 'partner');
                      },
                    ),
                  ),
                  _staggered(
                    index: 20,
                    child: _snakeItem(
                      context,
                      icon: Icons.support_agent_outlined,
                      color: Colors.amberAccent,
                      title: 'Help & Support',
                      subtitle: '24/7 Creator Operations Desk',
                      onTap: () {
                        Navigator.pop(context);
                        LegalPolicyDialog.showPolicy(context, 'support');
                      },
                    ),
                  ),
                  _staggered(
                    index: 21,
                    child: _snakeItem(
                      context,
                      icon: Icons.info_outline,
                      color: kNeonCyan,
                      title: 'About MayaJaal',
                      subtitle: 'Version & info',
                      onTap: () {
                        Haptic.medium();
                        Navigator.pop(context);
                        _showAboutDialog(context);
                      },
                    ),
                  ),
                  _staggered(
                    index: 22,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.redAccent),
                          title: const Text(
                            'Logout Session',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _logout(context);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snakeItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: AnimatedBuilder(
        animation: _snakeController,
        builder: (c, _) {
          return Stack(
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10.5,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 14,
                ),
                onTap: onTap,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CustomPaint(
                      painter: SnakeBorderPainter(
                        progress: _snakeController.value,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _socialItem(
    BuildContext context, {
    required String imageUrl,
    required IconData fallbackIcon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.7), width: 1.2),
          ),
          padding: const EdgeInsets.all(5),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => Icon(fallbackIcon, color: color, size: 22),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10.5,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: color, size: 14),
        onTap: onTap,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// LIVE PULSE CARD
// ═══════════════════════════════════════════════════════
class _LivePulseCard extends StatefulWidget {
  @override
  State<_LivePulseCard> createState() => _LivePulseCardState();
}

class _LivePulseCardState extends State<_LivePulseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blink;
  double _currentEarning = 0;
  double _prevEarning = 0;
  bool _hasData = false;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MayaJaalAccount.cachedUid == null) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>>(
      stream: MayaJaalAccount.getDashboardStream(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final totalViews = (data['totalViews'] ?? 0) as int;
        final earning = MayaJaalAccount.calcEarnings(totalViews);
        if (earning != _currentEarning) {
          _prevEarning = _currentEarning;
          _currentEarning = earning;
          _hasData = true;
        }
        final up = _currentEarning >= _prevEarning;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kGreen.withOpacity(0.12), Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGreen.withOpacity(0.5), width: 1.2),
            boxShadow: [BoxShadow(color: kGreen.withOpacity(0.15), blurRadius: 12)],
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _blink,
                builder: (c, _) => Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kGreen,
                    boxShadow: [
                      BoxShadow(
                        color: kGreen.withOpacity(0.7 * _blink.value),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE PULSE',
                      style: TextStyle(
                        color: kGreen.withOpacity(0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasData ? '\$${_currentEarning.toStringAsFixed(2)}' : '—',
                      style: const TextStyle(
                        color: kGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: kGreen, blurRadius: 10)],
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasData)
                Icon(
                  up ? Icons.trending_up : Icons.trending_down,
                  color: up ? kGreen : Colors.orangeAccent,
                  size: 22,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// SNAKE BORDER PAINTER
// ═══════════════════════════════════════════════════════
class SnakeBorderPainter extends CustomPainter {
  final double progress;
  final Color color;

  SnakeBorderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;

    final snakeLength = totalLength * 0.25;
    final startPos = (progress * totalLength) % totalLength;
    final endPos = startPos + snakeLength;

    final extractPath = Path();
    if (endPos <= totalLength) {
      extractPath.addPath(
        metrics.extractPath(startPos, endPos),
        Offset.zero,
      );
    } else {
      extractPath.addPath(
        metrics.extractPath(startPos, totalLength),
        Offset.zero,
      );
      extractPath.addPath(
        metrics.extractPath(0, endPos - totalLength),
        Offset.zero,
      );
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(extractPath, paint);

    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(extractPath, corePaint);
  }

  @override
  bool shouldRepaint(covariant SnakeBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// ═══════════════════════════════════════════════════════
// CHANNEL SCREEN
// ═══════════════════════════════════════════════════════
class ChannelScreen extends StatelessWidget {
  const ChannelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('CHANNELS & NODES')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGreen.withOpacity(0.4)),
            ),
            child: const ListTile(
              leading: Icon(Icons.bolt, color: kGreen, size: 32),
              title: Text(
                'Quantum Streaming Node',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Direct hardware pipeline active',
                style: TextStyle(color: kDimGreen, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kNeonCyan.withOpacity(0.4)),
            ),
            child: const ListTile(
              leading: Icon(Icons.cloud_done, color: kNeonCyan, size: 32),
              title: Text(
                'High Speed CDN Node',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Buffer acceleration: ENABLED',
                style: TextStyle(color: kNeonCyan, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kNeonPurple.withOpacity(0.4)),
            ),
            child: const ListTile(
              leading: Icon(Icons.security, color: kNeonPurple, size: 32),
              title: Text(
                'Encrypted Pipeline',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'AES-256 quantum cipher: ACTIVE',
                style: TextStyle(color: kNeonPurple, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// GALLERY SCREEN
// ═══════════════════════════════════════════════════════
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<AssetEntity> _allAssets = [];
  List<AssetEntity> _videos = [];
  List<AssetEntity> _images = [];
  bool _loading = true;
  bool _permissionDenied = false;
  String _selectedTab = 'all';

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) {
        setState(() {
          _loading = false;
          _permissionDenied = true;
        });
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
      );

      if (albums.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final recent = albums.first;
      final assets = await recent.getAssetListPaged(page: 0, size: 200);

      final videos = <AssetEntity>[];
      final images = <AssetEntity>[];

      for (final a in assets) {
        if (a.type == AssetType.video) {
          videos.add(a);
        } else if (a.type == AssetType.image) {
          images.add(a);
        }
      }

      if (mounted) {
        setState(() {
          _allAssets = assets;
          _videos = videos;
          _images = images;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Gallery error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _permissionDenied = true;
        });
      }
    }
  }

  List<AssetEntity> get _currentAssets {
    switch (_selectedTab) {
      case 'videos':
        return _videos;
      case 'images':
        return _images;
      default:
        return _allAssets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('GALLERY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kGreen),
            onPressed: () {
              Haptic.light();
              setState(() => _loading = true);
              _loadGallery();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _permissionDenied
              ? _buildPermissionDenied()
              : Column(
                  children: [
                    _buildTabs(),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _currentAssets.isEmpty
                          ? _buildEmpty()
                          : _buildGrid(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined, color: kGreen, size: 80),
            const SizedBox(height: 16),
            const Text(
              'GALLERY PERMISSION NEEDED',
              style: TextStyle(color: kGreen, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please allow gallery access to view your photos and videos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => PhotoManager.openSetting(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OPEN SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, color: kGreen.withOpacity(0.4), size: 80),
          const SizedBox(height: 12),
          Text(
            'Koi ${_selectedTab == 'videos' ? 'video' : _selectedTab == 'images' ? 'photo' : 'media'} nahi mila',
            style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF011206),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGreen.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          _tabButton('all', 'ALL', Icons.apps),
          _tabButton('videos', 'VIDEOS', Icons.videocam),
          _tabButton('images', 'PHOTOS', Icons.image),
        ],
      ),
    );
  }

  Widget _tabButton(String key, String label, IconData icon) {
    final active = _selectedTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Haptic.selection();
          setState(() => _selectedTab = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF01240B) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: kGreen, width: 1.2) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? kGreen : Colors.white54, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active ? kGreen : Colors.white54,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: _currentAssets.length,
      itemBuilder: (context, index) => _buildTile(_currentAssets[index]),
    );
  }

  Widget _buildTile(AssetEntity asset) {
    final isVideo = asset.type == AssetType.video;
    return GestureDetector(
      onTap: () {
        Haptic.light();
        _openPreview(asset);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(300),
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                color: kCardBg,
                child: const Icon(Icons.broken_image, color: kGreen),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGreen.withOpacity(0.3), width: 1),
              ),
            ),
          ),
          if (isVideo)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kGreen.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: kGreen, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(asset.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (isVideo)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: kGreen.withOpacity(0.9), shape: BoxShape.circle),
                child: const Icon(Icons.videocam, color: Colors.black, size: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openPreview(AssetEntity asset) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: AssetEntityImage(
                  asset,
                  isOriginal: true,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: kGreen, size: 60),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Haptic.light();
                  Navigator.pop(c);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                    border: Border.all(color: kGreen, width: 1.5),
                  ),
                  child: const Icon(Icons.close, color: kGreen, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SAVED VIDEOS SCREEN (With Auto-Thumbnail)
// ═══════════════════════════════════════════════════════
class SavedVideosScreen extends StatefulWidget {
  const SavedVideosScreen({super.key});
  @override
  State<SavedVideosScreen> createState() => _SavedVideosScreenState();
}

class _SavedVideosScreenState extends State<SavedVideosScreen> {
  List<Map<String, dynamic>> _saved = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('saved_videos_v1');
    if (jsonStr != null) {
      try {
        final List decoded = jsonDecode(jsonStr);
        if (mounted) setState(() => _saved = decoded.cast<Map<String, dynamic>>());
      } catch (_) {}
    }
  }

  Future<void> _removeSaved(int index) async {
    Haptic.light();
    final prefs = await SharedPreferences.getInstance();
    setState(() => _saved.removeAt(index));
    await prefs.setString('saved_videos_v1', jsonEncode(_saved));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('SAVED VIDEOS')),
      body: _saved.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 60, color: kGreen.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text('No saved videos yet', style: TextStyle(color: kGreen.withOpacity(0.6))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _saved.length,
              itemBuilder: (c, i) {
                final item = _saved[i];
                final thumb = item['thumbnail']?.toString() ?? '';
                final title = item['title']?.toString() ?? 'Video';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGreen.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kGreen.withOpacity(0.5)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: buildMediaThumbnail(thumb, title, isSmall: true),
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontSize: 13, color: kGreen, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'By: ${item['uploader'] ?? 'Node'}',
                      style: TextStyle(fontSize: 11, color: kDimGreen.withOpacity(0.8)),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                      onPressed: () => _removeSaved(i),
                    ),
                    onTap: () {
                      Haptic.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StreamPreviewScreen(targetUrl: item['url']),
                        ),
                      ).then((_) => _loadSaved());
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// HISTORY SCREEN (With Auto-Thumbnail)
// ═══════════════════════════════════════════════════════
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString('watch_history_v2');
    if (localJson != null) {
      try {
        final List decoded = jsonDecode(localJson);
        if (mounted) setState(() => _history = decoded.cast<Map<String, dynamic>>());
      } catch (_) {}
    }
  }

  Future<void> _deleteItem(int index) async {
    Haptic.light();
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history.removeAt(index));
    await prefs.setString('watch_history_v2', jsonEncode(_history));
  }

  Future<void> _clearAll() async {
    Haptic.medium();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('watch_history_v2');
    setState(() => _history = []);
  }

  Future<void> _saveItem(Map<String, dynamic> item) async {
    Haptic.medium();
    final prefs = await SharedPreferences.getInstance();
    final savedStr = prefs.getString('saved_videos_v1');
    List<Map<String, dynamic>> savedList = [];
    if (savedStr != null) {
      try {
        savedList = (jsonDecode(savedStr) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    if (savedList.any((s) => s['url'] == item['url'])) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: kCardBg, content: Text('Already saved!', style: TextStyle(color: kGreen))),
        );
      }
      return;
    }

    savedList.insert(0, item);
    await prefs.setString('saved_videos_v1', jsonEncode(savedList));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: kCardBg, content: Text('✅ Video Saved!', style: TextStyle(color: kGreen))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('WATCH HISTORY'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.orangeAccent),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: kGreen.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text(tr('no_history'), style: TextStyle(color: kGreen.withOpacity(0.6))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (c, i) {
                final item = _history[i];
                final thumb = item['thumbnail']?.toString() ?? '';
                final title = item['title']?.toString() ?? 'Media Node';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGreen.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kGreen.withOpacity(0.5)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: buildMediaThumbnail(thumb, title, isSmall: true),
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontSize: 13, color: kGreen, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'By: ${item['uploader'] ?? 'Node'}',
                      style: TextStyle(fontSize: 11, color: kDimGreen.withOpacity(0.8)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bookmark_add_outlined, size: 20, color: kNeonCyan),
                          onPressed: () => _saveItem(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                          onPressed: () => _deleteItem(i),
                        ),
                      ],
                    ),
                    onTap: () {
                      Haptic.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StreamPreviewScreen(targetUrl: item['url']),
                        ),
                      ).then((_) => _loadHistory());
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SETTINGS SCREEN
// ═══════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkTheme = true;
  String _language = 'English';
  String _downloadLocation = 'Internal Storage / Mayajaall';

  final List<String> _languages = ['English', 'Hindi'];
  final List<String> _downloadLocations = [
    'Internal Storage / Mayajaall',
    'Internal Storage / Download',
    'Internal Storage / Movies'
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkTheme = prefs.getBool('dark_theme') ?? true;
      _language = prefs.getString('language') ?? 'English';
      _downloadLocation = prefs.getString('download_location') ?? 'Internal Storage / Mayajaall';
    });
  }

  Future<void> _saveDarkTheme(bool value) async {
    Haptic.selection();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    setState(() => _darkTheme = value);
  }

  Future<void> _saveLanguage(String value) async {
    Haptic.selection();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
    languageNotifier.value = value;
    setState(() => _language = value);
  }

  Future<void> _saveDownloadLocation(String value) async {
    Haptic.selection();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_location', value);
    setState(() => _downloadLocation = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined, color: kGreen),
            title: Text(tr('dark_theme'), style: const TextStyle(color: kGreen)),
            subtitle: Text(
              _darkTheme ? 'Matrix Cyber Neon' : 'Standard Light',
              style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12),
            ),
            trailing: Switch(
              value: _darkTheme,
              activeColor: kGreen,
              onChanged: _saveDarkTheme,
            ),
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.language, color: kGreen),
            title: Text(tr('language'), style: const TextStyle(color: kGreen)),
            subtitle: Text(_language, style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kGreen),
            onTap: _showLanguageDialog,
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          ListTile(
            leading: const Icon(Icons.download, color: kGreen),
            title: Text(tr('download_location'), style: const TextStyle(color: kGreen)),
            subtitle: Text(_downloadLocation, style: TextStyle(color: kGreen.withOpacity(0.6), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kGreen),
            onTap: _showDownloadLocationDialog,
          ),
          Divider(color: kGreen.withOpacity(0.2)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF031A0B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGreen.withOpacity(0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield, color: kGreen, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Security',
                        style: TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Gmail-only · Device-locked · Provider-verified',
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: Text('> MayaJaal v1.2.0 // Quantum Core',
              style: TextStyle(color: kGreen.withOpacity(0.5), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kGreen.withOpacity(0.5))),
        title: Text(tr('language'), style: const TextStyle(color: kGreen)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _languages.map((l) {
            return RadioListTile<String>(
              title: Text(l, style: const TextStyle(color: kGreen)),
              value: l,
              groupValue: _language,
              activeColor: kGreen,
              onChanged: (val) {
                if (val != null) {
                  _saveLanguage(val);
                  Navigator.pop(c);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDownloadLocationDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kGreen.withOpacity(0.5))),
        title: Text(tr('download_location'), style: const TextStyle(color: kGreen)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _downloadLocations.map((loc) {
            return RadioListTile<String>(
              title: Text(loc, style: const TextStyle(color: kGreen, fontSize: 12)),
              value: loc,
              groupValue: _downloadLocation,
              activeColor: kGreen,
              onChanged: (val) {
                if (val != null) {
                  _saveDownloadLocation(val);
                  Navigator.pop(c);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// STREAM PREVIEW SCREEN (Home Button at Top)
// ═══════════════════════════════════════════════════════
class StreamPreviewScreen extends StatefulWidget {
  final String targetUrl;
  const StreamPreviewScreen({super.key, required this.targetUrl});
  @override
  State<StreamPreviewScreen> createState() => _StreamPreviewScreenState();
}

class _StreamPreviewScreenState extends State<StreamPreviewScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String _streamUrl = '';
  String _videoTitle = 'MayaJaal Video';
  String _uploaderName = '@mayajaal';
  String _rawId = '';
  String _token = '';

  String _thumbnailUrl = '';

  int _countdown = 10;
  Timer? _countdownTimer;
  bool _isReadyToPlay = false;

  late AnimationController _snakeCtrl;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _snakeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    if (!MayaJaalAccount.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: kCardBg, content: Text('Please login to watch videos', style: TextStyle(color: kGreen))),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      });
      return;
    }

    _secureInit();
  }

  Future<void> _secureInit() async {
    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: kCardBg,
            content: Text(
              '🔒 Session expired. Please login again.',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
        );
        await MayaJaalAccount.signOut();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      }
      return;
    }
    _fetchStreamMetadata();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 10;
      _isReadyToPlay = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
          if (_countdown <= 3 && _countdown > 0) Haptic.light();
        } else {
          Haptic.heavy();
          _countdownTimer?.cancel();
          setState(() => _isReadyToPlay = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _snakeCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchStreamMetadata() async {
    try {
      final uri = Uri.parse(widget.targetUrl);
      _rawId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'stream';
      _token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';

      if (widget.targetUrl.endsWith('.mp4') || widget.targetUrl.endsWith('.m3u8')) {
        setState(() {
          _streamUrl = widget.targetUrl;
          _videoTitle = _rawId;
          _loading = false;
        });
        _startCountdown();
        return;
      }

      final apiUrl = _token.isNotEmpty
          ? '$kBackendBaseUrl/api/stream-info/$_rawId?t=$_token'
          : '$kBackendBaseUrl/api/stream-info/$_rawId';

      final deviceId = await DeviceIdHelper.get();
      final headers = SecurityGuard.signedHeaders(
        method: 'GET',
        path: '/api/stream-info/$_rawId',
        body: '',
        deviceId: deviceId,
        uid: MayaJaalAccount.cachedUid,
      );

      final res = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && (data['url'] != null || data['video_url'] != null)) {
          setState(() {
            _streamUrl = data['url'] ?? data['video_url'];
            _videoTitle = data['title'] ?? data['file_name'] ?? _rawId;
            _uploaderName = data['uploader'] ?? '@mayajaal';
            _thumbnailUrl = data['thumbnail'] ?? data['poster'] ?? '';
            _loading = false;
          });
          _startCountdown();
          return;
        }
      }

      setState(() {
        _streamUrl = widget.targetUrl;
        _loading = false;
      });
      _startCountdown();
    } catch (e) {
      setState(() {
        _streamUrl = widget.targetUrl;
        _loading = false;
      });
      _startCountdown();
    }
  }

  void _shareStreamDirect() {
    Haptic.light();
    Share.share('🚀 Watch this stream on MayaJaal:\n${widget.targetUrl}');
  }

  Future<void> _saveWatchRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString('watch_history_v2');
    List<Map<String, dynamic>> history = [];
    if (localJson != null) {
      try {
        final List decoded = jsonDecode(localJson);
        history = decoded.cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    final item = {
      'url': widget.targetUrl,
      'title': _videoTitle,
      'uploader': _uploaderName,
      'id': _rawId,
      'thumbnail': _thumbnailUrl,
      'time': DateTime.now().toIso8601String(),
    };

    history.removeWhere((h) => h['url'] == widget.targetUrl);
    history.insert(0, item);
    if (history.length > 50) history.removeLast();

    await prefs.setString('watch_history_v2', jsonEncode(history));
  }

  void _launchNativePlayer() {
    _saveWatchRecord();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NativeVideoPlayerScreen(
          videoUrl: _streamUrl,
          title: _videoTitle,
          uploader: _uploaderName,
          sourcePageUrl: widget.targetUrl,
          videoId: _rawId,
          thumbnailUrl: _thumbnailUrl,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _startCountdown();
      }
    });
  }

  void _goToHome() {
    Haptic.heavy();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationHolder()),
      (route) => false,
    );
  }

  Widget _buildCountdownCircle() {
    final progress = 1.0 - (_countdown / 10.0);
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, color: Colors.orangeAccent, size: 30),
              const SizedBox(height: 2),
              Text(
                '$_countdown',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  shadows: [Shadow(color: Colors.orangeAccent, blurRadius: 10)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedSnakePlayButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_snakeCtrl, _pulseAnimation]),
      builder: (c, _) => Transform.scale(
        scale: _pulseAnimation.value,
        child: GestureDetector(
          onTap: _launchNativePlayer,
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: kRed.withOpacity(0.5), blurRadius: 22, spreadRadius: 1)],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: SnakeBorderPainter(progress: _snakeCtrl.value, color: kRed)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.play_arrow_rounded, color: kRed, size: 32),
                    SizedBox(width: 8),
                    Text(
                      'PLAY NOW',
                      style: TextStyle(color: kRed, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2.5, shadows: [Shadow(color: kRed, blurRadius: 14)]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ProfessionalLoader(message: 'DECRYPTING STREAM...');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const MatrixRain(opacity: 0.35),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: kGreen, size: 22),
                        onPressed: () {
                          Haptic.light();
                          Navigator.pop(context);
                        },
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'STREAM READY',
                              style: TextStyle(color: kGreen, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(color: kGreen, blurRadius: 12)]),
                            ),
                            Text(
                              'MATRIX NEURAL STREAM',
                              style: TextStyle(color: kGreen.withOpacity(0.7), fontSize: 9, letterSpacing: 2.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen.withOpacity(0.6))),
                        child: const Icon(Icons.verified_user_rounded, color: kGreen, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF011206),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _isReadyToPlay ? kGreen : Colors.orangeAccent.withOpacity(0.6), width: 1.8),
                      boxShadow: [BoxShadow(color: (_isReadyToPlay ? kGreen : Colors.orangeAccent).withOpacity(0.25), blurRadius: 30)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            buildMediaThumbnail(_thumbnailUrl, _videoTitle),
                            Container(color: Colors.black.withOpacity(0.3)),
                            if (!_isReadyToPlay) _buildCountdownCircle(),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(5), border: Border.all(color: kGreen, width: 1)),
                                child: const Text('HD', style: TextStyle(color: kGreen, fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 🏠 HOME BUTTON AT TOP
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _goToHome,
                      icon: const Icon(Icons.home, color: Colors.white54, size: 20),
                      label: const Text('GO TO HOME PAGE', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white24, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🐍 RED SNAKE PLAY BUTTON (Below Home)
                  if (_isReadyToPlay)
                    _buildRedSnakePlayButton()
                  else
                    Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(32)),
                      child: Center(
                        child: Text(
                          'PLEASE WAIT $_countdown SEC...',
                          style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF031A0B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kGreen.withOpacity(0.35)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: kGreen.withOpacity(0.5))),
                              child: const Icon(Icons.video_collection_outlined, color: kGreen, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('FILE NAME', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9.5, letterSpacing: 1)),
                                  const SizedBox(height: 2),
                                  Text(_videoTitle, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: kGreen.withOpacity(0.15)),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: kGreen.withOpacity(0.5))),
                              child: const Icon(Icons.person_outline, color: kGreen, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('UPLOADER', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9.5, letterSpacing: 1)),
                                  const SizedBox(height: 2),
                                  Text(_uploaderName, style: const TextStyle(color: kGreen, fontSize: 13.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _shareStreamDirect,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: kGreen, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.share, color: kGreen, size: 20),
                          SizedBox(width: 10),
                          Text('SHARE VIDEO', style: TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// NATIVE VIDEO PLAYER (With Frame Capture for Auto Thumbnail)
// ═══════════════════════════════════════════════════════
class NativeVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String uploader;
  final String sourcePageUrl;
  final String videoId;
  final String thumbnailUrl; 

  const NativeVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.uploader,
    required this.sourcePageUrl,
    required this.videoId,
    this.thumbnailUrl = '', 
  });

  @override
  State<NativeVideoPlayerScreen> createState() => _NativeVideoPlayerScreenState();
}

class _NativeVideoPlayerScreenState extends State<NativeVideoPlayerScreen> {
  late VideoPlayerController _controller;
  final GlobalKey _videoKey = GlobalKey(); // 🔐 For Capturing Frame

  bool _isInitialized = false;
  bool _hasError = false;

  bool _isFullscreen = false;
  String _flashFeedback = '';
  Timer? _feedbackTimer;

  bool _showControls = true;
  Timer? _controlsTimer;

  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  bool _isLongPressBoost = false;

  String _selectedQuality = 'Auto (1080p)';
  final List<String> _qualities = ['Auto (1080p)', '1080p FHD', '720p HD', '480p SD', '360p Low'];

  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  double _volume = 1.0;
  double _brightness = 1.0;
  double _brightnessStart = 1.0;
  double _volumeStart = 1.0;
  double _dragStartY = 0;
  bool _isAdjustingVolume = false;
  bool _isAdjustingBrightness = false;

  Map<String, int> _stats = {'views': 0, 'likes': 0, 'unlikes': 0, 'shares': 0};
  bool _isLiked = false;
  bool _isUnliked = false;
  bool _isSaved = false;
  String _ownerUid = '';

  StreamSubscription? _statsSub;
  StreamSubscription? _likeSub;
  StreamSubscription? _unlikeSub;

  bool _viewReported = false;
  Timer? _watchTimer;
  int _watchedSeconds = 0;

  List<Map<String, dynamic>> _relatedVideos = [];
  bool _relatedLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPrefs();
    _initVideo();
    _startStatsListeners();
    _fetchOwner().then((_) => _loadRelatedVideos());
  }

  // 🖼️ CAPTURE FRAME FOR THUMBNAIL
  Future<void> _captureThumbnail() async {
    if (widget.thumbnailUrl.isNotEmpty) return; // Already has thumbnail
    try {
      await Future.delayed(const Duration(seconds: 2)); // Wait for first frame to render
      if (!mounted || !_isInitialized) return;
      
      RenderRepaintBoundary boundary = _videoKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 0.5); // Low res for storage
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final Uint8List bytes = byteData.buffer.asUint8List();
        final base64String = base64Encode(bytes);
        
        final prefs = await SharedPreferences.getInstance();
        
        // Update history with the actual thumbnail image
        final localJson = prefs.getString('watch_history_v2');
        if (localJson != null) {
          List<Map<String, dynamic>> history = (jsonDecode(localJson) as List).cast<Map<String, dynamic>>();
          for (var h in history) {
            if (h['id'] == widget.videoId && (h['thumbnail'] == null || h['thumbnail'] == '')) {
              h['thumbnail'] = base64String;
            }
          }
          await prefs.setString('watch_history_v2', jsonEncode(history));
        }

        // Update saved videos
        final savedStr = prefs.getString('saved_videos_v1');
        if (savedStr != null) {
          List<Map<String, dynamic>> savedList = (jsonDecode(savedStr) as List).cast<Map<String, dynamic>>();
          for (var s in savedList) {
            if (s['id'] == widget.videoId && (s['thumbnail'] == null || s['thumbnail'] == '')) {
              s['thumbnail'] = base64String;
            }
          }
          await prefs.setString('saved_videos_v1', jsonEncode(savedList));
        }
      }
    } catch (e) {
      debugPrint('Thumbnail capture error: $e');
    }
  }

  Future<void> _reportViewToBackend() async {
    if (_viewReported) return;
    _viewReported = true;

    try {
      final uri = Uri.parse(widget.sourcePageUrl);
      final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';
      final deviceId = await DeviceIdHelper.get();

      final url = token.isNotEmpty
          ? '$kBackendBaseUrl/api/view/${widget.videoId}?t=$token'
          : '$kBackendBaseUrl/api/view/${widget.videoId}';

      final body = jsonEncode({
        'playedSeconds': _watchedSeconds,
        'deviceId': deviceId,
        'token': token,
      });

      final headers = SecurityGuard.signedHeaders(
        method: 'POST',
        path: '/api/view/${widget.videoId}',
        body: body,
        deviceId: deviceId,
        uid: MayaJaalAccount.cachedUid,
      );

      await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('View report error: $e');
    }
  }

  void _startWatchTracking() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_controller.value.isInitialized && _controller.value.isPlaying) {
        _watchedSeconds++;
        if (_watchedSeconds == 10 && !_viewReported) {
          _reportViewToBackend();
        }
      }
    });
  }

  void _startStatsListeners() {
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;

    _statsSub = FirebaseService.getVideoStatsStream(widget.videoId).listen((s) {
      if (mounted) setState(() => _stats = s);
    });

    _likeSub = FirebaseService.isLikedStream(widget.videoId, uid).listen((liked) {
      if (mounted) setState(() => _isLiked = liked);
    });

    _unlikeSub = FirebaseService.isUnlikedStream(widget.videoId, uid).listen((unliked) {
      if (mounted) setState(() => _isUnliked = unliked);
    });
  }

  Future<void> _fetchOwner() async {
    try {
      final snap = await FirebaseDatabase.instance.ref('links/${widget.videoId}/ownerUid').once();
      _ownerUid = snap.snapshot.value?.toString() ?? '';
    } catch (_) {}
  }

  Future<void> _loadRelatedVideos() async {
    try {
      final recentIds = await WatchHistory.getRecentIds(limit: 5);
      final related = await FirebaseService.getRelatedVideos(
        currentVideoId: widget.videoId,
        currentOwnerUid: _ownerUid,
        recentIds: recentIds,
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _relatedVideos = related;
          _relatedLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _relatedLoading = false);
    }
  }

  Future<void> _loadUserPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isSaved = prefs.getBool('saved_${widget.videoId}') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _initVideo() async {
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Referer': 'https://www.mayajaal.online/',
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
      'Connection': 'keep-alive',
    };

    String realVideoUrl = widget.videoUrl;
    final isDirectUrl = widget.videoUrl.contains('.r2.dev') || widget.videoUrl.contains('cloudflarestorage') || widget.videoUrl.contains('.mp4');

    if (!isDirectUrl) {
      try {
        final uri = Uri.parse(widget.sourcePageUrl);
        final token = uri.queryParameters['t'] ?? uri.queryParameters['s'] ?? '';

        final deviceId = await DeviceIdHelper.get();
        final signed = SecurityGuard.signedHeaders(
          method: 'GET',
          path: '/api/stream-info/${widget.videoId}',
          body: '',
          deviceId: deviceId,
          uid: MayaJaalAccount.cachedUid,
        );

        final apiResp = await http.get(
          Uri.parse('$kBackendBaseUrl/api/stream-info/${widget.videoId}?t=$token'),
          headers: {
            ...signed,
            'User-Agent': 'MayaJaalApp/1.0',
          },
        ).timeout(const Duration(seconds: 8));

        if (apiResp.statusCode == 200) {
          final apiData = jsonDecode(apiResp.body);
          if (apiData['success'] == true && apiData['url'] != null) {
            realVideoUrl = apiData['url'];
          }
        }
      } catch (e) {
        debugPrint('⚠️ API fallback: $e');
      }
    }

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(realVideoUrl),
      httpHeaders: headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await _controller.initialize();
      _controller.play();
      _controller.setPlaybackSpeed(_playbackSpeed);
      _controller.setVolume(_volume);

      _controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() => _isInitialized = true);
      _resetControlTimer();
      _startWatchTracking();
      
      // Auto Capture Thumbnail
      _captureThumbnail();
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _likeSub?.cancel();
    _unlikeSub?.cancel();
    _controlsTimer?.cancel();
    _feedbackTimer?.cancel();
    _watchTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetControlTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onScreenTapped() {
    Haptic.light();
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlTimer();
  }

  void _showFeedback(String text) {
    _feedbackTimer?.cancel();
    setState(() => _flashFeedback = text);
    _feedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _flashFeedback = '');
    });
  }

  void _onLongPressStart() {
    Haptic.light();
    setState(() {
      _isLongPressBoost = true;
      _controller.setPlaybackSpeed(2.0);
    });
    _showFeedback('▶▶ 2x');
  }

  void _onLongPressEnd() {
    if (_isLongPressBoost) {
      _controller.setPlaybackSpeed(_playbackSpeed);
      setState(() => _isLongPressBoost = false);
      _resetControlTimer();
    }
  }

  void _onDoubleTap(TapDownDetails details, double width) {
    final dx = details.localPosition.dx;
    if (dx < width * 0.35) {
      final newPos = _controller.value.position - const Duration(seconds: 10);
      _controller.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
      Haptic.medium();
      _showFeedback('◀◀ 10s');
    } else if (dx > width * 0.65) {
      final newPos = _controller.value.position + const Duration(seconds: 10);
      final maxPos = _controller.value.duration;
      _controller.seekTo(newPos > maxPos ? maxPos : newPos);
      Haptic.medium();
      _showFeedback('10s ▶▶');
    } else {
      setState(() {
        _controller.value.isPlaying ? _controller.pause() : _controller.play();
      });
      Haptic.light();
      _resetControlTimer();
    }
  }

  void _seekRelative(int seconds) {
    Haptic.medium();
    final newPos = _controller.value.position + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > _controller.value.duration ? _controller.value.duration : newPos);
    _controller.seekTo(clamped);
    _showFeedback(seconds > 0 ? '+${seconds}s' : '${seconds}s');
    _resetControlTimer();
  }

  void _toggleSmartFullscreen() {
    Haptic.light();
    setState(() => _isFullscreen = !_isFullscreen);

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final isWide = _controller.value.aspectRatio >= 1.2;
      if (isWide) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours > 0 ? '${d.inHours}:' : '';
    return '$h$m:$s';
  }

  Future<void> _handleLike() async {
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;
    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      _showFeedback('🔒 Session expired');
      return;
    }
    await FirebaseService.toggleLike(widget.videoId, uid, _ownerUid, widget.title);
  }

  Future<void> _handleDislike() async {
    Haptic.medium();
    final uid = MayaJaalAccount.cachedUid;
    if (uid == null) return;
    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      _showFeedback('🔒 Session expired');
      return;
    }
    await FirebaseService.toggleDislike(widget.videoId, uid);
  }

  Future<void> _shareVideoLink() async {
    Haptic.light();
    await FirebaseService.recordShare(widget.videoId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF021206),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kGreen.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('SHARE VIDEO', style: TextStyle(color: kGreen, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 6),
            Text(widget.title, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _shareOption(Icons.link, 'Copy Link', kNeonCyan, () async {
                  Haptic.medium();
                  await Clipboard.setData(ClipboardData(text: widget.sourcePageUrl));
                  if (c.mounted) Navigator.pop(c);
                  _showFeedback('🔗 Link Copied!');
                }),
                _shareOption(Icons.share, 'Share Now', kGreen, () {
                  Haptic.medium();
                  Navigator.pop(c);
                  Share.share('🎬 Watch "${widget.title}" on MayaJaal:\n${widget.sourcePageUrl}');
                }),
                _shareOption(Icons.send_rounded, 'Telegram', const Color(0xFF229ED9), () {
                  Haptic.medium();
                  Navigator.pop(c);
                  Share.share('🎬 Watch "${widget.title}" on MayaJaal:\n${widget.sourcePageUrl}');
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, border: Border.all(color: color, width: 1.5), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12)]),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _startInAppDownload() async {
    if (_isDownloading) return;
    Haptic.medium();

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.videoUrl));
      request.headers.set('User-Agent', 'Mozilla/5.0');
      final response = await request.close();

      final totalBytes = response.contentLength;
      int receivedBytes = 0;

      Directory baseDir = Directory('/storage/emulated/0/Download');
      if (!baseDir.existsSync()) baseDir = Directory('/storage/emulated/0/Movies');
      if (!baseDir.existsSync()) baseDir = Directory.systemTemp;

      final safeName = widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final savePath = '${baseDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File(savePath);
      final sink = file.openWrite();

      await response.listen((List<int> chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() => _downloadProgress = receivedBytes / totalBytes);
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: kCardBg, content: Text('✅ Video saved to:\n$savePath', style: const TextStyle(color: kGreen, fontSize: 11))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download status: $e')));
      }
    }
  }

  Future<void> _toggleSave() async {
    Haptic.medium();
    final prefs = await SharedPreferences.getInstance();
    final savedStr = prefs.getString('saved_videos_v1');
    List<Map<String, dynamic>> savedList = [];
    if (savedStr != null) {
      try { savedList = (jsonDecode(savedStr) as List).cast<Map<String, dynamic>>(); } catch (_) {}
    }

    setState(() => _isSaved = !_isSaved);

    if (_isSaved) {
      savedList.add({
        'url': widget.sourcePageUrl,
        'title': widget.title,
        'uploader': widget.uploader,
        'id': widget.videoId,
        'thumbnail': widget.thumbnailUrl,
      });
      await prefs.setString('saved_videos_v1', jsonEncode(savedList));
      prefs.setBool('saved_${widget.videoId}', true);
    } else {
      savedList.removeWhere((s) => s['url'] == widget.sourcePageUrl);
      await prefs.setString('saved_videos_v1', jsonEncode(savedList));
      prefs.setBool('saved_${widget.videoId}', false);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isSaved ? 'Video Saved to Favorites' : 'Removed from Favorites'), duration: const Duration(seconds: 1)),
    );
  }

  void _showQualityDialog() {
    Haptic.light();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF031408),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kGreen, width: 1.5)),
        title: Row(
          children: const [Icon(Icons.hd, color: kGreen, size: 24), SizedBox(width: 8), Text('SELECT QUALITY', style: TextStyle(color: kGreen, fontSize: 15, fontWeight: FontWeight.bold))],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _qualities.map((q) {
            return RadioListTile<String>(
              value: q,
              groupValue: _selectedQuality,
              activeColor: kGreen,
              title: Text(q, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              onChanged: (val) {
                if (val != null) {
                  Haptic.selection();
                  setState(() => _selectedQuality = val);
                  Navigator.pop(c);
                  _showFeedback('Quality: $val');
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSpeedDialog() {
    Haptic.light();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF031408),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kGreen, width: 1.5)),
        title: const Text('PLAYBACK SPEED', style: TextStyle(color: kGreen, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _speeds.map((s) {
            return RadioListTile<double>(
              value: s,
              groupValue: _playbackSpeed,
              activeColor: kGreen,
              title: Text('${s}x', style: const TextStyle(color: Colors.white, fontSize: 13)),
              onChanged: (val) {
                if (val != null) {
                  Haptic.selection();
                  setState(() => _playbackSpeed = val);
                  _controller.setPlaybackSpeed(val);
                  Navigator.pop(c);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScaledVideo() {
    if (_isFullscreen) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: RepaintBoundary(
          key: _videoKey, // 🔐 Added for capture
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }

  void _onVerticalDragStart(DragStartDetails details, double width) {
    _dragStartY = details.localPosition.dy;
    final dx = details.localPosition.dx;
    if (dx > width / 2) {
      _isAdjustingVolume = true;
      _isAdjustingBrightness = false;
      _volumeStart = _volume;
    } else {
      _isAdjustingBrightness = true;
      _isAdjustingVolume = false;
      _brightnessStart = _brightness;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, double height) {
    final delta = (_dragStartY - details.localPosition.dy) / height;

    if (_isAdjustingVolume) {
      final newVol = (_volumeStart + delta).clamp(0.0, 1.0);
      setState(() => _volume = newVol);
      _controller.setVolume(newVol);
      _showFeedback('🔊 ${(newVol * 100).toInt()}%');
    } else if (_isAdjustingBrightness) {
      final newBright = (_brightnessStart + delta).clamp(0.1, 1.0);
      setState(() => _brightness = newBright);
      _showFeedback('☀️ ${(newBright * 100).toInt()}%');
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _isAdjustingVolume = false;
    _isAdjustingBrightness = false;
    _resetControlTimer();
  }

  Widget _buildWaterFillDownloadButton() {
    return GestureDetector(
      onTap: _isDownloading ? null : _startInAppDownload,
      child: Container(
        width: 108,
        height: 42,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: kGreen, width: 1.2)),
        child: Stack(
          children: [
            if (_isDownloading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 42 * _downloadProgress,
                  decoration: BoxDecoration(color: kGreen.withOpacity(0.35), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9))),
                ),
              ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isDownloading ? Icons.downloading : Icons.download_rounded, color: kGreen, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _isDownloading ? '${(_downloadProgress * 100).toInt()}%' : 'Download',
                    style: const TextStyle(color: kGreen, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return GestureDetector(
              onTap: _onScreenTapped,
              onDoubleTapDown: (d) => _onDoubleTap(d, w),
              onDoubleTap: () {},
              onLongPressStart: (_) => _onLongPressStart(),
              onLongPressEnd: (_) => _onLongPressEnd(),
              onVerticalDragStart: (d) => _onVerticalDragStart(d, w),
              onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, h),
              onVerticalDragEnd: _onVerticalDragEnd,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildScaledVideo(),
                  if (_brightness < 1.0)
                    Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity(1.0 - _brightness)))),
                  if (_showControls) ...[
                    Positioned(
                      top: 20,
                      left: 20,
                      child: GestureDetector(
                        onTap: _toggleSmartFullscreen,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                          child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _seekRelative(-10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: const Icon(Icons.replay_10, color: Colors.white, size: 30),
                          ),
                        ),
                        const SizedBox(width: 30),
                        GestureDetector(
                          onTap: () {
                            Haptic.light();
                            setState(() {
                              _controller.value.isPlaying ? _controller.pause() : _controller.play();
                            });
                            _resetControlTimer();
                          },
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                          ),
                        ),
                        const SizedBox(width: 30),
                        GestureDetector(
                          onTap: () => _seekRelative(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: const Icon(Icons.forward_10, color: Colors.white, size: 30),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Row(
                        children: [
                          Text(_formatDuration(_controller.value.position), style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(trackHeight: 3, activeTrackColor: kGreen, inactiveTrackColor: Colors.white30, thumbColor: kGreen, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                              child: Slider(
                                value: _controller.value.position.inSeconds.toDouble().clamp(0.0, _controller.value.duration.inSeconds.toDouble() <= 0 ? 1.0 : _controller.value.duration.inSeconds.toDouble()),
                                min: 0.0,
                                max: _controller.value.duration.inSeconds.toDouble() > 0 ? _controller.value.duration.inSeconds.toDouble() : 1.0,
                                onChanged: (val) => _controller.seekTo(Duration(seconds: val.toInt())),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatDuration(_controller.value.duration), style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                  if (_flashFeedback.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(10), border: Border.all(color: kGreen, width: 1)),
                        child: Text(_flashFeedback, style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: kGreen, size: 22),
                      onPressed: () {
                        Haptic.light();
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen, width: 1.5)),
                                child: const Center(child: Icon(Icons.change_history, color: kGreen, size: 14)),
                              ),
                              const SizedBox(width: 8),
                              const Text('MayaJaal', style: TextStyle(color: kGreen, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1, shadows: [Shadow(color: kGreen, blurRadius: 10)])),
                            ],
                          ),
                          Text('— STREAM BEYOND LIMITS —', style: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 8.5, letterSpacing: 2, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.share, color: kGreen, size: 22), onPressed: _shareVideoLink),
                  ],
                ),
              ),
              Expanded(
                flex: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Container(
                    width: double.infinity,
                    height: 230,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGreen.withOpacity(0.55), width: 1.5)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _hasError
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 45),
                                  const SizedBox(height: 10),
                                  const Text('Stream Connection Error', style: TextStyle(color: Colors.redAccent)),
                                  TextButton(onPressed: _initVideo, child: const Text('RETRY', style: TextStyle(color: kGreen))),
                                ],
                              ),
                            )
                          : !_isInitialized
                              ? const ProfessionalLoader(message: 'LOADING PLAYER...')
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final w = constraints.maxWidth;
                                    final h = constraints.maxHeight;
                                    return GestureDetector(
                                      onTap: _onScreenTapped,
                                      onDoubleTapDown: (d) => _onDoubleTap(d, w),
                                      onDoubleTap: () {},
                                      onLongPressStart: (_) => _onLongPressStart(),
                                      onLongPressEnd: (_) => _onLongPressEnd(),
                                      onVerticalDragStart: (d) => _onVerticalDragStart(d, w),
                                      onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, h),
                                      onVerticalDragEnd: _onVerticalDragEnd,
                                      behavior: HitTestBehavior.opaque,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          _buildScaledVideo(),
                                          if (_brightness < 1.0)
                                            Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity(1.0 - _brightness)))),
                                          Positioned(
                                            top: 10,
                                            left: 10,
                                            child: GestureDetector(
                                              onTap: _showQualityDialog,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(6), border: Border.all(color: kGreen, width: 1)),
                                                child: const Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('HD', style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    Text('1080p', style: TextStyle(color: kGreen, fontSize: 7, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: GestureDetector(
                                              onTap: _showSpeedDialog,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(6), border: Border.all(color: kNeonCyan, width: 1)),
                                                child: Text('${_playbackSpeed}x', style: const TextStyle(color: kNeonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ),
                                          if (_showControls && !_isLongPressBoost)
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                GestureDetector(
                                                  onTap: () => _seekRelative(-10),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                                    child: const Icon(Icons.replay_10, color: Colors.white, size: 26),
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                GestureDetector(
                                                  onTap: () {
                                                    Haptic.light();
                                                    setState(() {
                                                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                                                    });
                                                    _resetControlTimer();
                                                  },
                                                  child: Container(
                                                    width: 62,
                                                    height: 62,
                                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                                    child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                GestureDetector(
                                                  onTap: () => _seekRelative(10),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                                    child: const Icon(Icons.forward_10, color: Colors.white, size: 26),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (_flashFeedback.isNotEmpty)
                                            Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(10), border: Border.all(color: kGreen, width: 1)),
                                                child: Text(_flashFeedback, style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                                              ),
                                            ),
                                          if (_showControls)
                                            Positioned(
                                              bottom: 6,
                                              left: 10,
                                              right: 10,
                                              child: Row(
                                                children: [
                                                  Text(_formatDuration(_controller.value.position), style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: SliderTheme(
                                                      data: SliderTheme.of(context).copyWith(trackHeight: 2.5, activeTrackColor: kGreen, inactiveTrackColor: Colors.white30, thumbColor: kGreen, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4)),
                                                      child: Slider(
                                                        value: _controller.value.position.inSeconds.toDouble().clamp(0.0, _controller.value.duration.inSeconds.toDouble() <= 0 ? 1.0 : _controller.value.duration.inSeconds.toDouble()),
                                                        min: 0.0,
                                                        max: _controller.value.duration.inSeconds.toDouble() > 0 ? _controller.value.duration.inSeconds.toDouble() : 1.0,
                                                        onChanged: (val) => _controller.seekTo(Duration(seconds: val.toInt())),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(_formatDuration(_controller.value.duration), style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: _toggleSmartFullscreen,
                                                    child: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 20),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(16), border: Border.all(color: kGreen.withOpacity(0.55))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.play_circle_fill, color: kGreen, size: 26),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: kGreen)),
                                  child: const Text('HD', style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.account_circle, color: kGreen, size: 14),
                                const SizedBox(width: 4),
                                Text('Uploaded by: ${widget.uploader}', style: const TextStyle(color: kGreen, fontSize: 10)),
                                const SizedBox(width: 8),
                                Text('|   👁 ${_stats['views']} views', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _handleLike,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: _isLiked ? kGreen : kGreen.withOpacity(0.4))),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, color: kGreen, size: 14),
                                              const SizedBox(width: 4),
                                              Text('${_stats['likes']}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const Text('Like', style: TextStyle(color: Colors.white54, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: _handleDislike,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: _isUnliked ? Colors.redAccent : kGreen.withOpacity(0.4))),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_isUnliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined, color: Colors.redAccent, size: 14),
                                              const SizedBox(width: 4),
                                              Text('${_stats['unlikes']}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const Text('Dislike', style: TextStyle(color: Colors.white54, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: _toggleSave,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: _isSaved ? kGreen : kGreen.withOpacity(0.4))),
                                      child: Column(
                                        children: [
                                          Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? kGreen : Colors.white, size: 14),
                                          const Text('Save', style: TextStyle(color: Colors.white54, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildWaterFillDownloadButton(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AdBanner(slot: 'player-mid'),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Icon(Icons.play_circle_outline, color: kGreen, size: 18),
                          SizedBox(width: 6),
                          Text('Related Videos', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _relatedLoading
                          ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: kGreen, strokeWidth: 2)))
                          : _relatedVideos.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
                                  child: const Center(child: Text('No related videos yet', style: TextStyle(color: Colors.white54, fontSize: 12))),
                                )
                              : SizedBox(
                                  height: 155,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _relatedVideos.length,
                                    itemBuilder: (context, i) {
                                      final v = _relatedVideos[i];
                                      return _buildRelatedCard(v);
                                    },
                                  ),
                                ),
                      const SizedBox(height: 12),
                      AdBanner(slot: 'player-bottom'),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelatedCard(Map<String, dynamic> v) {
    final id = v['id']?.toString() ?? '';
    final title = (v['filename'] ?? v['originalUrl'] ?? 'Video').toString();
    final uploader = (v['uploader'] ?? '@mayajaal').toString();
    final views = (v['views'] ?? 0) as int;
    final thumb = v['thumbnail']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: () {
          Haptic.medium();
          final url = '$kBackendBaseUrl/v/$id';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StreamPreviewScreen(targetUrl: url),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 175,
          decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.35))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: buildMediaThumbnail(thumb, title, isSmall: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: Text(uploader, style: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.visibility, color: Colors.white54, size: 10),
                        const SizedBox(width: 2),
                        Text('$views', style: const TextStyle(color: Colors.white54, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// WITHDRAW SCREEN
// ═══════════════════════════════════════════════════════
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});
  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  bool _loading = true;
  double _balance = 0;
  bool _enabled = false;

  final _upiCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _gmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    _bankCtrl.dispose();
    _ifscCtrl.dispose();
    _gmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final ok = await SecurityGuard.validateSession();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: kCardBg,
              content: Text('🔒 Session expired. Please login again.', style: TextStyle(color: Colors.orangeAccent)),
            ),
          );
        }
        return;
      }

      final dash = await MayaJaalAccount.getDashboard();
      final views = (dash['totalViews'] ?? 0) as int;
      final balance = MayaJaalAccount.calcEarnings(views);
      final info = await MayaJaalAccount.getWithdrawalInfo();

      if (mounted) {
        setState(() {
          _balance = balance;
          _enabled = (info['enabled'] ?? false) == true;
          _upiCtrl.text = info['upi']?.toString() ?? '';
          _bankCtrl.text = info['bank_account']?.toString() ?? '';
          _ifscCtrl.text = info['ifsc']?.toString() ?? '';
          _gmailCtrl.text = info['gmail']?.toString() ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveInfo() async {
    Haptic.medium();
    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kCardBg,
          content: Text('🔒 Session expired', style: TextStyle(color: Colors.orangeAccent)),
        ),
      );
      return;
    }
    await MayaJaalAccount.saveWithdrawalInfo({
      'upi': _upiCtrl.text.trim(),
      'bank_account': _bankCtrl.text.trim(),
      'ifsc': _ifscCtrl.text.trim().toUpperCase(),
      'gmail': _gmailCtrl.text.trim(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: kCardBg, content: Text('✅ Withdrawal details saved', style: TextStyle(color: kGreen))),
    );
  }

  Future<void> _requestWithdraw() async {
    if (_balance < 5) {
      Haptic.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: kCardBg, content: Text('❌ Minimum \$5 balance required', style: TextStyle(color: Colors.orangeAccent))),
      );
      return;
    }

    if (!_enabled) {
      Haptic.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: kCardBg, content: Text('⚠️ Withdrawals coming soon — save your details first', style: TextStyle(color: Colors.orangeAccent))),
      );
      return;
    }

    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kCardBg,
          content: Text('🔒 Session expired. Please login again.', style: TextStyle(color: Colors.orangeAccent)),
        ),
      );
      return;
    }

    Haptic.medium();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: kCardBg, content: Text('✅ Withdrawal request submitted', style: TextStyle(color: kGreen))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('WITHDRAW EARNINGS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(16), border: Border.all(color: kGreen, width: 1.5), boxShadow: [BoxShadow(color: kGreen.withOpacity(0.15), blurRadius: 20)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AVAILABLE BALANCE', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        Text('\$${_balance.toStringAsFixed(2)}', style: const TextStyle(color: kGreen, fontSize: 38, fontWeight: FontWeight.w900, shadows: [Shadow(color: kGreen, blurRadius: 20)])),
                        const SizedBox(height: 4),
                        Text('≈ ₹${(_balance * 80).toStringAsFixed(0)} INR', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: _balance >= 5 ? kGreen.withOpacity(0.15) : Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: _balance >= 5 ? kGreen : Colors.orange, width: 1)),
                          child: Text(
                            _balance >= 5 ? '✅ Minimum reached — Ready to withdraw' : '⚠️ Minimum \$5 to withdraw',
                            style: TextStyle(color: _balance >= 5 ? kGreen : Colors.orange, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('PAYMENT DETAILS', style: TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  const Text('Save your details for faster withdrawals', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 12),
                  _field('UPI ID', _upiCtrl, 'yourname@upi'),
                  const SizedBox(height: 10),
                  _field('Bank Account Number', _bankCtrl, '1234567890'),
                  const SizedBox(height: 10),
                  _field('IFSC Code', _ifscCtrl, 'HDFC0001234'),
                  const SizedBox(height: 10),
                  _field('Gmail', _gmailCtrl, 'yourname@gmail.com'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _saveInfo,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: kGreen, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('💾 SAVE DETAILS', style: TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _requestWithdraw,
                      style: ElevatedButton.styleFrom(backgroundColor: _balance >= 5 ? kGreen : Colors.grey[850], foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: _balance >= 5 ? 10 : 0),
                      child: Text(
                        _balance >= 5 ? '💸 REQUEST WITHDRAWAL' : 'EARN \$5 TO WITHDRAW',
                        style: TextStyle(color: _balance >= 5 ? Colors.black : Colors.white54, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Icon(Icons.info_outline, color: kGreen, size: 16), SizedBox(width: 6), Text('INFO', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2))]),
                        SizedBox(height: 8),
                        Text('• Minimum withdrawal: \$5 (≈₹400)', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                        Text('• Processing time: 24–48 hours', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                        Text('• Methods: UPI · Bank Transfer', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                        Text('• TDS @ 2% applies above ₹15,000/year', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF031A0B), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.4))),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 11, letterSpacing: 1),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// USER SEARCH DELEGATE
// ═══════════════════════════════════════════════════════
class UserSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      inputDecorationTheme: const InputDecorationTheme(hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
      textTheme: const TextTheme(titleLarge: TextStyle(color: Colors.white, fontSize: 16)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear, color: kGreen), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, color: kGreen),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearch();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearch();

  Widget _buildSearch() {
    if (query.trim().isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, color: kGreen.withOpacity(0.4), size: 60),
              const SizedBox(height: 12),
              const Text('Search users by name or email', style: TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: FirebaseService.searchUsers(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGreen));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, color: kGreen.withOpacity(0.4), size: 60),
                  const SizedBox(height: 12),
                  Text('No user found for "$query"', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              final name = u['name'] ?? 'User';
              final email = u['email'] ?? '';
              final photo = u['photoURL']?.toString() ?? '';

              return ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen, width: 1.5)),
                  child: photo.isNotEmpty
                      ? ClipOval(child: Image.network(photo, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, color: kGreen)))
                      : const Icon(Icons.person, color: kGreen),
                ),
                title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(email, style: TextStyle(color: kGreen.withOpacity(0.7), fontSize: 11.5)),
                trailing: const Icon(Icons.arrow_forward_ios, color: kGreen, size: 14),
                onTap: () {
                  Haptic.light();
                  close(context, null);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(channelProfile: u)));
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// USER PROFILE SCREEN
// ═══════════════════════════════════════════════════════
class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> channelProfile;
  const UserProfileScreen({super.key, required this.channelProfile});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isSubscribed = false;
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;

  String get _channelUid => widget.channelProfile['uid']?.toString() ?? '';
  String get _channelName => widget.channelProfile['name']?.toString() ?? 'User';
  String get _channelEmail => widget.channelProfile['email']?.toString() ?? '';
  String get _channelPhoto => widget.channelProfile['photoURL']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final myUid = MayaJaalAccount.cachedUid;
      if (myUid != null && _channelUid.isNotEmpty) {
        _isSubscribed = await FirebaseService.isSubscribed(myUid, _channelUid);
      }
      _videos = await FirebaseService.getUserVideos(_channelUid, limit: 50);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSub() async {
    Haptic.medium();
    final myUid = MayaJaalAccount.cachedUid;
    if (myUid == null) return;
    final ok = await SecurityGuard.validateSession();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kCardBg,
          content: Text('🔒 Session expired', style: TextStyle(color: Colors.orangeAccent)),
        ),
      );
      return;
    }
    final newState = await FirebaseService.toggleSubscription(myUid, _channelUid);
    if (mounted) {
      setState(() => _isSubscribed = newState);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: kCardBg, content: Text(newState ? '✅ Subscribed!' : 'Unsubscribed', style: const TextStyle(color: kGreen)), duration: const Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = MayaJaalAccount.cachedUid == _channelUid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text('@${_channelName.split(' ').first}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen, width: 2), boxShadow: [BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 20)]),
                  child: _channelPhoto.isNotEmpty
                      ? ClipOval(child: Image.network(_channelPhoto, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, size: 45, color: kGreen)))
                      : const Icon(Icons.person, size: 45, color: kGreen),
                ),
                const SizedBox(height: 12),
                Text(_channelName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(_channelEmail, style: TextStyle(color: kGreen.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 6),
                StreamBuilder<int>(
                  stream: FirebaseService.getSubscriberCount(_channelUid),
                  builder: (c, s) {
                    final count = s.data ?? 0;
                    return Text('$count subscribers', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11));
                  },
                ),
                const SizedBox(height: 16),
                if (!isOwnProfile)
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: _toggleSub,
                      style: ElevatedButton.styleFrom(backgroundColor: _isSubscribed ? Colors.grey[850] : kGreen, foregroundColor: _isSubscribed ? Colors.white : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: Text(_isSubscribed ? '✓ SUBSCRIBED' : '+ SUBSCRIBE', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                const Divider(color: Colors.white24, height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.video_library, color: kGreen, size: 18),
                      const SizedBox(width: 6),
                      Text('VIDEOS (${_videos.length})', style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _videos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_outlined, color: kGreen.withOpacity(0.4), size: 60),
                              const SizedBox(height: 12),
                              const Text('No uploads yet', style: TextStyle(color: Colors.white54, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _videos.length,
                          itemBuilder: (context, i) {
                            final vid = _videos[i];
                            final id = vid['id']?.toString() ?? '';
                            final name = vid['filename'] ?? 'Video';
                            final views = vid['views'] ?? 0;
                            final thumb = vid['thumbnail']?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
                              child: ListTile(
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: kGreen.withOpacity(0.5))),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: buildMediaThumbnail(thumb, name, isSmall: true),
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Row(
                                  children: [
                                    const Icon(Icons.visibility, color: kGreen, size: 11),
                                    const SizedBox(width: 3),
                                    Text('$views views', style: TextStyle(color: kGreen.withOpacity(0.8), fontSize: 10.5)),
                                  ],
                                ),
                                onTap: () {
                                  Haptic.light();
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => StreamPreviewScreen(targetUrl: '$kBackendBaseUrl/v/$id')));
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// EARNINGS SCREEN
// ═══════════════════════════════════════════════════════
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _links = [];
  double _totalIncome = 0;
  int _currentTier = 1;
  double _currentRate = 1.0;
  int _nextBoost = 1000;
  int _rankIndex = 0;

  late AnimationController _rankAnimCtrl;
  late Animation<double> _rankScale;

  @override
  void initState() {
    super.initState();
    _rankAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _rankScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _rankAnimCtrl, curve: Curves.easeOut));
    _loadData();
  }

  @override
  void dispose() {
    _rankAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (!MayaJaalAccount.isLoggedIn) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final ok = await SecurityGuard.validateSession();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: kCardBg,
              content: Text('🔒 Session expired. Please login again.', style: TextStyle(color: Colors.orangeAccent)),
            ),
          );
        }
        if (mounted) setState(() => _loading = false);
        return;
      }

      final dash = await MayaJaalAccount.getDashboard();
      final links = await MayaJaalAccount.getUserLinks(limit: 50);

      final views = (dash['totalViews'] ?? 0) as int;
      final income = MayaJaalAccount.calcEarnings(views);
      final tierInfo = MayaJaalAccount.getTierInfo(views);
      final newRankIndex = CyberRank.getIndex(views);

      if (newRankIndex != _rankIndex && _rankIndex != 0) {
        _rankAnimCtrl.forward(from: 0);
      }

      if (mounted) {
        setState(() {
          _dashboard = dash;
          _links = links;
          _totalIncome = income;
          _currentTier = (tierInfo['tier'] ?? 1) as int;
          _currentRate = (tierInfo['rate'] ?? 1.0) as double;
          _nextBoost = (tierInfo['next'] ?? 0) as int;
          _rankIndex = newRankIndex;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Earnings load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('EARNINGS DASHBOARD', style: TextStyle(letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kGreen),
            onPressed: () {
              Haptic.light();
              setState(() => _loading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : !MayaJaalAccount.isLoggedIn
              ? _buildNotLoggedIn()
              : _buildDashboard(),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, color: Colors.orangeAccent, size: 60),
            const SizedBox(height: 16),
            const Text('NOT LOGGED IN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            const Text('Login karke earnings dekh sakte hain.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final totalViews = (_dashboard['totalViews'] ?? 0) as int;
    final todayViews = (_dashboard['todayViews'] ?? 0) as int;
    final totalLinks = (_dashboard['totalLinks'] ?? 0) as int;
    final rank = CyberRank.get(totalViews);
    final nextRank = CyberRank.next(totalViews);
    final rankColor = rank['color'] as Color;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: kGreen,
      backgroundColor: kCardBg,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.5))),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: kGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LOGGED IN AS', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text(MayaJaalAccount.cachedEmail ?? 'N/A', style: const TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _rankScale,
              builder: (c, child) => Transform.scale(scale: _rankScale.value, child: child),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [rankColor.withOpacity(0.15), Colors.black], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: rankColor.withOpacity(0.5), width: 1.5),
                  boxShadow: [BoxShadow(color: rankColor.withOpacity(0.25), blurRadius: 18)],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rankColor, width: 2), boxShadow: [BoxShadow(color: rankColor.withOpacity(0.5), blurRadius: 15)]),
                      child: Center(child: Text(rank['emoji'] as String, style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CYBER RANK', style: TextStyle(color: rankColor, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(rank['name'] as String, style: TextStyle(color: rankColor, fontSize: 18, fontWeight: FontWeight.w900, shadows: [Shadow(color: rankColor.withOpacity(0.6), blurRadius: 12)])),
                          if (nextRank != null)
                            Text('${(nextRank['min'] as int) - totalViews} views to ${nextRank['name']}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(16), border: Border.all(color: kGreen, width: 1.5), boxShadow: [BoxShadow(color: kGreen.withOpacity(0.15), blurRadius: 20)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL BALANCE', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text('\$${_totalIncome.toStringAsFixed(2)}', style: const TextStyle(color: kGreen, fontSize: 40, fontWeight: FontWeight.w900, shadows: [Shadow(color: kGreen, blurRadius: 20)])),
                  const SizedBox(height: 4),
                  Text('≈ ₹${(_totalIncome * 80).toStringAsFixed(0)} INR', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  const Divider(color: Colors.white24, height: 28),
                  Row(
                    children: [
                      Expanded(child: _statChip('👁 Total Views', '$totalViews')),
                      const SizedBox(width: 8),
                      Expanded(child: _statChip('📅 Today', '$todayViews')),
                      const SizedBox(width: 8),
                      Expanded(child: _statChip('🔗 Links', '$totalLinks')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orangeAccent.withOpacity(0.5))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('TIER $_currentTier', style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _tierStat('Current Rate', '\$${_currentRate.toStringAsFixed(2)}/1K')),
                      const SizedBox(width: 8),
                      Expanded(child: _tierStat('Next Boost', '$_nextBoost views')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Rates: 1K = \$1.50 · 2K = \$4.00 · 4K = \$8.00 · 6K = \$12.00 · 8K = \$16.00 · 10K = \$20.00\nAfter 10K: \$2.00 per 1K views', style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('YOUR LINKS', style: TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _links.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
                    child: const Center(child: Text('No links yet. Bot me video upload karke start karein.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12))),
                  )
                : Column(
                    children: _links.map((link) {
                      final views = (link['views'] ?? 0) as int;
                      final earnings = MayaJaalAccount.calcEarnings(views);
                      final name = (link['filename'] ?? link['originalUrl'] ?? 'link').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: kGreen.withOpacity(0.5))),
                              child: const Icon(Icons.play_circle_outline, color: kGreen, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.visibility, color: kGreen, size: 11),
                                      const SizedBox(width: 3),
                                      Text('$views', style: TextStyle(color: kGreen.withOpacity(0.9), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.attach_money, color: Colors.amberAccent, size: 11),
                                      const SizedBox(width: 2),
                                      Text('\$${earnings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.amberAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF031408), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen.withOpacity(0.3))),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.info_outline, color: kGreen, size: 16), SizedBox(width: 6), Text('WITHDRAWAL INFO', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2))]),
                  SizedBox(height: 8),
                  Text('Minimum: \$5 (≈₹400)', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                  Text('Methods: Bank Transfer · UPI · Any Bank', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                  Text('Processing: 24–48 hours', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: kGreen.withOpacity(0.2))),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9.5), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tierStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============ END OF FILE ============
