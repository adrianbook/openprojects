
function openProjectsInDirectory {

    param([string]$Path)


    $dirPath = DisplayProjectDirectories $Path

    if ($dirPath -eq $null)
    {
        cd $Path
    }
    else 
    {
        OpenProjectInChosenDirectory $dirPath
    }
}

function DisplayProjectDirectories
{
    param([string]$Path)

    $children = get-childitem -Path $Path -Directory | where {(Get-ChildItem -Path $_.FullName -Hidden) -ne $null} 

    $paddingBase = 0

    foreach ($c in $children){
        if ($c.Name -match "%20"){
            $newName = $c.Name.Replace('%20', '')
            Move-Item -Path $c.FullName -Destination ($Path+'\'+$newName)
        }
        if ($c.Name.Length -gt $paddingBase){
            $paddingBase = $c.Name.Length
        }
    }
    $paddingBase += 3

    $children = get-childitem -Path $Path -Directory | where {(Get-ChildItem -Path $_.FullName -Hidden) -ne $null} 
    # "url\s+=\s+https?://(?:github\.com/([^/]+)/((?:.(?!git\s))+)|[^@]+@dev\.azure\.com/([^/]+)/([^/]+)/_git/(\w+))"

    foreach ($c in $children){
        
        $possiblePath = ($c.FullName+'\.git\config')

        if(Test-Path $possiblePath){
        # hitta regex som också fångar upp github
            $fetchHead = (get-content $possiblePath | Select-String -Pattern "^\s*url\s+=\s+https?://(?:github\.com/([^/]+)/(\S+)\.git|[^@]+@dev\.azure\.com/([^/]+)/([^/]+)/_git/(\w+)|([^\.]+)\.visualstudio.com/([^/]+)/_git/([^/]+))").Matches.Groups.Captures #| select {$_.Captures}   

            if ($fetchHead -ne $null -and $fetchHead.Count -gt 0){
                $st = ""
                for ($i = 1; $i -lt $fetchHead.Count; $i++){
                    $st += $fetchHead[$i]
                    if ($i -ne $fetchHead.Count - 1){
                        $st += ":"
                    }
                }

                $st = $st.Replace('%20', ' ')
                $padding = " " * ($paddingBase - $c.Name.Length)

                $propVal = "{0}{1}{2}" -f $c.Name,$padding, $st 
            }
            else {
                $remote_status = (get-content $possiblePath | Select-String -Pattern "url" -Quiet)
                if ($remote_status){
                    $remote_status = "git remote not parsed"
                }
                else {
                    $remote_status = "local repository"
                }

                $padding = " " * ($paddingBase - $c.Name.Length)
                $propVal = $c.Name + $padding + $remote_status
            }
        } else {
            $propVal = $c.Name
        }

        Add-Member -InputObject $c -NotePropertyName DisplayName -NotePropertyValue $propVal
    }
    
    


    $displayChildren = [ordered]@{}

    for ($i = 0; $i -lt $children.Length; $i++ ){
        $child = $children[$i]
        if ((Get-ChildItem -Path $child.FullName -Hidden) -ne $null) {
            $displayChildren.Add([char] ($i + 97), $child)
        }
    }

   

    $header = "PRESS   PROJECT{0}REMOTE" -f (" " * ($paddingBase - 7))
    Write-Host $header
    foreach ($k in $displayChildren.Keys) {
        $row = '  '+$k +" for " +  $displayChildren[$k].DisplayName
        Write-Host $row
    }

    $keypress = $Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character
    
    $chosenPath = $displayChildren[[char]$keypress].FullName


    return $chosenPath
}


function OpenProjectInChosenDirectory
{
    param([string]$Path)

    if ($Path -eq $null)
    {
        return
    }

   # cls

    cd $Path
    Write-Host $Path
    ($Path)+"`n>`n"

    checkGitStatus


    checkNodeVersion



    $openVS = queryOpenVisualStudio 

    $nodeadress = queryOpenVSCode
    $openVSCode = $nodeadress -ne $null

    if ($openVS.Item1)
    {
        foreach ($path in $openVS.Item2)
        {
            ii $path
        }
    }
    if ($openVSCode)
    {
        code $nodeadress
    }

}


function queryOpenVSCode
{
    $nodeadress = $null
    for ($i = 0; $i -lt 3 -and $nodeadress -eq $null; $i++)
    {
        $nodeadress =((Get-ChildItem -Recurse -Depth $i -File -Filter package.json).Directory).FullName
    }

    if ($nodeadress -ne $null){
       Write-Host "`nOpen Visual Studio Code? (y/n)"
        if (($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y')
        {
            return $nodeadress
        }
    }
    return $null
}

function queryOpenVisualStudio
{

    $VSPath = $null
    $sln = $null
    for ($i = 0; $i -lt 2 -and $sln -eq $null; $i++){
        $sln = Get-ChildItem -Path .\*  -File  -Recurse -Depth $i -Filter *.sln
    }
    if ($sln -eq $null){
        return [System.Tuple]::Create($false,"no solutions in directory")
    }
  

    if ($sln.Count -eq 1){
       # ii $sln
        Write-Host "`nOpen Visual Studio? (y/n)"
        $openVS = ($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'
        if ($openVS)
        {
            return [System.Tuple]::Create($true,$sln.FullName)
        }
    }

    elseif ($sln.Length -gt 1)
    {
        $paths = @()
        for ($i = 0; $i -lt $sln.Count; $i++)
        {
            $projName = ($sln[$i].Name|Select-String -Pattern '(.+)\.[^\.]+$').Matches[0].Groups[1].Value 
            $q ="`nOpen "+$projName+"? (y/n)"
            Write-Host $q
            $openVS = ($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'

            if ($openVS) {
                $paths += $sln[$i].FullName
                
            }
        }
        return [System.Tuple]::Create($true,$paths)
    }
    return [System.Tuple]::Create($false,”dont open visual studio”)
}


function checkGitStatus
{
     if ((Get-ChildItem -Path .\* -Hidden -Filter .git) -ne $null){
        $gitmessage = git status
        $gitmessage
        if ($gitmessage -match "^On branch ([m|M]ain|[m|M]aster)"){
            write-host  "`n`nIn main branch. Create new branch to work in? (y/n)"
            if(($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'){
                $branchname = Read-Host "Enter new branch name"
                git switch -c $branchname
            }
        }
    } else {
        write-host "Not a git repo. Make it one? (y/n)"
        if(($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'){
            git init
            Start-Sleep -Seconds .2
            git branch -m main
        }
    }
}

function checkNodeVersion
{
    $packageJsonPath = $null
    for ($i = 0;$i -lt 4; $i++)
    {
        $packageJsonPath = Get-ChildItem -Path .\* -File -Recurse -Depth $i -Filter 'package.json'
        if ($packageJsonPath -ne $null)
        {
            break
        }
    }

    if ($packageJsonPath -ne $null){
        $packageJson = cat $packageJsonPath.FullName | ConvertFrom-Json

        if ($packageJson.engines -eq $null -or $packageJson.engines.node -eq $null)
        {
            return
        }
    }

    $buildNodeVersion = $packageJson.engines.node
    $declaredNodeVersion
    if($buildNodeVersion -ne $null){
        $nodeMajorVersionRegex = '(\d+)\.\d+\.\d+\s*$'
        $currentNodeVersion = node -v 
        $currentNodeMajorVersion = ($currentNodeVersion | Select-String -Pattern $nodeMajorVersionRegex).Matches.Groups[1].Value
     
        $buildNodeMajorVersion = ($buildNodeVersion | Select-String -Pattern $nodeMajorVersionRegex).Matches.Groups[1].Value
  
        if ($buildNodeMajorVersion -ne $currentNodeMajorVersion ){
            Write-error "WARNING: project optimized for node version: $buildNodeVersion Currently running node version: $currentNodeVersion"
     
            "`nChange nodeversion? (y/n)"
            if (($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'){
                nvm use $buildNodeVersion
            }
        }
    }
}
#Export-ModuleMember -Function *