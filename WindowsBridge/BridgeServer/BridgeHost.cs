using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

internal sealed class BridgeHost : IAsyncDisposable
{
    private const int TelemetryPort = 8766;
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly int _port;
    private readonly ControlMap _controls;
    private readonly TcpListener _listener;
    private readonly object _pairLock = new();
    private string _pairingCode = CreatePairingCode();
    private string? _pairingToken;
    private ClientSession? _activeClient;
    private volatile bool _gameActive;
    private volatile bool _gamePaused = true;
    private long _lastTelemetryUtcTicks;
    private readonly ConcurrentDictionary<string, ushort> _heldKeys = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<Guid, Task> _clientTasks = new();

    public BridgeHost(int port, ControlMap controls)
    {
        _port = port;
        _controls = controls;
        _listener = new TcpListener(IPAddress.Any, port);
    }

    public string PairingCode => _pairingCode;

    public async Task RunAsync(CancellationToken cancellationToken)
    {
        _listener.Start();
        Console.WriteLine($"브리지 서버가 포트 {_port}에서 실행 중입니다.");
        using var udp = new UdpClient(new IPEndPoint(IPAddress.Loopback, TelemetryPort));
        var telemetryTask = ReadTelemetryAsync(udp, cancellationToken);
        var heartbeatTask = SendHeartbeatsAsync(cancellationToken);
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                var tcpClient = await _listener.AcceptTcpClientAsync(cancellationToken);
                tcpClient.NoDelay = true;
                var clientId = Guid.NewGuid();
                var task = Task.Run(() => HandleClientAsync(tcpClient, cancellationToken), CancellationToken.None);
                _clientTasks[clientId] = task;
                _ = task.ContinueWith(completed =>
                {
                    _clientTasks.TryRemove(clientId, out var removedTask);
                }, CancellationToken.None, TaskContinuationOptions.ExecuteSynchronously, TaskScheduler.Default);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        finally
        {
            _listener.Stop();
            udp.Dispose();
            try { await Task.WhenAll(telemetryTask, heartbeatTask); }
            catch (OperationCanceledException) { }
            ReleaseHeldKeys();
            try { await Task.WhenAll(_clientTasks.Values); }
            catch (OperationCanceledException) { }
        }
    }

    private async Task ReadTelemetryAsync(UdpClient udp, CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            UdpReceiveResult result;
            try
            {
                result = await udp.ReceiveAsync(cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { return; }
            catch (ObjectDisposedException) { return; }

            var json = Encoding.UTF8.GetString(result.Buffer);
            try
            {
                using var document = JsonDocument.Parse(json);
                var root = document.RootElement;
                if (root.TryGetProperty("type", out var type) && type.GetString() == "telemetry.snapshot" &&
                    root.TryGetProperty("data", out var data))
                {
                    _gameActive = data.TryGetProperty("gameActive", out var active) && active.GetBoolean();
                    _gamePaused = data.TryGetProperty("paused", out var paused) && paused.GetBoolean();
                    Interlocked.Exchange(ref _lastTelemetryUtcTicks, DateTime.UtcNow.Ticks);
                }
            }
            catch (JsonException)
            {
                continue;
            }

            var client = _activeClient;
            if (client is not null && client.IsAuthenticated)
            {
                try { await client.SendRawAsync(result.Buffer, cancellationToken); }
                catch (WebSocketException) { }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { return; }
            }
        }
    }

    private async Task SendHeartbeatsAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(1));
        while (await timer.WaitForNextTickAsync(cancellationToken))
        {
            var client = _activeClient;
            if (client is null || !client.IsAuthenticated) continue;
            try
            {
                await client.SendObjectAsync(new
                {
                    type = "bridge.status",
                    version = 1,
                    gameState = CurrentGameState()
                }, cancellationToken);
            }
            catch (WebSocketException)
            {
                client.Abort();
            }
        }
    }

    private string CurrentGameState()
    {
        var last = Interlocked.Read(ref _lastTelemetryUtcTicks);
        if (last == 0) return "waiting";
        if (DateTime.UtcNow.Ticks - last > TimeSpan.FromSeconds(3).Ticks) return "stale";
        if (_gamePaused) return "paused";
        return _gameActive ? "live" : "waiting";
    }

    private async Task HandleClientAsync(TcpClient tcpClient, CancellationToken cancellationToken)
    {
        await using var session = new ClientSession(tcpClient);
        try
        {
            var headers = await session.ReadHttpHeadersAsync(cancellationToken);
            if (!headers.TryGetValue("sec-websocket-key", out var key) ||
                !headers.TryGetValue("upgrade", out var upgrade) || !upgrade.Equals("websocket", StringComparison.OrdinalIgnoreCase) ||
                !headers.TryGetValue("sec-websocket-version", out var websocketVersion) || websocketVersion != "13" ||
                !headers.TryGetValue("connection", out var connection) || !connection.Contains("upgrade", StringComparison.OrdinalIgnoreCase))
            {
                await session.SendHttpErrorAsync("400 Bad Request", cancellationToken);
                return;
            }

            await session.AcceptWebSocketAsync(key, cancellationToken);
            using var firstMessage = await session.ReceiveJsonAsync(cancellationToken);
            if (firstMessage is null)
            {
                await session.CloseAsync(WebSocketCloseStatus.PolicyViolation, "pairing or authentication is required", cancellationToken);
                return;
            }

            var request = firstMessage.RootElement;
            if (!request.TryGetProperty("type", out var typeElement))
            {
                await session.SendObjectAsync(new { type = "auth.rejected", message = "인증 요청이 필요합니다." }, cancellationToken);
                return;
            }

            var type = typeElement.GetString();
            if (type == "pair.request")
            {
                var suppliedCode = request.TryGetProperty("code", out var codeValue) ? codeValue.GetString() : null;
                var paired = TryPair(suppliedCode, out var token);
                if (!paired)
                {
                    await session.SendObjectAsync(new { type = "pair.rejected", message = "페어링 코드가 올바르지 않거나 이미 사용되었습니다." }, cancellationToken);
                    await session.CloseAsync(WebSocketCloseStatus.PolicyViolation, "pairing rejected", cancellationToken);
                    return;
                }
                session.SetAuthenticated();
                ReplaceActiveClient(session);
                await session.SendObjectAsync(new { type = "pair.accepted", version = 1, token }, cancellationToken);
            }
            else if (type == "auth")
            {
                var token = request.TryGetProperty("token", out var tokenElement) ? tokenElement.GetString() : null;
                if (!IsValidToken(token))
                {
                    await session.SendObjectAsync(new { type = "auth.rejected", message = "저장된 페어링 정보가 만료되었습니다. Windows 브리지를 다시 시작해 새 코드를 입력하세요." }, cancellationToken);
                    await session.CloseAsync(WebSocketCloseStatus.PolicyViolation, "authentication rejected", cancellationToken);
                    return;
                }
                session.SetAuthenticated();
                ReplaceActiveClient(session);
                await session.SendObjectAsync(new { type = "auth.accepted", version = 1 }, cancellationToken);
            }
            else
            {
                await session.SendObjectAsync(new { type = "auth.rejected", message = "지원하지 않는 인증 요청입니다." }, cancellationToken);
                await session.CloseAsync(WebSocketCloseStatus.PolicyViolation, "invalid authentication", cancellationToken);
                return;
            }

            await session.SendObjectAsync(new { type = "bridge.status", version = 1, gameState = CurrentGameState() }, cancellationToken);
            await ReceiveClientMessagesAsync(session, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (IOException)
        {
        }
        catch (WebSocketException)
        {
        }
        finally
        {
            if (ReferenceEquals(_activeClient, session))
            {
                _activeClient = null;
                ReleaseHeldKeys();
            }
        }
    }

    private bool TryPair(string? code, out string token)
    {
        token = string.Empty;
        lock (_pairLock)
        {
            if (string.IsNullOrWhiteSpace(code) || _pairingToken is not null ||
                !CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(_pairingCode), Encoding.UTF8.GetBytes(code)))
            {
                return false;
            }
            _pairingToken = CreateToken();
            token = _pairingToken;
            _pairingCode = string.Empty;
            Console.WriteLine("iPad가 페어링되었습니다.");
            return true;
        }
    }

    private bool IsValidToken(string? token)
    {
        lock (_pairLock)
        {
            if (token is null || _pairingToken is null) return false;
            return CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(_pairingToken), Encoding.UTF8.GetBytes(token));
        }
    }

    private void ReplaceActiveClient(ClientSession newClient)
    {
        var previous = Interlocked.Exchange(ref _activeClient, newClient);
        if (previous is not null && !ReferenceEquals(previous, newClient))
        {
            ReleaseHeldKeys();
            previous.Abort();
        }
    }

    private async Task ReceiveClientMessagesAsync(ClientSession client, CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested && client.IsAuthenticated)
        {
            using var document = await client.ReceiveJsonAsync(cancellationToken);
            if (document is null) return;
            var root = document.RootElement;
            if (!root.TryGetProperty("type", out var type) || type.GetString() != "command.request") continue;
            var commandId = root.TryGetProperty("commandId", out var id) ? id.GetString() : null;
            var control = root.TryGetProperty("control", out var controlElement) ? controlElement.GetString() : null;
            var phase = root.TryGetProperty("phase", out var phaseElement) ? phaseElement.GetString() : "tap";
            var (success, message) = await ExecuteCommandAsync(control, phase);
            await client.SendObjectAsync(new { type = "command.result", version = 1, commandId, success, message }, cancellationToken);
        }
    }

    private async Task<(bool Success, string Message)> ExecuteCommandAsync(string? control, string? phase)
    {
        if (string.IsNullOrWhiteSpace(control) || !_controls.TryGetKey(control, out var key))
            return (false, "이 조작은 controls.json에 등록되지 않았습니다.");
        var requestedPhase = phase ?? "tap";
        if (requestedPhase == "up")
        {
            if (_heldKeys.TryRemove(control, out var heldKey)) SendKey(heldKey, keyUp: true);
            return (true, "버튼을 놓았습니다.");
        }
        if (CurrentGameState() != "live")
            return (false, "ETS2 실시간 주행 중일 때만 조작할 수 있습니다.");
        if (!IsEts2Foreground())
            return (false, "ETS2 창을 앞으로 가져온 뒤 다시 누르세요.");

        if (requestedPhase == "down")
        {
            if (SendKey(key, keyUp: false))
            {
                _heldKeys[control] = key;
                return (true, "버튼을 누르고 있습니다.");
            }
            return (false, "Windows 키 입력에 실패했습니다.");
        }
        if (requestedPhase != "tap") return (false, "지원하지 않는 조작 단계입니다.");

        if (!SendKey(key, keyUp: false)) return (false, "Windows 키 입력에 실패했습니다.");
        await Task.Delay(90);
        SendKey(key, keyUp: true);
        return (true, "ETS2에 키 입력을 보냈습니다.");
    }

    private static bool IsEts2Foreground()
    {
        var window = NativeMethods.GetForegroundWindow();
        if (window == IntPtr.Zero) return false;
        NativeMethods.GetWindowThreadProcessId(window, out var processId);
        if (processId == 0) return false;
        try
        {
            using var process = Process.GetProcessById((int)processId);
            return process.ProcessName.Equals("eurotrucks2", StringComparison.OrdinalIgnoreCase);
        }
        catch (ArgumentException)
        {
            return false;
        }
    }

    private static bool SendKey(ushort virtualKey, bool keyUp)
    {
        var input = new NativeMethods.Input
        {
            Type = NativeMethods.InputKeyboard,
            Union = new NativeMethods.InputUnion
            {
                Keyboard = new NativeMethods.KeyboardInput
                {
                    VirtualKey = virtualKey,
                    Flags = keyUp ? NativeMethods.KeyEventKeyUp : 0
                }
            }
        };
        return NativeMethods.SendInput(1, [input], Marshal.SizeOf<NativeMethods.Input>()) == 1;
    }

    private void ReleaseHeldKeys()
    {
        foreach (var item in _heldKeys.ToArray())
        {
            if (_heldKeys.TryRemove(item.Key, out var key)) SendKey(key, keyUp: true);
        }
    }

    private static string CreatePairingCode() => RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

    private static string CreateToken() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
        .TrimEnd('=').Replace('+', '-').Replace('/', '_');

    public async ValueTask DisposeAsync()
    {
        _listener.Stop();
        var active = Interlocked.Exchange(ref _activeClient, null);
        if (active is not null)
        {
            active.Abort();
            await active.DisposeAsync();
        }
        ReleaseHeldKeys();
    }

    private static class NativeMethods
    {
        public const uint InputKeyboard = 1;
        public const uint KeyEventKeyUp = 0x0002;

        [StructLayout(LayoutKind.Sequential)]
        public struct Input
        {
            public uint Type;
            public InputUnion Union;
        }

        [StructLayout(LayoutKind.Explicit, Size = 32)]
        public struct InputUnion
        {
            [FieldOffset(0)] public MouseInput Mouse;
            [FieldOffset(0)] public KeyboardInput Keyboard;
            [FieldOffset(0)] public HardwareInput Hardware;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct MouseInput
        {
            public int Dx;
            public int Dy;
            public uint MouseData;
            public uint Flags;
            public uint Time;
            public nuint ExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KeyboardInput
        {
            public ushort VirtualKey;
            public ushort ScanCode;
            public uint Flags;
            public uint Time;
            public nuint ExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct HardwareInput
        {
            public uint Message;
            public ushort ParamLow;
            public ushort ParamHigh;
        }

        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint SendInput(uint inputCount, [In] Input[] inputs, int inputSize);

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    }
}

internal sealed class ClientSession : IAsyncDisposable
{
    private const string WebSocketGuid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    private readonly TcpClient _client;
    private readonly NetworkStream _stream;
    private readonly SemaphoreSlim _sendLock = new(1, 1);
    private WebSocket? _socket;
    private bool _disposed;

    public ClientSession(TcpClient client)
    {
        _client = client;
        _stream = client.GetStream();
    }

    public bool IsAuthenticated { get; private set; }

    public void SetAuthenticated() => IsAuthenticated = true;

    public async Task<Dictionary<string, string>> ReadHttpHeadersAsync(CancellationToken cancellationToken)
    {
        var bytes = new List<byte>(1024);
        var oneByte = new byte[1];
        while (bytes.Count < 8192)
        {
            var read = await _stream.ReadAsync(oneByte.AsMemory(), cancellationToken);
            if (read == 0) break;
            bytes.Add(oneByte[0]);
            var count = bytes.Count;
            if (count >= 4 && bytes[count - 4] == '\r' && bytes[count - 3] == '\n' && bytes[count - 2] == '\r' && bytes[count - 1] == '\n') break;
        }

        var text = Encoding.ASCII.GetString(bytes.ToArray());
        var lines = text.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);
        if (lines.Length == 0 || !lines[0].StartsWith("GET /ws ", StringComparison.Ordinal))
            throw new IOException("WebSocket /ws endpoint required.");
        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var line in lines.Skip(1))
        {
            var separator = line.IndexOf(':');
            if (separator <= 0) continue;
            headers[line[..separator].Trim()] = line[(separator + 1)..].Trim();
        }
        return headers;
    }

    public async Task AcceptWebSocketAsync(string key, CancellationToken cancellationToken)
    {
        var accept = Convert.ToBase64String(SHA1.HashData(Encoding.ASCII.GetBytes(key + WebSocketGuid)));
        var response = "HTTP/1.1 101 Switching Protocols\r\n" +
                       "Upgrade: websocket\r\n" +
                       "Connection: Upgrade\r\n" +
                       $"Sec-WebSocket-Accept: {accept}\r\n\r\n";
        await _stream.WriteAsync(Encoding.ASCII.GetBytes(response), cancellationToken);
        _socket = WebSocket.CreateFromStream(_stream, true, null, TimeSpan.FromSeconds(20));
    }

    public async Task SendObjectAsync(object value, CancellationToken cancellationToken)
    {
        var payload = JsonSerializer.SerializeToUtf8Bytes(value, value.GetType(), JsonOptionsForWire);
        await SendRawAsync(payload, cancellationToken);
    }

    private static readonly JsonSerializerOptions JsonOptionsForWire = new(JsonSerializerDefaults.Web);

    public async Task SendRawAsync(byte[] payload, CancellationToken cancellationToken)
    {
        if (_socket?.State != WebSocketState.Open) return;
        await _sendLock.WaitAsync(cancellationToken);
        try
        {
            if (_socket.State == WebSocketState.Open)
                await _socket.SendAsync(new ArraySegment<byte>(payload), WebSocketMessageType.Text, true, cancellationToken);
        }
        finally
        {
            _sendLock.Release();
        }
    }

    public async Task<JsonDocument?> ReceiveJsonAsync(CancellationToken cancellationToken)
    {
        if (_socket is null) return null;
        var buffer = new byte[8192];
        using var message = new MemoryStream();
        while (true)
        {
            var result = await _socket.ReceiveAsync(new ArraySegment<byte>(buffer), cancellationToken);
            if (result.MessageType == WebSocketMessageType.Close) return null;
            if (result.MessageType != WebSocketMessageType.Text) continue;
            message.Write(buffer, 0, result.Count);
            if (message.Length > 32 * 1024) throw new WebSocketException("WebSocket message exceeds 32 KB.");
            if (result.EndOfMessage) break;
        }
        return JsonDocument.Parse(message.ToArray());
    }

    public async Task SendHttpErrorAsync(string status, CancellationToken cancellationToken)
    {
        var response = $"HTTP/1.1 {status}\r\nConnection: close\r\nContent-Length: 0\r\n\r\n";
        await _stream.WriteAsync(Encoding.ASCII.GetBytes(response), cancellationToken);
    }

    public async Task CloseAsync(WebSocketCloseStatus status, string description, CancellationToken cancellationToken)
    {
        if (_socket?.State == WebSocketState.Open)
            await _socket.CloseAsync(status, description, cancellationToken);
    }

    public void Abort()
    {
        try { _socket?.Abort(); }
        catch (ObjectDisposedException) { }
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;
        if (_socket is not null)
        {
            try
            {
                if (_socket.State == WebSocketState.Open) await _socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "bridge client closed", CancellationToken.None);
            }
            catch (WebSocketException) { }
            _socket.Dispose();
        }
        _sendLock.Dispose();
        _stream.Dispose();
        _client.Dispose();
    }
}
