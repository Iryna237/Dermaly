import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_colors.dart';
import 'models/subscription.dart';
import 'services/notchpay_service.dart';
import 'services/subscription_service.dart';

const String _priceLabel = '${Subscription.price} FCFA';

/// Vrai si le patient est abonné. Sinon, ouvre la page d'abonnement et
/// retourne vrai seulement s'il vient de payer.
Future<bool> ensureSubscribed(BuildContext context) async {
  if (await SubscriptionService.isActive()) return true;
  if (!context.mounted) return false;

  final paid = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (context) => const SubscriptionPage()),
  );
  return paid == true;
}

/// Étapes du paiement, du formulaire à son issue
enum _Step { form, sending, waiting, success }

/// Abonnement mensuel payé en Mobile Money via Notch Pay.
///
/// Le patient choisit son opérateur, saisit son numéro puis valide la demande
/// reçue sur son téléphone. L'app suit le paiement et active l'abonnement dès
/// qu'il est confirmé. Retourne `true` à la page appelante après un paiement.
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  // Flux créé une seule fois : le recréer à chaque build relance la lecture Firestore
  late final Stream<Subscription?> _subscription = SubscriptionService.watch();

  final TextEditingController _phoneController = TextEditingController();
  MobileMoneyChannel _channel = MobileMoneyChannel.mtn;
  _Step _step = _Step.form;
  String? _error;
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    // Un paiement validé après la fermeture de l'app est compté dès maintenant
    SubscriptionService.resumePending();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final phone = NotchPayService.normalizeCameroonPhone(_phoneController.text);
    if (phone == null) {
      setState(() => _error = 'Enter a valid Cameroonian mobile number, e.g. 6 70 00 00 00.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _step = _Step.sending;
      _error = null;
    });

    try {
      final reference = await SubscriptionService.startPayment(channel: _channel, phone: phone);
      if (!mounted) return;
      setState(() => _step = _Step.waiting);

      final payment = await SubscriptionService.waitForResult(reference);
      if (!mounted) return;

      if (payment != null && payment.isComplete) {
        setState(() {
          _step = _Step.success;
          _paid = true;
        });
        return;
      }

      setState(() {
        _step = _Step.form;
        _error = switch (payment?.status) {
          'failed' => 'The payment failed. Check your balance and try again.',
          'canceled' => 'The payment was canceled.',
          'expired' => 'The payment request expired. Please try again.',
          _ => 'No confirmation received yet. If you approve the request later, '
              'your subscription will activate the next time you open this page.',
        };
      });
    } catch (e) {
      debugPrint('Erreur paiement abonnement: $e');
      if (!mounted) return;
      setState(() {
        _step = _Step.form;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _step == _Step.sending || _step == _Step.waiting;

    return PopScope(
      // Le retour passe toujours par ici pour rendre [_paid] à la page appelante.
      // Quitter pendant la confirmation n'annulerait rien (le paiement est
      // retrouvé à la prochaine ouverture) : on évite seulement un retour accidentel.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (busy) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please wait for the payment to finish.')),
          );
        } else {
          Navigator.pop(context, _paid);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.darkPurple, size: 20),
            onPressed: busy ? null : () => Navigator.maybePop(context),
          ),
          title: const Text(
            'Dermatologist access',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
          ),
          centerTitle: true,
        ),
        body: StreamBuilder<Subscription?>(
          stream: _subscription,
          builder: (context, snapshot) {
            final subscription = snapshot.data;

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
              children: [
                _buildOffer(),
                const SizedBox(height: 20),
                _buildStatus(subscription),
                const SizedBox(height: 25),
                if (_step == _Step.success)
                  _buildSuccess(subscription)
                else if (_step == _Step.waiting)
                  _buildWaiting()
                else
                  _buildForm(Subscription.activeIn(subscription)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOffer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '$_priceLabel / month',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.white),
          ),
          const SizedBox(height: 14),
          for (final benefit in const [
            'Request consultations with verified dermatologists',
            'Chat with your dermatologist',
            'Dermaly AI Assistant stays free',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(benefit, style: const TextStyle(color: AppColors.white, fontSize: 14)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatus(Subscription? subscription) {
    final active = Subscription.activeIn(subscription);
    final date = subscription == null ? null : DateFormat('MMM d, y').format(subscription.expiresAt);

    return Row(
      children: [
        Icon(
          active ? Icons.verified_rounded : Icons.lock_outline_rounded,
          color: active ? AppColors.primaryPurple : AppColors.greyText,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            active
                ? 'Active until $date'
                : subscription == null
                    ? 'No active subscription'
                    : 'Expired on $date',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkPurple),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(bool active) {
    final sending = _step == _Step.sending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pay with Mobile Money',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final channel in MobileMoneyChannel.values) ...[
              Expanded(child: _buildChannel(channel, enabled: !sending)),
              if (channel != MobileMoneyChannel.values.last) const SizedBox(width: 12),
            ],
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          enabled: !sending,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: '${_channel.label} number',
            hintText: '6 70 00 00 00',
            prefixText: '+237 ',
            filled: true,
            fillColor: AppColors.softPurple,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13, height: 1.4)),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: sending ? null : _pay,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: sending
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                )
              : Text(
                  active ? 'Add one month · $_priceLabel' : 'Subscribe · $_priceLabel',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Widget _buildChannel(MobileMoneyChannel channel, {required bool enabled}) {
    final selected = _channel == channel;

    return InkWell(
      onTap: enabled ? () => setState(() => _channel = channel) : null,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.softPurple : AppColors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? AppColors.primaryPurple : AppColors.softGrey,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          channel.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.primaryPurple : AppColors.darkPurple,
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const CircularProgressIndicator(color: AppColors.primaryPurple),
        const SizedBox(height: 20),
        const Text(
          'Approve the payment on your phone',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
        const SizedBox(height: 8),
        Text(
          'A ${_channel.label} request of $_priceLabel was sent to your number. '
          'Enter your PIN to confirm it.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.greyText, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSuccess(Subscription? subscription) {
    return Column(
      children: [
        const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.primaryPurple),
        const SizedBox(height: 16),
        const Text(
          'Payment received',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
        const SizedBox(height: 8),
        Text(
          subscription == null
              ? 'Your subscription is active.'
              : 'You can chat with dermatologists until '
                  '${DateFormat('MMM d, y').format(subscription.expiresAt)}.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.greyText, height: 1.4),
        ),
        const SizedBox(height: 25),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: const Text('CONTINUE'),
        ),
      ],
    );
  }
}

/// Carte d'état de l'abonnement, en tête des consultations du patient
class SubscriptionBanner extends StatelessWidget {
  final Subscription? subscription;

  const SubscriptionBanner({super.key, required this.subscription});

  @override
  Widget build(BuildContext context) {
    final active = Subscription.activeIn(subscription);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: active ? AppColors.softPurple : AppColors.terracotta.withAlpha(15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: active ? AppColors.softGrey : AppColors.terracotta.withAlpha(90),
        ),
      ),
      child: ListTile(
        leading: Icon(
          active ? Icons.verified_rounded : Icons.lock_outline_rounded,
          color: active ? AppColors.primaryPurple : AppColors.terracotta,
        ),
        title: Text(
          active
              ? 'Subscribed until ${DateFormat('MMM d').format(subscription!.expiresAt)}'
              : 'Subscribe to chat with a dermatologist',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
        subtitle: Text(
          active ? 'Tap to extend your access' : '$_priceLabel per month · Mobile Money',
          style: const TextStyle(fontSize: 12, color: AppColors.greyText),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.softGrey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SubscriptionPage()),
        ),
      ),
    );
  }
}
