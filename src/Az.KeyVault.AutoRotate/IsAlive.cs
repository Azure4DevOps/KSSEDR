using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using System.ComponentModel;
using System.Reflection;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;
using Microsoft.OpenApi.Models;
using System.Net;

namespace Az.KeyVault.AutoRotate
{
    public static class IsAlive
    {
        public static readonly string ApplicationVersion = Assembly.GetExecutingAssembly().GetName().Version.ToString();

        [OpenApiOperation(operationId: "Run", tags: new[] { "name" })]
        [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "text/plain", bodyType: typeof(IsAliveContract), Description = "The OK response")]
        [FunctionName("IsAlive")]
        public static IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = null)] HttpRequest req, ILogger log)
        {
            var result = new IsAliveContract
            {
                isAlive = true,
                timestamp = DateTimeOffset.UtcNow,
                version = ApplicationVersion,
                regionName = Environment.GetEnvironmentVariable("REGION_NAME")
            };

            return new OkObjectResult(result);
        }

        [Description("Is Alive Contract")]
        public class IsAliveContract
        {
            [System.ComponentModel.DataAnnotations.Display(Description = "Version of Application")]
            public string version { get; set; }

            [System.ComponentModel.DataAnnotations.Display(Description = "TimeStamp")]
            public DateTimeOffset timestamp { get; set; }

            [System.ComponentModel.DataAnnotations.Display(Description = "Is Alive Value")]
            public bool isAlive { get; set; }

            [System.ComponentModel.DataAnnotations.Display(Description = "Region name")]
            public string regionName { get; set; }
        }
    }
}
