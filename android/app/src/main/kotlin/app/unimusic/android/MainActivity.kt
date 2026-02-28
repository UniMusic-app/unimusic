package app.unimusic.android

import io.flutter.embedding.engine.FlutterEngine
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.plugins.add(MediaStorePlugin())
    flutterEngine.plugins.add(AudioRoutingPlugin())
  }
}
