import 'package:flutter/material.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/models/track.dart';

class SpotifyPlayerWidget extends StatefulWidget {
  @override
  _SpotifyPlayerWidgetState createState() => _SpotifyPlayerWidgetState();
}

class _SpotifyPlayerWidgetState extends State<SpotifyPlayerWidget> {
  PlayerState? _playerState;
  Track? _track;

  @override
  void initState() {
    super.initState();
    _fetchPlayerState();
  }

  Future<void> _fetchPlayerState() async {
    try {
      var playerState = await SpotifySdk.getPlayerState();
      setState(() {
        _playerState = playerState;
        _track = playerState?.track;
      });
    } catch (e) {
      print('Error fetching player state: $e');
    }
  }

  Future<void> _playPause() async {
    if (_playerState?.isPaused ?? true) {
      await SpotifySdk.resume();
    } else {
      await SpotifySdk.pause();
    }
    _fetchPlayerState();
  }

  Future<void> _next() async {
    await SpotifySdk.skipNext();
    _fetchPlayerState();
  }

  Future<void> _previous() async {
    await SpotifySdk.skipPrevious();
    _fetchPlayerState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_track != null) ...[
          if (_track!.imageUri.raw != null)
            Image.network(
              'https://i.scdn.co/image/${_track!.imageUri.raw.replaceAll("spotify:image:", "")}',
              width: 100,
              height: 100,
            ),
          Text(_track!.name ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(_track!.artist.name ?? '', style: TextStyle(fontSize: 16)),
        ] else
          Text('No track playing'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: Icon(Icons.skip_previous), onPressed: _previous),
            IconButton(
              icon: Icon(_playerState?.isPaused ?? true ? Icons.play_arrow : Icons.pause),
              onPressed: _playPause,
            ),
            IconButton(icon: Icon(Icons.skip_next), onPressed: _next),
          ],
        ),
        ElevatedButton(
          onPressed: _fetchPlayerState,
          child: Text('Refresh'),
        ),
      ],
    );
  }
}