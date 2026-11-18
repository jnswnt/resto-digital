/// Ekspor universal untuk manajemen gambar file lintas platform (Native & Web).
library;

export 'file_helper_web.dart'
    if (dart.library.io) 'file_helper_io.dart';
