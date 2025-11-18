using LinkShare.API.Data;
using LinkShare.Worker;
using LinkShare.Worker.Services;
using Microsoft.EntityFrameworkCore;

var builder = Host.CreateApplicationBuilder(args);

// Add Database Context
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(connectionString));

// Add HttpClient for web scraping
builder.Services.AddHttpClient();

// Add Services
builder.Services.AddScoped<IWebScrapingService, WebScrapingService>();

// Add Worker
builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
