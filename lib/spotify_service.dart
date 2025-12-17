import 'package:spotify_sdk/spotify_sdk.dart';

class SpotifyService {
  static const String clientId = '294cd47ad20d4ca6b7b41f631208358b'; // From Spotify Dashboard
  static const String redirectUri = 'yourapp://callback'; // Must match dashboard
  static const List<String> scopes = [
    'user-read-playback-state',
    'user-modify-playback-state',
    'streaming',
  ];

  Future<bool> authenticate() async {
    try {
      // Request authentication token
      final String? accessToken = await SpotifySdk.getAccessToken(
        clientId: clientId,
        redirectUrl: redirectUri,
        scope: scopes.join(','),
      );

      if (accessToken != null) {
        // Connect to Spotify for playback control
        bool connected = await SpotifySdk.connectToSpotifyRemote(
          clientId: clientId,
          redirectUrl: redirectUri,
        );
        return connected;
      }
      return false;
    } catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }

  Future<void> playTrack(String trackUri) async {
    try {
      await SpotifySdk.play(spotifyUri: trackUri);
    } catch (e) {
      print('Error playing track: $e');
    }
  }

  Future<void> pauseTrack() async {
    try {
      await SpotifySdk.pause();
    } catch (e) {
      print('Error pausing track: $e');
    }
  }
}