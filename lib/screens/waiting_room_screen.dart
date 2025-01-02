import 'dart:async';
import 'dart:convert';

import 'package:chess/constant/constants.dart';
import 'package:chess/screens/main_menu_screen.dart';
import 'package:chess/services/web_socket_service.dart';
import 'package:chess/utils/custom_page_route.dart';
import 'package:chess/utils/network_helper.dart';
import 'package:chess/widgets/custom_alert_dialog.dart';
import 'package:chess/widgets/custom_image_spinner.dart';
import 'package:chess/widgets/custom_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:chess/model/invitation_model.dart';
import 'package:provider/provider.dart';
import 'package:chess/provider/game_provider.dart';

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({
    super.key,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late GameProvider _gameProvider;
  late WebSocketService _webSocketService;
  late InvitationMessage? invitation;
  late NetworkHelper _networkHelper;

  StreamSubscription? _onlineUsersSubscription;
  StreamSubscription? _networkSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize WebSocket connection
    _webSocketService = WebSocketService();
    _gameProvider = context.read<GameProvider>();
    _networkHelper = NetworkHelper();

    // Initialize animation controller
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _gameProvider.loadUser();

    invitation = _gameProvider.currentInvitation;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });

    _setupNetworkMonitoring();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize WebSocket
      bool connected = await _webSocketService.initializeConnection(context);
      if (!connected) {
        if (mounted) {
          showCustomSnackBarTop(context,
              "Connexion au serveur impossible. Certaines fonctionnalités peuvent être indisponibles.");
        }
      }

      // Setup subscriptions
      _setupSubscriptions();
    } catch (e) {
      print('Error during initialization: $e');
    }
  }

  void _setupSubscriptions() {
    // Cancel existing subscriptions if any
    _onlineUsersSubscription?.cancel();

    // Setup new subscriptions
    _onlineUsersSubscription =
        _gameProvider.onlineUsersStream.listen((users) {}, onError: (error) {
      print('Error in online users stream: $error');
    });
  }

  void _setupNetworkMonitoring() async {
    if (!await NetworkHelper().isConnected()) {
      if (mounted) {
        showCustomSnackBarTop(context,
            "Pas de connexion internet. Certaines fonctionnalités peuvent être indisponibles.");
        Navigator.pushReplacement(
          context,
          CustomPageRoute(child: const MainMenuScreen()),
        );
      }
      return;
    }

    _networkHelper.initNetworkMonitoring();
    _networkSubscription =
        _networkHelper.connectionStream.listen((isConnected) {
      if (!isConnected) {
        // Informer l'utilisateur de la perte de connexion et rediriger vers la page d'accueil
        if (mounted) {
          showCustomSnackBarTop(context,
              "Connexion internet perdue. Veuillez vérifier votre connexion.");
        }
        Navigator.pushReplacement(
          context,
          CustomPageRoute(child: const MainMenuScreen()),
        );
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (_gameProvider.onlineMode && _gameProvider.onWillPop) {
      Navigator.pushReplacement(
        context,
        CustomPageRoute(child: const MainMenuScreen()),
      );
      return true;
    }

    if (_gameProvider.invitationRejct) {
      _gameProvider.setInvitationRejct(value: false);

      Navigator.pushReplacement(
        context,
        CustomPageRoute(child: const MainMenuScreen()),
      );
      return true;
    }

    if (!_gameProvider.invitationRejct) {
      // Show confirmation dialog
      bool? shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => const CustomAlertDialog(
          titleMessage: "Annuler l'invitation ?",
          subtitleMessage:
              "Êtes-vous sûr de vouloir quitter la salle d'attente ?",
          typeDialog: 1,
        ),
      );

      if (shouldExit != null && shouldExit) {
        alertOtherPlayer();
      }
      return shouldExit ?? false;
    }

    return false;
  }

  void alertOtherPlayer() async {
    if (invitation != null && _gameProvider.friendsMode) {
      _webSocketService.sendInvitationCancel(invitation!);

      _gameProvider.setCurrentInvitation();
      _gameProvider.setFriendsMode(value: false);
    } else if (_gameProvider.onlineMode) {
      _webSocketService
          .sendMessage(json.encode({'type': 'public_queue_leave'}));
    }
    Navigator.pushReplacement(
      context,
      CustomPageRoute(child: const MainMenuScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: ColorsConstants.colorBg,
        appBar: AppBar(
          backgroundColor: ColorsConstants.colorBg,
          leading: IconButton(
            icon: Image.asset(
              'assets/icons8_arrow_back.png',
              width: 30,
            ),
            onPressed: () {
              _onWillPop();
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(top: 50, bottom: 100),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/chess_logo.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const CustomImageSpinner(
                size: 100.0,
                duration: Duration(milliseconds: 2000),
                type: false,
              ),
              const SizedBox(height: 20),
              Text(
                invitation != null
                    ? (invitation!.toUsername != _gameProvider.user.userName
                        ? 'En attente de ${invitation!.toUsername}'
                        : 'En attente de ${invitation!.fromUsername}')
                    : 'En attente d\'un adversaire...',
                style: const TextStyle(
                  fontSize: 25,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    _onlineUsersSubscription?.cancel();
    _controller.dispose();
    _networkHelper.dispose();
    super.dispose();
  }
}
