$config = "debug"
$platform = "windows"
$arch = "x86"

$sourceDir = "src"
$mainSource = "$sourceDir\idl\main.d"
$outputDir = "bin\$config-$platform-$arch"
$outputFile = "$outputDir\IDL.dll"

$outdated = $false

if (Test-Path -Path $outputFile -PathType Leaf) {
	$outputFile = Get-Item -Path $outputFile
	$thisPath = Get-Item -Path $MyInvocation.MyCommand.Path
	if ($thisPath.LastWriteTime -gt $outputFile.LastWriteTime) {
		$outdated = $true
	}
	else {
		$files = Get-ChildItem -Recurse -Path $sourceDir
		foreach ($file in $files) {
			if ($file.LastWriteTime -gt $outputFile.LastWriteTime) {
				$outdated = $true
				break
			}
		}
	}
}
else {
	$outdated = $true
}

if ($outdated) {
	dmd -i -shared -m32mscoff -w -I"$sourceDir" "$mainSource" -of"$outputFile"
	if ($? -and [System.IO.Directory]::Exists("..\LF2.IDE\Assemblies\IDL")) {
		[System.IO.File]::Copy("$outputFile", "..\LF2.IDE\Assemblies\IDL\IDL.dll", $true)
	}
}
