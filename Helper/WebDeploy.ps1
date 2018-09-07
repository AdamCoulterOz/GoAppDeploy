function WebDeploy([string]$username,[string]$password,[string]$zipPath,[string]$appName)
{
    $pair = "$($username):$($password)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"

    $Headers = @{ Authorization = $basicAuthValue }

    Resolve-Path $zipPath # this is what you want to go into wwwroot

    # use kudu deploy from zip file
    Invoke-WebRequest -Uri https://$appName.scm.azurewebsites.net/api/zipdeploy -Headers $Headers `
        -InFile $zipPath -ContentType "multipart/form-data" -Method Post
}