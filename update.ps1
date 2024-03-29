import-module au

function global:au_BeforeUpdate {
    # FileNameBase is made to override the name the gov specified with spaces.
    # We don't have to respecify the extension otherwise it will be added
    # twice as AU's Get-RemoteFiles function is already taking care of this.
    Get-RemoteFiles -Purge -NoSuffix -FileNameBase "eid-belgium-viewer"
}

function global:au_SearchReplace {
  @{
    ".\tools\chocolateyInstall.ps1" = @{
      "(?i)(^\s*file\s*=\s*`"[$]toolsDir\\).*" = "`${1}$($Latest.FileName32)`""
    }
    ".\legal\verification.txt" = @{
      "(?i)(32-Bit.+)\<.*\>" = "`${1}<$($Latest.URL32)>"
      "(?i)(checksum type:\s+).*" = "`${1}$($Latest.ChecksumType32)"
      "(?i)(checksum32:\s+).*" = "`${1}$($Latest.Checksum32)"
    }
    "eid-belgium-viewer.nuspec" = @{
      "\<(releaseNotes)\>.*\<\/releaseNotes\>" = "<`$1>$($Latest.ReleaseNotes)</`$1>"
    }
  }
}

function global:au_GetLatest {

  try {
    $64bitUrl = "https://eid.belgium.be/en/download/41/license"
    $64bitUrl = (Invoke-WebRequest $64bitUrl -UseBasicParsing).Links | Select -ExpandProperty href -Unique | Where-Object { $_ -like '*msi*' }

    $releaseNotesUrl = "https://eid.belgium.be/en/future-versions-eid-software-and-eid-viewer"
    $releaseNotesUrls = (Invoke-WebRequest $releaseNotesUrl -UseBasicParsing).Links | Select -ExpandProperty href | Where-Object { $_ -like '*pdf*' }

    # We may get several PDF with release notes. Just ask the server which one
    # is the latest by checking the Last-Modified HTTP header.
    $latestReleaseNote = ""
    $latestReleaseNoteUrl = ""
    foreach ($url in $releaseNotesUrls) {
      $url = "https://eid.belgium.be" + $url
      $result = Invoke-WebRequest -Method HEAD -Uri $url -UseBasicParsing
      $releaseNoteDate = Get-Date -Date $result.Headers."Last-Modified" -UFormat %s
      if ($releaseNoteDate -ge $latestReleaseNote) {
        $latestReleaseNote = $releaseNoteDate
        $latestReleaseNoteUrl = $url
      }
    }
  } catch {
    throw "Checking the URLs has failed. This shouldn't happen. Upstream has likely changed their URLs, manual intervention required."
  }

  $64bitVersion = (([uri]$64bitUrl).Segments[-1].Split('_')[-1].Trim('.msi') -Split '%20')[-1]

  return @{
    URL32 = $64bitUrl
    URL64 = $64bitUrl
    Version = $64bitVersion
    ReleaseNotes = $latestReleaseNoteUrl
  }
}

update -ChecksumFor none
