package com.moodframe.app

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Bluetooth
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.ListAlt
import androidx.compose.material.icons.filled.Login
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.UUID

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MoodFrameTheme {
                MoodFrameApp()
            }
        }
    }
}

private val Purple = Color(0xFF8C66D1)
private val Pink = Color(0xFFE68CAA)
private val Peach = Color(0xFFFDB78C)
private val TextGray = Color(0xFF8C8499)
private val PageBrush = Brush.verticalGradient(
    listOf(Color(0xFFF0EBFA), Color(0xFFFAEFF3), Color(0xFFFFF6F6))
)
private val PrimaryBrush = Brush.horizontalGradient(listOf(Purple, Pink))

private enum class RootScreen { Splash, Login, SignUp, Main }
private enum class AppPage(val title: String, val icon: ImageVector) {
    Chat("채팅", Icons.Default.Chat),
    SendFrame("프레임 전송", Icons.Default.Send),
    Gallery("이미지 저장", Icons.Default.Image),
    Records("기록", Icons.Default.ListAlt),
    Diary("일기장", Icons.Default.Book),
    Calendar("캘린더", Icons.Default.CalendarMonth)
}

private data class ChatMessage(val text: String, val isUser: Boolean)
private data class MoodRecord(
    val date: LocalDate,
    val emoji: String,
    val label: String,
    val note: String
)
private data class DiaryEntry(
    val date: LocalDate,
    val title: String,
    val content: String
)

@Composable
private fun MoodFrameTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = MaterialTheme.colorScheme.copy(
            primary = Purple,
            secondary = Pink,
            surface = Color.White,
            background = Color(0xFFFFF7F7)
        ),
        content = content
    )
}

@Composable
private fun MoodFrameApp() {
    var screen by remember { mutableStateOf(RootScreen.Splash) }
    var currentUser by remember { mutableStateOf("") }

    LaunchedEffect(Unit) {
        delay(2500)
        if (screen == RootScreen.Splash) screen = RootScreen.Login
    }

    when (screen) {
        RootScreen.Splash -> SplashScreen()
        RootScreen.Login -> LoginScreen(
            onLogin = { id, password ->
                if (id.isNotBlank() && password.isNotBlank()) {
                    currentUser = id
                    screen = RootScreen.Main
                    true
                } else {
                    false
                }
            },
            onSignUp = { screen = RootScreen.SignUp }
        )
        RootScreen.SignUp -> SignUpScreen(
            onBack = { screen = RootScreen.Login },
            onCreated = { screen = RootScreen.Login }
        )
        RootScreen.Main -> MainScreen(
            currentUser = currentUser,
            onLogout = {
                currentUser = ""
                screen = RootScreen.Login
            }
        )
    }
}

@Composable
private fun PageBackground(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PageBrush)
    ) {
        content()
    }
}

@Composable
private fun SplashScreen() {
    PageBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Box(
                modifier = Modifier
                    .size(96.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .background(PrimaryBrush),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.Image, contentDescription = null, tint = Color.White, modifier = Modifier.size(40.dp))
            }
            Spacer(Modifier.height(18.dp))
            BrandTitle(size = 38)
            Spacer(Modifier.height(8.dp))
            Text("감정을 기록하고 프레임에 담아요", color = TextGray)
        }
    }
}

@Composable
private fun LoginScreen(
    onLogin: (String, String) -> Boolean,
    onSignUp: () -> Unit
) {
    var id by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var showError by remember { mutableStateOf(false) }

    PageBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp, vertical = 56.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(
                modifier = Modifier
                    .size(84.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .background(PrimaryBrush),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.Image, contentDescription = null, tint = Color.White, modifier = Modifier.size(34.dp))
            }
            Spacer(Modifier.height(14.dp))
            BrandTitle(size = 32)
            Spacer(Modifier.height(6.dp))
            Text("감정을 기록하세요", color = TextGray)
            Spacer(Modifier.height(34.dp))

            LabeledField(label = "아이디", value = id, onValueChange = { id = it }, placeholder = "아이디를 입력하세요")
            Spacer(Modifier.height(16.dp))
            LabeledField(
                label = "비밀번호",
                value = password,
                onValueChange = { password = it },
                placeholder = "비밀번호를 입력하세요",
                password = true
            )

            if (showError) {
                Spacer(Modifier.height(10.dp))
                Text("아이디 또는 비밀번호를 확인해주세요.", color = Color(0xFFD44747), fontSize = 13.sp)
            }

            Spacer(Modifier.height(20.dp))
            GradientButton(text = "로그인", icon = Icons.Default.Login) {
                showError = !onLogin(id, password)
            }
            Spacer(Modifier.height(18.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("계정이 없으신가요?", color = TextGray, fontSize = 14.sp)
                TextButton(onClick = onSignUp) {
                    Text("회원가입", color = Purple, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun SignUpScreen(onBack: () -> Unit, onCreated: () -> Unit) {
    var id by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }

    PageBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 28.dp, vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "뒤로")
                }
                Spacer(Modifier.weight(1f))
            }
            BrandTitle(text = "회원가입", size = 28)
            Spacer(Modifier.height(28.dp))
            LabeledField("아이디", id, { id = it }, "아이디를 입력하세요")
            Spacer(Modifier.height(14.dp))
            LabeledField("비밀번호", password, { password = it }, "비밀번호를 입력하세요", password = true)
            Spacer(Modifier.height(14.dp))
            LabeledField("비밀번호 확인", confirm, { confirm = it }, "비밀번호를 다시 입력하세요", password = true)
            if (message.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                Text(message, color = Color(0xFFD44747), fontSize = 13.sp)
            }
            Spacer(Modifier.height(20.dp))
            GradientButton(text = "가입 완료", icon = Icons.Default.Check) {
                message = when {
                    id.isBlank() || password.isBlank() -> "아이디와 비밀번호를 입력해주세요."
                    password != confirm -> "비밀번호가 일치하지 않습니다."
                    else -> {
                        onCreated()
                        ""
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MainScreen(currentUser: String, onLogout: () -> Unit) {
    val context = LocalContext.current
    val bleManager = remember { AndroidBleManager(context.applicationContext) }
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    var selectedPage by remember { mutableStateOf(AppPage.Chat) }
    var showBle by remember { mutableStateOf(false) }
    var input by remember { mutableStateOf("") }
    val today = remember { LocalDate.now() }
    val records = remember {
        mutableStateListOf(
            MoodRecord(today, "🙂", "설렘", "오늘은 설레는 기분이에요"),
            MoodRecord(today.minusDays(1), "😌", "평온", "평온한 하루였어요"),
            MoodRecord(today.minusDays(3), "😊", "기쁨", "좋은 일이 있었어요")
        )
    }
    val diary = remember {
        mutableStateListOf(
            DiaryEntry(today.minusDays(2), "오늘의 기록", "Mood Frame 앱을 처음 써봤어요. 감정을 기록하는 일이 생각보다 편해요.")
        )
    }
    val messages = remember {
        mutableStateListOf(
            ChatMessage("안녕하세요.\n오늘 기분은 어떤가요? 지금 느끼는 감정을 자유롭게 이야기해주세요.", false),
            ChatMessage("오늘은 설레는 기분이에요.", true),
            ChatMessage("설렘이 느껴지는 하루였군요.\n어떤 일이 있었나요?", false)
        )
    }
    val savedImages = remember { mutableStateListOf<Bitmap>() }

    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = {
            ModalDrawerSheet(modifier = Modifier.width(280.dp)) {
                Column(Modifier.fillMaxHeight().padding(vertical = 24.dp)) {
                    BrandTitle(modifier = Modifier.padding(horizontal = 24.dp, vertical = 12.dp), size = 24)
                    Text("메뉴", modifier = Modifier.padding(horizontal = 24.dp), color = TextGray, fontSize = 13.sp)
                    Spacer(Modifier.height(20.dp))
                    AppPage.values().forEach { page ->
                        NavigationDrawerItem(
                            label = { Text(page.title) },
                            selected = selectedPage == page,
                            icon = { Icon(page.icon, contentDescription = null, tint = Purple) },
                            onClick = {
                                selectedPage = page
                                scope.launch { drawerState.close() }
                            },
                            modifier = Modifier.padding(horizontal = 12.dp)
                        )
                    }
                    Spacer(Modifier.weight(1f))
                    TextButton(
                        onClick = {
                            scope.launch { drawerState.close() }
                            onLogout()
                        },
                        modifier = Modifier.padding(horizontal = 16.dp)
                    ) {
                        Icon(Icons.Default.Close, contentDescription = null)
                        Spacer(Modifier.width(10.dp))
                        Text("로그아웃")
                    }
                }
            }
        }
    ) {
        if (showBle) {
            BleScreen(
                bleManager = bleManager,
                onClose = {
                    bleManager.stopScanning()
                    showBle = false
                }
            )
        } else {
            Scaffold(
                topBar = {
                    TopAppBar(
                        title = {
                            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                                BrandTitle(size = 22)
                            }
                        },
                        navigationIcon = {
                            IconButton(onClick = { scope.launch { drawerState.open() } }) {
                                Icon(Icons.Default.Menu, contentDescription = "메뉴", tint = Purple)
                            }
                        },
                        actions = {
                            IconButton(onClick = { showBle = true }) {
                                Icon(
                                    if (bleManager.connectedName != null) Icons.Default.Wifi else Icons.Default.Bluetooth,
                                    contentDescription = "블루투스",
                                    tint = if (bleManager.connectedName != null) Purple else TextGray
                                )
                            }
                        },
                        colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
                    )
                },
                containerColor = Color.Transparent
            ) { padding ->
                PageBackground {
                    Box(Modifier.padding(padding).fillMaxSize()) {
                        when (selectedPage) {
                            AppPage.Chat -> ChatHome(
                                currentUser = currentUser,
                                messages = messages,
                                input = input,
                                onInputChange = { input = it },
                                onSend = {
                                    val trimmed = input.trim()
                                    if (trimmed.isNotEmpty()) {
                                        messages.add(ChatMessage(trimmed, true))
                                        records.add(0, MoodRecord(LocalDate.now(), "💬", "직접 입력", trimmed))
                                        input = ""
                                    }
                                },
                                onQuickMood = { emoji, label ->
                                    val text = "오늘은 $label 기분이에요 $emoji"
                                    messages.add(ChatMessage(text, true))
                                    records.add(0, MoodRecord(LocalDate.now(), emoji, label, text))
                                }
                            )
                            AppPage.Gallery -> ImageGalleryPage(
                                savedImages = savedImages,
                                bleManager = bleManager
                            )
                            AppPage.SendFrame -> SendFramePage(
                                bleManager = bleManager,
                                onImageSent = { bitmap -> savedImages.add(0, bitmap) }
                            )
                            AppPage.Records -> RecordsPage(records)
                            AppPage.Diary -> DiaryPage(diary)
                            AppPage.Calendar -> CalendarPage(records)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SendFramePage(
    bleManager: AndroidBleManager,
    onImageSent: (Bitmap) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selectedUri by remember { mutableStateOf<Uri?>(null) }
    var previewBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var isSending by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        selectedUri = uri
        previewBitmap = uri?.let { context.decodeBitmap(it) }
        message = ""
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text("프레임 전송", fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
        Text("선택한 이미지를 4색 EPD 포맷으로 변환해서 MoodFrame-EPD로 보냅니다.", color = TextGray, fontSize = 14.sp)

        Surface(shape = RoundedCornerShape(8.dp), color = Color.White.copy(alpha = 0.88f)) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp)
                    .padding(12.dp),
                contentAlignment = Alignment.Center
            ) {
                val bitmap = previewBitmap
                if (bitmap == null) {
                    Text("이미지를 선택하세요", color = TextGray)
                } else {
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = "선택한 이미지",
                        modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(6.dp)),
                        contentScale = ContentScale.Fit
                    )
                }
            }
        }

        Button(onClick = { picker.launch("image/*") }, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Default.Image, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text("이미지 선택")
        }

        GradientButton(text = if (isSending) "전송 중..." else "프레임으로 전송", icon = Icons.Default.Send) {
            val uri = selectedUri
            if (uri == null) {
                message = "먼저 이미지를 선택해주세요."
                return@GradientButton
            }
            if (bleManager.connectedName == null) {
                message = "먼저 블루투스 화면에서 MoodFrame-EPD에 연결해주세요."
                return@GradientButton
            }
            if (isSending) return@GradientButton

            isSending = true
            message = "이미지 변환 및 전송 중..."
            scope.launch {
                val ok = bleManager.sendImage(uri)
                if (ok) {
                    previewBitmap?.let(onImageSent)
                    message = "전송 완료. 이미지 저장 목록에 추가했습니다."
                } else {
                    message = bleManager.status
                }
                isSending = false
            }
        }

        if (message.isNotEmpty()) {
            Text(message, color = if (message.contains("완료")) Purple else TextGray, fontSize = 14.sp)
        }
        Text(bleManager.status, color = TextGray, fontSize = 13.sp)
    }
}

@Composable
private fun ImageGalleryPage(
    savedImages: List<Bitmap>,
    bleManager: AndroidBleManager
) {
    val scope = rememberCoroutineScope()
    var sendingIndex by remember { mutableStateOf<Int?>(null) }
    var message by remember { mutableStateOf("") }

    if (savedImages.isEmpty()) {
        SimplePage("이미지 저장", "저장된 이미지가 아직 없습니다.")
        return
    }

    LazyColumn(
        contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("이미지 저장", fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(4.dp))
            Text("${savedImages.size}개의 전송 이미지", color = TextGray, fontSize = 13.sp)
            if (message.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                Text(message, color = if (message.contains("완료")) Purple else TextGray, fontSize = 13.sp)
            }
        }
        items(savedImages.size) { index ->
            val bitmap = savedImages[index]
            Surface(shape = RoundedCornerShape(8.dp), color = Color.White.copy(alpha = 0.9f)) {
                Column(Modifier.fillMaxWidth().padding(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = "전송한 이미지",
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(180.dp)
                            .clip(RoundedCornerShape(6.dp)),
                        contentScale = ContentScale.Fit
                    )
                    Button(
                        onClick = {
                            if (sendingIndex != null) return@Button
                            if (bleManager.connectedName == null) {
                                message = "먼저 블루투스 화면에서 기기에 연결해주세요."
                                return@Button
                            }
                            sendingIndex = index
                            message = "저장 이미지 재전송 중..."
                            scope.launch {
                                val ok = bleManager.sendImage(bitmap)
                                message = if (ok) "저장 이미지 재전송 완료" else bleManager.status
                                sendingIndex = null
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Default.Send, contentDescription = null)
                        Spacer(Modifier.width(8.dp))
                        Text(if (sendingIndex == index) "전송 중..." else "다시 전송")
                    }
                }
            }
        }
    }
}

@Composable
private fun ChatHome(
    currentUser: String,
    messages: List<ChatMessage>,
    input: String,
    onInputChange: (String) -> Unit,
    onSend: () -> Unit,
    onQuickMood: (String, String) -> Unit
) {
    Column(Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                Text("안녕하세요, $currentUser", color = TextGray, fontSize = 13.sp)
            }
            items(messages) { message ->
                ChatBubble(message)
            }
        }
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            listOf("😊" to "기쁨", "🙂" to "설렘", "😢" to "우울", "😌" to "평온").forEach { (emoji, label) ->
                TextButton(
                    onClick = { onQuickMood(emoji, label) },
                    colors = ButtonDefaults.textButtonColors(containerColor = Color.White.copy(alpha = 0.82f))
                ) {
                    Text("$emoji $label", color = Purple, fontSize = 13.sp)
                }
            }
        }
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            OutlinedTextField(
                value = input,
                onValueChange = onInputChange,
                placeholder = { Text("감정을 입력해보세요...") },
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(24.dp),
                singleLine = true
            )
            IconButton(
                onClick = onSend,
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(PrimaryBrush)
            ) {
                Icon(Icons.Default.Send, contentDescription = "전송", tint = Color.White)
            }
        }
    }
}

@Composable
private fun ChatBubble(message: ChatMessage) {
    Row(Modifier.fillMaxWidth()) {
        if (message.isUser) Spacer(Modifier.weight(1f))
        Text(
            text = message.text,
            color = if (message.isUser) Color.White else Color(0xFF24202A),
            modifier = Modifier
                .fillMaxWidth(0.78f)
                .clip(RoundedCornerShape(18.dp))
                .background(if (message.isUser) PrimaryBrush else Brush.linearGradient(listOf(Color.White, Color.White)))
                .padding(horizontal = 16.dp, vertical = 12.dp)
        )
        if (!message.isUser) Spacer(Modifier.weight(1f))
    }
}

@Composable
private fun RecordsPage(records: List<MoodRecord>) {
    LazyColumn(contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items(records) { record ->
            Surface(shape = RoundedCornerShape(8.dp), color = Color.White.copy(alpha = 0.88f)) {
                Column(Modifier.fillMaxWidth().padding(16.dp)) {
                    Text("${record.emoji} ${record.label}", fontWeight = FontWeight.SemiBold)
                    Text(record.date.format(DateTimeFormatter.ISO_DATE), color = TextGray, fontSize = 13.sp)
                    Spacer(Modifier.height(6.dp))
                    Text(record.note)
                }
            }
        }
    }
}

@Composable
private fun DiaryPage(entries: List<DiaryEntry>) {
    LazyColumn(contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items(entries) { entry ->
            Surface(shape = RoundedCornerShape(8.dp), color = Color.White.copy(alpha = 0.88f)) {
                Column(Modifier.fillMaxWidth().padding(16.dp)) {
                    Text(entry.title, fontWeight = FontWeight.SemiBold)
                    Text(entry.date.format(DateTimeFormatter.ISO_DATE), color = TextGray, fontSize = 13.sp)
                    Spacer(Modifier.height(6.dp))
                    Text(entry.content)
                }
            }
        }
    }
}

@Composable
private fun CalendarPage(records: List<MoodRecord>) {
    val grouped = records.groupBy { it.date }.toSortedMap(compareByDescending { it })
    LazyColumn(contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        grouped.forEach { (date, dayRecords) ->
            item {
                Surface(shape = RoundedCornerShape(8.dp), color = Color.White.copy(alpha = 0.88f)) {
                    Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(date.format(DateTimeFormatter.ISO_DATE), fontWeight = FontWeight.SemiBold)
                            Text("${dayRecords.size}개의 감정 기록", color = TextGray, fontSize = 13.sp)
                        }
                        Text(dayRecords.joinToString(" ") { it.emoji }, fontSize = 24.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun SimplePage(title: String, message: String) {
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Text(title, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(8.dp))
        Text(message, color = TextGray)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BleScreen(bleManager: AndroidBleManager, onClose: () -> Unit) {
    val context = LocalContext.current
    val permissions = remember { blePermissions() }
    var hasPermissions by remember { mutableStateOf(permissions.all { ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED }) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { grants ->
        hasPermissions = permissions.all { grants[it] == true || ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED }
        if (hasPermissions) bleManager.startScanning()
    }

    LaunchedEffect(Unit) {
        if (!hasPermissions) launcher.launch(permissions)
    }

    LaunchedEffect(hasPermissions) {
        if (hasPermissions) bleManager.startScanning()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("기기 연결") },
                navigationIcon = {
                    IconButton(onClick = onClose) {
                        Icon(Icons.Default.Close, contentDescription = "닫기")
                    }
                },
                actions = {
                    IconButton(onClick = {
                        if (hasPermissions) bleManager.startScanning() else launcher.launch(permissions)
                    }) {
                        Icon(Icons.Default.Refresh, contentDescription = "새로고침")
                    }
                }
            )
        }
    ) { padding ->
        PageBackground {
            Column(Modifier.padding(padding).fillMaxSize().padding(18.dp)) {
                if (!hasPermissions) {
                    Text("갤럭시에서 Mood Frame 기기를 찾으려면 블루투스 권한이 필요합니다.", color = TextGray)
                    Spacer(Modifier.height(14.dp))
                    GradientButton("권한 허용", Icons.Default.Bluetooth) {
                        launcher.launch(permissions)
                    }
                } else {
                    Text(bleManager.status, color = if (bleManager.status.contains("실패")) Color(0xFFD44747) else TextGray)
                    Spacer(Modifier.height(14.dp))

                    if (bleManager.connectedName != null) {
                        Button(
                            onClick = { bleManager.disconnect() },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD44747))
                        ) {
                            Icon(Icons.Default.Close, contentDescription = null, tint = Color.White)
                            Spacer(Modifier.width(8.dp))
                            Text("${bleManager.connectedName} 연결 해제", color = Color.White)
                        }
                        Spacer(Modifier.height(14.dp))
                    }

                    if (bleManager.devices.isEmpty() && bleManager.isScanning) {
                        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                            CircularProgressIndicator(color = Purple)
                            Spacer(Modifier.height(12.dp))
                            Text("MoodFrame-EPD를 검색 중입니다...", color = TextGray)
                        }
                    } else {
                        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            items(bleManager.devices, key = { it.address }) { device ->
                                Surface(shape = RoundedCornerShape(8.dp), color = Color.White.copy(alpha = 0.9f)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Column(Modifier.weight(1f)) {
                                            Text(device.name, fontWeight = FontWeight.SemiBold)
                                            Text("${device.address} / RSSI ${device.rssi}", color = TextGray, fontSize = 12.sp)
                                        }
                                        Button(onClick = { bleManager.connect(device) }) {
                                            Text(if (bleManager.connectedName == device.name) "연결됨" else "연결")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LabeledField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    password: Boolean = false
) {
    Column(Modifier.fillMaxWidth()) {
        Text(label, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder) },
            visualTransformation = if (password) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun GradientButton(text: String, icon: ImageVector, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth().height(54.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .background(PrimaryBrush)
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(icon, contentDescription = null, tint = Color.White)
            Spacer(Modifier.width(8.dp))
            Text(text, color = Color.White, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun BrandTitle(
    modifier: Modifier = Modifier,
    text: String = "Mood Frame",
    size: Int
) {
    Text(
        text = text,
        modifier = modifier,
        color = Purple,
        fontFamily = FontFamily.Serif,
        fontStyle = FontStyle.Italic,
        fontWeight = FontWeight.Bold,
        fontSize = size.sp
    )
}

private fun Context.decodeBitmap(uri: Uri): Bitmap? {
    return contentResolver.openInputStream(uri)?.use { input ->
        BitmapFactory.decodeStream(input)
    }
}

private fun Context.isLocationEnabled(): Boolean {
    val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        locationManager.isLocationEnabled
    } else {
        @Suppress("DEPRECATION")
        locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }
}

private data class DiscoveredBleDevice(
    val name: String,
    val address: String,
    val rssi: Int,
    val device: BluetoothDevice
)

private class AndroidBleManager(private val context: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private val scanner get() = bluetoothAdapter?.bluetoothLeScanner
    private var gatt: BluetoothGatt? = null
    private var mtu = 23
    private var pendingWrite: CompletableDeferred<Boolean>? = null

    val devices = mutableStateListOf<DiscoveredBleDevice>()
    var isScanning by mutableStateOf(false)
        private set
    var status by mutableStateOf("MoodFrame-EPD를 검색할 수 있습니다.")
        private set
    var connectedName by mutableStateOf<String?>(null)
        private set

    private val scanCallback = object : ScanCallback() {
        @SuppressLint("MissingPermission")
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            if (result.rssi <= -90) return
            val displayName = (result.scanRecord?.deviceName
                ?: result.device.name
                ?: return).trim()
            if (displayName.isEmpty()) return
            val discovered = DiscoveredBleDevice(displayName, result.device.address, result.rssi, result.device)
            mainHandler.post {
                val index = devices.indexOfFirst { it.address == discovered.address }
                if (index >= 0) devices[index] = discovered else devices.add(0, discovered)
            }
        }

        override fun onScanFailed(errorCode: Int) {
            mainHandler.post {
                isScanning = false
                status = "BLE 스캔 실패: $errorCode"
            }
        }
    }

    @SuppressLint("MissingPermission")
    fun startScanning() {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            status = "이 기기는 BLE를 지원하지 않습니다."
            return
        }
        if (!adapter.isEnabled) {
            status = "갤럭시 설정에서 블루투스를 켜주세요."
            return
        }
        if (!context.isLocationEnabled()) {
            status = "갤럭시 설정에서 위치를 켜주세요. 일부 Android BLE 스캔은 위치 토글이 꺼져 있으면 결과가 비어 있습니다."
            return
        }
        devices.clear()
        isScanning = true
        status = "주변 BLE 기기를 모두 검색 중..."
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        scanner?.stopScan(scanCallback)
        if (scanner == null) {
            isScanning = false
            status = "BLE scanner를 시작하지 못했습니다. 블루투스를 껐다 켠 뒤 다시 시도해주세요."
            return
        }
        try {
            scanner?.startScan(null, settings, scanCallback)
        } catch (securityException: SecurityException) {
            isScanning = false
            status = "BLE 권한이 부족합니다. 앱 정보에서 근처 기기와 위치 권한을 허용해주세요."
        } catch (exception: IllegalStateException) {
            isScanning = false
            status = "BLE 스캔을 시작하지 못했습니다: ${exception.message ?: "알 수 없는 오류"}"
        }
    }

    @SuppressLint("MissingPermission")
    fun stopScanning() {
        scanner?.stopScan(scanCallback)
        isScanning = false
    }

    @SuppressLint("MissingPermission")
    fun disconnect() {
        stopScanning()
        pendingWrite?.complete(false)
        pendingWrite = null
        val name = connectedName
        connectedName = null
        mtu = 23
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        status = if (name == null) {
            "연결된 기기가 없습니다."
        } else {
            "$name 연결을 해제했습니다."
        }
    }

    @SuppressLint("MissingPermission")
    fun connect(device: DiscoveredBleDevice) {
        stopScanning()
        status = "${device.name} 연결 중..."
        connectedName = null
        mtu = 23
        gatt?.close()
        gatt = device.device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
    }

    @SuppressLint("MissingPermission")
    suspend fun sendImage(uri: Uri): Boolean {
        val payload = withContext(Dispatchers.IO) {
            packImageForTag(context, uri)
        }
        if (payload == null) {
            postStatus("이미지를 읽거나 변환하지 못했습니다.")
            return false
        }
        return sendImagePayload(payload)
    }

    @SuppressLint("MissingPermission")
    suspend fun sendImage(bitmap: Bitmap): Boolean {
        val payload = withContext(Dispatchers.Default) {
            packBitmapForTag(bitmap)
        }
        return sendImagePayload(payload)
    }

    @SuppressLint("MissingPermission")
    private suspend fun sendImagePayload(payload: ByteArray): Boolean {
        val activeGatt = gatt
        if (activeGatt == null || connectedName == null) {
            postStatus("먼저 MoodFrame-EPD에 연결해주세요.")
            return false
        }

        val imageCharacteristic = activeGatt.getService(MOOD_FRAME_SERVICE_UUID)
            ?.getCharacteristic(MOOD_FRAME_IMAGE_UUID)

        if (imageCharacteristic == null) {
            val legacyCharacteristic = activeGatt.getService(LEGACY_SERVICE_UUID)
                ?.getCharacteristic(LEGACY_COMMAND_UUID)
            if (legacyCharacteristic != null) {
                val ok = writeCharacteristic(activeGatt, legacyCharacteristic, byteArrayOf(0x01), false)
                postStatus(if (ok) "nimble-bleprph에 기본 이미지 표시 명령을 보냈습니다." else "nimble-bleprph 명령 전송 실패")
                return ok
            }

            postStatus("이미지 전송 characteristic을 찾지 못했습니다. 펌웨어 종류를 확인해주세요.")
            return false
        }

        val chunkSize = minOf(CHUNK_SIZE, (mtu - 3).coerceAtLeast(20))
        val totalChunks = (payload.size + chunkSize - 1) / chunkSize
        postStatus("이미지 전송 시작: ${payload.size} bytes")

        for (offset in payload.indices step chunkSize) {
            val end = minOf(offset + chunkSize, payload.size)
            val chunk = payload.copyOfRange(offset, end)
            val writeOk = writeCharacteristicAwait(activeGatt, imageCharacteristic, chunk)
            if (!writeOk) {
                postStatus("이미지 전송 실패: ${offset / chunkSize + 1}/$totalChunks")
                return false
            }

            if (offset == 0 || end == payload.size || (offset / chunkSize) % 8 == 0) {
                postStatus("이미지 전송 중: ${offset / chunkSize + 1}/$totalChunks")
            }
            delay(5)
        }

        postStatus("전송 완료. 프레임 표시 확인 대기 중...")
        return true
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, statusCode: Int, newState: Int) {
            val name = gatt.device.name ?: MOOD_FRAME_DEVICE_NAME
            mainHandler.post {
                if (statusCode != BluetoothGatt.GATT_SUCCESS) {
                    connectedName = null
                    status = "연결 실패: $statusCode"
                    gatt.close()
                    return@post
                }
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        connectedName = name
                        status = "$name 연결됨. 전송 MTU 설정 중..."
                        if (!gatt.requestMtu(247)) {
                            gatt.discoverServices()
                        }
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        connectedName = null
                        status = "$name 연결이 해제되었습니다."
                        gatt.close()
                    }
                }
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, statusCode: Int) {
            this@AndroidBleManager.mtu = if (statusCode == BluetoothGatt.GATT_SUCCESS) mtu else 23
            mainHandler.post {
                status = "${connectedName ?: "기기"} 연결됨. 서비스 확인 중..."
                gatt.discoverServices()
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, statusCode: Int) {
            mainHandler.post {
                val imageService = gatt.getService(MOOD_FRAME_SERVICE_UUID)
                val legacyService = gatt.getService(LEGACY_SERVICE_UUID)
                status = if (statusCode == BluetoothGatt.GATT_SUCCESS && imageService != null) {
                    subscribeToStatus(gatt)
                    "${connectedName ?: "기기"} 준비 완료"
                } else if (statusCode == BluetoothGatt.GATT_SUCCESS && legacyService != null) {
                    "${connectedName ?: "nimble-bleprph"} 준비 완료: 기본 이미지 명령 전송 모드"
                } else {
                    "연결됨. 지원하는 Mood Frame 서비스를 찾지 못했습니다."
                }
            }
        }

        @Deprecated("Used by Android versions before API 33.")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            onStatusChanged(characteristic.uuid, characteristic.value)
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            onStatusChanged(characteristic.uuid, value)
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            pendingWrite?.complete(status == BluetoothGatt.GATT_SUCCESS)
            pendingWrite = null
        }
    }

    @SuppressLint("MissingPermission")
    private fun subscribeToStatus(gatt: BluetoothGatt) {
        val statusCharacteristic = gatt.getService(MOOD_FRAME_SERVICE_UUID)
            ?.getCharacteristic(MOOD_FRAME_STATUS_UUID)
            ?: return
        gatt.setCharacteristicNotification(statusCharacteristic, true)
        val descriptor = statusCharacteristic.getDescriptor(CLIENT_CONFIG_UUID) ?: return
        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        gatt.writeDescriptor(descriptor)
    }

    private fun onStatusChanged(uuid: UUID, value: ByteArray) {
        if (uuid == MOOD_FRAME_STATUS_UUID) {
            mainHandler.post {
                status = when (value.firstOrNull()?.toInt()) {
                    1 -> "프레임 표시 완료"
                    2 -> "프레임 표시 실패"
                    else -> "${connectedName ?: "기기"} 연결됨"
                }
            }
        }
    }

    private fun postStatus(value: String) {
        mainHandler.post { status = value }
    }

    @SuppressLint("MissingPermission")
    private fun writeCharacteristic(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        data: ByteArray,
        withoutResponse: Boolean
    ): Boolean {
        val writeType = if (withoutResponse) {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt.writeCharacteristic(characteristic, data, writeType) == BluetoothGatt.GATT_SUCCESS
        } else {
            @Suppress("DEPRECATION")
            characteristic.value = data
            characteristic.writeType = writeType
            @Suppress("DEPRECATION")
            gatt.writeCharacteristic(characteristic)
        }
    }

    @SuppressLint("MissingPermission")
    private suspend fun writeCharacteristicAwait(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        data: ByteArray
    ): Boolean {
        pendingWrite?.complete(false)
        val deferred = CompletableDeferred<Boolean>()
        pendingWrite = deferred

        val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt.writeCharacteristic(
                characteristic,
                data,
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            ) == BluetoothGatt.GATT_SUCCESS
        } else {
            @Suppress("DEPRECATION")
            characteristic.value = data
            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            @Suppress("DEPRECATION")
            gatt.writeCharacteristic(characteristic)
        }

        if (!started) {
            pendingWrite = null
            return false
        }

        return withTimeoutOrNull(3000) {
            deferred.await()
        } == true
    }

    companion object {
        private const val EPD_WIDTH = 250
        private const val EPD_HEIGHT = 122
        private const val EPD_RAM_HEIGHT = 128
        private const val CHUNK_SIZE = 180
        private const val MOOD_FRAME_DEVICE_NAME = "MoodFrame-EPD"
        private const val LEGACY_DEVICE_NAME = "nimble-bleprph"
        val MOOD_FRAME_SERVICE_UUID: UUID = UUID.fromString("7a0247e0-4b3a-4bde-9e1f-1c9b6a4f9001")
        val MOOD_FRAME_IMAGE_UUID: UUID = UUID.fromString("7a0247e1-4b3a-4bde-9e1f-1c9b6a4f9002")
        val MOOD_FRAME_STATUS_UUID: UUID = UUID.fromString("7a0247e2-4b3a-4bde-9e1f-1c9b6a4f9003")
        val LEGACY_SERVICE_UUID: UUID = UUID.fromString("59462f12-9543-9999-12c8-58b459a2712d")
        val LEGACY_COMMAND_UUID: UUID = UUID.fromString("33333333-2222-2222-1111-111100000000")
        val CLIENT_CONFIG_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        private val palette = arrayOf(
            intArrayOf(255, 255, 255),
            intArrayOf(255, 255, 0),
            intArrayOf(255, 0, 0),
            intArrayOf(0, 0, 0)
        )

        private fun packImageForTag(context: Context, uri: Uri): ByteArray? {
            val original = context.contentResolver.openInputStream(uri)?.use { input ->
                BitmapFactory.decodeStream(input)
            } ?: return null
            return packBitmapForTag(original)
        }

        private fun packBitmapForTag(original: Bitmap): ByteArray {
            val scaled = fitBitmapForTag(original)
            val pixels = IntArray(EPD_WIDTH * EPD_HEIGHT)
            scaled.getPixels(pixels, 0, EPD_WIDTH, 0, 0, EPD_WIDTH, EPD_HEIGHT)

            val rgb = FloatArray(EPD_WIDTH * EPD_HEIGHT * 3)
            for (index in pixels.indices) {
                val color = pixels[index]
                val base = index * 3
                rgb[base] = ((color shr 16) and 0xff).toFloat()
                rgb[base + 1] = ((color shr 8) and 0xff).toFloat()
                rgb[base + 2] = (color and 0xff).toFloat()
            }

            val colorMap = ByteArray(EPD_WIDTH * EPD_HEIGHT)
            for (y in 0 until EPD_HEIGHT) {
                for (x in 0 until EPD_WIDTH) {
                    val index = y * EPD_WIDTH + x
                    val base = index * 3
                    var best = 0
                    var bestDistance = Float.MAX_VALUE
                    for (paletteIndex in palette.indices) {
                        val p = palette[paletteIndex]
                        val dr = rgb[base] - p[0]
                        val dg = rgb[base + 1] - p[1]
                        val db = rgb[base + 2] - p[2]
                        val distance = dr * dr + dg * dg + db * db
                        if (distance < bestDistance) {
                            bestDistance = distance
                            best = paletteIndex
                        }
                    }
                    colorMap[index] = best.toByte()

                    val chosen = palette[best]
                    val er = rgb[base] - chosen[0]
                    val eg = rgb[base + 1] - chosen[1]
                    val eb = rgb[base + 2] - chosen[2]
                    diffuse(rgb, x + 1, y, er, eg, eb, 7f / 16f)
                    diffuse(rgb, x - 1, y + 1, er, eg, eb, 3f / 16f)
                    diffuse(rgb, x, y + 1, er, eg, eb, 5f / 16f)
                    diffuse(rgb, x + 1, y + 1, er, eg, eb, 1f / 16f)
                }
            }

            val bytesPerColumn = EPD_RAM_HEIGHT / 4
            val packed = ByteArray(EPD_WIDTH * bytesPerColumn)
            var out = 0
            for (x in EPD_WIDTH - 1 downTo 0) {
                for (byteY in 0 until bytesPerColumn) {
                    var value = 0
                    for (i in 0 until 4) {
                        val y = byteY * 4 + i
                        val color = if (y < EPD_HEIGHT) {
                            colorMap[y * EPD_WIDTH + x].toInt() and 0x03
                        } else {
                            0
                        }
                        value = value or (color shl (6 - i * 2))
                    }
                    packed[out++] = value.toByte()
                }
            }
            return packed
        }

        private fun fitBitmapForTag(original: Bitmap): Bitmap {
            val output = Bitmap.createBitmap(EPD_WIDTH, EPD_HEIGHT, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)
            canvas.drawColor(android.graphics.Color.WHITE)

            val scale = minOf(
                EPD_WIDTH.toFloat() / original.width.toFloat(),
                EPD_HEIGHT.toFloat() / original.height.toFloat()
            )
            val drawWidth = original.width * scale
            val drawHeight = original.height * scale
            val left = (EPD_WIDTH - drawWidth) / 2f
            val top = (EPD_HEIGHT - drawHeight) / 2f

            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            canvas.drawBitmap(
                original,
                null,
                RectF(left, top, left + drawWidth, top + drawHeight),
                paint
            )

            return output
        }

        private fun diffuse(
            rgb: FloatArray,
            x: Int,
            y: Int,
            er: Float,
            eg: Float,
            eb: Float,
            factor: Float
        ) {
            if (x !in 0 until EPD_WIDTH || y !in 0 until EPD_HEIGHT) return
            val base = (y * EPD_WIDTH + x) * 3
            rgb[base] = (rgb[base] + er * factor).coerceIn(0f, 255f)
            rgb[base + 1] = (rgb[base + 1] + eg * factor).coerceIn(0f, 255f)
            rgb[base + 2] = (rgb[base + 2] + eb * factor).coerceIn(0f, 255f)
        }
    }
}

private fun blePermissions(): Array<String> {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.ACCESS_FINE_LOCATION
        )
    } else {
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }
}
