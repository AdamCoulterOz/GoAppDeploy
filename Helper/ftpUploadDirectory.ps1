
param(
  [string]
  $FTPHost,
  [System.Net.NetworkCredential]
  $NetworkCredential,
  [string]
  $SourceFolder
)

$webclient = New-Object System.Net.WebClient
$webclient.Credentials = $NetworkCredential

$SrcEntries = Get-ChildItem $SourceFolder -Recurse
$Srcfolders = $SrcEntries | Where-Object{$_.PSIsContainer}
$SrcFiles = $SrcEntries | Where-Object{!$_.PSIsContainer}

# Create Folders If Needed
foreach($folder in $Srcfolders)
{
    $SrcFolderPath = $SourceFolder  -replace "\\","\\" -replace "\:","\:"
    $DesFolder = $folder.Fullname -replace $SrcFolderPath,$FTPHost
    $DesFolder = $DesFolder -replace "\\", "/"
    # Write-Output $DesFolder

    try
    {
        $makeDirectory = [System.Net.WebRequest]::Create($DesFolder);
        $makeDirectory.Credentials = $NetworkCredential
        $makeDirectory.Method = [System.Net.WebRequestMethods+FTP]::MakeDirectory;
        $makeDirectory.GetResponse();
        #folder created successfully
    }
    catch [Net.WebException]
    {
        try
        {
            #if there was an error returned, check if folder already exists on server
            $checkDirectory = [System.Net.WebRequest]::Create($DesFolder);
            $checkDirectory.Credentials = $NetworkCredential
            $checkDirectory.Method = [System.Net.WebRequestMethods+FTP]::PrintWorkingDirectory;
            $response = $checkDirectory.GetResponse();
            #folder already exists
        }
        catch [Net.WebException]
        {
            #some other error has occured
        }
    }
}

# Upload Files to correct folders
foreach($entry in $SrcFiles)
{
    $SrcFullname = $entry.fullname
    $SrcName = $entry.Name
    $SrcFilePath = $SourceFolder -replace "\\","\\" -replace "\:","\:"
    $DesFile = $SrcFullname -replace $SrcFilePath,$FTPHost
    $DesFile = $DesFile -replace "\\", "/"
    Write-Output "Destination: $DesFile"

    $uri = New-Object System.Uri($DesFile)
    #Write-Output $uri
    Write-Output "Source: $SrcFullname"
    Write-Output $webclient.UploadFile($uri, $SrcFullname)
}
