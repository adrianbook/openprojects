
function openProjectsInDirectory {

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


    foreach ($c in $children){
        
        $possiblePath = ($c.FullName+'\.git\FETCH_HEAD')
        if(Test-Path $possiblePath){
            $fetchHead = (get-content $possiblePath  | select -First 1 | Select-String -Pattern "/([^/])+/_git/([^/])+$").Matches.Groups #| select {$_.Captures}   
           
            $st = ""
            foreach ($row in $fetchHead[1].Captures){
                $st += $row.Value
            }
            $st += ': '
            foreach ($row in $fetchHead[2].Captures){
                $st += $row.Value
            }
            $st = $st.Replace('%20', ' ')
            $padding = " " * ($paddingBase - $c.Name.Length)

            $propVal = "{0}{1}{2}" -f $c.Name,$padding, $st 
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

   

    "PRESS   PROJECT{0}REMOTE" -f (" " * ($paddingBase - 7))
    foreach ($k in $displayChildren.Keys) {
            '  '+$k +" for " +  $displayChildren[$k].DisplayName
    }

    $keypress = $Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character
    $subpath = $displayChildren[[char]$keypress].Name
    
    if ($subpath -eq $null) {
        cd $Path
        return
    }
    cls
    $fullpath = "{0}\{1}" -f $Path, $subpath
    cd $fullpath
    ($fullpath)+">`n"
    if ((Get-ChildItem -Path .\* -Hidden -Filter .git) -ne $null){
        $gitmessage = git status
        $gitmessage
        if ($gitmessage -match "^On branch (main|master)"){
            "`n`nIn main branch. Create new branch to work in? (y/n)"
            if(($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'){
                $branchname = Read-Host "Enter new branch name"
                git switch -c $branchname
            }
        }
    } else {
        "Not a git repo. Make it one? (y/n)"
        if(($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'){
            git init
            Start-Sleep -Seconds .2
            git branch -m main
        }
    }

    $declaredNodeVersion = Get-ChildItem -Path .\* -File -Recurse -Depth 2 -Filter 'nodeversion.txt'
    if($declaredNodeVersion -ne $null){
        $nodeMajorVersionRegex = '(\d+)\.\d+\.\d+\s*$'
        $currentNodeVersion = node -v 
        $currentNodeMajorVersion = ($currentNodeVersion | Select-String -Pattern $nodeMajorVersionRegex).Matches.Groups[1].Value

        $buildNodeVersion = cat $declaredNodeVersion.FullName 
        $buildNodeMajorVersion = ($buildNodeVersion | Select-String -Pattern $nodeMajorVersionRegex).Matches.Groups[1].Value

        if ($buildNodeVersion -ne $null -and $buildNodeMajorVersion -ne $currentNodeMajorVersion ){
            Write-error "WARNING: project optimized for node version: $buildNodeVersion Currently running node version: $currentNodeVersion"
        }
        "`nChange nodeversion? (y/n)"
        if (($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'){
            nvm use $buildNodeVersion
        }
    }

    $VS = $null
    $sln = Get-ChildItem -Path .\* -Include *.sln
    if ($sln.Length -ne 0){
       # ii $sln
        "`nOpen Visual Studio? (y/n)"
        $VS = ($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'
    }

    $VSCode = $null
    $nodeadress = ((Get-ChildItem -File -Filter package.json).Directory).FullName
    if ($nodeadress -eq $null){
        $nodeadress = ((Get-ChildItem -Recurse -Depth 2 -File -Filter package.json).Directory).FullName
    }

    if ($nodeadress -ne $null){
       "`nOpen Visual Studio Code? (y/n)"
        $VSCode = ($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'    
    }

    if ($VS){
        ii $sln
    }
    if ($VSCode){
        code $nodeadress
    }
}

#Export-ModuleMember -Function *