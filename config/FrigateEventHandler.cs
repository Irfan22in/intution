using System;
using System.Net.Http;
using System.Threading.Tasks;
using UAManagedCore;
using OpcUa = UAManagedCore.OpcUa;
using FTOptix.HMIProject;
using FTOptix.NetLogic;
using FTOptix.UI;
using FTOptix.CoreBase;
using FTOptix.WebUI;
using Newtonsoft.Json.Linq;
using System.Linq;

public class FrigateEventHandler : BaseNetLogic
{
    private static readonly HttpClient httpClient = new HttpClient();
    private const string FRIGATE_HOST = "http://192.168.1.100:5000"; // Change to your Frigate IP
    private const string CAMERA_NAME = "camera1";
    
    private IUAVariable eventActiveTag;
    private IUAVariable eventIdVariable;
    private IUAVariable eventClipUrlVariable;
    private IUAVariable eventThumbnailUrlVariable;
    private PeriodicTask periodicTask;

    public override void Start()
    {
        eventActiveTag = Project.Current.GetVariable("Model/EventActive");
        eventIdVariable = Project.Current.GetVariable("Model/LastEventId");
        eventClipUrlVariable = Project.Current.GetVariable("Model/EventClipUrl");
        eventThumbnailUrlVariable = Project.Current.GetVariable("Model/EventThumbnailUrl");
        periodicTask = new PeriodicTask(CheckForEvents, 500, LogicObject);
        periodicTask.Start();
    }

    public override void Stop()
    {
        periodicTask?.Dispose();
        periodicTask = null;
    }

    private void CheckForEvents()
    {
        bool isEventActive = eventActiveTag.Value;
        if (isEventActive)
        {
            Task.Run(async () => await GetLatestFrigateEvent());
        }
    }

    private async Task GetLatestFrigateEvent()
    {
        try
        {
            string apiUrl = $"{FRIGATE_HOST}/api/events?camera={CAMERA_NAME}&limit=1&has_clip=true";
            HttpResponseMessage response = await httpClient.GetAsync(apiUrl);
            if (response.IsSuccessStatusCode)
            {
                string jsonContent = await response.Content.ReadAsStringAsync();
                JArray events = JArray.Parse(jsonContent);
                if (events.Count > 0)
                {
                    JObject latestEvent = (JObject)events[0];
                    string eventId = latestEvent["id"].ToString();
                    bool hasClip = latestEvent["has_clip"]?.Value<bool>() ?? false;
                    eventIdVariable.Value = eventId;
                    if (hasClip)
                    {
                        string clipUrl = $"{FRIGATE_HOST}/api/events/{eventId}/clip.mp4";
                        string thumbnailUrl = $"{FRIGATE_HOST}/api/events/{eventId}/thumbnail.jpg";
                        eventClipUrlVariable.Value = clipUrl;
                        eventThumbnailUrlVariable.Value = thumbnailUrl;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Log.Error("FrigateEventHandler", $"Error getting event: {ex.Message}");
        }
    }

    [ExportMethod]
    public void PlayEventClip()
    {
        string clipUrl = eventClipUrlVariable.Value;
        if (!string.IsNullOrEmpty(clipUrl))
        {
            Log.Info($"Playing clip: {clipUrl}");
        }
        else
        {
            Log.Warning("No event clip available");
        }
    }
    
    [ExportMethod]
    public async Task<string> GetEventClipByTime(DateTime startTime, DateTime endTime)
    {
        try
        {
            long startTimestamp = new DateTimeOffset(startTime).ToUnixTimeSeconds();
            long endTimestamp = new DateTimeOffset(endTime).ToUnixTimeSeconds();
            string apiUrl = $"{FRIGATE_HOST}/api/events?camera={CAMERA_NAME}&after={startTimestamp}&before={endTimestamp}&has_clip=true";
            HttpResponseMessage response = await httpClient.GetAsync(apiUrl);
            if (response.IsSuccessStatusCode)
            {
                string jsonContent = await response.Content.ReadAsStringAsync();
                JArray events = JArray.Parse(jsonContent);
                if (events.Count > 0)
                {
                    JObject firstEvent = (JObject)events[0];
                    string eventId = firstEvent["id"].ToString();
                    return $"{FRIGATE_HOST}/api/events/{eventId}/clip.mp4";
                }
            }
            return null;
        }
        catch (Exception ex)
        {
            Log.Error("FrigateEventHandler", $"Error: {ex.Message}");
            return null;
        }
    }
}
