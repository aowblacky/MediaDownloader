# ==============================================================================
# Media Downloader - Universal Video & Audio Downloader (MP4 / MP3)
# Modern Multi-Video Queue GUI with Individual Progress Bars & Live Thumbnails
# by BlAcky
# Version: 1.0.2
# ==============================================================================

# Hide background console window immediately if present
Add-Type -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
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
$AppVersion = "1.0.2"
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
if (-not (Test-Path (Join-Path $RootDir "core")) -and -not (Test-Path (Join-Path $RootDir "powershell"))) {
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
            if ($json.DownloadPath -and (Test-Path $json.DownloadPath)) {
                return $json
            }
        } catch {}
    }
    return [PSCustomObject]@{
        DownloadPath = $DefaultDownloadDir
        FormatIndex  = 0
    }
}

function Save-AppSettings([string]$downloadPath, [int]$formatIdx = -1) {
    try {
        $existing = Load-SavedSettings
        $targetPath = if ($downloadPath) { $downloadPath } else { $existing.DownloadPath }
        $targetIdx  = if ($formatIdx -ge 0) { $formatIdx } else { $existing.FormatIndex }

        $cfg = [PSCustomObject]@{
            DownloadPath = $targetPath
            FormatIndex  = $targetIdx
        }
        $jsonStr = $cfg | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllText($ConfigFile, $jsonStr, [System.Text.Encoding]::UTF8)
    } catch {}
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
                        <Button x:Name="BtnPaste" Content="&#x1F4CB; Paste" Style="{StaticResource ModernBtn}" Padding="8,3" FontSize="11" Margin="0,0,6,0"/>
                        <Button x:Name="BtnAddUrls" Content="&#x2795; Add to Queue" Style="{StaticResource AccentBtn}" Padding="10,3" FontSize="11" Margin="0,0,6,0"/>
                        <Button x:Name="BtnClearAll" Content="&#x1F5D1; Clear List" Style="{StaticResource ModernBtn}" Padding="8,3" FontSize="11"/>
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
                    <ColumnDefinition Width="2*"/>
                    <ColumnDefinition Width="3*"/>
                </Grid.ColumnDefinitions>

                <!-- Format Selection -->
                <StackPanel Grid.Row="0" Grid.Column="0" Margin="0,0,12,6">
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

                <!-- Download Path Selection -->
                <StackPanel Grid.Row="0" Grid.Column="1" Margin="0,0,0,6">
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
                <WrapPanel Grid.Row="1" Grid.ColumnSpan="2" Margin="0,2,0,0">
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
                </Grid.RowDefinitions>

                <Grid Grid.Row="0" Margin="0,0,0,8">
                    <TextBlock x:Name="TxtQueueHeader" Text="&#x1F4CB; Download Queue (0 Videos)" FontWeight="SemiBold" FontSize="13"/>
                    <TextBlock x:Name="TxtOverallStatus" Text="Ready" HorizontalAlignment="Right" FontSize="12" Foreground="#89B4FA" FontWeight="SemiBold"/>
                </Grid>

                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <StackPanel x:Name="QueueContainer">
                        <!-- Empty Placeholder -->
                        <Border x:Name="EmptyPlaceholder" Background="#151521" CornerRadius="8" Padding="24" Margin="0,20,0,0" HorizontalAlignment="Center">
                            <StackPanel HorizontalAlignment="Center">
                                <TextBlock Text="&#x1F3AC;" FontSize="32" HorizontalAlignment="Center" Margin="0,0,0,6" Foreground="#6C7086"/>
                                <TextBlock Text="No videos in the queue yet" FontWeight="SemiBold" FontSize="14" HorizontalAlignment="Center" Foreground="#BAC2DE"/>
                                <TextBlock Text="Paste one or more links above and click 'Add to Queue'." FontSize="12" Foreground="#6C7086" Margin="0,4,0,0" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
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
$BtnUpdateCheck     = $window.FindName("BtnUpdateCheck")
$BtnCancel          = $window.FindName("BtnCancel")
$BtnStartDownload   = $window.FindName("BtnStartDownload")

$savedCfg = Load-SavedSettings
$TxtAppVer.Text       = "v$AppVersion"
$TxtDownloadPath.Text = $savedCfg.DownloadPath
if ($savedCfg.FormatIndex -ge 0 -and $savedCfg.FormatIndex -lt $CmbFormat.Items.Count) {
    $CmbFormat.SelectedIndex = $savedCfg.FormatIndex
}

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
    MetaResults      = [System.Collections.Concurrent.ConcurrentQueue[PSObject]]::new()
    Finished         = $false
    ResultDir        = ""
    Runspace         = $null
    Powershell       = $null
})

# ------------------------------------------------------------------------------
# DYNAMIC QUEUE CARD GENERATOR
# ------------------------------------------------------------------------------
function Create-QueueCardUI {
    param($itemData)

    $cardXAML = @"
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Background="#1E1E2E" CornerRadius="8" BorderBrush="#313244" BorderThickness="1"
        Padding="10" Margin="0,0,0,8">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <!-- 1. Thumbnail -->
        <Border Grid.Column="0" CornerRadius="6" Width="110" Height="64" Background="#11111B" Margin="0,0,12,0" ClipToBounds="True">
            <Image x:Name="ImgThumb" Stretch="UniformToFill" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>

        <!-- 2. Details & Progress -->
        <Grid Grid.Column="1" VerticalAlignment="Center">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Title -->
            <TextBlock x:Name="TxtTitle" Grid.Row="0" Text="Video Title..." FontWeight="Bold" FontSize="13" TextTrimming="CharacterEllipsis" MaxHeight="22" Foreground="#CDD6F4"/>

            <!-- Meta -->
            <TextBlock x:Name="TxtMeta" Grid.Row="1" Text="Channel &#x2022; 00:00" FontSize="11" Foreground="#BAC2DE" Margin="0,2,0,3"/>

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

        <!-- 3. Status Badge & Actions -->
        <StackPanel Grid.Column="2" VerticalAlignment="Center" Margin="12,0,0,0" HorizontalAlignment="Right">
            <Border x:Name="PillBadge" Background="#313244" CornerRadius="10" Padding="8,3" HorizontalAlignment="Right">
                <TextBlock x:Name="TxtBadge" Text="Waiting" FontSize="11" FontWeight="SemiBold" Foreground="#BAC2DE"/>
            </Border>
            <Button x:Name="BtnRemoveItem" Content="&#x2715;" ToolTip="Remove video from queue"
                    Background="Transparent" Foreground="#6C7086" BorderThickness="0"
                    FontSize="13" FontWeight="Bold" Margin="0,8,0,0" Cursor="Hand" HorizontalAlignment="Right" Padding="6,2">
                <Button.Style>
                    <Style TargetType="Button">
                        <Setter Property="Template">
                            <Setter.Value>
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
                            </Setter.Value>
                        </Setter>
                    </Style>
                </Button.Style>
            </Button>
        </StackPanel>
    </Grid>
</Border>
"@

    $sReader = New-Object System.IO.StringReader $cardXAML
    $xReader = [System.Xml.XmlReader]::Create($sReader)
    $card = [System.Windows.Markup.XamlReader]::Load($xReader)

    $uiRefs = @{
        Card        = $card
        ImgThumb    = $card.FindName("ImgThumb")
        TxtTitle    = $card.FindName("TxtTitle")
        TxtMeta     = $card.FindName("TxtMeta")
        TxtStatus   = $card.FindName("TxtStatus")
        TxtPercent  = $card.FindName("TxtPercent")
        ProgressBar = $card.FindName("ItemProgressBar")
        PillBadge   = $card.FindName("PillBadge")
        TxtBadge    = $card.FindName("TxtBadge")
        BtnRemove   = $card.FindName("BtnRemoveItem")
        ItemId      = $itemData.Id
        Url         = $itemData.Url
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

    $targetId = $itemData.Id
    $uiRefs.BtnRemove.Tag = $targetId
    $clickHandler = {
        param($sender, $e)
        $id = if ($sender -and $sender.Tag) { $sender.Tag } else { $targetId }
        if ($id) {
            Remove-QueueItem $id
        }
    }.GetNewClosure()
    $uiRefs.BtnRemove.Add_Click($clickHandler)

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
                    Id        = $it.Id
                    Title     = if ($json.title) { $json.title } else { $it.Title }
                    Uploader  = if ($json.uploader) { $json.uploader } else { "Channel" }
                    Duration  = if ($json.duration_string) { $json.duration_string } else { "" }
                    Thumbnail = if ($json.thumbnail) { $json.thumbnail } else { $it.ThumbJpg }
                    VidId     = if ($json.id) { $json.id } else { $it.YtId }
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

    $itemData = [PSCustomObject]@{
        Id       = $itemId
        Url      = $url
        YtId     = $ytId
        Title    = if ($ytId) { "YouTube Video ($ytId)" } else { $url }
        Meta     = "Loading metadata..."
        ThumbJpg = $thumbJpg
        Status   = "In Queue"
        Progress = 0
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

    $matchObj = @($global:ItemsList) | Where-Object { $_.Id -eq $itemId } | Select-Object -First 1
    if ($matchObj) {
        $global:ItemsList.Remove($matchObj) | Out-Null
    }

    Update-QueueHeader
}

function Update-QueueHeader {
    $count = $global:ItemsList.Count
    $clipIcon = [char]::ConvertFromUtf32(0x1F4CB)
    $TxtQueueHeader.Text = "$clipIcon Download Queue ($count Video$(if ($count -ne 1) { 's' }))"
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
            $ui.TxtTitle.Text = $res.Title
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
            [System.Windows.MessageBox]::Show("All downloads in the queue have been completed!`n`nSaved to:`n$destDir", "Completed!", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    }
})
$mainTimer.Start()

# ------------------------------------------------------------------------------
# EVENT HANDLERS
# ------------------------------------------------------------------------------

# Hinzufuegen
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

# Einfuegen & Hinzufuegen
$BtnPaste.Add_Click({
    if ([System.Windows.Clipboard]::ContainsText()) {
        $clipText = [System.Windows.Clipboard]::GetText().Trim()
        if ($clipText) {
            $lines = $clipText -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
            foreach ($line in $lines) {
                Add-UrlToQueue $line
            }
        }
    }
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
        Save-AppSettings -downloadPath $dialog.SelectedPath -formatIdx $CmbFormat.SelectedIndex
    }
})

# Format changed
$CmbFormat.Add_SelectionChanged({
    Save-AppSettings -downloadPath $TxtDownloadPath.Text -formatIdx $CmbFormat.SelectedIndex
})

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

            # 4. Clean legacy powershell folder if core exists
            $legacyPsDir = Join-Path $RootDir "powershell"
            if ((Test-Path $targetCore) -and (Test-Path $legacyPsDir) -and ($targetCore -ne $legacyPsDir)) {
                $oldSettings = Join-Path $legacyPsDir "settings.json"
                $newSettings = Join-Path $targetCore "settings.json"
                if ((Test-Path $oldSettings) -and -not (Test-Path $newSettings)) {
                    Copy-Item -Path $oldSettings -Destination $newSettings -Force -ErrorAction SilentlyContinue
                }
                Remove-Item -Path $legacyPsDir -Recurse -Force -ErrorAction SilentlyContinue
            }

            # 5. Clean up temporary download files
            Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $tempExt -Recurse -Force -ErrorAction SilentlyContinue

            $DlgTxtStatus.Text = "Restarting application..."

            # 6. Relaunch
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
    Save-AppSettings -downloadPath $downloadDir -formatIdx $CmbFormat.SelectedIndex

    $selectedTag      = $CmbFormat.SelectedItem.Tag
    $embedThumb       = [bool]$ChkEmbedThumbnail.IsChecked
    $embedMeta        = [bool]$ChkEmbedMetadata.IsChecked
    $downloadPlaylist = [bool]$ChkDownloadPlaylist.IsChecked
    $embedSubs        = [bool]$ChkEmbedSubs.IsChecked

    # Snap snapshot of current items list for the worker
    $snapshotItems = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($it in $global:ItemsList) {
        $snapshotItems.Add([PSCustomObject]@{
            Id  = $it.Id
            Url = $it.Url
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
            $argsList.Add("-o")
            $argsList.Add("%(title)s.%(ext)s")

            if ($cfg.DownloadPlaylist) {
                $argsList.Add("--yes-playlist")
            } else {
                $argsList.Add("--no-playlist")
            }

            if ($cfg.EmbedMeta) {
                $argsList.Add("--add-metadata")
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
                    if ($line -and $line -match "\[PROGRESS\]\s+([\d\.]+)%") {
                        $state.CurrentItemPct = [double]$matches[1]
                        if ($line -match "at\s+([^\s]+)") { $state.CurrentItemSpeed = $matches[1] }
                        if ($line -match "\(ETA\s+([^\)]+)\)") { $state.CurrentItemEta = $matches[1] }
                    }
                }

                $proc.WaitForExit()
                $exitCode = $proc.ExitCode
                $state.CurrentProcessId = 0

                if ($exitCode -eq 0) {
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



