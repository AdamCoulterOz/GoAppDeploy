# GoAppDeploy

This project is provided to complete the Vibrato Go Test App deployment technical test.

## Architecure
The chosen cloud provider is Azure using the Azure PostgreSQL for the database and Azure App Services to host the Go App.

The deployment scripts rely on Azure ARM templates plus PowerShell to perform execution.

Azure App Services

## Approach

### Building Locally

Attempting to setup the project and compile the project locally intially was troublesome because I couldn't get the createdb command to run. Wasn't sure where the problem was and have never used or debugged Go code before. I setup a debugger (GoLand) and struggled to get it to hit my breakpoints. I then realised that Go apps fully quality all imports, which means any code in a folder will go to the gopath src folder version of it, ignoring my local clone. This seems to be odd, as I would only expect to reference external code this way, not within a project. Apparently Go doesnt support go files broken down into more than a single folder before you need to break it into multiple apps.

I figured out debugging a Go app and how it builds, etc including why dep ensure acts differently than go get. This allowed me to find where the createdb command was failing, which was because a connection to a PostgreSQL database requires specifying a default database otherwise you can't run scripts. No idea how anyone has managed to get updatedb to run before. Tom fixed it for me with the following commit:

https://github.com/vibrato/TechTestApp/pull/20/commits/fea0f139dc070e7187165d205419ea9adaae8412

Notice line 50 in db/db.go needed a default database specified, in this case just defaulting to the postgres db. Without this, the subsequent DROP and CREATE database queries completely fail. No sure how anyone else has passed this test before without finding this?

### Setup Custom Build

Initial approach attempted was to use a VSTS project with a custom GO build definition stored in YAML feeding a release pipeline to perform the deployment. I forked the TechTestApp to my own account, to have CI builds from it integrated with VSTS.

>**Super Hint:** Never try to fork a Go app on github, it can't reference its own local files as they are hardcoded to the original github account, took me a few hours to realise this. 
>*sigh*

My own custom build was initially needed as I had to modify the code in 2 ways:

1. Fix the afore mentioned bug
2. Change the create database query slightly to support Azure's PostgreSQL implementation:

    * Remove tablespace specification (disk managed for you by Azure)
    * Added template specification as template0 instead of template1, because Azure PostgreSQL has a template1 not compatible with en-US language (uses some newer type of language setting)
    * Removed database owner specification as Azure PostgreSQL requires a username with “@dbservername”, (which I specified in the toml file to connect with) but fails for internal PostgreSQL commands (needs it without the @db). Database creates default to the user connected anyway, so didn’t need to worry, could add some additional logic if it was a production system to make it more explicit.

Tom fixed the second problem for me by adding a switch to skip database creation/recreation when running updatedb. This allows the database infrastructure to be setup in separate scripts which may vary significantly between cloud PaaS solution (and is actually better).

I had actually gotten the stateless build agent installing go, setting up dep, compiling the app, and releasing as an artefact to the release pipeline, but oh well.

I was then left with choosing whether to continue to pursue using VSTS to do the Release pipeline on its own now I dont need to rebuilt the app myself. This approach would have required too much UI setup for the marker to configure their own VSTS account before importing build & release configurations, so abandoned it in favour of similar PS scripts which can have subscription credentials typed in.

I did lose the ability to have a continuous deployment pipeline by abandoning VSTS, but I've been at this a week now (around a full time job, annual performance processes, crazy home life, crazy health issues and no sleep...) and don't have time left to work more on this. Ideally I would use VSTS to manage all DevOps lifecycles with apps on Azure. There is so much out-of-the-box that you can do things in a few minutes.

## Deployment Code ... Finally

I have created this repo with the Azure ARM templates, and the PowerShell scripts needed to do the deployment.

Initially I was unsure how to deploy a Go app which has it's own listener daemon on Azure App Service Web Apps. Usually Azure Web Apps handle the hosting layer for you. I found a way to work around this by using the Microsoft IIS HttpPlatformHandler which is basically just requires you to specify a configuration file (web.config) which maps the Web App hosting to your listener endpoint, while retaining all the goodies of scaling on App Service Web Apps like security, load balancing, autoscaling, and automated management.

I have run into an issue though as the port the HttpPlatformHandler runs the wrapped service on is assigned arbitrarily at instantiation. Currently the Vibrto TechTestApp doesn't allow you to pass this as a runtime argument or specify it as a local environment variable (the 2 ways the HttpPlatformHandler supports passing this value). So I've raised a feature request to the Vibrato repo to add something like this, as it would probably be valuable for other hosting scenarios too.

https://github.com/vibrato/TechTestApp/issues/21

Artefacts in deployment:

1. **getLatestArtefact.ps1** - pulls the latest artefact from Vibrato's TechTestApp releases. I use the win64 version as I'm hosting on Azure App Service.
2. **web.config** - bootstraps custom listener daemons on Azure Web Apps - uses the IIS HttpPlatformHandler.
3. 
4. 



