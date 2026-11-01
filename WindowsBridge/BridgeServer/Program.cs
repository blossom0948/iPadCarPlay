using System.Net;
using System.Net.NetworkInformation;

var port = 8765;
if (int.TryParse(Environment.GetEnvironmentVariable("ETS2CP_PORT"), out var configuredPort) && configuredPort is > 0 and <= 65535)
{
    port = configuredPort;
}

var controlsPath = Path.Combine(AppContext.BaseDirectory, "controls.json");
var controlMap = ControlMap.Load(controlsPath);
await using var host = new BridgeHost(port, controlMap);

Console.WriteLine("ETS2 CarPlay Windows Bridge");
Console.WriteLine($"WebSocket: ws://<이 PC의 IP>:{port}/ws");
Console.WriteLine("ETS2 telemetry UDP: 127.0.0.1:8766");
Console.WriteLine($"iPad 페어링 코드(한 번 사용): {host.PairingCode}");
Console.WriteLine("같은 신뢰할 수 있는 Wi-Fi에서만 연결하고, 인터넷으로 포트를 열지 마세요.");
Console.WriteLine("등록된 조작 키: " + string.Join(", ", controlMap.EnabledControls));
foreach (var address in GetLocalIPv4Addresses()) Console.WriteLine($"PC 주소: {address}");
Console.WriteLine("종료하려면 Ctrl+C를 누르세요.");

using var cancellation = new CancellationTokenSource();
Console.CancelKeyPress += (_, eventArgs) =>
{
    eventArgs.Cancel = true;
    cancellation.Cancel();
};

await host.RunAsync(cancellation.Token);

static IEnumerable<IPAddress> GetLocalIPv4Addresses() =>
    NetworkInterface.GetAllNetworkInterfaces()
        .Where(adapter => adapter.OperationalStatus == OperationalStatus.Up &&
                          adapter.NetworkInterfaceType != NetworkInterfaceType.Loopback)
        .SelectMany(adapter => adapter.GetIPProperties().UnicastAddresses)
        .Where(address => address.Address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
        .Select(address => address.Address);
