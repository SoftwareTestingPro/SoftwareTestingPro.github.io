Get-ChildItem -Path .\Automation\Advanced\*.html, .\Automation\Beginner\*.html, .\Automation\Intermediate\*.html | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $newContent = $content -replace 'href="\.\./assets/css/[^"]*"', 'href="../assets/css/styles.css"'
    Set-Content $_.FullName $newContent
}
