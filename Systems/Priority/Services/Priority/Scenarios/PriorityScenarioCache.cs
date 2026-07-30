using System.Collections.Concurrent;

namespace Maba.Api.Services.Priority.Scenarios;

/// <summary>
/// Process-lifetime cache of Priority lookups that rarely change, so repeated scenario
/// runs skip the resolution round-trips (calibrator id, main contact, dummy-device id).
/// Registered as a singleton. Values are cleared on restart; call <see cref="Clear"/> to
/// force a refresh (e.g. after a calibrator is added in Priority).
/// </summary>
public class PriorityScenarioCache
{
    private readonly ConcurrentDictionary<string, int> _calibratorIds = new();   // name → BUSERID
    private readonly ConcurrentDictionary<string, string> _mainContacts = new(); // customer → contact name
    private readonly ConcurrentDictionary<string, int> _deviceIds = new();       // serial → SERNUMBERS.SERN

    public bool TryGetCalibrator(string name, out int id) => _calibratorIds.TryGetValue(name, out id);
    public void SetCalibrator(string name, int id) => _calibratorIds[name] = id;

    public bool TryGetContact(string customer, out string contact) => _mainContacts.TryGetValue(customer, out contact!);
    public void SetContact(string customer, string contact) => _mainContacts[customer] = contact;

    public bool TryGetDeviceId(string serial, out int id) => _deviceIds.TryGetValue(serial, out id);
    public void SetDeviceId(string serial, int id) => _deviceIds[serial] = id;

    public void Clear()
    {
        _calibratorIds.Clear();
        _mainContacts.Clear();
        _deviceIds.Clear();
    }
}
