part of 'preload_bloc.dart';

@Freezed(makeCollectionsUnmodifiable: false)
class PreloadState with _$PreloadState {
  factory PreloadState({
    required List<List<String>> challenges,
    required Map<int, Map<int, VideoPlayerController>> controllers,
    required int focusedIndex,
    required int reloadCounter,
    required bool isLoading,
    required int currentChallengeIndex,
  }) = _PreloadState;

  factory PreloadState.initial() => PreloadState(
        focusedIndex: 0,
        reloadCounter: 0,
        isLoading: false,
        challenges: [],
        controllers: {},
        currentChallengeIndex: 0,
      );
}
