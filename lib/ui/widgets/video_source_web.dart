import 'package:video_player/video_player.dart';

// В браузере путь выбранного файла — это blob-ссылка.
VideoPlayerController controllerForPath(String path) =>
    VideoPlayerController.networkUrl(Uri.parse(path));
