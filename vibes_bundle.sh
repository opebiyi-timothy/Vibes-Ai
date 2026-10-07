#!/bin/bash
set -e
# Recreates the AI Vibes Android project in ./android
mkdir -p android/.
cat > android/build.gradle.kts <<'END_OF_FILE'
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.20" apply false
}
END_OF_FILE
mkdir -p android/.
cat > android/gradle.properties <<'END_OF_FILE'
org.gradle.jvmargs=-Xmx2048m
android.useAndroidX=true
END_OF_FILE
mkdir -p android/.
cat > android/settings.gradle.kts <<'END_OF_FILE'
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositories { google(); mavenCentral() } }
rootProject.name = "VibesVideo"
include(":app")
END_OF_FILE
mkdir -p android/app
cat > android/app/build.gradle.kts <<'END_OF_FILE'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}
android {
    namespace = "com.example.vibesvideo"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.example.vibesvideo"
        minSdk = 26; targetSdk = 34; versionCode = 1; versionName = "1.0"
    }
    buildFeatures { compose = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
END_OF_FILE
mkdir -p android/app/src/main
cat > android/app/src/main/AndroidManifest.xml <<'END_OF_FILE'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:label="AI Vibes"
        android:usesCleartextTraffic="false"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
END_OF_FILE
mkdir -p android/app/src/main/java/com/example/vibesvideo
cat > android/app/src/main/java/com/example/vibesvideo/MainActivity.kt <<'END_OF_FILE'
package com.example.vibesvideo

import android.os.Bundle
import android.widget.MediaController
import android.widget.VideoView
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView

class MainActivity : ComponentActivity() {
    private val vm: VibesViewModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        vm.loadVideos()
        setContent { MaterialTheme { App(vm) } }
    }
}

@Composable
fun App(vm: VibesViewModel) {
    var tab by remember { mutableIntStateOf(0) }
    val tabs = listOf("Create", "My videos", "Settings")
    Scaffold(
        topBar = {
            TabRow(selectedTabIndex = tab) {
                tabs.forEachIndexed { i, t -> Tab(selected = tab == i, onClick = { tab = i }, text = { Text(t) }) }
            }
        }
    ) { pad ->
        Column(Modifier.padding(pad).padding(16.dp).fillMaxSize()) {
            if (vm.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
                when (tab) {
                    0 -> CreateTab(vm)
                    1 -> LibraryTab(vm) { tab = 0 }
                    else -> SettingsTab(vm)
                }
            }
            Text(vm.status, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun CreateTab(vm: VibesViewModel) {
    var prompt by remember { mutableStateOf("") }
    var steps by remember { mutableStateOf(30f) }
    var hd by remember { mutableStateOf(true) }
    Text("Make a video", style = MaterialTheme.typography.titleLarge)
    if (vm.serverUrl.isBlank()) Text("First add your server address in the Settings tab.", style = MaterialTheme.typography.bodySmall)
    OutlinedTextField(prompt, { prompt = it }, label = { Text("Describe your video") }, modifier = Modifier.fillMaxWidth().height(120.dp))
    Text("Steps: ${steps.toInt()} (more = nicer but slower)", style = MaterialTheme.typography.bodySmall)
    Slider(steps, { steps = it }, valueRange = 15f..50f)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Switch(hd, { hd = it })
        Text("HD: bigger (1440x960) and smoother (24 fps)", style = MaterialTheme.typography.bodySmall)
    }
    Button(
        onClick = { vm.createVideo(prompt, steps.toInt(), hd) },
        enabled = prompt.isNotBlank() && !vm.busy && vm.serverUrl.isNotBlank()
    ) { Text("Create video") }
    vm.currentVideo?.let { f ->
        key(f.path) {
            AndroidView(
                factory = { ctx ->
                    VideoView(ctx).apply {
                        setVideoPath(f.path)
                        setMediaController(MediaController(ctx).also { it.setAnchorView(this) })
                        setOnPreparedListener { it.isLooping = true; start() }
                    }
                },
                modifier = Modifier.fillMaxWidth().height(300.dp)
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { vm.saveVideo() }) { Text("Save") }
            OutlinedButton(onClick = { vm.shareVideo() }) { Text("Share") }
        }
    }
}

@Composable
fun LibraryTab(vm: VibesViewModel, onOpen: () -> Unit) {
    LaunchedEffect(Unit) { vm.loadVideos() }
    Text("My videos", style = MaterialTheme.typography.titleLarge)
    Text("Tap a finished video to watch it.", style = MaterialTheme.typography.bodySmall)
    vm.jobs.forEach { j ->
        val label = if (j.status == "done") "▶ " else "(${j.status}) "
        Text(
            label + j.prompt.take(70),
            Modifier.fillMaxWidth().clickable(enabled = j.status == "done") { vm.playVideo(j.id); onOpen() }.padding(8.dp)
        )
    }
}

@Composable
fun SettingsTab(vm: VibesViewModel) {
    Text("Video server", style = MaterialTheme.typography.titleLarge)
    Text("Paste the address printed by the Colab notebook.", style = MaterialTheme.typography.bodySmall)
    OutlinedTextField(vm.serverUrl, { vm.serverUrl = it }, label = { Text("https://….trycloudflare.com") }, modifier = Modifier.fillMaxWidth())
    Button(onClick = { vm.saveUrl() }) { Text("Save") }
}
END_OF_FILE
mkdir -p android/app/src/main/java/com/example/vibesvideo
cat > android/app/src/main/java/com/example/vibesvideo/VibesViewModel.kt <<'END_OF_FILE'
package com.example.vibesvideo

import android.app.Application
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File

class VibesViewModel(app: Application) : AndroidViewModel(app) {
    private val prefs = app.getSharedPreferences("vibes", 0)
    var serverUrl by mutableStateOf(prefs.getString("url", "") ?: "")
    var jobs by mutableStateOf<List<VideoJob>>(emptyList())
    var status by mutableStateOf("")
    var busy by mutableStateOf(false)
    var currentVideo by mutableStateOf<File?>(null)

    private fun api() = VideoApi(serverUrl)

    fun saveUrl() {
        serverUrl = serverUrl.trim()
        prefs.edit().putString("url", serverUrl).apply()
        status = "Saved"
        loadVideos()
    }

    private fun run(block: suspend () -> Unit) = viewModelScope.launch {
        busy = true
        try { block() } catch (e: Exception) { status = "Error: ${e.message}" }
        busy = false
    }

    fun loadVideos() {
        if (serverUrl.isNotBlank()) viewModelScope.launch { runCatching { jobs = api().list() } }
    }

    private suspend fun openVideo(id: String) {
        val f = File(getApplication<Application>().cacheDir, "video_$id.mp4")
        if (!f.exists() || f.length() == 0L) { status = "Downloading…"; api().download(id, f) }
        currentVideo = f
        status = "Ready"
    }

    fun playVideo(id: String) = run { openVideo(id) }

    fun createVideo(prompt: String, steps: Int, hd: Boolean) = run {
        status = "Sending…"
        val id = api().create(prompt, steps, hd)
        var failures = 0
        while (true) {
            val o = runCatching { api().get(id) }.getOrNull()
            if (o == null) {
                if (++failures > 20) error("Lost contact with the video server")
                status = "Reconnecting…"
            } else {
                failures = 0
                val st = o.optString("status")
                if (st == "done") break
                if (st == "failed") error(o.optString("error"))
                status = if (st == "queued") "Waiting for the model (first run can take 10+ minutes)…"
                else "Creating video… step ${o.optInt("step")}/${o.optInt("steps")}"
            }
            delay(3000)
        }
        openVideo(id)
        loadVideos()
    }

    private fun saveToDownloads(bytes: ByteArray): Uri? {
        val app = getApplication<Application>()
        val name = "vibe_${System.currentTimeMillis()}.mp4"
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val v = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, name)
                    put(MediaStore.Downloads.MIME_TYPE, "video/mp4")
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }
                val uri = app.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, v)!!
                app.contentResolver.openOutputStream(uri)!!.use { it.write(bytes) }
                status = "Saved to Downloads: $name"
                uri
            } else {
                val dir = app.getExternalFilesDir(Environment.DIRECTORY_MOVIES)!!
                File(dir, name).writeBytes(bytes)
                status = "Saved to ${dir.path}"
                null
            }
        } catch (e: Exception) { status = "Save failed: ${e.message}"; null }
    }

    fun saveVideo() { currentVideo?.let { saveToDownloads(it.readBytes()) } }

    fun shareVideo() {
        val f = currentVideo ?: return
        val uri = saveToDownloads(f.readBytes())
        if (uri == null) { status = "Sharing needs Android 10 or newer"; return }
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        getApplication<Application>().startActivity(
            Intent.createChooser(send, "Share video").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }
}
END_OF_FILE
mkdir -p android/app/src/main/java/com/example/vibesvideo
cat > android/app/src/main/java/com/example/vibesvideo/VideoApi.kt <<'END_OF_FILE'
package com.example.vibesvideo

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

data class VideoJob(val id: String, val prompt: String, val status: String, val step: Int, val steps: Int)

/** Talks to the AI video server (vibes_video_server.ipynb). */
class VideoApi(baseUrl: String) {
    private val base = baseUrl.trimEnd('/')
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    private suspend fun <T> exec(req: Request, parse: (Response) -> T): T = withContext(Dispatchers.IO) {
        client.newCall(req).execute().use {
            if (!it.isSuccessful) error("HTTP ${it.code}: ${it.body?.string()?.take(200)}")
            parse(it)
        }
    }

    suspend fun create(prompt: String, steps: Int, hd: Boolean): String {
        val body = JSONObject().put("prompt", prompt).put("steps", steps).put("hd", hd)
            .toString().toRequestBody("application/json".toMediaType())
        return exec(Request.Builder().url("$base/videos").post(body).build()) {
            JSONObject(it.body!!.string()).getString("id")
        }
    }

    suspend fun get(id: String): JSONObject =
        exec(Request.Builder().url("$base/videos/$id").build()) { JSONObject(it.body!!.string()) }

    suspend fun list(): List<VideoJob> = exec(Request.Builder().url("$base/videos").build()) { r ->
        val arr = JSONArray(r.body!!.string())
        (0 until arr.length()).map { arr.getJSONObject(it) }.map { o ->
            VideoJob(o.optString("id"), o.optString("prompt"), o.optString("status"), o.optInt("step"), o.optInt("steps"))
        }
    }

    suspend fun download(id: String, dest: File) {
        exec(Request.Builder().url("$base/videos/$id/file").build()) { r ->
            r.body!!.byteStream().use { inp -> dest.outputStream().use { inp.copyTo(it) } }
        }
    }
}
END_OF_FILE
