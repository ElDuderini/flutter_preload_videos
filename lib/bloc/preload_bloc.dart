import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:flutter_preload_videos/core/constants.dart';
import 'package:flutter_preload_videos/main.dart';
import 'package:flutter_preload_videos/service/api_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:video_player/video_player.dart';

part 'preload_bloc.freezed.dart';
part 'preload_event.dart';
part 'preload_state.dart';

@injectable
@prod
class PreloadBloc extends Bloc<PreloadEvent, PreloadState> {
  PreloadBloc() : super(PreloadState.initial());

  @override
  Stream<PreloadState> mapEventToState(
    PreloadEvent event,
  ) async* {
    yield* event.map(
      setLoading: (e) async* {
        yield state.copyWith(isLoading: true);
      },
      getChallengesFromApi: (e) async* {
        /// Fetch first 5 videos from api
        final List<List<String>> _challenges = await ApiService.getChallenges();
        state.challenges.addAll(_challenges);

        await _initializeChallengeAtIndex(0);

        await _initializeChallengeAtIndex(1);

        /// Initialize 1st video
        await _initializeControllerAtIndex(0, 0);

        /// Play 1st video
        _playControllerAtIndex(0, 0);

        /// Initialize 2nd video
        await _initializeControllerAtIndex(0, 1);

        /// Initialize 3rd video in new challenge
        await _initializeControllerAtIndex(1, 0);

        yield state.copyWith(reloadCounter: state.reloadCounter + 1);
      },
      onVideoIndexChanged: (e) async* {
        /// Condition to fetch new videos
        final bool shouldFetch = (e.index + kPreloadLimit) % kNextLimit == 0 &&
            state.challenges[state.currentChallengeIndex].length == e.index + kPreloadLimit;

        if (shouldFetch) {
          createIsolate(e.index);
        }

        /// Next / Prev video decider
        if (e.index > state.focusedIndex) {
          _playNextVideo(state.currentChallengeIndex, e.index);
        } else {
          _playPreviousVideo(state.currentChallengeIndex, e.index);
        }

        yield state.copyWith(focusedIndex: e.index);
      },
      onChallengeIndexChanged: (e) async* {
        /// Condition to fetch new videos
        final bool shouldFetch =
            (e.index + kPreloadLimit) % kNextLimit == 0 && state.challenges.length == e.index + kPreloadLimit;

        if (shouldFetch) {
          createIsolate(e.index);
        }

        /// Next / Prev video decider
        if (e.index > state.currentChallengeIndex) {
          _playNextChallenge(e.index, state.focusedIndex);
        } else {
          _playPreviousChallenge(e.index, state.focusedIndex);
        }

        yield state.copyWith(currentChallengeIndex: e.index, focusedIndex: 0);
      },
      updateChallenges: (e) async* {
        /// Add new urls to current challenge
        state.challenges.addAll(e.challenges);

        _initializeChallengeAtIndex(state.currentChallengeIndex + 1);
        _initializeControllerAtIndex(state.currentChallengeIndex + 1, 0);

        yield state.copyWith(reloadCounter: state.reloadCounter + 1, isLoading: false);
        log('🚀🚀🚀 NEW VIDEOS ADDED');
      },
    );
  }

  void _playNextChallenge(int challengeIndex, int index) {
    /// Stop [index - 1] controller
    _stopControllerAtIndex(challengeIndex - 1, index);

    /// Dispose [index - 2] controller
    _disposeControllerAtIndex(challengeIndex - 2, index);
    _disposeControllerAtIndex(challengeIndex - 2, index - 1);
    _disposeControllerAtIndex(challengeIndex - 2, index + 1);

    /// Play current video (already initialized)
    _playControllerAtIndex(challengeIndex, 0);

    _initializeChallengeAtIndex(challengeIndex + 1);

    /// Initialize [index + 1] controller
    _initializeControllerAtIndex(challengeIndex + 1, 0);

    _initializeControllerAtIndex(challengeIndex, 1);
  }

  void _playPreviousChallenge(int challengeIndex, int index) {
    /// Stop [index + 1] controller
    _stopControllerAtIndex(challengeIndex + 1, index);

    /// Dispose [index + 2] controller
    _disposeControllerAtIndex(challengeIndex + 2, index);
    _disposeControllerAtIndex(challengeIndex + 2, index - 1);
    _disposeControllerAtIndex(challengeIndex + 2, index + 1);

    /// Play current video (already initialized)
    _playControllerAtIndex(challengeIndex, 0);

    _initializeChallengeAtIndex(challengeIndex - 1);

    /// Initialize [index - 1] controller
    _initializeControllerAtIndex(challengeIndex - 1, 0);

    _initializeControllerAtIndex(challengeIndex, 1);
  }

  void _playNextVideo(int challengeIndex, int index) {
    /// Stop [index - 1] controller
    _stopControllerAtIndex(challengeIndex, index - 1);

    /// Dispose [index - 2] controller
    _disposeControllerAtIndex(challengeIndex, index - 2);

    /// Play current video (already initialized)
    _playControllerAtIndex(challengeIndex, index);

    /// Initialize [index + 1] controller
    _initializeControllerAtIndex(challengeIndex, index + 1);
  }

  void _playPreviousVideo(int challengeIndex, int index) {
    /// Stop [index + 1] controller
    _stopControllerAtIndex(challengeIndex, index + 1);

    /// Dispose [index + 2] controller
    _disposeControllerAtIndex(challengeIndex, index + 2);

    /// Play current video (already initialized)
    _playControllerAtIndex(challengeIndex, index);

    /// Initialize [index - 1] controller
    _initializeControllerAtIndex(challengeIndex, index - 1);
  }

  Future _initializeChallengeAtIndex(int challengeIndex) async {
    if (state.challenges.length > challengeIndex && challengeIndex >= 0) {
      final Map<int, VideoPlayerController> _controllerList = {};

      state.controllers[challengeIndex] = _controllerList;
    }

    log('🚀🚀🚀 INITIALIZED CHALLENGE: $challengeIndex');
  }

  Future _initializeControllerAtIndex(int challengeIndex, int videoIndex) async {
    if (state.challenges.length > challengeIndex && challengeIndex >= 0) {
      if (state.challenges[challengeIndex].length > videoIndex && videoIndex >= 0) {
        /// Create new controller
        final VideoPlayerController _controller =
            VideoPlayerController.network(state.challenges[challengeIndex][videoIndex]);

        /// Add to [controllers] list
        state.controllers[challengeIndex]![videoIndex] = _controller;

        /// Initialize
        await _controller.initialize();

        log('🚀🚀🚀 INITIALIZED CHALLENGE: $challengeIndex, VIDEO: $videoIndex');
      }
    }
  }

  void _playControllerAtIndex(int challengeIndex, int videoIndex) {
    if (state.challenges.length > challengeIndex && challengeIndex >= 0) {
      if (state.challenges[challengeIndex].length > videoIndex && videoIndex >= 0) {
        /// Get controller at [index]
        final VideoPlayerController _controller = state.controllers[challengeIndex]![videoIndex]!;

        /// Play controller
        _controller.play();

        log('🚀🚀🚀 PLAYING CHALLENGE: $challengeIndex, VIDEO: $videoIndex');
      }
    }
  }

  void _stopControllerAtIndex(int challengeIndex, int videoIndex) {
    if (state.challenges.length > challengeIndex && challengeIndex >= 0) {
      if (state.challenges[challengeIndex].length > videoIndex && videoIndex >= 0) {
        /// Get controller at [index]
        final VideoPlayerController _controller = state.controllers[challengeIndex]![videoIndex]!;

        /// Pause
        _controller.pause();

        /// Reset postiton to beginning
        _controller.seekTo(const Duration());

        log('🚀🚀🚀 STOPPED CHALLENGE: $challengeIndex, VIDEO: $videoIndex');
      }
    }
  }

  void _disposeControllerAtIndex(int challengeIndex, int videoIndex) {
    if (state.challenges.length > challengeIndex && challengeIndex >= 0) {
      if (state.challenges[challengeIndex].length > videoIndex && videoIndex >= 0) {
        /// Get controller at [index]
        final VideoPlayerController? _controller = state.controllers[challengeIndex]![videoIndex];

        /// Dispose controller
        _controller?.dispose();

        if (_controller != null) {
          state.controllers[challengeIndex]!.remove(_controller);
        }

        log('🚀🚀🚀 DISPOSED CHALLENGE: $challengeIndex, VIDEO: $videoIndex');
      }
    }
  }
}
