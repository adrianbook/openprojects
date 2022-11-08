 param([string]$Path)
 if ($Path -eq $null){
    $Path -eq '.'
 }
 
(type ($Path+'\README.md') -Head 10 | findstr node| Select-String -Pattern '(\d+\.\d+\.\d+)\s*$').Matches.Groups[1].Value > ($Path+'nodeversion.txt')