
function openProjectsInDirectory {

    param([string]$Path)


    $children = get-childitem -Path $Path -Directory | where {(Get-ChildItem -Path $_.FullName -Hidden) -ne $null} 



    foreach ($c in $children){
        
        $possiblePath = ($c.FullName+'\.git\FETCH_HEAD')
        if(Test-Path $possiblePath){
            $fetchHead = (get-content $possiblePath  | select -First 1 | Select-String -Pattern "([^/]+)$").Matches[0].Value
            $propVal = "{0}:    {1}" -f $c.Name, $fetchHead 
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

   

    "PRESS:"
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
    
    $VS = $null
    $sln = Get-ChildItem -Path .\* -Include *.sln
    if ($sln.Length -ne 0){
       # ii $sln
        "`nOpen Visual Studio? (y/n)"
        $VS = ($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'
    }

    $VSCode = $null
    $nodeadress = $null
    $isnode = (Get-ChildItem -File -Filter package.json) -ne $null
    if ($isnode) {
        #code .
        $nodeadress = '.'
        "`nOpen Visual Studio Code? (y/n)"
        $VSCode = ($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'
        
    }
    
    if ($nodeadress -eq $null){
        $childdirs = (Get-ChildItem -Path .\*  -Exclude node_modules).FullName
       # $childdirs
        foreach ($dir in $childdirs){
            $nodeadress = ((Get-ChildItem -Path $dir -File -Filter package.json ).Directory).FullName
            if ($nodeadress -ne $null) {
                #code $nodeadress
                "`nOpen Visual Studio Code? (y/n)"
                $VSCode = ($Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho').Character) -eq [char]'y'
                break
            }
        }
    }

    if ($VS){
        ii $sln
    }
    if ($VSCode){
        code $nodeadress
    }
}

#Export-ModuleMember -Function *