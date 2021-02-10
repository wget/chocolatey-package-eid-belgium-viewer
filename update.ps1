import-module au

function global:au_BeforeUpdate {
    Get-RemoteFiles -Purge -NoSuffix 
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
function Get-VersionUrl($tags, $versionPatterns, $baseURLs, $filenamePatterns, $filenameArchPatterns) {
  foreach ($tag in $tags) {
    foreach ($versionPattern in $versionPatterns) {
      $version = $tag.Name -Replace $versionPattern
      foreach ($baseUrl in $baseUrls) {
        foreach ($filename in $filenamePatterns) {
          foreach ($archPattern in $filenameArchPatterns) {
            try {
              $baseUrl = $($baseUrl -Replace "\[VERSION\]","$version" -Replace "\[ARCH\]","$archPattern")
              $url = $($filename -Replace "\[VERSION\]","$version" -Replace "\[ARCH\]","$archPattern")
              $url = "$($baseUrl)$($url)"
              Write-Host "Checking: $url"
              Invoke-WebRequest -Uri $url -UseBasicParsing -DisableKeepAlive -Method HEAD | Out-Null
              $versionUrl = @{}
              $versionUrl.version = $version
              $versionUrl.url = $url
              return $versionUrl
            } catch [Net.WebException] {
            }
          }
        }
      }
    }
  }
  return $null
}

function global:au_GetLatest {

  $tagsUrl = "https://api.github.com/repos/fedict/eid-mw/tags"
  $releaseNotesFilenamePatterns = @(
    "rn[VERSION].pdf",
    "RN[version].pdf"
  )
  $releaseNotesVersionPatterns = @(
    '[^0-9.]',
    '[^0-9]'
  )
  $errorMessage = "[PREFIX]This shouldn't happen. Upstream has likely changed their URLs, manual intervention required."

  $url = "https://eid.belgium.be/en/download/41/license"
  $content = Invoke-WebRequest -Uri $url -UseBasicParsing
  foreach ($i in $content.Links.href) {
    if ($i.endswith("msi")) {
      [System.Uri]$viewerUrl = $i.trim()
      break;
    }
  }
  if (!$viewerUrl) {
    throw $errorMessage -Replace "\[PREFIX\]","The viewer URL was not found. "
  }
  
  $version = Split-Path $viewerUrl.LocalPath -leaf
  $version = ($version -Replace '[^0-9.]').trim('.')
  
  # Determine release notes URL
  $versionUrlReleaseNotes = Get-VersionUrl $tags $releaseNotesVersionPatterns $releaseNotesBaseUrls $releaseNotesFilenamePatterns @{}
  if (!$versionUrlReleaseNotes) {
    throw $errorMessage -Replace "\[PREFIX\]","The URL to the release notes was not found. "
  }

  return @{
    URL32 = $viewerUrl.AbsoluteUri
    Version = $version
    ReleaseNotes = $versionUrlReleaseNotes.url
  }
}

update -ChecksumFor none
