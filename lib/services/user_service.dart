import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chess/model/friend_model.dart';
import 'package:chess/utils/api_link.dart';

class AuthException implements Exception {
  final String message;
  final int statusCode;

  AuthException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class UserService {
  /// Retrieves a user by their username
  /// Throws AuthException if authentication fails
  static Future<UserProfile?> getUserByUsername(String username) async {
    try {
      final response =
          await http.get(Uri.parse('${apiLink}get?username=$username'));

      if (response.statusCode == 200) {
        return UserProfile.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw AuthException('Failed to get user', response.statusCode);
      }
    } catch (e) {
      print('Error fetching user: $e');
      rethrow;
    }
  }

  /// Creates or authenticates a user
  /// Throws AuthException if authentication fails
  static Future<UserProfile> createUser(String username) async {
    try {
      final createResponse = await http.post(Uri.parse('${apiLink}create'),
          body: json.encode({'username': username}),
          headers: {'Content-Type': 'application/json'});

      if (createResponse.statusCode == 200) {
        return UserProfile.fromJson(json.decode(createResponse.body));
      }

      // Gérer spécifiquement l'erreur d'authentification
      if (createResponse.statusCode == 409) {
        throw AuthException('L\'utilisateur à déja  une session active',
            createResponse.statusCode);
      }

      throw AuthException(
          'Echec de la création/authentification de l\'utilisateur: ${createResponse.body}',
          createResponse.statusCode);
    } catch (e) {
      print('Error in createUser: $e');
      rethrow;
    }
  }

  static Future<bool> updateUserOnlineStatus(
      String username, bool isOnline) async {
    try {
      final response = await http.post(Uri.parse('${apiLink}users/online'),
          body: json.encode({'username': username, 'is_online': isOnline}),
          headers: {'Content-Type': 'application/json'});

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating online status: $e');
      return false;
    }
  }

  /// Déconnecte l'utilisateur et supprime son profil
  /// Retourne true si la déconnexion est réussie
  /// Throws AuthException en cas d'erreur
  static Future<bool> disconnectUser(String username) async {
    try {
      final response = await http.delete(
          Uri.parse('${apiLink}disconnect?username=$username'),
          headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        return true;
      }

      // Gérer les différents cas d'erreur
      switch (response.statusCode) {
        case 404:
          throw AuthException('Utilisateur non trouvé', response.statusCode);
        case 400:
          throw AuthException('Nom d\'utilisateur requis', response.statusCode);
        default:
          throw AuthException(
              'Échec de la déconnexion: ${response.body}', response.statusCode);
      }
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      print('Erreur lors de la déconnexion: $e');
      throw AuthException('Erreur de connexion au serveur', 500);
    }
  }
}
