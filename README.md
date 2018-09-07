# GoAppDeploy

This project is provided to complete the Vibrato Go Test App deployment technical test.

## Architecure
The chosen cloud provider is Azure using:
 
 * Azure Database for PostgreSQL to host the database
 * Azure App Services to host the Go App

Azure Database for PostgreSQL and App Services both provide high-availability and scaling. I've selected the cheapest / free implementations of both for this template, but can be upgraded to auto-scale and have location redundancy by modifying some of the values in the Template Parameters file.

The deployment scripts rely on Azure ARM templates plus PowerShell to perform execution. The PowerShell can be executed on Windows, macOS or Linux by using just the AzureRM.NetCore library and built-in PowerShell Core 6 modules.

Please install PowerShell Core 6.0+ and the AzureRM.NetCore library before running the deployment script. PowerShell Core can be installed using the following instructions:

* [Windows (choco)](https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-powershell-core-on-windows?view=powershell-6)
* [macOS (brew)](https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-powershell-core-on-macos?view=powershell-6)
* [Linux (apt/yum/zypper/dnf)](https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-powershell-core-on-linux?view=powershell-6)

Then install the AzureRM.Core PowerShell module from a PWSH command prompt using the following command:

```powershell
Install-Module AzureRM.NetCore
```

To run the app deployment, git clone this repo to your deployment machine and execute the following command from the root project folder context (obviously with your target sub-id):

```powershell
.\deploy.ps1 -subscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

The main deploy script (**deploy.ps1**) orchestrates the provisioning and deployment end-to-end. It goes through the following steps:
1. **Parameter Initialisation** - Defaults provided for everything except for the subscription-id which must be provided explicitly.
2. **Host OS Validation** - Check the OS the script is running on to get the right GO App binary from GitHub.
3. **Azure Template Deployment** - Login to Azure - follow instructions in console. It then triggers an ARM group deployment using the template in the Template folder. Template sets up application settings used  to configure the go app (overrides the toml file using the web.config in the next step).
4. **Create Deployment Package** - Determines latest GO App release in the Vibrato TechTestApp releases and downloads the appropriate binaries. Copies over the web.config for execution of the go app as an Azure Web App.
5. **Deploy Package** - Download the provisioning profile and use WebDeploy to deploy the package
6. **Initialise Database** - Get the Vibrato Go App binary for current platform (determined in step 2) if not win64, then run with the updatedb -s command.
7. **Startup & Test** - Restarts the web app with new config and checks the app is running correctly by running the healthcheck page.

Some helper scripts support generic functions:

* **GitHubArtefacts.ps1** pulls the latest artefact from Vibrato's TechTestApp releases. I use the win64 version as I'm hosting on Azure App Service.
* **GeneratePassword.ps1** creates a password for the PostgreSQL database user with enough complexity.
* **WebDeploy.ps1** provides a simple mechanism to deploy the web app package.

Additional configuration had to be defined to run a GO app binary inside web app, due to it having a custom listener:
* **web.config** - bootstraps custom listener daemons on Azure Web Apps - uses the IIS HttpPlatformHandler.


## Approach

### Building Locally

Attempting to setup the project and compile the project locally initially was troublesome because I couldn't get the createdb command to run. Wasn't sure where the problem was and have never used or debugged Go code before. I setup a debugger (GoLand) and struggled to get it to hit my breakpoints. I then realised that Go apps fully quality all imports, which means any code in a folder will go to the gopath src folder version of it, ignoring my local clone. This seems to be odd, as I would only expect to reference external code this way, not within a project. Apparently Go doesn't support go files broken down into more than a single folder before you need to break it into multiple apps.

I figured out debugging a Go app and how it builds, etc including why dep ensure acts differently than go get. This allowed me to find where the createdb command was failing, which was because a connection to a PostgreSQL database requires specifying a default database otherwise you can't run scripts. No idea how anyone has managed to get updatedb to run before. Tom fixed it for me with the following commit:

https://github.com/vibrato/TechTestApp/pull/20/commits/fea0f139dc070e7187165d205419ea9adaae8412

Notice line 50 in db/db.go needed a default database specified, in this case just defaulting to the postgreSQL db. Without this, the subsequent DROP and CREATE database queries completely fail. No sure how anyone else has passed this test before without finding this?

### Setup Custom Build

Initial approach attempted was to use a VSTS project with a custom GO build definition stored in YAML feeding a release pipeline to perform the deployment. I forked the TechTestApp to my own account, to have CI builds from it integrated with VSTS.

>**Super Hint:** Never try to fork a Go app on github, it can't reference its own local files as they are hard-coded to the original github account, took me a few hours to realise this. 
>*sigh*

My own custom build was initially needed as I had to modify the code in 2 ways:

1. Fix the afore mentioned bug
2. Change the create database query slightly to support Azure's PostgreSQL implementation:

    * Remove tablespace specification (disk managed for you by Azure)
    * Added template specification as template0 instead of template1, because Azure PostgreSQL has a template1 not compatible with en-US language (uses some newer type of language setting)
    * Removed database owner specification as Azure PostgreSQL requires a username with “@dbservername”, (which I specified in the toml file to connect with) but fails for internal PostgreSQL commands (needs it without the @db). Database creates default to the user connected anyway, so didn’t need to worry, could add some additional logic if it was a production system to make it more explicit.

Tom fixed the second problem for me by adding a switch to skip database creation/recreation when running updatedb. This allows the database infrastructure to be setup in separate scripts which may vary significantly between cloud PaaS solution (and is actually better).

https://github.com/vibrato/TechTestApp/issues/19

I had actually gotten the stateless build agent installing go, setting up dep, compiling the app, and releasing as an artefact to the release pipeline, but oh well.

I was then left with choosing whether to continue to pursue using VSTS to do the Release pipeline on its own now I dont need to rebuilt the app myself. This approach would have required too much UI setup for the marker to configure their own VSTS account before importing build & release configurations, so abandoned it in favour of simpler PS scripts which can have subscription credentials typed in. 

I did lose the ability to have a continuous deployment pipeline by abandoning VSTS, but I've been at this a week now (around a full time job, annual performance processes, crazy home life, crazy health issues and no sleep...) and don't have time left to work more on this. Ideally I would use VSTS to manage all DevOps life-cycles with apps on Azure. There is so much out-of-the-box that you can do things in a few minutes.

While I was investigating the VSTS option, I realised the VSTS GO App build definition template didn't quite work either, as it both didn't support DEP and didn't clone the repo into the right structure for the GOPATH. I raised an issue with Microsoft, discussed the problem and how to fix it. They are implementing a fix for it: 

https://github.com/MicrosoftDocs/vsts-docs/issues/1527

### Deployment Code ... Finally

I have created this repo with the Azure ARM templates, and the PowerShell scripts needed to do the deployment.

Initially I was unsure how to deploy a Go app which has it's own listener daemon on Azure App Service Web Apps. Usually Azure Web Apps handle the hosting layer for you. I found a way to work around this by using the Microsoft IIS HttpPlatformHandler which is basically just requires you to specify a configuration file (web.config) which maps the Web App hosting to your listener endpoint, while retaining all the goodies of scaling on App Service Web Apps like security, load balancing, autoscaling, and automated management.

I ran into an issue where the port the HttpPlatformHandler assigns the wrapped service is assigned arbitrarily at instantiation. At the time the Vibrato TechTestApp didn't allow you to pass this as a runtime argument or specify it as a local environment variable (the 2 ways the HttpPlatformHandler supports passing this value). I raised a feature request to the Vibrato repo to add something like this, as it would probably be valuable for other hosting scenarios too. This was implemented under the following feature request:

https://github.com/vibrato/TechTestApp/issues/21

Problem number ... 7? Found a bug with the HttpPlatformHandler now. When mapping environment variables it [adds random whitespace](https://social.msdn.microsoft.com/Forums/windowsserver/en-US/f34dfb44-b67d-46b9-8401-1eb5a2aafcda/unnecessary-space-is-attached-to-the-expansion-result-of-httpplatformport?forum=windowsazurewebsitespreview) to the end of the value.... this causes the go app to fail :-/ I can't win. I worked around it by getting user input cleaning added to the app:

https://github.com/vibrato/TechTestApp/issues/23

### Azure ARM Templates

I started by generating my initial template by going through the Azure Portal and configuring an Azure Web App + Azure Database for PostgreSQL deployment, and selecting to export the template. This was very basic and I had to almost re-write the whole thing. 

I was working on Windows at the time with AzureRM for Windows, but wanted to move to my Mac. I refactored the PowerShell script to use AzureRM.Core so it would be cross platform supported and setup a VS Code project running on macOS. I got a bit side tracked as I've only ever built in Visual Studio before and ended up learning how VS Code works, including the plugin and debug support for .NET core / PowerShell.

I spent an enormous amount of time figuring out the cleanest way to create the database instance (as I couldnt use the GO app as it's implementation of updatedb wasn't compatible with Azure PostgreSQL due to trying to Issue 19). I went as far as to setup ODBC drivers and other PowerShell modules trying to make it easy to install. I then realised I could define an additional resource in the ARM template which would create the database for me too. Score.

### Deployment of Code

Now the ARM template was working perfectly, I just needed to to deploy the code. I thought this would be easy using FTP, but seems not. Microsoft's FTP service for code deployment randomly "not logged in" errors inconsistently. I couldn't figure out the source of the problem even after changing the implementation to 3 different libraries. I gave up and found a new way to do it using the ZipDeploy API which is significantly more stable.

### Database Initialisation

I was very thoughtful about this, I couldn't run the GoApp "updatedb -s" command from the website itself as it would create a race condition when there are multiple nodes. I also didn't want to run it locally as then I would need to potentially get a different version of the GO binary based on what platform I was executing from. In the end there wasn't an easy way around it so I run it it locally by downloading the additional binary for mac or linux if the script is not running on Windows. 

I then found that the .NET CORE implementation of unzip doesn't retain file permissions (like execute), apparently by design, so had to add a chmod line for Linux and macOS to add execution permissions on the go binary.

I then found that the securestring implementation doesn't support ConvertFrom-SecureString on macOS and linux also. I've spent too long on this already, so just allowed the generated database password to stay as a plain string in this script. For a production project this wouldnt be an issue as I would expect to be using something like VSTS which has secrets management built-in.