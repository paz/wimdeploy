Add-Type -AssemblyName PresentationFramework
$BaseDir = "N:\Images\WIMs\"
$xamlFile = ".\MainWindow.xaml"
$inputXML = Get-Content $xamlFile -Raw
$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$XAML = $inputXML

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $window = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}

Function Format-Bytes {
    Param
    (
        [Parameter(
            ValueFromPipeline = $true
        )]
        [ValidateNotNullOrEmpty()]
        [float]$number
    )
    Begin{
        $sizes = 'KB','MB','GB','TB','PB'
    }
    Process {
        if ($number -lt 1KB) {
            return "$number B"
        } elseif ($number -lt 1MB) {
            $number = $number / 1KB
            $number = "{0:N2}" -f $number
            return "$number KB"
        } elseif ($number -lt 1GB) {
            $number = $number / 1MB
            $number = "{0:N2}" -f $number
            return "$number MB"
        } elseif ($number -lt 1TB) {
            $number = $number / 1GB
            $number = "{0:N2}" -f $number
            return "$number GB"
        } elseif ($number -lt 1PB) {
            $number = $number / 1TB
            $number = "{0:N2}" -f $number
            return "$number TB"
        } else {
            $number = $number / 1PB
            $number = "{0:N2}" -f $number
            return "$number PB"
        }
    }
    End{}
}

if ($result = Get-PhysicalDisk) {
    foreach ($item in $result) {
        $var_DestinationDisk.Items.add("Disk " + $item.DeviceId + " | " + $item.FriendlyName + " | " + $(Format-Bytes $item.Size))
    }
}

if ($result = Get-ChildItem $BaseDir -Recurse -Include *.wim, *.ffu, *.esd | Select-Object -ExpandProperty DirectoryName -Unique) {
    foreach ($item in $result) {
        $var_ImageFile.Items.add($item)
    }
}

$SelectedWim = $false

$var_ImageFile.Add_SelectionChanged({
    param($sender, $args)
    $selected = $sender.SelectedItem
    $SelectedWim = $selected
    $ffu = Get-ChildItem $selected\install.ffu
    $validffu = (($ffu -ne $null) -and ($ffu -ne ""))
    $wim = Get-ChildItem $selected\install.wim
    $validwim = (($wim -ne $null) -and ($wim -ne ""))
    if ( $validwim ) { $var_EFI.isChecked = $true; $var_EFI.isEnabled = $true; $var_MBR.isEnabled = $true; } else { $var_EFI.isEnabled = $false; $var_MBR.isEnabled = $false; }
    if ( $validffu ) { $var_FFU.isChecked = $true; $var_FFU.isEnabled = $true; } else { $var_FFU.isChecked = $false; $var_FFU.isEnabled = $false; }

    $var_ImageIndex.Items.Clear()
    if ($validwim) { $ImageInfo = Get-WindowsImage -ImagePath $selected\install.wim }
    foreach ($img in $ImageInfo){
        $var_ImageIndex.Items.Add("" + $img.ImageIndex + " | " + $img.ImageName + " | " + $img.ImageDescription + "(" + $(Format-Bytes $img.ImageSize) + ")")
    }

    if ($validffu) { $DiskImageInfo = Get-WindowsImage -ImagePath $selected\install.ffu }
    foreach ($img in $DiskImageInfo){
        $var_ImageIndex.Items.Add("" + $img.ImageIndex + " | " + $img.ImageName + " | " + $img.ImageDescription + "(" + $(Format-Bytes $img.ImageSize) + ") [FFU]")
    }

    $var_ImageIndex.isEnabled = $true;
})

$var_ImageIndex.Add_SelectionChanged({
    # set FFU/WIM type
    param($sender, $args)
    $selected = $sender.SelectedItem
    $var_StartDeploy.isEnabled = $true;
})

$var_DestinationDisk.Add_SelectionChanged({
    # verify disk is OK
})

$var_StartDeploy.Add_Click({

    # CHECK PARAMS FIRST

    $wshell = New-Object -ComObject Wscript.Shell
    $answer = $wshell.Popup("Are you sure you want to COMPLETLEY wipe disk '" + $var_DestinationDisk.Text + "' and deploy '" + $var_ImageFile.Text + " - " + $var_ImageIndex.Text + "'",0,"Destructive Action",48+4)
    if($answer -eq "6"){
        $ready = $true
        if($var_MBR.isChecked) {
            $boottype = "MBR"
        }
        if($var_EFI.isChecked) {
            $boottype = "EFI"
        }
        if($var_FFU.isChecked){
            $wimext = "ffu"
            $boottype = "FFU"
        }else{
            $wimext = "wim"
        }
        $wimindex = $var_ImageIndex.Text.Split(" | ")[0]
        $DiskNo = $var_DestinationDisk.Text.Split(" | ")[1]
        $SourceImage = $var_ImageFile.Text + "\" + "install." + $wimext
        # $wimindex
        # $boottype
    }
    if($answer -eq "7"){
        $ready = $false
    }
})

$Null = $window.ShowDialog()

