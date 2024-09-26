using namespace System.Management.Automation

$result = [PSCustomObject]@{
    minMajor = 0
    minMinor = 0
    maxMajor = 0
    maxMinor = 0
}


$hasExactResultMessage = "Success"
function GetHasNoExactMatchMessage
{
    param(
        [string]$currentVersion,
        [string]$expectedVersion
    )

    return "Current node version is: $currentVersion. Expected: $expectedVersion"
}


function ParseNodeVersion{
    param(
     [string]$packageJsonEnginesString,
     [string]$currentNodeVersion   
    )

    $result = [PSCustomObject]@{
        Match = $false
        NeededVersion = $null
        Message = $null
    }

    if ($packageJsonEnginesString -eq $null){
        $result.Message = "No node version specified for project. Consider adding it to package.json"
        return $result
    }

    if ($currentNodeVersion -eq $null){
        $result.Message = "No current node version provided. Check if nvm is installed?"
        return $result
    }

    [string]$cleanCurrentNodeVersionString = (RunSimpleRegex -pattern '([0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2})' -matchAgainst $currentNodeVersion).Output

    if ($cleanCurrentNodeVersionString -eq $null){
        $result.Message = "Failed to parse current node version string: $currentNodeVersion"
        return $result
    }


    $exactVersionRequired = RunSimpleRegex -pattern '^\s*([0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2})\s*$' -matchAgainst $packageJsonEnginesString

    if ($exactVersionRequired.Match){
        $result.Match = $cleanCurrentNodeVersionString -eq $exactVersionRequired.Output

        if (-not $result.Match){
            $result.Message = "`nCurrent node version is: $cleanCurrentNodeVersionString. Expected: $($exactVersionRequired.Output)"
            $result.NeededVersion = $exactVersionRequired.Output
        }

        return $result
    }

    $result.Message = "`nFailed to parse node version. Current version is: $currentNodeVersion package.json: $packageJsonEnginesString"
    return $result
}



function RunSimpleRegex
{
    param(
        [string]$matchAgainst,
        [string]$pattern
    )

    $result = [PSCustomObject]@{
        Match = $false
    }

    $match = Select-String -InputObject $matchAgainst -Pattern $pattern
    
    if ($match -eq $null){
        return $result
    } 

    if ($match.Matches[0].Groups.Count -eq 1){
        $result | Add-Member -MemberType NoteProperty -Name 'Output' -Value $match.Matches[0].Value
        $result.Match = $true
        return $result
    }

    if ($match.Matches[0].Groups.Count -gt 1){
        $matches = $match.Matches[0].Groups[1..($match.Matches[0].Groups.Count/1)]|%{$_.Value}

        $result | Add-Member -MemberType NoteProperty -Name 'Output' $matches
        $result.Match = $true
        return $result
    }

    return $result
}

function ParseExactVersion{
    param(
     [string]$packageJsonEnginesString,
     [string]$currentNodeVersion   
    )

    
}