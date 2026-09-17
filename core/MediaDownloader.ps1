# ==============================================================================
# Media Downloader - Universal Video & Audio Downloader (MP4 / MP3)
# Modern Multi-Video Queue GUI with Individual Progress Bars & Live Thumbnails
# by BlAcky
# Version: 1.1.0
# ==============================================================================

# Hide background console window immediately if present & define Win32 helpers
Add-Type -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern uint GetClipboardSequenceNumber();
'@ -Name 'Win32Console' -Namespace 'Win32' -ErrorAction SilentlyContinue

$consoleHwnd = [Win32.Win32Console]::GetConsoleWindow()
if ($consoleHwnd -ne [IntPtr]::Zero) {
    [Win32.Win32Console]::ShowWindow($consoleHwnd, 0) | Out-Null
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms

# Application Meta
$AppVersion = "1.1.0"
$AppTitle   = "Media Downloader"
$GitHubRepo = "aowblacky/MediaDownloader"

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $ScriptDir) {
    $ScriptDir = Get-Location
}

# Resolve Root Directory
$RootDir = Split-Path -Parent $ScriptDir
if (-not (Test-Path (Join-Path $RootDir "core"))) {
    $RootDir = $ScriptDir
}

$BinDir     = Join-Path $RootDir "bin"
$YtDlpExe   = Join-Path $BinDir "yt-dlp.exe"
$FfmpegExe  = Join-Path $BinDir "ffmpeg.exe"
$ConfigFile = Join-Path $ScriptDir "settings.json"

# Default Download Directory (Downloads\MediaDownloader)
$DefaultDownloadDir = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads\MediaDownloader"
if (-not (Test-Path $DefaultDownloadDir)) {
    New-Item -ItemType Directory -Path $DefaultDownloadDir -Force | Out-Null
}

function Load-SavedSettings {
    if (Test-Path $ConfigFile) {
        try {
            $json = Get-Content -Path $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($json) {
                if (-not $json.DownloadPath -or -not (Test-Path $json.DownloadPath)) {
                    $json.DownloadPath = $DefaultDownloadDir
                }
                return $json
            }
        } catch {}
    }
    return [PSCustomObject]@{
        DownloadPath         = $DefaultDownloadDir
        FormatIndex          = 0
        SpeedLimitIndex      = 0
        AutoClipboard        = $false
        NotificationsEnabled = $true
        SponsorBlockDefault  = $false
        EmbedThumbnail       = $true
        EmbedMetadata        = $true
        DownloadPlaylist     = $false
        EmbedSubs            = $false
    }
}

function Save-AppSettings([string]$downloadPath = "", [int]$formatIdx = -1, [int]$speedIdx = -1, $autoClip = $null, $notif = $null, $sponsorDef = $null) {
    try {
        $existing = Load-SavedSettings
        $targetPath = if ($downloadPath) { $downloadPath } else { $existing.DownloadPath }
        $targetFmt  = if ($formatIdx -ge 0) { $formatIdx } else { $existing.FormatIndex }
        $targetSpd  = if ($speedIdx -ge 0) { $speedIdx } else { if ($null -ne $existing.SpeedLimitIndex) { $existing.SpeedLimitIndex } else { 0 } }
        $targetClip = if ($null -ne $autoClip) { [bool]$autoClip } else { if ($null -ne $existing.AutoClipboard) { [bool]$existing.AutoClipboard } else { $false } }
        $targetNotif = if ($null -ne $notif) { [bool]$notif } else { if ($null -ne $existing.NotificationsEnabled) { [bool]$existing.NotificationsEnabled } else { $true } }
        $targetSpons = if ($null -ne $sponsorDef) { [bool]$sponsorDef } else { if ($null -ne $existing.SponsorBlockDefault) { [bool]$existing.SponsorBlockDefault } else { $false } }

        $cfg = [PSCustomObject]@{
            DownloadPath         = $targetPath
            FormatIndex          = $targetFmt
            SpeedLimitIndex      = $targetSpd
            AutoClipboard        = $targetClip
            NotificationsEnabled = $targetNotif
            SponsorBlockDefault  = $targetSpons
            EmbedThumbnail       = if ($null -ne $ChkEmbedThumbnail) { [bool]$ChkEmbedThumbnail.IsChecked } else { [bool]$existing.EmbedThumbnail }
            EmbedMetadata        = if ($null -ne $ChkEmbedMetadata) { [bool]$ChkEmbedMetadata.IsChecked } else { [bool]$existing.EmbedMetadata }
            DownloadPlaylist     = if ($null -ne $ChkDownloadPlaylist) { [bool]$ChkDownloadPlaylist.IsChecked } else { [bool]$existing.DownloadPlaylist }
            EmbedSubs            = if ($null -ne $ChkEmbedSubs) { [bool]$ChkEmbedSubs.IsChecked } else { [bool]$existing.EmbedSubs }
        }
        $jsonStr = $cfg | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllText($ConfigFile, $jsonStr, [System.Text.Encoding]::UTF8)
    } catch {}
}

function Format-DurationSec([double]$seconds) {
    if ($seconds -le 0 -or [double]::IsNaN($seconds) -or [double]::IsInfinity($seconds)) { return "00:00:00" }
    $ts = [TimeSpan]::FromSeconds($seconds)
    $hours = [int][math]::Floor($ts.TotalHours)
    return "{0:D2}:{1:D2}:{2:D2}" -f $hours, $ts.Minutes, $ts.Seconds
}

function Parse-DurationString([string]$str, [double]$fallbackMax = 0) {
    if (-not $str -or $str.Trim() -eq "" -or $str.Trim() -eq "inf") {
        return $fallbackMax
    }
    $str = $str.Trim()
    if ($str -match "^\d+$") {
        return [double]$str
    }
    if ($str -match "^(?:(\d+):)?(\d{1,2}):(\d{2})$") {
        $h = if ($matches[1]) { [int]$matches[1] } else { 0 }
        $m = [int]$matches[2]
        $s = [int]$matches[3]
        return ($h * 3600) + ($m * 60) + $s
    }
    return 0
}

# ------------------------------------------------------------------------------
# XAML MAIN WINDOW DEFINITION
# ------------------------------------------------------------------------------
$xamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Media Downloader &#x2022; YouTube &amp; Multi-Platform (MP4 / MP3)"
        Height="860" Width="920"
        MinHeight="700" MinWidth="800"
        WindowStartupLocation="CenterScreen"
        Background="#181825"
        Foreground="#CDD6F4"
        FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol">
    <Window.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontFamily" Value="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1E1E2E"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="CaretBrush" Value="#89B4FA"/>
            <Setter Property="FontFamily" Value="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"/>
        </Style>
        <Style TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="#11111B"/>
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontFamily" Value="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="Foreground" Value="#11111B"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontFamily" Value="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Margin" Value="0,2,14,2"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontFamily" Value="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"/>
        </Style>
        <Style x:Key="ModernBtn" TargetType="Button">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontFamily" Value="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#45475A"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#585B70"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#1E1E2E"/>
                                <Setter Property="Foreground" Value="#6C7086"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="AccentBtn" TargetType="Button" BasedOn="{StaticResource ModernBtn}">
            <Setter Property="Background" Value="#89B4FA"/>
            <Setter Property="Foreground" Value="#11111B"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#B4BEFE"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#74C7EC"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#45475A"/>
                                <Setter Property="Foreground" Value="#A6ADC8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="DangerBtn" TargetType="Button" BasedOn="{StaticResource ModernBtn}">
            <Setter Property="Background" Value="#F38BA8"/>
            <Setter Property="Foreground" Value="#11111B"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#EBA0AC"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#F2CDCD"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#45475A"/>
                                <Setter Property="Foreground" Value="#6C7086"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background" Value="#1E1E2E"/>
            <Setter Property="CornerRadius" Value="10"/>
            <Setter Property="BorderBrush" Value="#313244"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- 0: Header -->
            <RowDefinition Height="Auto"/> <!-- 1: Input & Add -->
            <RowDefinition Height="Auto"/> <!-- 2: Settings -->
            <RowDefinition Height="*"/>    <!-- 3: Video Queue List -->
            <RowDefinition Height="Auto"/> <!-- 4: Bottom Action Bar -->
        </Grid.RowDefinitions>

        <!-- 0. Header -->
        <Grid Grid.Row="0" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#x26A1; Media Downloader" FontSize="20" FontWeight="Bold" Foreground="#89B4FA"/>
                    <Border Background="#313244" CornerRadius="8" Padding="6,2" Margin="8,0,0,0" VerticalAlignment="Center">
                        <TextBlock x:Name="TxtAppVer" Text="v1.0.0" FontSize="11" FontWeight="Bold" Foreground="#89B4FA"/>
                    </Border>
                </StackPanel>
                <TextBlock Text="YouTube, TikTok, Twitter/X, Instagram, Vimeo, Soundcloud &amp; more &#x2022; MP4 &amp; MP3" FontSize="12" Foreground="#A6ADC8" Margin="0,2,0,0"/>
            </StackPanel>
            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                <Border x:Name="PillStatus" Background="#313244" CornerRadius="12" Padding="10,4" Margin="0,0,8,0">
                    <TextBlock x:Name="TxtPillStatus" Text="Ready" FontSize="11" FontWeight="SemiBold" Foreground="#A6E3A1"/>
                </Border>
                <Button x:Name="BtnAppSettings" Content="&#x2699; Settings" Style="{StaticResource ModernBtn}" Padding="10,5" FontSize="11" Margin="0,0,8,0" ToolTip="Program options (Clipboard auto-add, Notifications, SponsorBlock default)"/>
                <Button x:Name="BtnUpdateCheck" Content="&#x27F3; Check for Updates" Style="{StaticResource ModernBtn}" Padding="10,5" FontSize="11" ToolTip="Check for updates for Media Downloader &amp; tools"/>
            </StackPanel>
        </Grid>

        <!-- 1. URL Input & Add Card -->
        <Border Grid.Row="1" Style="{StaticResource Card}">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="0,0,0,6">
                    <TextBlock Text="&#x1F517; Enter or paste video link(s):" FontWeight="SemiBold"/>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="BtnPaste" Content="&#x1F4CB; Paste" Style="{StaticResource ModernBtn}" Padding="10,3" FontSize="11" Margin="0,0,6,0"/>
                        <Button x:Name="BtnAddUrls" Content="&#x2795; Add to Queue" Style="{StaticResource AccentBtn}" Padding="12,3" FontSize="11"/>
                    </StackPanel>
                </Grid>
                <TextBox x:Name="TxtUrls" Grid.Row="1" Height="50" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" TextWrapping="NoWrap"
                         ToolTip="Paste links here and click 'Add to Queue'"/>
            </Grid>
        </Border>

        <!-- 2. Settings Card -->
        <Border Grid.Row="2" Style="{StaticResource Card}">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="2.2*"/>
                    <ColumnDefinition Width="1.4*"/>
                    <ColumnDefinition Width="2.6*"/>
                </Grid.ColumnDefinitions>

                <!-- Format Selection -->
                <StackPanel Grid.Row="0" Grid.Column="0" Margin="0,0,10,6">
                    <TextBlock Text="&#x1F3B5; Format:" FontWeight="SemiBold" Margin="0,0,0,3" FontSize="12"/>
                    <ComboBox x:Name="CmbFormat" SelectedIndex="0">
                        <ComboBoxItem Content="&#x1F3B5; MP3 Audio (Best Quality 320kbps)" Tag="mp3_best"/>
                        <ComboBoxItem Content="&#x1F3AC; MP4 Video (Best Quality)" Tag="mp4_best"/>
                        <ComboBoxItem Content="&#x1F3AC; MP4 Video (1080p Full HD)" Tag="mp4_1080p"/>
                        <ComboBoxItem Content="&#x1F3AC; MP4 Video (720p HD)" Tag="mp4_720p"/>
                        <ComboBoxItem Content="&#x1F3B5; M4A Audio (Apple AAC)" Tag="m4a_best"/>
                        <ComboBoxItem Content="&#x1F3B5; WAV Audio (Lossless)" Tag="wav_best"/>
                        <ComboBoxItem Content="&#x1F3B5; FLAC Audio (Lossless)" Tag="flac_best"/>
                    </ComboBox>
                </StackPanel>

                <!-- Speed Limit Selection -->
                <StackPanel Grid.Row="0" Grid.Column="1" Margin="0,0,10,6">
                    <TextBlock Text="&#x26A1; Speed Limit:" FontWeight="SemiBold" Margin="0,0,0,3" FontSize="12"/>
                    <ComboBox x:Name="CmbSpeedLimit" SelectedIndex="0">
                        <ComboBoxItem Content="Unlimited" Tag=""/>
                        <ComboBoxItem Content="50 MB/s" Tag="50M"/>
                        <ComboBoxItem Content="20 MB/s" Tag="20M"/>
                        <ComboBoxItem Content="10 MB/s" Tag="10M"/>
                        <ComboBoxItem Content="5 MB/s" Tag="5M"/>
                        <ComboBoxItem Content="2 MB/s" Tag="2M"/>
                        <ComboBoxItem Content="1 MB/s" Tag="1M"/>
                    </ComboBox>
                </StackPanel>

                <!-- Download Path Selection -->
                <StackPanel Grid.Row="0" Grid.Column="2" Margin="0,0,0,6">
                    <TextBlock Text="&#x1F4C1; Download Folder:" FontWeight="SemiBold" Margin="0,0,0,3" FontSize="12"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="TxtDownloadPath" Grid.Column="0" IsReadOnly="True" Margin="0,0,6,0"/>
                        <Button x:Name="BtnBrowsePath" Grid.Column="1" Content="Browse..." Style="{StaticResource ModernBtn}" Margin="0,0,6,0"/>
                        <Button x:Name="BtnOpenFolder" Grid.Column="2" Content="&#x1F4C2; Open" Style="{StaticResource ModernBtn}"/>
                    </Grid>
                </StackPanel>

                <!-- Options Checkboxes -->
                <WrapPanel Grid.Row="1" Grid.ColumnSpan="3" Margin="0,4,0,0">
                    <CheckBox x:Name="ChkEmbedThumbnail" Content="Embed cover / thumbnail" IsChecked="True"/>
                    <CheckBox x:Name="ChkEmbedMetadata" Content="Embed metadata" IsChecked="True"/>
                    <CheckBox x:Name="ChkDownloadPlaylist" Content="Download entire playlist" IsChecked="False"/>
                    <CheckBox x:Name="ChkEmbedSubs" Content="Embed subtitles" IsChecked="False"/>
                </WrapPanel>
            </Grid>
        </Border>

        <!-- 3. Video Queue List Area -->
        <Border Grid.Row="3" Style="{StaticResource Card}" Padding="10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <!-- Queue Header -->
                <Grid Grid.Row="0" Margin="0,0,0,8">
                    <TextBlock x:Name="TxtQueueHeader" Text="&#x1F4CB; Download Queue (0 Videos)" FontWeight="SemiBold" FontSize="13"/>
                    <TextBlock x:Name="TxtOverallStatus" Text="Ready" HorizontalAlignment="Right" FontSize="12" Foreground="#89B4FA" FontWeight="SemiBold"/>
                </Grid>

                <!-- Scrollable Video Cards List -->
                <Grid Grid.Row="1">
                    <!-- Empty Placeholder -->
                    <Border x:Name="EmptyPlaceholder" Background="#151521" CornerRadius="8" Padding="24" Margin="0,20,0,0" HorizontalAlignment="Center" VerticalAlignment="Top">
                        <StackPanel HorizontalAlignment="Center">
                            <TextBlock Text="&#x1F3AC;" FontSize="32" HorizontalAlignment="Center" Margin="0,0,0,6" Foreground="#6C7086"/>
                            <TextBlock Text="No videos in the queue yet" FontWeight="SemiBold" FontSize="14" HorizontalAlignment="Center" Foreground="#BAC2DE"/>
                            <TextBlock Text="Paste one or more links above and click 'Add to Queue'." FontSize="12" Foreground="#6C7086" Margin="0,4,0,0" HorizontalAlignment="Center"/>
                        </StackPanel>
                    </Border>
                    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                        <StackPanel x:Name="QueueContainer">
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- Queue Footer: Clear List Button -->
                <Grid Grid.Row="2" Margin="0,8,0,0">
                    <Button x:Name="BtnClearAll" Content="&#x1F5D1; Clear List" Style="{StaticResource ModernBtn}" HorizontalAlignment="Right" Padding="10,4" FontSize="11" ToolTip="Remove all videos from queue"/>
                </Grid>
            </Grid>
        </Border>

        <!-- 4. Bottom Action Bar -->
        <Grid Grid.Row="4" Margin="0,4,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <TextBlock x:Name="TxtFooter" Grid.Column="0" Text="Media Downloader &#x2022; Ready" VerticalAlignment="Center" FontSize="12" Foreground="#6C7086"/>

            <Button x:Name="BtnCancel" Grid.Column="1" Content="&#x23F9; Cancel" Style="{StaticResource DangerBtn}" Margin="0,0,10,0" IsEnabled="False" Width="130" Height="36"/>
            <Button x:Name="BtnStartDownload" Grid.Column="2" Content="&#x2B07; Download All" Style="{StaticResource AccentBtn}" Width="200" Height="36"/>
        </Grid>
    </Grid>
</Window>
"@

# ------------------------------------------------------------------------------
# LOAD XAML & ROOT CONTROLS
# ------------------------------------------------------------------------------
$stringReader = New-Object System.IO.StringReader $xamlString
$xmlReader = [System.Xml.XmlReader]::Create($stringReader)
$window = [System.Windows.Markup.XamlReader]::Load($xmlReader)

# Element References
$TxtAppVer          = $window.FindName("TxtAppVer")
$TxtUrls            = $window.FindName("TxtUrls")
$BtnPaste           = $window.FindName("BtnPaste")
$BtnAddUrls         = $window.FindName("BtnAddUrls")
$BtnClearAll        = $window.FindName("BtnClearAll")
$CmbFormat          = $window.FindName("CmbFormat")
$CmbSpeedLimit      = $window.FindName("CmbSpeedLimit")
$TxtDownloadPath    = $window.FindName("TxtDownloadPath")
$BtnBrowsePath      = $window.FindName("BtnBrowsePath")
$BtnOpenFolder      = $window.FindName("BtnOpenFolder")
$ChkEmbedThumbnail  = $window.FindName("ChkEmbedThumbnail")
$ChkEmbedMetadata   = $window.FindName("ChkEmbedMetadata")
$ChkDownloadPlaylist = $window.FindName("ChkDownloadPlaylist")
$ChkEmbedSubs       = $window.FindName("ChkEmbedSubs")
$TxtQueueHeader     = $window.FindName("TxtQueueHeader")
$TxtOverallStatus   = $window.FindName("TxtOverallStatus")
$QueueContainer     = $window.FindName("QueueContainer")
$EmptyPlaceholder   = $window.FindName("EmptyPlaceholder")
$TxtFooter          = $window.FindName("TxtFooter")
$PillStatus         = $window.FindName("PillStatus")
$TxtPillStatus      = $window.FindName("TxtPillStatus")
$BtnAppSettings     = $window.FindName("BtnAppSettings")
$BtnUpdateCheck     = $window.FindName("BtnUpdateCheck")
$BtnCancel          = $window.FindName("BtnCancel")
$BtnStartDownload   = $window.FindName("BtnStartDownload")

$savedCfg = Load-SavedSettings
$TxtAppVer.Text       = "v$AppVersion"
$TxtDownloadPath.Text = $savedCfg.DownloadPath
if ($savedCfg.FormatIndex -ge 0 -and $savedCfg.FormatIndex -lt $CmbFormat.Items.Count) {
    $CmbFormat.SelectedIndex = $savedCfg.FormatIndex
}
if ($null -ne $savedCfg.SpeedLimitIndex -and $savedCfg.SpeedLimitIndex -ge 0 -and $savedCfg.SpeedLimitIndex -lt $CmbSpeedLimit.Items.Count) {
    $CmbSpeedLimit.SelectedIndex = $savedCfg.SpeedLimitIndex
}
$ChkEmbedThumbnail.IsChecked   = if ($null -ne $savedCfg.EmbedThumbnail) { [bool]$savedCfg.EmbedThumbnail } else { $true }
$ChkEmbedMetadata.IsChecked    = if ($null -ne $savedCfg.EmbedMetadata) { [bool]$savedCfg.EmbedMetadata } else { $true }
$ChkDownloadPlaylist.IsChecked = [bool]$savedCfg.DownloadPlaylist
$ChkEmbedSubs.IsChecked        = [bool]$savedCfg.EmbedSubs

# ------------------------------------------------------------------------------
# THREAD-SAFE STATE & DATA STRUCTURES
# ------------------------------------------------------------------------------
$global:ItemsList   = [System.Collections.Generic.List[PSObject]]::new()
$global:ItemUIMap   = @{}
$global:ItemIdSeq   = 0

$global:EngineState = [hashtable]::Synchronized(@{
    IsDownloading    = $false
    CancelRequested  = $false
    CurrentProcessId = 0
    ActiveItemId     = ""
    CurrentItemPct   = 0
    CurrentItemSpeed = ""
    CurrentItemEta   = ""
    CompletedItems   = [System.Collections.Generic.List[string]]::new()
    FailedItems      = [System.Collections.Generic.List[string]]::new()
    ResultFileMap    = [hashtable]::Synchronized(@{})
    MetaResults      = [System.Collections.Concurrent.ConcurrentQueue[PSObject]]::new()
    Finished         = $false
    ResultDir        = ""
    Runspace         = $null
    Powershell       = $null
})

# ------------------------------------------------------------------------------
# WINDOWS TOAST NOTIFICATION (Native WinRT & Balloon Fallback with Sound)
# ------------------------------------------------------------------------------
function Show-WindowsNotification([string]$title, [string]$message, [string]$folderPath = "") {
    try {
        $cfg = Load-SavedSettings
        if ($null -ne $cfg.NotificationsEnabled -and -not [bool]$cfg.NotificationsEnabled) {
            return
        }
    } catch {}

    try {
        [System.Media.SystemSounds]::Asterisk.Play()
    } catch {}

    # 1. Native Windows 10 / 11 WinRT Action Center Toast
    try {
        Add-Type -AssemblyName WindowsBase -ErrorAction SilentlyContinue
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $escapedTitle = [System.Security.SecurityElement]::Escape($title)
        $escapedMsg   = [System.Security.SecurityElement]::Escape($message)

        $template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$escapedTitle</text>
            <text>$escapedMsg</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Media Downloader").Show($toast)
        return
    } catch {}

    # 2. Tray Balloon Tip Fallback
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.BalloonTipTitle = $title
        $notify.BalloonTipText  = $message
        $notify.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::Info
        $notify.Visible = $true

        if ($folderPath) {
            $notify.add_BalloonTipClicked({
                if ($folderPath -and (Test-Path $folderPath)) {
                    [System.Diagnostics.Process]::Start("explorer.exe", $folderPath) | Out-Null
                }
                $this.Visible = $false
                $this.Dispose()
            }.GetNewClosure())
        }

        $notify.ShowBalloonTip(6000)

        $cleanup = New-Object System.Windows.Threading.DispatcherTimer
        $cleanup.Interval = [TimeSpan]::FromSeconds(8)
        $cleanup.add_Tick({
            $cleanup.Stop()
            try {
                $notify.Visible = $false
                $notify.Dispose()
            } catch {}
        })
        $cleanup.Start()
    } catch {}
}

# ------------------------------------------------------------------------------
# PROGRAM SETTINGS & PREFERENCES DIALOG (Catppuccin Dark)
# ------------------------------------------------------------------------------
function Show-ProgramSettingsDialog {
    $cur = Load-SavedSettings
    $settXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Settings &amp; Options" Width="480" Height="360"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent"
        FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol">
    <Border Background="#1E1E2E" CornerRadius="12" BorderBrush="#45475A" BorderThickness="1.5">
        <Border.Effect>
            <DropShadowEffect BlurRadius="25" ShadowDepth="4" Direction="270" Color="#000000" Opacity="0.7"/>
        </Border.Effect>
        <Grid Margin="22">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Header -->
            <Grid Grid.Row="0" Margin="0,0,0,16">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#x2699;" FontSize="18" Foreground="#89B4FA" Margin="0,0,8,0" VerticalAlignment="Center"/>
                    <TextBlock Text="Program Settings &amp; Preferences" FontSize="16" FontWeight="Bold" Foreground="#CDD6F4" VerticalAlignment="Center"/>
                </StackPanel>
                <Button x:Name="BtnCloseSett" Content="&#x2715;" HorizontalAlignment="Right" VerticalAlignment="Center"
                        Background="Transparent" Foreground="#6C7086" BorderThickness="0" FontSize="13" FontWeight="Bold" Cursor="Hand" Padding="4"/>
            </Grid>

            <!-- Options Stack -->
            <StackPanel Grid.Row="1">
                <!-- Auto Clipboard -->
                <Border Background="#181825" CornerRadius="8" Padding="12,10" Margin="0,0,0,10" BorderBrush="#313244" BorderThickness="1">
                    <Grid>
                        <StackPanel Margin="0,0,40,0">
                            <TextBlock Text="&#x1F4CB; Auto-add copied links" FontWeight="Bold" FontSize="13" Foreground="#CDD6F4"/>
                            <TextBlock Text="Automatically add video links copied from browser to the queue." FontSize="11" Foreground="#A6ADC8" Margin="0,2,0,0" TextWrapping="Wrap"/>
                        </StackPanel>
                        <CheckBox x:Name="ChkDlgAutoClip" HorizontalAlignment="Right" VerticalAlignment="Center" Cursor="Hand"/>
                    </Grid>
                </Border>

                <!-- Windows Notifications -->
                <Border Background="#181825" CornerRadius="8" Padding="12,10" Margin="0,0,0,10" BorderBrush="#313244" BorderThickness="1">
                    <Grid>
                        <StackPanel Margin="0,0,40,0">
                            <TextBlock Text="&#x1F514; Completion Notifications &amp; Sound" FontWeight="Bold" FontSize="13" Foreground="#CDD6F4"/>
                            <TextBlock Text="Show a Windows toast notification and sound chime when all downloads finish." FontSize="11" Foreground="#A6ADC8" Margin="0,2,0,0" TextWrapping="Wrap"/>
                        </StackPanel>
                        <CheckBox x:Name="ChkDlgNotifications" HorizontalAlignment="Right" VerticalAlignment="Center" Cursor="Hand"/>
                    </Grid>
                </Border>

                <!-- Default SponsorBlock -->
                <Border Background="#181825" CornerRadius="8" Padding="12,10" Margin="0,0,0,4" BorderBrush="#313244" BorderThickness="1">
                    <Grid>
                        <StackPanel Margin="0,0,40,0">
                            <TextBlock Text="&#x1F6E1; Default: Skip sponsors (SponsorBlock)" FontWeight="Bold" FontSize="13" Foreground="#CDD6F4"/>
                            <TextBlock Text="Automatically enable SponsorBlock for newly added YouTube videos." FontSize="11" Foreground="#A6ADC8" Margin="0,2,0,0" TextWrapping="Wrap"/>
                        </StackPanel>
                        <CheckBox x:Name="ChkDlgSponsorDefault" HorizontalAlignment="Right" VerticalAlignment="Center" Cursor="Hand"/>
                    </Grid>
                </Border>
            </StackPanel>

            <!-- Buttons -->
            <Grid Grid.Row="2" Margin="0,14,0,0">
                <Button x:Name="BtnSaveSett" Content="&#x2714; Save &amp; Close" HorizontalAlignment="Right" Width="130" Height="34"
                        Background="#89B4FA" Foreground="#11111B" FontSize="12" FontWeight="Bold" BorderThickness="0" Cursor="Hand">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="6">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="b" Property="Background" Value="#B4BEFE"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
            </Grid>
        </Grid>
    </Border>
</Window>
"@
    $sReader = New-Object System.IO.StringReader $settXaml
    $xReader = [System.Xml.XmlReader]::Create($sReader)
    $settWin = [System.Windows.Markup.XamlReader]::Load($xReader)
    $settWin.Owner = $window

    $settWin.Add_MouseLeftButtonDown({
        try { $settWin.DragMove() } catch {}
    })

    $ChkDlgAutoClip       = $settWin.FindName("ChkDlgAutoClip")
    $ChkDlgNotifications  = $settWin.FindName("ChkDlgNotifications")
    $ChkDlgSponsorDefault = $settWin.FindName("ChkDlgSponsorDefault")
    $BtnCloseSett         = $settWin.FindName("BtnCloseSett")
    $BtnSaveSett          = $settWin.FindName("BtnSaveSett")

    $ChkDlgAutoClip.IsChecked       = [bool]$cur.AutoClipboard
    $ChkDlgNotifications.IsChecked  = if ($null -ne $cur.NotificationsEnabled) { [bool]$cur.NotificationsEnabled } else { $true }
    $ChkDlgSponsorDefault.IsChecked = [bool]$cur.SponsorBlockDefault

    $BtnCloseSett.Add_Click({ $settWin.Close() })

    $BtnSaveSett.Add_Click({
        Save-AppSettings -autoClip $ChkDlgAutoClip.IsChecked -notif $ChkDlgNotifications.IsChecked -sponsorDef $ChkDlgSponsorDefault.IsChecked
        $settWin.Close()
    })

    $settWin.ShowDialog() | Out-Null
}

# ------------------------------------------------------------------------------
# COMPREHENSIVE PER-VIDEO SETTINGS & TIMELINE TRIMMING MODAL DIALOG
# ------------------------------------------------------------------------------
function Show-VideoSettingsDialog($itemData, $uiRefs) {
    $videoXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Video Settings &amp; Trimming" Width="580" Height="520"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent"
        FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol">
    <Window.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontFamily" Value="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#11111B"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="CaretBrush" Value="#89B4FA"/>
            <Setter Property="FontFamily" Value="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"/>
        </Style>
        <Style x:Key="ModernBtn" TargetType="Button">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontFamily" Value="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#45475A"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#585B70"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Border Background="#1E1E2E" CornerRadius="12" BorderBrush="#45475A" BorderThickness="1.5">
        <Border.Effect>
            <DropShadowEffect BlurRadius="30" ShadowDepth="6" Direction="270" Color="#000000" Opacity="0.75"/>
        </Border.Effect>
        <Grid Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/> <!-- 0: Header -->
                <RowDefinition Height="Auto"/> <!-- 1: Video Preview Card -->
                <RowDefinition Height="Auto"/> <!-- 2: Tags & Metadata -->
                <RowDefinition Height="*"/>    <!-- 3: Visual Timeline & Trimming -->
                <RowDefinition Height="Auto"/> <!-- 4: SponsorBlock -->
                <RowDefinition Height="Auto"/> <!-- 5: Buttons -->
            </Grid.RowDefinitions>

            <!-- 0. Header -->
            <Grid Grid.Row="0" Margin="0,0,0,12">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#x2699;" FontSize="18" Foreground="#89B4FA" Margin="0,0,8,0" VerticalAlignment="Center"/>
                    <TextBlock Text="Video Settings &amp; Options" FontSize="16" FontWeight="Bold" Foreground="#CDD6F4" VerticalAlignment="Center"/>
                </StackPanel>
                <Button x:Name="BtnCloseDialog" Content="&#x2715;" HorizontalAlignment="Right" VerticalAlignment="Center"
                        Background="Transparent" Foreground="#6C7086" BorderThickness="0" FontSize="13" FontWeight="Bold" Cursor="Hand" Padding="4"/>
            </Grid>

            <!-- 1. Video Info Summary Card -->
            <Border Grid.Row="1" Background="#181825" CornerRadius="8" Padding="10" Margin="0,0,0,10" BorderBrush="#313244" BorderThickness="1">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Border Grid.Column="0" CornerRadius="4" Width="90" Height="52" Background="#11111B" Margin="0,0,10,0" ClipToBounds="True">
                        <Image x:Name="DlgImgThumb" Stretch="UniformToFill"/>
                    </Border>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                        <TextBlock x:Name="DlgTxtVideoTitle" Text="Video Title..." FontWeight="Bold" FontSize="12" Foreground="#CDD6F4" TextTrimming="CharacterEllipsis"/>
                        <TextBlock x:Name="DlgTxtDuration" Text="Total Duration: --:--" FontSize="11" Foreground="#A6ADC8" Margin="0,2,0,0"/>
                    </StackPanel>
                </Grid>
            </Border>

            <!-- 2. Metadata / Tags -->
            <Border Grid.Row="2" Background="#181825" CornerRadius="8" Padding="10" Margin="0,0,0,10" BorderBrush="#313244" BorderThickness="1">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.2*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <StackPanel Grid.Column="0" Margin="0,0,8,0">
                        <TextBlock Text="Title / Filename:" FontSize="11" Foreground="#BAC2DE" Margin="0,0,0,3" FontWeight="SemiBold"/>
                        <TextBox x:Name="TxtEditTitle" Height="28" FontSize="12" Background="#11111B" Foreground="#CDD6F4" BorderBrush="#45475A"/>
                    </StackPanel>

                    <StackPanel Grid.Column="1">
                        <TextBlock Text="Artist / Channel (ID3):" FontSize="11" Foreground="#BAC2DE" Margin="0,0,0,3" FontWeight="SemiBold"/>
                        <TextBox x:Name="TxtEditArtist" Height="28" FontSize="12" Background="#11111B" Foreground="#CDD6F4" BorderBrush="#45475A"/>
                    </StackPanel>
                </Grid>
            </Border>

            <!-- 3. Interactive Visual Trimming Timeline -->
            <Border Grid.Row="3" Background="#181825" CornerRadius="8" Padding="12" Margin="0,0,0,10" BorderBrush="#313244" BorderThickness="1">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/> <!-- Title & Pill -->
                        <RowDefinition Height="Auto"/> <!-- Timeline Sliders -->
                        <RowDefinition Height="Auto"/> <!-- Time Badges / Inputs -->
                        <RowDefinition Height="Auto"/> <!-- Quick Action Buttons -->
                    </Grid.RowDefinitions>

                    <!-- Title & Pill -->
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="&#x2702; Video Trimming &amp; Cut Points" FontWeight="Bold" FontSize="12" Foreground="#89B4FA"/>
                        </StackPanel>
                        <Border x:Name="PillTrimStatus" Background="#313244" CornerRadius="10" Padding="8,2" HorizontalAlignment="Right">
                            <TextBlock x:Name="TxtTrimDurationSelected" Text="Full Video" FontSize="11" FontWeight="Bold" Foreground="#A6E3A1"/>
                        </Border>
                    </Grid>

                    <!-- Timeline Sliders -->
                    <Grid Grid.Row="1" Margin="0,2,0,8">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Start Slider -->
                        <Grid Grid.Row="0" Margin="0,0,0,6">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Start:" FontSize="11" Foreground="#89B4FA" FontWeight="Bold" Width="42" VerticalAlignment="Center"/>
                            <Slider x:Name="SliderTrimStart" Grid.Column="1" Minimum="0" Maximum="100" Value="0" SmallChange="1" LargeChange="5"/>
                        </Grid>

                        <!-- End Slider -->
                        <Grid Grid.Row="1">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="End:" FontSize="11" Foreground="#F38BA8" FontWeight="Bold" Width="42" VerticalAlignment="Center"/>
                            <Slider x:Name="SliderTrimEnd" Grid.Column="1" Minimum="0" Maximum="100" Value="100" SmallChange="1" LargeChange="5"/>
                        </Grid>
                    </Grid>

                    <!-- Time Badges & Precise Text Inputs -->
                    <Grid Grid.Row="2" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- Start Time Box -->
                        <Border Grid.Column="0" Background="#11111B" CornerRadius="6" Padding="6,4" BorderBrush="#313244" BorderThickness="1">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="&#x25B6; Start:" FontSize="11" Foreground="#89B4FA" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,6,0"/>
                                <TextBox x:Name="TxtEditTrimStart" Grid.Column="1" Text="00:00:00" Height="22" FontSize="11" Background="Transparent" Foreground="#CDD6F4" BorderThickness="0" Padding="0" HorizontalContentAlignment="Right"/>
                            </Grid>
                        </Border>

                        <TextBlock Grid.Column="1" Text="&#x2794;" FontSize="13" Foreground="#6C7086" Margin="10,0" VerticalAlignment="Center"/>

                        <!-- End Time Box -->
                        <Border Grid.Column="2" Background="#11111B" CornerRadius="6" Padding="6,4" BorderBrush="#313244" BorderThickness="1">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="&#x23F9; End:" FontSize="11" Foreground="#F38BA8" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,6,0"/>
                                <TextBox x:Name="TxtEditTrimEnd" Grid.Column="1" Text="" Height="22" FontSize="11" Background="Transparent" Foreground="#CDD6F4" BorderThickness="0" Padding="0" HorizontalContentAlignment="Right"/>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- Quick buttons -->
                    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="BtnResetTrim" Content="&#x27F2; Reset (Full Video)" Style="{StaticResource ModernBtn}" Padding="8,3" FontSize="10" Margin="0,0,6,0"/>
                        <Button x:Name="BtnStartMinus5" Content="-5s" Style="{StaticResource ModernBtn}" Padding="6,3" FontSize="10" Margin="0,0,4,0" ToolTip="Move start marker back 5 seconds"/>
                        <Button x:Name="BtnStartPlus5" Content="+5s" Style="{StaticResource ModernBtn}" Padding="6,3" FontSize="10" Margin="0,0,8,0" ToolTip="Move start marker forward 5 seconds"/>
                        <Button x:Name="BtnEndMinus5" Content="-5s" Style="{StaticResource ModernBtn}" Padding="6,3" FontSize="10" Margin="0,0,4,0" ToolTip="Move end marker back 5 seconds"/>
                        <Button x:Name="BtnEndPlus5" Content="+5s" Style="{StaticResource ModernBtn}" Padding="6,3" FontSize="10" Margin="0,0,0,0" ToolTip="Move end marker forward 5 seconds"/>
                    </StackPanel>
                </Grid>
            </Border>

            <!-- 4. SponsorBlock -->
            <Border Grid.Row="4" Background="#181825" CornerRadius="8" Padding="10,8" Margin="0,0,0,12" BorderBrush="#313244" BorderThickness="1">
                <Grid>
                    <StackPanel VerticalAlignment="Center" Margin="0,0,40,0">
                        <TextBlock Text="&#x1F6E1; Skip Sponsor Segments (SponsorBlock)" FontWeight="Bold" FontSize="12" Foreground="#CDD6F4"/>
                        <TextBlock Text="Automatically cut out sponsorships, self-promotions, and intros for this video." FontSize="10" Foreground="#A6ADC8" Margin="0,1,0,0"/>
                    </StackPanel>
                    <CheckBox x:Name="ChkEditSponsor" HorizontalAlignment="Right" VerticalAlignment="Center" Cursor="Hand"/>
                </Grid>
            </Border>

            <!-- 5. Action Buttons -->
            <Grid Grid.Row="5">
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <Button x:Name="BtnCancelDialog" Content="Cancel" Width="90" Height="32" Margin="0,0,10,0"
                            Background="#313244" Foreground="#CDD6F4" FontSize="12" FontWeight="SemiBold" BorderThickness="0" Cursor="Hand"/>
                    <Button x:Name="BtnSaveDialog" Content="&#x2714; Save Changes" Width="130" Height="32"
                            Background="#89B4FA" Foreground="#11111B" FontSize="12" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
                </StackPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

    $sReader = New-Object System.IO.StringReader $videoXaml
    $xReader = [System.Xml.XmlReader]::Create($sReader)
    $dlgWin = [System.Windows.Markup.XamlReader]::Load($xReader)
    $dlgWin.Owner = $window

    $dlgWin.Add_MouseLeftButtonDown({
        try { $dlgWin.DragMove() } catch {}
    })

    # Controls
    $BtnCloseDialog         = $dlgWin.FindName("BtnCloseDialog")
    $DlgImgThumb            = $dlgWin.FindName("DlgImgThumb")
    $DlgTxtVideoTitle       = $dlgWin.FindName("DlgTxtVideoTitle")
    $DlgTxtDuration         = $dlgWin.FindName("DlgTxtDuration")
    $TxtEditTitle           = $dlgWin.FindName("TxtEditTitle")
    $TxtEditArtist          = $dlgWin.FindName("TxtEditArtist")
    $TxtTrimDurationSelected = $dlgWin.FindName("TxtTrimDurationSelected")
    $SliderTrimStart        = $dlgWin.FindName("SliderTrimStart")
    $SliderTrimEnd          = $dlgWin.FindName("SliderTrimEnd")
    $TxtEditTrimStart       = $dlgWin.FindName("TxtEditTrimStart")
    $TxtEditTrimEnd         = $dlgWin.FindName("TxtEditTrimEnd")
    $BtnResetTrim           = $dlgWin.FindName("BtnResetTrim")
    $BtnStartMinus5         = $dlgWin.FindName("BtnStartMinus5")
    $BtnStartPlus5          = $dlgWin.FindName("BtnStartPlus5")
    $BtnEndMinus5           = $dlgWin.FindName("BtnEndMinus5")
    $BtnEndPlus5            = $dlgWin.FindName("BtnEndPlus5")
    $ChkEditSponsor         = $dlgWin.FindName("ChkEditSponsor")
    $BtnCancelDialog        = $dlgWin.FindName("BtnCancelDialog")
    $BtnSaveDialog          = $dlgWin.FindName("BtnSaveDialog")

    # Populate basic info
    $DlgTxtVideoTitle.Text = $itemData.Title
    $TxtEditTitle.Text     = $itemData.Title
    $TxtEditArtist.Text    = if ($itemData.Artist) { $itemData.Artist } else { "Channel" }
    $ChkEditSponsor.IsChecked = [bool]$itemData.SponsorBlock

    if ($uiRefs.ImgThumb.Source) {
        $DlgImgThumb.Source = $uiRefs.ImgThumb.Source
    }

    # Duration setup
    $totalSec = if ($itemData.DurationSec -and $itemData.DurationSec -gt 0) { [double]$itemData.DurationSec } else { 0 }
    if ($totalSec -gt 0) {
        $DlgTxtDuration.Text = "Total Duration: $(Format-DurationSec $totalSec) ($($itemData.Duration))"
    } else {
        $DlgTxtDuration.Text = "Total Duration: Unknown"
    }

    $maxSliderSec = if ($totalSec -gt 0) { $totalSec } else { 600 }
    $SliderTrimStart.Minimum = 0
    $SliderTrimStart.Maximum = $maxSliderSec
    $SliderTrimEnd.Minimum   = 0
    $SliderTrimEnd.Maximum   = $maxSliderSec

    # Initial Trim Values
    $initStartSec = Parse-DurationString $itemData.TrimStart 0
    $initEndSec   = if ($itemData.TrimEnd -and $itemData.TrimEnd -ne "inf") { Parse-DurationString $itemData.TrimEnd $maxSliderSec } else { $maxSliderSec }

    $isUpdatingSliders = $false

    $updateTrimStatusDisplay = {
        $st = $SliderTrimStart.Value
        $en = $SliderTrimEnd.Value
        if ($st -le 0 -and ($en -ge $maxSliderSec -or $TxtEditTrimEnd.Text.Trim() -eq "")) {
            $TxtTrimDurationSelected.Text = "Full Video"
            $TxtTrimDurationSelected.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A6E3A1")
        } else {
            $diff = [math]::Max(0, ($en - $st))
            $TxtTrimDurationSelected.Text = "$([char]0x2702) $(Format-DurationSec $diff) Selected"
            $TxtTrimDurationSelected.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#89B4FA")
        }
    }

    $SliderTrimStart.Value = $initStartSec
    $SliderTrimEnd.Value   = $initEndSec
    $TxtEditTrimStart.Text = Format-DurationSec $initStartSec
    $TxtEditTrimEnd.Text   = if ($itemData.TrimEnd -and $itemData.TrimEnd -ne "inf") { Format-DurationSec $initEndSec } else { "" }
    & $updateTrimStatusDisplay

    # Sliders change listeners
    $SliderTrimStart.Add_ValueChanged({
        if ($isUpdatingSliders) { return }
        $isUpdatingSliders = $true
        if ($SliderTrimStart.Value -gt $SliderTrimEnd.Value) {
            $SliderTrimEnd.Value = $SliderTrimStart.Value
            $TxtEditTrimEnd.Text = Format-DurationSec $SliderTrimEnd.Value
        }
        $TxtEditTrimStart.Text = Format-DurationSec $SliderTrimStart.Value
        & $updateTrimStatusDisplay
        $isUpdatingSliders = $false
    })

    $SliderTrimEnd.Add_ValueChanged({
        if ($isUpdatingSliders) { return }
        $isUpdatingSliders = $true
        if ($SliderTrimEnd.Value -lt $SliderTrimStart.Value) {
            $SliderTrimStart.Value = $SliderTrimEnd.Value
            $TxtEditTrimStart.Text = Format-DurationSec $SliderTrimStart.Value
        }
        $TxtEditTrimEnd.Text = Format-DurationSec $SliderTrimEnd.Value
        & $updateTrimStatusDisplay
        $isUpdatingSliders = $false
    })

    # Manual TextBox Listeners
    $TxtEditTrimStart.Add_LostFocus({
        $val = Parse-DurationString $TxtEditTrimStart.Text 0
        $isUpdatingSliders = $true
        $SliderTrimStart.Value = [math]::Min($val, $SliderTrimEnd.Value)
        $TxtEditTrimStart.Text = Format-DurationSec $SliderTrimStart.Value
        & $updateTrimStatusDisplay
        $isUpdatingSliders = $false
    })

    $TxtEditTrimEnd.Add_LostFocus({
        $raw = $TxtEditTrimEnd.Text.Trim()
        $isUpdatingSliders = $true
        if ($raw -eq "" -or $raw -eq "inf") {
            $SliderTrimEnd.Value = $maxSliderSec
        } else {
            $val = Parse-DurationString $raw $maxSliderSec
            $SliderTrimEnd.Value = [math]::Max($val, $SliderTrimStart.Value)
            $TxtEditTrimEnd.Text = Format-DurationSec $SliderTrimEnd.Value
        }
        & $updateTrimStatusDisplay
        $isUpdatingSliders = $false
    })

    # Reset button
    $BtnResetTrim.Add_Click({
        $isUpdatingSliders = $true
        $SliderTrimStart.Value = 0
        $SliderTrimEnd.Value   = $maxSliderSec
        $TxtEditTrimStart.Text = "00:00:00"
        $TxtEditTrimEnd.Text   = ""
        & $updateTrimStatusDisplay
        $isUpdatingSliders = $false
    })

    # Fine-tuning buttons
    $BtnStartMinus5.Add_Click({
        $isUpdatingSliders = $true
        $SliderTrimStart.Value = [math]::Max(0, ($SliderTrimStart.Value - 5))
        $TxtEditTrimStart.Text = Format-DurationSec $SliderTrimStart.Value
        & $updateTrimStatusDisplay
        $isUpdatingSliders = $false
    })

    $BtnStartPlus5.Add_Click({
        $isUpdatingSliders = $true
        $SliderTrimStart.Value = [math]::Min($SliderTrimEnd.Value, ($SliderTrimStart.Value + 5))
        $TxtEditTrimStart.Text = Format-DurationSec $SliderTrimStart.Value
        & $updateTrimStatusDisplay
        $isUpdatingSliders = $false
    })

    $BtnEndMinus5.Add_Click({
        $isUpdatingSliders = $true
        $SliderTrimEnd.Value = [math]::Max($SliderTrimStart.Value, ($SliderTrimEnd.Value - 5))
        $TxtEditTrimEnd.Text = Format-DurationSec $SliderTrimEnd.Value
        & $updateTrimStatusDisplay
        $isUpdatingSliders = $false
    })

    $BtnEndPlus5.Add_Click({
        $isUpdatingSliders = $true
        $SliderTrimEnd.Value = [math]::Min($maxSliderSec, ($SliderTrimEnd.Value + 5))
        $TxtEditTrimEnd.Text = Format-DurationSec $SliderTrimEnd.Value
        & $updateTrimStatusDisplay
        $isUpdatingSliders = $false
    })

    # Close & Cancel
    $BtnCloseDialog.Add_Click({ $dlgWin.Close() })
    $BtnCancelDialog.Add_Click({ $dlgWin.Close() })

    # Save
    $BtnSaveDialog.Add_Click({
        $newTitle  = $TxtEditTitle.Text.Trim()
        $newArtist = $TxtEditArtist.Text.Trim()
        if ($newTitle) {
            $itemData.Title = $newTitle
            $itemData.CustomTitle = $true
            $uiRefs.TxtTitle.Text = $newTitle
        }
        if ($newArtist) {
            $itemData.Artist = $newArtist
            $bullet = [char]0x2022
            $durStr = if ($itemData.Duration) { " $bullet $($itemData.Duration)" } else { "" }
            $uiRefs.TxtMeta.Text = "$newArtist$durStr"
        }

        $trimStartStr = $TxtEditTrimStart.Text.Trim()
        $trimEndStr   = $TxtEditTrimEnd.Text.Trim()

        $itemData.TrimStart    = $trimStartStr
        $itemData.TrimEnd      = $trimEndStr
        $itemData.SponsorBlock = [bool]$ChkEditSponsor.IsChecked

        # Update Badges on Card
        if ($trimEndStr -ne "" -or ($trimStartStr -ne "" -and $trimStartStr -ne "00:00:00")) {
            $uiRefs.BadgeTrim.Visibility = [System.Windows.Visibility]::Visible
            $uiRefs.TxtBadgeTrim.Text = "$([char]0x2702) $trimStartStr - $(if ($trimEndStr) { $trimEndStr } else { 'End' })"
        } else {
            $uiRefs.BadgeTrim.Visibility = [System.Windows.Visibility]::Collapsed
        }

        if ($itemData.SponsorBlock) {
            $uiRefs.BadgeSponsor.Visibility = [System.Windows.Visibility]::Visible
            if ($uiRefs.CtxSponsorBlock) { $uiRefs.CtxSponsorBlock.IsChecked = $true }
        } else {
            $uiRefs.BadgeSponsor.Visibility = [System.Windows.Visibility]::Collapsed
            if ($uiRefs.CtxSponsorBlock) { $uiRefs.CtxSponsorBlock.IsChecked = $false }
        }

        $dlgWin.Close()
    })

    $dlgWin.ShowDialog() | Out-Null
}

# ------------------------------------------------------------------------------
# DYNAMIC QUEUE CARD GENERATOR (Clean Design with ⚙ Settings Modal)
# ------------------------------------------------------------------------------
function Create-QueueCardUI {
    param($itemData)

    $cardXAML = @"
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Background="#1E1E2E" CornerRadius="8" BorderBrush="#313244" BorderThickness="1"
        Padding="10" Margin="0,0,0,8">
    <Border.ContextMenu>
        <ContextMenu Background="#181825" BorderBrush="#45475A" Foreground="#CDD6F4">
            <MenuItem x:Name="CtxPlay" Header="&#x25B6; Play File" FontWeight="SemiBold"/>
            <MenuItem x:Name="CtxShowFolder" Header="&#x1F4C1; Show in Folder"/>
            <Separator Background="#313244"/>
            <MenuItem x:Name="CtxSettings" Header="&#x2699; Video Settings &amp; Trimming..."/>
            <MenuItem x:Name="CtxSponsorBlock" Header="&#x1F6E1; Skip Sponsors (SponsorBlock)" IsCheckable="True"/>
            <MenuItem x:Name="CtxCopyUrl" Header="&#x1F517; Copy Link"/>
            <Separator Background="#313244"/>
            <MenuItem x:Name="CtxRemove" Header="&#x2715; Remove from Queue" Foreground="#F38BA8"/>
        </ContextMenu>
    </Border.ContextMenu>
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <!-- 1. Thumbnail -->
        <Border Grid.Column="0" CornerRadius="6" Width="110" Height="68" Background="#11111B" Margin="0,0,12,0" ClipToBounds="True" VerticalAlignment="Center">
            <Image x:Name="ImgThumb" Stretch="UniformToFill" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>

        <!-- 2. Details & Progress -->
        <Grid Grid.Column="1" VerticalAlignment="Center" Margin="0,0,10,0">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/> <!-- Title -->
                <RowDefinition Height="Auto"/> <!-- Meta & Badges -->
                <RowDefinition Height="Auto"/> <!-- Status & Pct -->
                <RowDefinition Height="Auto"/> <!-- Progress Bar -->
            </Grid.RowDefinitions>

            <!-- Title -->
            <TextBlock x:Name="TxtTitle" Grid.Row="0" Text="Video Title..." FontWeight="Bold" FontSize="13" TextTrimming="CharacterEllipsis" MaxHeight="22" Foreground="#CDD6F4" VerticalAlignment="Center"/>

            <!-- Meta & Badges Row -->
            <WrapPanel Grid.Row="1" Margin="0,2,0,4" VerticalAlignment="Center">
                <TextBlock x:Name="TxtMeta" Text="Channel &#x2022; 00:00" FontSize="11" Foreground="#BAC2DE" VerticalAlignment="Center" Margin="0,0,8,0"/>
                <Border x:Name="BadgeTrim" Background="#313244" CornerRadius="4" Padding="5,1" Margin="0,0,6,0" Visibility="Collapsed" VerticalAlignment="Center">
                    <TextBlock x:Name="TxtBadgeTrim" Text="&#x2702; Trimmed" FontSize="10" FontWeight="SemiBold" Foreground="#89B4FA"/>
                </Border>
                <Border x:Name="BadgeSponsor" Background="#313244" CornerRadius="4" Padding="5,1" Margin="0,0,6,0" Visibility="Collapsed" VerticalAlignment="Center">
                    <TextBlock Text="&#x1F6E1; SponsorBlock" FontSize="10" FontWeight="SemiBold" Foreground="#A6E3A1"/>
                </Border>
            </WrapPanel>

            <!-- Status & Percentage -->
            <Grid Grid.Row="2" Margin="0,0,0,3">
                <TextBlock x:Name="TxtStatus" Text="In Queue..." FontSize="11" Foreground="#A6ADC8"/>
                <TextBlock x:Name="TxtPercent" Text="0 %" FontSize="11" FontWeight="SemiBold" Foreground="#89B4FA" HorizontalAlignment="Right"/>
            </Grid>

            <!-- Progress Bar -->
            <ProgressBar x:Name="ItemProgressBar" Grid.Row="3" Height="5" Minimum="0" Maximum="100" Value="0"
                         Foreground="#89B4FA" Background="#313244" BorderThickness="0">
                <ProgressBar.Clip>
                    <RectangleGeometry RadiusX="2" RadiusY="2" Rect="0,0,800,5"/>
                </ProgressBar.Clip>
            </ProgressBar>
        </Grid>

        <!-- 3. Status Badge & Action Buttons -->
        <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Right">
            <Border x:Name="PillBadge" Background="#313244" CornerRadius="10" Padding="8,3" HorizontalAlignment="Right">
                <TextBlock x:Name="TxtBadge" Text="Waiting" FontSize="11" FontWeight="SemiBold" Foreground="#BAC2DE"/>
            </Border>

            <!-- Pre-Download Action Tools (Gear Settings & Remove) -->
            <StackPanel x:Name="PnlPreActions" Orientation="Horizontal" Margin="0,8,0,0" HorizontalAlignment="Right">
                <Button x:Name="BtnItemSettings" Content="&#x2699;" ToolTip="Video Settings, Tags &amp; Trimming"
                        Background="#313244" Foreground="#CDD6F4" BorderThickness="0" FontSize="13" Margin="0,0,6,0" Cursor="Hand" Padding="6,3">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="btnB" Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="btnB" Property="Background" Value="#45475A"/>
                                    <Setter Property="Foreground" Value="#89B4FA"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
                <Button x:Name="BtnRemoveItem" Content="&#x2715;" ToolTip="Remove video from queue"
                        Background="Transparent" Foreground="#6C7086" BorderThickness="0"
                        FontSize="13" FontWeight="Bold" Cursor="Hand" Padding="6,3">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="btnBorder" Background="Transparent" CornerRadius="4" Padding="{TemplateBinding Padding}">
                                <TextBlock x:Name="btnText" Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="btnBorder" Property="Background" Value="#313244"/>
                                    <Setter TargetName="btnText" Property="Foreground" Value="#F38BA8"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
            </StackPanel>

            <!-- Post-Download Quick Action Buttons (Play, Folder, Remove) -->
            <StackPanel x:Name="PnlPostActions" Orientation="Horizontal" Margin="0,8,0,0" HorizontalAlignment="Right" Visibility="Collapsed">
                <Button x:Name="BtnPlayItem" Content="&#x25B6; Play" ToolTip="Play downloaded media"
                        Background="#89B4FA" Foreground="#11111B" FontSize="11" FontWeight="Bold" Margin="0,0,4,0" Cursor="Hand" Padding="8,3" BorderThickness="0">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
                <Button x:Name="BtnFolderItem" Content="&#x1F4C1;" ToolTip="Show file in folder"
                        Background="#313244" Foreground="#CDD6F4" FontSize="11" FontWeight="Bold" Margin="0,0,4,0" Cursor="Hand" Padding="6,3" BorderThickness="0">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
                <Button x:Name="BtnPostRemoveItem" Content="&#x2715;" ToolTip="Remove from queue"
                        Background="Transparent" Foreground="#6C7086" BorderThickness="0"
                        FontSize="13" FontWeight="Bold" Cursor="Hand" Padding="4,2"/>
            </StackPanel>
        </StackPanel>
    </Grid>
</Border>
"@

    $sReader = New-Object System.IO.StringReader $cardXAML
    $xReader = [System.Xml.XmlReader]::Create($sReader)
    $card = [System.Windows.Markup.XamlReader]::Load($xReader)

    $uiRefs = @{
        Card             = $card
        ImgThumb         = $card.FindName("ImgThumb")
        TxtTitle         = $card.FindName("TxtTitle")
        TxtMeta          = $card.FindName("TxtMeta")
        BadgeTrim        = $card.FindName("BadgeTrim")
        TxtBadgeTrim     = $card.FindName("TxtBadgeTrim")
        BadgeSponsor     = $card.FindName("BadgeSponsor")
        TxtStatus        = $card.FindName("TxtStatus")
        TxtPercent       = $card.FindName("TxtPercent")
        ProgressBar      = $card.FindName("ItemProgressBar")
        PillBadge        = $card.FindName("PillBadge")
        TxtBadge         = $card.FindName("TxtBadge")
        PnlPostActions   = $card.FindName("PnlPostActions")
        BtnPlayItem      = $card.FindName("BtnPlayItem")
        BtnFolderItem    = $card.FindName("BtnFolderItem")
        BtnPostRemove    = $card.FindName("BtnPostRemoveItem")
        PnlPreActions    = $card.FindName("PnlPreActions")
        BtnItemSettings  = $card.FindName("BtnItemSettings")
        BtnRemove        = $card.FindName("BtnRemoveItem")
        CtxPlay          = $card.FindName("CtxPlay")
        CtxShowFolder    = $card.FindName("CtxShowFolder")
        CtxSettings      = $card.FindName("CtxSettings")
        CtxSponsorBlock  = $card.FindName("CtxSponsorBlock")
        CtxCopyUrl       = $card.FindName("CtxCopyUrl")
        CtxRemove        = $card.FindName("CtxRemove")
        ItemId           = $itemData.Id
        Url              = $itemData.Url
        ResultFilePath   = ""
    }

    $uiRefs.TxtTitle.Text = $itemData.Title
    $uiRefs.TxtMeta.Text  = $itemData.Meta

    if ($itemData.ThumbJpg) {
        try {
            $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.UriSource = New-Object System.Uri($itemData.ThumbJpg)
            $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.EndInit()
            $uiRefs.ImgThumb.Source = $bmp
        } catch {}
    }

    # Initial Badge Status
    if ($itemData.SponsorBlock) {
        $uiRefs.BadgeSponsor.Visibility = [System.Windows.Visibility]::Visible
        if ($uiRefs.CtxSponsorBlock) { $uiRefs.CtxSponsorBlock.IsChecked = $true }
    }

    if ($itemData.TrimEnd -or ($itemData.TrimStart -and $itemData.TrimStart -ne "00:00:00")) {
        $uiRefs.BadgeTrim.Visibility = [System.Windows.Visibility]::Visible
        $uiRefs.TxtBadgeTrim.Text = "$([char]0x2702) $($itemData.TrimStart) - $(if ($itemData.TrimEnd) { $itemData.TrimEnd } else { 'End' })"
    }

    # Settings Modal Launcher
    $openSettingsHandler = {
        try {
            Show-VideoSettingsDialog -itemData $itemData -uiRefs $uiRefs
        } catch {
            [System.Windows.MessageBox]::Show("Error opening video settings: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }.GetNewClosure()

    $uiRefs.BtnItemSettings.Add_Click($openSettingsHandler)
    if ($uiRefs.CtxSettings) { $uiRefs.CtxSettings.Add_Click($openSettingsHandler) }

    # Double click card opens settings modal as well
    $card.Add_MouseLeftButtonDown({
        param($s, $e)
        if ($e.ClickCount -ge 2 -and -not $global:EngineState.IsDownloading) {
            Show-VideoSettingsDialog -itemData $itemData -uiRefs $uiRefs
        }
    }.GetNewClosure())

    # SponsorBlock Context Menu Toggle
    if ($uiRefs.CtxSponsorBlock) {
        $uiRefs.CtxSponsorBlock.Add_Click({
            $itemData.SponsorBlock = -not $itemData.SponsorBlock
            if ($itemData.SponsorBlock) {
                $uiRefs.BadgeSponsor.Visibility = [System.Windows.Visibility]::Visible
                $uiRefs.CtxSponsorBlock.IsChecked = $true
            } else {
                $uiRefs.BadgeSponsor.Visibility = [System.Windows.Visibility]::Collapsed
                $uiRefs.CtxSponsorBlock.IsChecked = $false
            }
        }.GetNewClosure())
    }

    # Copy URL Context Menu
    if ($uiRefs.CtxCopyUrl) {
        $uiRefs.CtxCopyUrl.Add_Click({
            try { [System.Windows.Clipboard]::SetText($itemData.Url) } catch {}
        }.GetNewClosure())
    }

    # Play & Show in Folder Handlers
    $playAction = {
        $fp = $uiRefs.ResultFilePath
        if (-not $fp -or -not (Test-Path $fp)) {
            $fp = $itemData.ResultFilePath
        }
        if ($fp -and (Test-Path $fp)) {
            Start-Process $fp
        } elseif ($global:EngineState.ResultDir -and (Test-Path $global:EngineState.ResultDir)) {
            [System.Diagnostics.Process]::Start("explorer.exe", $global:EngineState.ResultDir) | Out-Null
        }
    }.GetNewClosure()

    $folderAction = {
        $fp = $uiRefs.ResultFilePath
        if (-not $fp -or -not (Test-Path $fp)) {
            $fp = $itemData.ResultFilePath
        }
        if ($fp -and (Test-Path $fp)) {
            [System.Diagnostics.Process]::Start("explorer.exe", "/select,`"$fp`"") | Out-Null
        } elseif ($global:EngineState.ResultDir -and (Test-Path $global:EngineState.ResultDir)) {
            [System.Diagnostics.Process]::Start("explorer.exe", $global:EngineState.ResultDir) | Out-Null
        }
    }.GetNewClosure()

    $uiRefs.BtnPlayItem.Add_Click($playAction)
    if ($uiRefs.CtxPlay) { $uiRefs.CtxPlay.Add_Click($playAction) }
    $uiRefs.BtnFolderItem.Add_Click($folderAction)
    if ($uiRefs.CtxShowFolder) { $uiRefs.CtxShowFolder.Add_Click($folderAction) }

    # Remove Item Handlers
    $targetId = $itemData.Id
    $uiRefs.BtnRemove.Tag = $targetId
    if ($uiRefs.BtnPostRemove) { $uiRefs.BtnPostRemove.Tag = $targetId }

    $clickHandler = {
        param($sender, $e)
        $id = if ($sender -and $sender.Tag) { $sender.Tag } else { $targetId }
        if ($id) {
            Remove-QueueItem $id
        }
    }.GetNewClosure()

    $uiRefs.BtnRemove.Add_Click($clickHandler)
    if ($uiRefs.BtnPostRemove) { $uiRefs.BtnPostRemove.Add_Click($clickHandler) }
    if ($uiRefs.CtxRemove) { $uiRefs.CtxRemove.Add_Click($clickHandler) }

    return $uiRefs
}

function Fetch-ItemMetadataAsync($itemData) {
    if (-not (Test-Path $YtDlpExe)) { return }

    $metaRs = [runspacefactory]::CreateRunspace()
    $metaRs.Open()
    $metaPs = [powershell]::Create()
    $metaPs.Runspace = $metaRs

    $metaScript = {
        param($it, $st, $exe)
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = "--no-warnings --no-playlist --dump-json `"$($it.Url)`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $false
        $psi.CreateNoWindow = $true

        try {
            $p = [System.Diagnostics.Process]::Start($psi)
            $raw = $p.StandardOutput.ReadToEnd()
            $p.WaitForExit(9000)

            $jsonLine = ($raw -split "`r?`n" | Where-Object { $_.Trim().StartsWith("{") } | Select-Object -First 1)
            if ($jsonLine) {
                $json = $jsonLine | ConvertFrom-Json
                $st.MetaResults.Enqueue([PSCustomObject]@{
                    Id          = $it.Id
                    Title       = if ($json.title) { $json.title } else { $it.Title }
                    Uploader    = if ($json.uploader) { $json.uploader } else { "Channel" }
                    Duration    = if ($json.duration_string) { $json.duration_string } else { "" }
                    DurationSec = if ($json.duration) { [double]$json.duration } else { 0 }
                    Thumbnail   = if ($json.thumbnail) { $json.thumbnail } else { $it.ThumbJpg }
                    VidId       = if ($json.id) { $json.id } else { $it.YtId }
                })
            }
            $p.Dispose()
        } catch {}
    }

    $metaPs.AddScript($metaScript).AddArgument($itemData).AddArgument($global:EngineState).AddArgument($YtDlpExe) | Out-Null
    $async = $metaPs.BeginInvoke()

    # Clean up runspace when done
    $cleanTimer = New-Object System.Windows.Threading.DispatcherTimer
    $cleanTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    $cleanTimer.add_Tick({
        if ($async.IsCompleted) {
            $cleanTimer.Stop()
            try { $metaPs.EndInvoke($async) } catch {}
            $metaPs.Dispose()
            $metaRs.Close()
            $metaRs.Dispose()
        }
    })
    $cleanTimer.Start()
}

function Add-UrlToQueue([string]$url) {
    $url = $url.Trim()
    if (-not $url) { return }

    # Deduplicate URL in queue
    foreach ($existing in $global:ItemsList) {
        if ($existing.Url -eq $url) {
            return
        }
    }

    $global:ItemIdSeq++
    $itemId = "item_$($global:ItemIdSeq)"

    $ytId = $null
    if ($url -match "(?:\?v=|\/embed\/|\.be\/|\/v\/|\/shorts\/)([a-zA-Z0-9_-]{11})") {
        $ytId = $matches[1]
    }

    $thumbJpg = $null
    if ($ytId) {
        $thumbJpg = "https://img.youtube.com/vi/$ytId/mqdefault.jpg"
    }

    $curCfg = Load-SavedSettings

    $itemData = [PSCustomObject]@{
        Id             = $itemId
        Url            = $url
        YtId           = $ytId
        Title          = if ($ytId) { "YouTube Video ($ytId)" } else { $url }
        Artist         = ""
        Meta           = "Loading metadata..."
        Duration       = ""
        DurationSec    = 0
        ThumbJpg       = $thumbJpg
        Status         = "In Queue"
        Progress       = 0
        TrimStart      = "00:00:00"
        TrimEnd        = ""
        SponsorBlock   = [bool]$curCfg.SponsorBlockDefault
        CustomTitle    = $false
        ResultFilePath = ""
    }

    $global:ItemsList.Add($itemData)

    $uiRefs = Create-QueueCardUI $itemData
    $global:ItemUIMap[$itemId] = $uiRefs

    $EmptyPlaceholder.Visibility = [System.Windows.Visibility]::Collapsed
    $QueueContainer.Children.Add($uiRefs.Card) | Out-Null

    Update-QueueHeader

    # Launch Runspace metadata query
    Fetch-ItemMetadataAsync $itemData
}

function Remove-QueueItem([string]$itemId) {
    if (-not $itemId) { return }

    if ($global:EngineState.IsDownloading -and $global:EngineState.ActiveItemId -eq $itemId) {
        [System.Windows.MessageBox]::Show("This video is currently being downloaded and cannot be removed.", "Notice", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    if ($global:ItemUIMap.ContainsKey($itemId)) {
        $uiRefs = $global:ItemUIMap[$itemId]
        if ($uiRefs -and $uiRefs.Card) {
            $QueueContainer.Children.Remove($uiRefs.Card) | Out-Null
        }
        $global:ItemUIMap.Remove($itemId)
    }

    $removeIdx = -1
    for ($i = 0; $i -lt $global:ItemsList.Count; $i++) {
        if ($global:ItemsList[$i].Id -eq $itemId) {
            $removeIdx = $i
            break
        }
    }
    if ($removeIdx -ge 0) {
        $global:ItemsList.RemoveAt($removeIdx)
    }

    Update-QueueHeader
}

function Update-QueueHeader {
    $count = $global:ItemsList.Count
    $clipIcon = [char]::ConvertFromUtf32(0x1F4CB)
    $plural = if ($count -ne 1) { "s" } else { "" }
    $TxtQueueHeader.Text = "$clipIcon Download Queue ($count Video$plural)"
    if ($count -eq 0) {
        $EmptyPlaceholder.Visibility = [System.Windows.Visibility]::Visible
    } else {
        $EmptyPlaceholder.Visibility = [System.Windows.Visibility]::Collapsed
    }
}

function Set-UIBusyState([bool]$downloading, [string]$status = "") {
    $global:EngineState.IsDownloading = $downloading
    $BtnStartDownload.IsEnabled = -not $downloading
    $BtnCancel.IsEnabled        = $downloading
    $BtnAddUrls.IsEnabled       = -not $downloading
    $BtnPaste.IsEnabled         = -not $downloading
    $BtnClearAll.IsEnabled      = -not $downloading
    $CmbFormat.IsEnabled        = -not $downloading
    $BtnBrowsePath.IsEnabled    = -not $downloading
    $BtnUpdateCheck.IsEnabled   = -not $downloading

    if ($status) {
        $TxtOverallStatus.Text = $status
        $TxtFooter.Text        = $status
    }

    if ($downloading) {
        $TxtPillStatus.Text = "Running..."
        $TxtPillStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F9E2AF")
    } else {
        $TxtPillStatus.Text = "Ready"
        $TxtPillStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A6E3A1")
    }
}

# ------------------------------------------------------------------------------
# MAIN UI DISPATCHER TIMER (50ms Update Loop)
# ------------------------------------------------------------------------------
$mainTimer = New-Object System.Windows.Threading.DispatcherTimer
$mainTimer.Interval = [TimeSpan]::FromMilliseconds(50)
$mainTimer.add_Tick({
    # 1. Process Metadata Results
    $res = $null
    while ($global:EngineState.MetaResults.TryDequeue([ref]$res)) {
        if ($res -and $global:ItemUIMap.ContainsKey($res.Id)) {
            $ui = $global:ItemUIMap[$res.Id]
            $itemMatch = @($global:ItemsList) | Where-Object { $_.Id -eq $res.Id } | Select-Object -First 1

            if ($itemMatch) {
                if (-not $itemMatch.CustomTitle) {
                    $itemMatch.Title = $res.Title
                    $ui.TxtTitle.Text = $res.Title
                }
                if ($res.Uploader -and -not $itemMatch.Artist) {
                    $itemMatch.Artist = $res.Uploader
                }
                $itemMatch.Duration = $res.Duration
                $itemMatch.DurationSec = $res.DurationSec
            }

            $bullet = [char]0x2022
            $durStr = if ($res.Duration) { " $bullet Duration: $($res.Duration)" } else { "" }
            $ui.TxtMeta.Text  = "$($res.Uploader)$durStr"

            $thumbUrl = $res.Thumbnail
            if ($res.VidId) {
                $thumbUrl = "https://img.youtube.com/vi/$($res.VidId)/hqdefault.jpg"
            }
            if ($thumbUrl) {
                try {
                    $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
                    $bmp.BeginInit()
                    $bmp.UriSource = New-Object System.Uri($thumbUrl)
                    $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                    $bmp.EndInit()
                    $ui.ImgThumb.Source = $bmp
                } catch {}
            }
        }
    }

    # 2. Update Active Item Progress
    if ($global:EngineState.IsDownloading -and $global:EngineState.ActiveItemId) {
        $activeId = $global:EngineState.ActiveItemId
        if ($global:ItemUIMap.ContainsKey($activeId)) {
            $ui = $global:ItemUIMap[$activeId]
            $pct = $global:EngineState.CurrentItemPct
            $ui.ProgressBar.Value = $pct
            $ui.TxtPercent.Text   = "$([math]::Round($pct)) %"

            $speed = $global:EngineState.CurrentItemSpeed
            $eta   = $global:EngineState.CurrentItemEta
            $bullet = [char]0x2022
            $detailStr = if ($speed) { " $bullet $speed" } else { "" }
            $etaStr    = if ($eta) { " (ETA $eta)" } else { "" }
            $ui.TxtStatus.Text = "Downloading: $([math]::Round($pct))%$detailStr$etaStr"

            $ui.PillBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F9E2AF")
            $ui.TxtBadge.Text = "Running"
            $ui.TxtBadge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11111B")
        }
    }

    # 3. Process Completed Items
    while ($global:EngineState.CompletedItems.Count -gt 0) {
        $cId = $global:EngineState.CompletedItems[0]
        $global:EngineState.CompletedItems.RemoveAt(0)
        if ($global:ItemUIMap.ContainsKey($cId)) {
            $ui = $global:ItemUIMap[$cId]
            $ui.ProgressBar.Value = 100
            $ui.TxtPercent.Text   = "100 %"
            $checkIcon = [char]0x2714
            $ui.TxtStatus.Text    = "$checkIcon Completed successfully"
            $ui.PillBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A6E3A1")
            $ui.TxtBadge.Text = "Done"
            $ui.TxtBadge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11111B")

            if ($global:EngineState.ResultFileMap.ContainsKey($cId)) {
                $ui.ResultFilePath = $global:EngineState.ResultFileMap[$cId]
            }
            if ($ui.PnlPostActions) {
                $ui.PnlPostActions.Visibility = [System.Windows.Visibility]::Visible
            }
            if ($ui.PnlPreActions) {
                $ui.PnlPreActions.Visibility = [System.Windows.Visibility]::Collapsed
            }
        }
    }

    # 4. Process Failed Items
    while ($global:EngineState.FailedItems.Count -gt 0) {
        $fId = $global:EngineState.FailedItems[0]
        $global:EngineState.FailedItems.RemoveAt(0)
        if ($global:ItemUIMap.ContainsKey($fId)) {
            $ui = $global:ItemUIMap[$fId]
            $crossIcon = [char]0x2716
            $ui.TxtStatus.Text    = "$crossIcon Failed or cancelled"
            $ui.PillBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F38BA8")
            $ui.TxtBadge.Text = "Error"
            $ui.TxtBadge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11111B")
        }
    }

    # 5. Handle All Completed
    if ($global:EngineState.Finished) {
        $global:EngineState.Finished = $false
        
        if ($global:EngineState.Powershell) {
            try { $global:EngineState.Powershell.Dispose() } catch {}
            $global:EngineState.Powershell = $null
        }
        if ($global:EngineState.Runspace) {
            try {
                $global:EngineState.Runspace.Close()
                $global:EngineState.Runspace.Dispose()
            } catch {}
            $global:EngineState.Runspace = $null
        }

        $destDir = $global:EngineState.ResultDir

        if ($global:EngineState.CancelRequested) {
            Set-UIBusyState -downloading $false -status "Download cancelled."
        } else {
            Set-UIBusyState -downloading $false -status "All downloads completed!"
            Show-WindowsNotification -title "Media Downloader" -message "All downloads in the queue have been completed successfully!" -folderPath $destDir
            [System.Windows.MessageBox]::Show("All downloads in the queue have been completed!`n`nSaved to:`n$destDir", "Completed!", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    }
})
$mainTimer.Start()

# ------------------------------------------------------------------------------
# CLIPBOARD AUTO-MONITOR TIMER (Triggers strictly ONCE per copy event)
# ------------------------------------------------------------------------------
$global:LastClipboardSeq = 0
try {
    $global:LastClipboardSeq = [Win32.Win32Console]::GetClipboardSequenceNumber()
} catch {}

$clipTimer = New-Object System.Windows.Threading.DispatcherTimer
$clipTimer.Interval = [TimeSpan]::FromMilliseconds(500)
$clipTimer.add_Tick({
    $cfg = Load-SavedSettings
    if ($cfg.AutoClipboard) {
        try {
            $curSeq = [Win32.Win32Console]::GetClipboardSequenceNumber()
            if ($curSeq -ne $global:LastClipboardSeq) {
                $global:LastClipboardSeq = $curSeq
                if ([System.Windows.Clipboard]::ContainsText()) {
                    $clip = [System.Windows.Clipboard]::GetText().Trim()
                    if ($clip) {
                        $urlMatches = [regex]::Matches($clip, "https?://[^\s""'<>]+")
                        foreach ($m in $urlMatches) {
                            $foundUrl = $m.Value
                            if ($foundUrl) {
                                Add-UrlToQueue $foundUrl
                            }
                        }
                    }
                }
            }
        } catch {}
    }
})
$clipTimer.Start()

# ------------------------------------------------------------------------------
# EVENT HANDLERS
# ------------------------------------------------------------------------------

# App Settings Button
$BtnAppSettings.Add_Click({
    Show-ProgramSettingsDialog
})

# Add Links
$BtnAddUrls.Add_Click({
    $raw = $TxtUrls.Text.Trim()
    if ($raw) {
        $lines = $raw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
        foreach ($line in $lines) {
            Add-UrlToQueue $line
        }
        $TxtUrls.Text = ""
    }
})

# Paste Button (Pastes clipboard into the input field and focuses it)
$BtnPaste.Add_Click({
    try {
        if ([System.Windows.Clipboard]::ContainsText()) {
            $clipText = [System.Windows.Clipboard]::GetText().Trim()
            if ($clipText) {
                $TxtUrls.Text = $clipText
                $TxtUrls.Focus() | Out-Null
            }
        }
    } catch {}
})

# Clear List
$BtnClearAll.Add_Click({
    if ($global:EngineState.IsDownloading) {
        [System.Windows.MessageBox]::Show("Downloads are currently running. Please cancel them first.", "Notice", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    $QueueContainer.Children.Clear()
    $global:ItemsList.Clear()
    $global:ItemUIMap.Clear()
    $TxtUrls.Text = ""
    Update-QueueHeader
})

# Browse Folder
$BtnBrowsePath.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.SelectedPath = $TxtDownloadPath.Text
    $dialog.Description = "Select destination folder for downloads"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtDownloadPath.Text = $dialog.SelectedPath
        Save-AppSettings -downloadPath $dialog.SelectedPath -formatIdx $CmbFormat.SelectedIndex -speedIdx $CmbSpeedLimit.SelectedIndex
    }
})

# Settings changes
$saveSettingsHandler = {
    Save-AppSettings -downloadPath $TxtDownloadPath.Text -formatIdx $CmbFormat.SelectedIndex -speedIdx $CmbSpeedLimit.SelectedIndex
}
$CmbFormat.Add_SelectionChanged($saveSettingsHandler)
$CmbSpeedLimit.Add_SelectionChanged($saveSettingsHandler)
$ChkEmbedThumbnail.Add_Checked($saveSettingsHandler)
$ChkEmbedThumbnail.Add_Unchecked($saveSettingsHandler)
$ChkEmbedMetadata.Add_Checked($saveSettingsHandler)
$ChkEmbedMetadata.Add_Unchecked($saveSettingsHandler)
$ChkDownloadPlaylist.Add_Checked($saveSettingsHandler)
$ChkDownloadPlaylist.Add_Unchecked($saveSettingsHandler)
$ChkEmbedSubs.Add_Checked($saveSettingsHandler)
$ChkEmbedSubs.Add_Unchecked($saveSettingsHandler)

# Open Folder
$BtnOpenFolder.Add_Click({
    $path = $TxtDownloadPath.Text
    if (Test-Path $path) {
        [System.Diagnostics.Process]::Start("explorer.exe", $path) | Out-Null
    } else {
        [System.Windows.MessageBox]::Show("Folder does not exist yet!", "Notice", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
})

# ------------------------------------------------------------------------------
# AUTO-UPDATE & MODAL DIALOGS (Styled Catppuccin Theme)
# ------------------------------------------------------------------------------
function Show-ModernInfoDialog([string]$title, [string]$message, [string]$statusType = "info") {
    $icon = switch ($statusType) {
        "success" { "&#x2714;" }
        "warning" { "&#x26A0;" }
        "error"   { "&#x2716;" }
        default   { "&#x2139;" }
    }
    $iconColor = switch ($statusType) {
        "success" { "#A6E3A1" }
        "warning" { "#F9E2AF" }
        "error"   { "#F38BA8" }
        default   { "#89B4FA" }
    }

    $infoXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$title" Width="440" Height="220"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent"
        FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol">
    <Border Background="#1E1E2E" CornerRadius="12" BorderBrush="#45475A" BorderThickness="1.5">
        <Border.Effect>
            <DropShadowEffect BlurRadius="25" ShadowDepth="4" Direction="270" Color="#000000" Opacity="0.7"/>
        </Border.Effect>
        <Grid Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
                <TextBlock Text="$icon" FontSize="18" Foreground="$iconColor" Margin="0,0,8,0" VerticalAlignment="Center"/>
                <TextBlock Text="$title" FontSize="16" FontWeight="Bold" Foreground="#CDD6F4" VerticalAlignment="Center"/>
            </StackPanel>
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,14">
                <TextBlock Text="$([System.Security.SecurityElement]::Escape($message))" FontSize="12" Foreground="#BAC2DE" TextWrapping="Wrap" LineHeight="18"/>
            </ScrollViewer>
            <Button x:Name="BtnOk" Grid.Row="2" Content="OK" HorizontalAlignment="Right" Width="90" Height="32"
                    Background="#89B4FA" Foreground="#11111B" FontSize="12" FontWeight="Bold" BorderThickness="0" Cursor="Hand">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#B4BEFE"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>
        </Grid>
    </Border>
</Window>
"@
    $sReader = New-Object System.IO.StringReader $infoXaml
    $xReader = [System.Xml.XmlReader]::Create($sReader)
    $infoWindow = [System.Windows.Markup.XamlReader]::Load($xReader)
    $infoWindow.Owner = $window

    $infoWindow.Add_MouseLeftButtonDown({
        try { $infoWindow.DragMove() } catch {}
    })
    $BtnOk = $infoWindow.FindName("BtnOk")
    $BtnOk.Add_Click({ $infoWindow.Close() })
    $infoWindow.ShowDialog() | Out-Null
}

function Show-ModernUpdatePopup($remoteMeta, $currentVersion, $scriptUrl) {
    $dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Update Available - Media Downloader"
        Width="500" Height="420"
        WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol">
    
    <Border Background="#1E1E2E" CornerRadius="12" BorderBrush="#45475A" BorderThickness="1.5">
        <Border.Effect>
            <DropShadowEffect BlurRadius="30" ShadowDepth="6" Direction="270" Color="#000000" Opacity="0.7"/>
        </Border.Effect>
        <Grid Margin="22">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/> <!-- 0: Header -->
                <RowDefinition Height="Auto"/> <!-- 1: Version Badges -->
                <RowDefinition Height="*"/>    <!-- 2: Changelog Card -->
                <RowDefinition Height="Auto"/> <!-- 3: Progress/Status -->
                <RowDefinition Height="Auto"/> <!-- 4: Bottom Buttons -->
            </Grid.RowDefinitions>

            <!-- Header -->
            <Grid Grid.Row="0" Margin="0,0,0,14">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#x26A1;" FontSize="20" Foreground="#89B4FA" Margin="0,0,8,0" VerticalAlignment="Center"/>
                    <TextBlock Text="New Version Available!" FontSize="17" FontWeight="Bold" Foreground="#CDD6F4" VerticalAlignment="Center"/>
                </StackPanel>
                <Button x:Name="DlgBtnClose" Content="&#x2715;" HorizontalAlignment="Right" VerticalAlignment="Center"
                        Background="Transparent" Foreground="#6C7086" BorderThickness="0" FontSize="14" FontWeight="Bold" Cursor="Hand" Padding="6,2">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="cb" Background="Transparent" CornerRadius="4" Padding="{TemplateBinding Padding}">
                                <TextBlock x:Name="ct" Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="cb" Property="Background" Value="#313244"/>
                                    <Setter TargetName="ct" Property="Foreground" Value="#F38BA8"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
            </Grid>

            <!-- Version Badges -->
            <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,14" VerticalAlignment="Center">
                <Border Background="#313244" CornerRadius="6" Padding="10,4">
                    <TextBlock x:Name="DlgTxtOldVer" Text="Current: v$currentVersion" FontSize="12" Foreground="#BAC2DE"/>
                </Border>
                <TextBlock Text="&#x2794;" FontSize="13" Foreground="#89B4FA" Margin="10,0" VerticalAlignment="Center" FontWeight="Bold"/>
                <Border Background="#A6E3A1" CornerRadius="6" Padding="10,4">
                    <TextBlock x:Name="DlgTxtNewVer" Text="New: v$($remoteMeta.version)" FontSize="12" FontWeight="Bold" Foreground="#11111B"/>
                </Border>
            </StackPanel>

            <!-- Changelog Card -->
            <Border Grid.Row="2" Background="#181825" CornerRadius="8" BorderBrush="#313244" BorderThickness="1" Padding="12" Margin="0,0,0,14">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="&#x1F4CB; What's new in this release:" FontWeight="SemiBold" FontSize="12" Foreground="#89B4FA" Margin="0,0,0,6"/>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                        <TextBlock x:Name="DlgTxtChangelog" Text="$([System.Security.SecurityElement]::Escape($remoteMeta.changelog))" FontSize="12" Foreground="#CDD6F4" TextWrapping="Wrap" LineHeight="18"/>
                    </ScrollViewer>
                </Grid>
            </Border>

            <!-- Progress / Status Area -->
            <StackPanel x:Name="DlgPnlProgress" Grid.Row="3" Margin="0,0,0,12" Visibility="Collapsed">
                <TextBlock x:Name="DlgTxtStatus" Text="Downloading update..." FontSize="12" Foreground="#89B4FA" Margin="0,0,0,6"/>
                <ProgressBar Height="5" IsIndeterminate="True" Foreground="#89B4FA" Background="#313244" BorderThickness="0">
                    <ProgressBar.Clip>
                        <RectangleGeometry RadiusX="2.5" RadiusY="2.5" Rect="0,0,450,5"/>
                    </ProgressBar.Clip>
                </ProgressBar>
            </StackPanel>

            <!-- Bottom Buttons -->
            <Grid Grid.Row="4">
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <Button x:Name="DlgBtnLater" Content="Later" Width="90" Height="34" Margin="0,0,10,0"
                            Background="#313244" Foreground="#CDD6F4" FontSize="12" FontWeight="SemiBold" BorderThickness="0" Cursor="Hand">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="6">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="b" Property="Background" Value="#45475A"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>

                    <Button x:Name="DlgBtnUpdate" Content="&#x1F680; Update &amp; Restart" Width="170" Height="34"
                            Background="#89B4FA" Foreground="#11111B" FontSize="12" FontWeight="Bold" BorderThickness="0" Cursor="Hand">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="6">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="b" Property="Background" Value="#B4BEFE"/>
                                    </Trigger>
                                    <Trigger Property="IsEnabled" Value="False">
                                        <Setter TargetName="b" Property="Background" Value="#45475A"/>
                                        <Setter Property="Foreground" Value="#6C7086"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </StackPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

    $sReader = New-Object System.IO.StringReader $dialogXaml
    $xReader = [System.Xml.XmlReader]::Create($sReader)
    $dlgWindow = [System.Windows.Markup.XamlReader]::Load($xReader)
    $dlgWindow.Owner = $window

    # Drag window
    $dlgWindow.Add_MouseLeftButtonDown({
        try { $dlgWindow.DragMove() } catch {}
    })

    $DlgBtnClose       = $dlgWindow.FindName("DlgBtnClose")
    $DlgBtnLater       = $dlgWindow.FindName("DlgBtnLater")
    $DlgBtnUpdate      = $dlgWindow.FindName("DlgBtnUpdate")
    $DlgPnlProgress    = $dlgWindow.FindName("DlgPnlProgress")
    $DlgTxtStatus      = $dlgWindow.FindName("DlgTxtStatus")

    $DlgBtnClose.Add_Click({ $dlgWindow.Close() })
    $DlgBtnLater.Add_Click({ $dlgWindow.Close() })

    $DlgBtnUpdate.Add_Click({
        $DlgBtnUpdate.IsEnabled = $false
        $DlgBtnLater.IsEnabled  = $false
        $DlgBtnClose.IsEnabled  = $false
        $DlgPnlProgress.Visibility = [System.Windows.Visibility]::Visible
        $DlgTxtStatus.Text = "Downloading update package from GitHub..."

        $zipUrl = "https://github.com/$GitHubRepo/archive/refs/heads/main.zip"
        $tempZip = Join-Path $env:TEMP "MediaDownloader_update.zip"
        $tempExt = Join-Path $env:TEMP "MediaDownloader_extracted"

        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem

            $wcDownload = New-Object System.Net.WebClient
            $wcDownload.Headers.Add("User-Agent", "MediaDownloader-Updater")
            $wcDownload.DownloadFile($zipUrl, $tempZip)
            $wcDownload.Dispose()

            if (Test-Path $tempExt) {
                Remove-Item -Path $tempExt -Recurse -Force -ErrorAction SilentlyContinue
            }

            [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExt)

            # Find extracted folder (e.g. MediaDownloader-main)
            $extractedInner = Get-ChildItem -Path $tempExt | Where-Object { $_.PSIsContainer } | Select-Object -First 1
            $sourceDir = if ($extractedInner) { $extractedInner.FullName } else { $tempExt }

            $DlgTxtStatus.Text = "Updating files and folders..."

            # 1. Update/Create core/ directory
            $targetCore = Join-Path $RootDir "core"
            $srcCore = Join-Path $sourceDir "core"
            if (Test-Path $srcCore) {
                if (-not (Test-Path $targetCore)) { New-Item -ItemType Directory -Path $targetCore -Force | Out-Null }
                Get-ChildItem -Path $srcCore -File | ForEach-Object {
                    Copy-Item -Path $_.FullName -Destination (Join-Path $targetCore $_.Name) -Force
                }
            }

            # 2. Update Root files (MediaDownloader.bat, README.md, version.json)
            $rootFiles = @("MediaDownloader.bat", "version.json", "README.md", ".gitignore")
            foreach ($rf in $rootFiles) {
                $srcFile = Join-Path $sourceDir $rf
                if (Test-Path $srcFile) {
                    Copy-Item -Path $srcFile -Destination (Join-Path $RootDir $rf) -Force
                }
            }

            # 3. Clean up legacy root files if upgrading from older versions (e.g. Start.vbs, Start.bat)
            $legacyFiles = @("Start.vbs", "Start.bat", "Start-MediaDownloader.bat", "Start-MediaDownloader.vbs")
            foreach ($lf in $legacyFiles) {
                $legacyPath = Join-Path $RootDir $lf
                if (Test-Path $legacyPath) {
                    Remove-Item -Path $legacyPath -Force -ErrorAction SilentlyContinue
                }
            }

            # 4. Clean up temporary download files
            Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $tempExt -Recurse -Force -ErrorAction SilentlyContinue

            $DlgTxtStatus.Text = "Restarting application..."

            # 5. Relaunch
            $batStarter = Join-Path $RootDir "MediaDownloader.bat"
            $vbsStarter = Join-Path $targetCore "launcher.vbs"

            if (Test-Path $batStarter) {
                Start-Process "cmd.exe" -ArgumentList "/c `"$batStarter`"" -WindowStyle Hidden
            } elseif (Test-Path $vbsStarter) {
                Start-Process "wscript.exe" -ArgumentList "`"$vbsStarter`""
            } else {
                $newScript = Join-Path $targetCore "MediaDownloader.ps1"
                Start-Process "powershell.exe" -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$newScript`""
            }

            $dlgWindow.Close()
            $window.Close()
        } catch {
            # Fallback to single-file script update if zip extraction fails
            $DlgTxtStatus.Text = "Fallback: Updating script..."
            try {
                $targetFile = $MyInvocation.MyCommand.Path
                if (-not $targetFile) { $targetFile = Join-Path $ScriptDir "MediaDownloader.ps1" }
                $tempFile = Join-Path $env:TEMP "MediaDownloader_update.ps1"
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($scriptUrl, $tempFile)
                $wc.Dispose()
                if ((Test-Path $tempFile) -and (Get-Item $tempFile).Length -gt 5000) {
                    Copy-Item -Path $tempFile -Destination $targetFile -Force
                    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                    Start-Process "powershell.exe" -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$targetFile`""
                    $dlgWindow.Close()
                    $window.Close()
                    return
                }
            } catch {}

            $DlgTxtStatus.Text = "Error: $($_.Exception.Message)"
            $DlgBtnLater.IsEnabled = $true
        }
    })

    $dlgWindow.ShowDialog() | Out-Null
}

function Check-Updates([bool]$silentIfCurrent = $false) {
    $TxtFooter.Text = "Checking for updates..."

    # 1. Update yt-dlp & FFmpeg Tools in background
    $setupScript = Join-Path $ScriptDir "Setup-Dependencies.ps1"
    if (Test-Path $setupScript) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$setupScript`" -ForceUpdate" -WindowStyle Hidden
    }

    # 2. Check GitHub for Media Downloader App Update
    $cacheBust     = [System.Guid]::NewGuid().ToString("N")
    $updateJsonUrl = "https://raw.githubusercontent.com/$GitHubRepo/main/version.json?cb=$cacheBust"
    $scriptUrl     = "https://raw.githubusercontent.com/$GitHubRepo/main/core/MediaDownloader.ps1?cb=$cacheBust"

    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "MediaDownloader-Updater")
        $wc.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
        $wc.Headers.Add("Pragma", "no-cache")
        $jsonStr = $wc.DownloadString($updateJsonUrl)
        $wc.Dispose()

        $remoteMeta = $jsonStr | ConvertFrom-Json
        $remoteVer = [version]$remoteMeta.version
        $currentVer = [version]$AppVersion

        if ($remoteVer -gt $currentVer) {
            Show-ModernUpdatePopup -remoteMeta $remoteMeta -currentVersion $AppVersion -scriptUrl $scriptUrl
        } else {
            if (-not $silentIfCurrent) {
                Show-ModernInfoDialog -title "Up to Date" -message "Media Downloader and all tools are fully up to date! (v$AppVersion)" -statusType "success"
            }
        }
    } catch {
        if (-not $silentIfCurrent) {
            $errText = $_.Exception.Message
            if ($errText -match "404") {
                $errText = "Repository is currently Private or version.json is not yet published.`n`nTo allow your friends and the app to check for updates, set your repository visibility to 'Public' on GitHub (Settings -> Change visibility)."
            }
            Show-ModernInfoDialog -title "Update Status" -message "yt-dlp and FFmpeg are being updated in the background.`n`nGitHub check note:`n$errText" -statusType "info"
        }
    }

    $bullet = [char]0x2022
    $TxtFooter.Text = "Media Downloader $bullet Ready"
}

# Check for updates
$BtnUpdateCheck.Add_Click({
    Check-Updates -silentIfCurrent $false
})

# Cancel
$BtnCancel.Add_Click({
    if ($global:EngineState.IsDownloading) {
        $global:EngineState.CancelRequested = $true
        $procId = $global:EngineState.CurrentProcessId
        if ($procId -gt 0) {
            try {
                Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }
})

# ------------------------------------------------------------------------------
# DOWNLOAD QUEUE ENGINE (Runs in pure isolated background Runspace)
# ------------------------------------------------------------------------------
$BtnStartDownload.Add_Click({
    if ($global:ItemsList.Count -eq 0) {
        $raw = $TxtUrls.Text.Trim()
        if ($raw) {
            $lines = $raw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
            foreach ($line in $lines) { Add-UrlToQueue $line }
            $TxtUrls.Text = ""
        }
    }

    if ($global:ItemsList.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please add at least one video link to the queue!", "Queue is empty", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    if (-not (Test-Path $YtDlpExe) -or -not (Test-Path $FfmpegExe)) {
        # Auto-download missing tools on first run
        $setupScript = Join-Path $ScriptDir "Setup-Dependencies.ps1"
        if (Test-Path $setupScript) {
            $TxtFooter.Text = "Downloading required tools..."
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$setupScript"
        }
        if (-not (Test-Path $YtDlpExe) -or -not (Test-Path $FfmpegExe)) {
            [System.Windows.MessageBox]::Show("yt-dlp or ffmpeg is missing in the bin folder.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
    }

    $downloadDir = $TxtDownloadPath.Text
    if (-not (Test-Path $downloadDir)) {
        New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    }
    Save-AppSettings -downloadPath $downloadDir -formatIdx $CmbFormat.SelectedIndex -speedIdx $CmbSpeedLimit.SelectedIndex

    $selectedTag      = $CmbFormat.SelectedItem.Tag
    $selectedSpeedTag = if ($CmbSpeedLimit.SelectedItem -and $CmbSpeedLimit.SelectedItem.Tag) { $CmbSpeedLimit.SelectedItem.Tag.ToString() } else { "" }
    $embedThumb       = [bool]$ChkEmbedThumbnail.IsChecked
    $embedMeta        = [bool]$ChkEmbedMetadata.IsChecked
    $downloadPlaylist = [bool]$ChkDownloadPlaylist.IsChecked
    $embedSubs        = [bool]$ChkEmbedSubs.IsChecked

    # Snap snapshot of current items list for the worker with UI inputs
    $snapshotItems = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($it in $global:ItemsList) {
        $trimStart = $it.TrimStart
        $trimEnd   = $it.TrimEnd

        $isTrimmed = $false
        if ($trimEnd -and $trimEnd -ne "" -and $trimEnd -ne "inf") {
            $isTrimmed = $true
        } elseif ($trimStart -and $trimStart -ne "" -and $trimStart -ne "00:00:00" -and $trimStart -ne "00:00" -and $trimStart -ne "0" -and $trimStart -ne "0:00") {
            $isTrimmed = $true
        }

        $snapshotItems.Add([PSCustomObject]@{
            Id           = $it.Id
            Url          = $it.Url
            Title        = $it.Title
            Artist       = $it.Artist
            IsTrimmed    = $isTrimmed
            TrimStart    = if ($trimStart) { $trimStart } else { "00:00:00" }
            TrimEnd      = if ($trimEnd) { $trimEnd } else { "inf" }
            SponsorBlock = [bool]$it.SponsorBlock
            CustomTitle  = [bool]$it.CustomTitle
        })
    }

    Set-UIBusyState -downloading $true -status "Starting download queue..."
    $global:EngineState.CancelRequested = $false
    $global:EngineState.Finished        = $false
    $global:EngineState.ResultDir       = $downloadDir
    $global:EngineState.CompletedItems.Clear()
    $global:EngineState.FailedItems.Clear()

    $taskConfig = [PSCustomObject]@{
        Items            = $snapshotItems
        DownloadDir      = $downloadDir
        SelectedTag      = $selectedTag
        SpeedLimit       = $selectedSpeedTag
        EmbedThumb       = $embedThumb
        EmbedMeta        = $embedMeta
        DownloadPlaylist = $downloadPlaylist
        EmbedSubs        = $embedSubs
        BinDir           = $BinDir
        YtDlpExe         = $YtDlpExe
    }

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    $global:EngineState.Runspace   = $runspace
    $global:EngineState.Powershell = $ps

    $queueWorkerScript = {
        param($cfg, $state)

        $itemsList = $cfg.Items
        $total = $itemsList.Count
        $idx = 0

        foreach ($item in $itemsList) {
            if ($state.CancelRequested) { break }

            $idx++
            $state.ActiveItemId     = $item.Id
            $state.CurrentItemPct   = 0
            $state.CurrentItemSpeed = ""
            $state.CurrentItemEta   = ""

            $argsList = [System.Collections.Generic.List[string]]::new()
            $argsList.Add("--ffmpeg-location")
            $argsList.Add($cfg.BinDir)
            $argsList.Add("-P")
            $argsList.Add($cfg.DownloadDir)

            if ($item.CustomTitle -and $item.Title) {
                $argsList.Add("-o")
                $argsList.Add("$($item.Title).%(ext)s")
            } else {
                $argsList.Add("-o")
                $argsList.Add("%(title)s.%(ext)s")
            }

            if ($cfg.SpeedLimit) {
                $argsList.Add("--limit-rate")
                $argsList.Add($cfg.SpeedLimit)
            }

            if ($item.SponsorBlock) {
                $argsList.Add("--sponsorblock-remove")
                $argsList.Add("sponsor,intro,outro,selfpromo")
            }

            if ($item.IsTrimmed) {
                $tStart = if ($item.TrimStart) { $item.TrimStart } else { "00:00:00" }
                $tEnd   = if ($item.TrimEnd -and $item.TrimEnd -ne "inf") { $item.TrimEnd } else { "inf" }
                $argsList.Add("--download-sections")
                $argsList.Add("*${tStart}-${tEnd}")
                $argsList.Add("--force-keyframes-at-cuts")
            }

            if ($cfg.DownloadPlaylist) {
                $argsList.Add("--yes-playlist")
            } else {
                $argsList.Add("--no-playlist")
            }

            if ($cfg.EmbedMeta) {
                $argsList.Add("--add-metadata")
            }

            if ($item.Artist) {
                $argsList.Add("--parse-metadata")
                $argsList.Add("$($item.Artist):%(artist)s")
                $argsList.Add("--parse-metadata")
                $argsList.Add("$($item.Artist):%(uploader)s")
            }

            switch ($cfg.SelectedTag) {
                "mp3_best" {
                    $argsList.Add("-x")
                    $argsList.Add("--audio-format")
                    $argsList.Add("mp3")
                    $argsList.Add("--audio-quality")
                    $argsList.Add("0")
                    if ($cfg.EmbedThumb) { $argsList.Add("--embed-thumbnail") }
                }
                "m4a_best" {
                    $argsList.Add("-x")
                    $argsList.Add("--audio-format")
                    $argsList.Add("m4a")
                    $argsList.Add("--audio-quality")
                    $argsList.Add("0")
                    if ($cfg.EmbedThumb) { $argsList.Add("--embed-thumbnail") }
                }
                "wav_best" {
                    $argsList.Add("-x")
                    $argsList.Add("--audio-format")
                    $argsList.Add("wav")
                }
                "flac_best" {
                    $argsList.Add("-x")
                    $argsList.Add("--audio-format")
                    $argsList.Add("flac")
                    if ($cfg.EmbedThumb) { $argsList.Add("--embed-thumbnail") }
                }
                "mp4_best" {
                    $argsList.Add("-f")
                    $argsList.Add("bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best")
                    $argsList.Add("--merge-output-format")
                    $argsList.Add("mp4")
                    if ($cfg.EmbedThumb) { $argsList.Add("--embed-thumbnail") }
                    if ($cfg.EmbedSubs) {
                        $argsList.Add("--write-auto-subs")
                        $argsList.Add("--embed-subs")
                    }
                }
                "mp4_1080p" {
                    $argsList.Add("-f")
                    $argsList.Add("bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080]+bestaudio/best[height<=1080]/best")
                    $argsList.Add("--merge-output-format")
                    $argsList.Add("mp4")
                    if ($cfg.EmbedThumb) { $argsList.Add("--embed-thumbnail") }
                    if ($cfg.EmbedSubs) {
                        $argsList.Add("--write-auto-subs")
                        $argsList.Add("--embed-subs")
                    }
                }
                "mp4_720p" {
                    $argsList.Add("-f")
                    $argsList.Add("bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=720]+bestaudio/best[height<=720]/best")
                    $argsList.Add("--merge-output-format")
                    $argsList.Add("mp4")
                    if ($cfg.EmbedThumb) { $argsList.Add("--embed-thumbnail") }
                    if ($cfg.EmbedSubs) {
                        $argsList.Add("--write-auto-subs")
                        $argsList.Add("--embed-subs")
                    }
                }
            }

            $argsList.Add("--no-keep-video")
            $argsList.Add("--windows-filenames")
            $argsList.Add("--newline")
            $argsList.Add("--progress")
            $argsList.Add("--progress-template")
            $argsList.Add("download:[PROGRESS] %(progress._percent_str)s of %(progress._total_bytes_str)s at %(progress._speed_str)s (ETA %(progress._eta_str)s)")
            $argsList.Add($item.Url)

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $cfg.YtDlpExe
            $psi.Arguments = ($argsList | ForEach-Object {
                if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
            }) -join " "
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $false
            $psi.CreateNoWindow = $true

            try {
                $proc = [System.Diagnostics.Process]::Start($psi)
                $state.CurrentProcessId = $proc.Id

                while (-not $proc.StandardOutput.EndOfStream) {
                    $line = $proc.StandardOutput.ReadLine()
                    if ($line) {
                        if ($line -match "\[PROGRESS\]\s+([\d\.]+)%") {
                            $state.CurrentItemPct = [double]$matches[1]
                            if ($line -match "at\s+([^\s]+)") { $state.CurrentItemSpeed = $matches[1] }
                            if ($line -match "\(ETA\s+([^\)]+)\)") { $state.CurrentItemEta = $matches[1] }
                        }
                        if ($line -match '\[(?:Merger|ExtractAudio|download)\]\s+(?:Merging formats into |Destination: )?"?([^"]+\.(?:mp3|mp4|m4a|wav|flac|webm|mkv))"?') {
                            $foundPath = $matches[1].Trim('"')
                            if (-not [System.IO.Path]::IsPathRooted($foundPath)) {
                                $foundPath = [System.IO.Path]::Combine($cfg.DownloadDir, $foundPath)
                            }
                            $state.ResultFileMap[$item.Id] = $foundPath
                        }
                    }
                }

                $proc.WaitForExit()
                $exitCode = $proc.ExitCode
                $state.CurrentProcessId = 0

                if ($exitCode -eq 0) {
                    # Untrimmed file cleanup: If this item was trimmed, ensure only the trimmed output remains in download dir
                    if ($item.IsTrimmed -and $state.ResultFileMap.ContainsKey($item.Id)) {
                        try {
                            $trimmedFile = $state.ResultFileMap[$item.Id]
                            if ($trimmedFile -and (Test-Path $trimmedFile)) {
                                $trimmedFileInfo = Get-Item $trimmedFile
                                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($trimmedFile)
                                $dirName  = [System.IO.Path]::GetDirectoryName($trimmedFile)

                                $allMatching = Get-ChildItem -Path $dirName -File | Where-Object {
                                    $_.FullName -ne $trimmedFile -and
                                    ($_.BaseName -eq $baseName -or $_.BaseName -eq $item.Title -or $_.Name -like "$baseName.*" -or $_.Name -like "$($item.Title).*")
                                }
                                foreach ($oldFile in $allMatching) {
                                    if ($oldFile.Length -gt $trimmedFileInfo.Length -or $oldFile.LastWriteTime -lt $trimmedFileInfo.LastWriteTime) {
                                        Remove-Item -Path $oldFile.FullName -Force -ErrorAction SilentlyContinue
                                    }
                                }
                            }
                        } catch {}
                    }
                    $state.CompletedItems.Add($item.Id)
                } else {
                    $state.FailedItems.Add($item.Id)
                }
                $proc.Dispose()
            } catch {
                $state.FailedItems.Add($item.Id)
            }
        }

        $state.ActiveItemId = ""
        $state.Finished = $true
    }

    $ps.AddScript($queueWorkerScript).AddArgument($taskConfig).AddArgument($global:EngineState) | Out-Null
    $ps.BeginInvoke() | Out-Null
})

# ------------------------------------------------------------------------------
# AUTOMATIC BACKGROUND UPDATE CHECK ON STARTUP
# ------------------------------------------------------------------------------
$startupTimer = New-Object System.Windows.Threading.DispatcherTimer
$startupTimer.Interval = [TimeSpan]::FromMilliseconds(1500)
$startupTimer.add_Tick({
    $startupTimer.Stop()
    Check-Updates -silentIfCurrent $true
})
$startupTimer.Start()

# ------------------------------------------------------------------------------
# INITIAL STARTUP
# ------------------------------------------------------------------------------
$window.ShowDialog() | Out-Null
