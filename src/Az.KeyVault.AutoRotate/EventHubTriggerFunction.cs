using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Azure.Identity;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.Management.Storage;
using Microsoft.Rest.Azure.Authentication;
using Azure.Security.KeyVault.Secrets;
using Newtonsoft.Json;
using System.Text;
using Microsoft.IdentityModel.Protocols;

namespace Az.KeyVault.AutoRotate
{
    public static class EventHubTriggerFunction
    {
        public class EventData2
        {
            public string Id { get; set; }
            public string VaultName { get; set; }
            public string ObjectType { get; set; }
            public string ObjectName { get; set; }
            public string Version { get; set; }
            public string NBF { get; set; }
            public string EXP { get; set; }
        }

        public class Event
        {
            public string Id { get; set; }
            public string Source { get; set; }
            public string Subject { get; set; }
            public string Type { get; set; }
            public DateTime Time { get; set; }
            public EventData2 Data { get; set; }
            public string SpecVersion { get; set; }
        }

        [FunctionName("EventHubTriggerFunction")]
        public static async Task Run([EventHubTrigger("rotate-dev-euw-eventhubname", Connection = "EventHub.ConnectionString")] EventData[] events, ILogger log)
        {
            log.LogInformation(events.ToString());

            var exceptions = new List<Exception>();

            foreach (EventData eventData in events)
            {
                try
                {
                    log.LogInformation($"C# Event Hub trigger function processed a message: {eventData}");
                    log.LogInformation($"C# Event Hub trigger function processed a message: {eventData.EventBody}");


                    string json = Encoding.UTF8.GetString(eventData.EventBody);
                    List<Event> eventaaa = JsonConvert.DeserializeObject<List<Event>>(json);

                    Event eventObject = eventaaa[0];

                    var split = eventObject.Source.Split('/');
                    string subscription = split[2];
                    string resourceGroup = split[4];
                    string vault = split[8];

                    string secretName = eventObject.Data.ObjectName;

                    string keyVaultUrl = $"https://{vault}.vault.azure.net/";

                    string tenantId = Environment.GetEnvironmentVariable("tenantId");
                    string clientId = Environment.GetEnvironmentVariable("clientId");
                    string clientSecret = Environment.GetEnvironmentVariable("clientSecret");


                    //use clientId and secret
                    var credential = new ClientSecretCredential(tenantId, clientId, clientSecret);
                    var clientkv = new SecretClient(new Uri(keyVaultUrl), credential);

                    //or use
                    //use Managed Identity or user managed Identity
                    //var clientkv = new SecretClient(new Uri(keyVaultUrl), new DefaultAzureCredential());


                    KeyVaultSecret currentSecret = clientkv.GetSecretAsync(secretName).Result;

                    string orgin = currentSecret.Properties.ContentType;
                    var splitOrgin = orgin.Split('/');
                    string subscriptionOrgin = splitOrgin[2];
                    string resourceGroupOrgin = splitOrgin[4];
                    string providerOrgin = splitOrgin[6];//Microsoft.Storage
                    string storageAccountsOrgin = splitOrgin[7];//storageAccounts
                    string storageAccountOrgin = splitOrgin[8];//rotateexamdeveuw
                    //currentSecret.Properties.Tags

                    if (providerOrgin == "Microsoft.Storage")
                    {
                        var serviceCreds = await ApplicationTokenProvider.LoginSilentAsync(tenantId, clientId, clientSecret);
                        var storageClient = new StorageManagementClient(serviceCreds) { SubscriptionId = subscriptionOrgin };

                        var keys = await storageClient.StorageAccounts.ListKeysAsync(resourceGroupOrgin, storageAccountOrgin);
                        var newkey = storageClient.StorageAccounts.RegenerateKeyAsync(resourceGroupOrgin, storageAccountOrgin, "key1").Result;


                        DateTimeOffset expirationDate = DateTimeOffset.UtcNow.AddMinutes(120);

                        var secretValue = newkey.Keys[0].Value;

                        var secret = new KeyVaultSecret(secretName, secretValue);

                        secret.Properties.ExpiresOn = expirationDate;
                        secret.Properties.ContentType = currentSecret.Properties.ContentType;
                        secret.Properties.Tags.Add("AutoRotate", DateTime.Now.ToString());
                        await clientkv.SetSecretAsync(secret);
                    }

                    await Task.Yield();
                }
                catch (Exception e)
                {
                    log.LogError(e.Message);
                    exceptions.Add(e);
                }
            }

            if (exceptions.Count > 1)
                throw new AggregateException(exceptions);

            if (exceptions.Count == 1)
                throw exceptions.Single();
        }
    }
}
