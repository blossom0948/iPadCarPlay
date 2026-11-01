using System.Text.Json;

internal sealed class ControlMap
{
    private static readonly string[] AllowedNames =
    [
        "horn", "lights.toggle", "wipers.toggle", "parkingBrake.toggle", "engine.toggle",
        "gear.up", "gear.down", "engineBrake.toggle", "retarder.up", "retarder.down",
        "cruise.toggle", "camera.next"
    ];

    private readonly Dictionary<string, ushort> _keys;

    private ControlMap(Dictionary<string, ushort> keys) => _keys = keys;

    public IEnumerable<string> EnabledControls => _keys.Keys.Order(StringComparer.Ordinal);

    public static ControlMap Load(string path)
    {
        Dictionary<string, string> configured;
        try
        {
            configured = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(path))
                         ?? new Dictionary<string, string>();
        }
        catch (FileNotFoundException)
        {
            configured = new Dictionary<string, string>();
        }
        catch (JsonException exception)
        {
            Console.WriteLine($"controls.json 형식 오류: {exception.Message}");
            configured = new Dictionary<string, string>();
        }

        var parsed = new Dictionary<string, ushort>(StringComparer.Ordinal);
        foreach (var pair in configured)
        {
            if (!AllowedNames.Contains(pair.Key, StringComparer.Ordinal)) continue;
            if (pair.Value.Equals("NONE", StringComparison.OrdinalIgnoreCase)) continue;
            if (TryParseVirtualKey(pair.Value, out var key)) parsed[pair.Key] = key;
            else Console.WriteLine($"키를 해석할 수 없습니다: {pair.Key} = {pair.Value}");
        }
        return new ControlMap(parsed);
    }

    public bool TryGetKey(string name, out ushort virtualKey) => _keys.TryGetValue(name, out virtualKey);

    private static bool TryParseVirtualKey(string value, out ushort virtualKey)
    {
        var key = value.Trim().ToUpperInvariant();
        if (key.Length == 1 && key[0] is >= 'A' and <= 'Z')
        {
            virtualKey = key[0];
            return true;
        }
        if (key.Length == 1 && key[0] is >= '0' and <= '9')
        {
            virtualKey = key[0];
            return true;
        }
        virtualKey = key switch
        {
            "SPACE" => 0x20,
            "ENTER" => 0x0D,
            "ESC" => 0x1B,
            "TAB" => 0x09,
            "UP" => 0x26,
            "DOWN" => 0x28,
            "LEFT" => 0x25,
            "RIGHT" => 0x27,
            "F1" => 0x70, "F2" => 0x71, "F3" => 0x72, "F4" => 0x73,
            "F5" => 0x74, "F6" => 0x75, "F7" => 0x76, "F8" => 0x77,
            "F9" => 0x78, "F10" => 0x79, "F11" => 0x7A, "F12" => 0x7B,
            _ => 0
        };
        return virtualKey != 0;
    }
}
