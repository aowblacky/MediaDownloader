# ==============================================================================
# YT Downloader - Universal Video & Audio Downloader (MP4 / MP3)
# Modern Multi-Video Queue GUI with Individual Progress Bars & Live Thumbnails
# by BlAcky
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

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $ScriptDir) {
    $ScriptDir = Get-Location
}

$BinDir = Join-Path $ScriptDir "bin"
$YtDlpExe = Join-Path $BinDir "yt-dlp.exe"
$FfmpegExe = Join-Path $BinDir "ffmpeg.exe"

# Default Download Directory (Downloads\YTDownloader)
$DefaultDownloadDir = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads\YTDownloader"
if (-not (Test-Path $DefaultDownloadDir)) {
    New-Item -ItemType Directory -Path $DefaultDownloadDir -Force | Out-Null
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
                <TextBlock Text="&#x26A1; Universal Video &amp; Audio Downloader" FontSize="20" FontWeight="Bold" Foreground="#89B4FA"/>
                <TextBlock Text="YouTube, TikTok, Twitter/X, Instagram, Vimeo, Soundcloud uvm. &#x2022; MP4 &amp; MP3" FontSize="12" Foreground="#A6ADC8" Margin="0,2,0,0"/>
            </StackPanel>
            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                <Border x:Name="PillStatus" Background="#313244" CornerRadius="12" Padding="10,4" Margin="0,0,8,0">
                    <TextBlock x:Name="TxtPillStatus" Text="Bereit" FontSize="11" FontWeight="SemiBold" Foreground="#A6E3A1"/>
                </Border>
                <Button x:Name="BtnUpdateTools" Content="&#x27F3; Tools pr&#xFC;fen" Style="{StaticResource ModernBtn}" Padding="10,5" FontSize="11"/>
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
                    <TextBlock Text="&#x1F517; Video-Link(s) eingeben oder einf&#xFC;gen:" FontWeight="SemiBold"/>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="BtnPaste" Content="&#x1F4CB; Einf&#xFC;gen" Style="{StaticResource ModernBtn}" Padding="8,3" FontSize="11" Margin="0,0,6,0"/>
                        <Button x:Name="BtnAddUrls" Content="&#x2795; Zur Liste hinzuf&#xFC;gen" Style="{StaticResource AccentBtn}" Padding="10,3" FontSize="11" Margin="0,0,6,0"/>
                        <Button x:Name="BtnClearAll" Content="&#x1F5D1; Liste leeren" Style="{StaticResource ModernBtn}" Padding="8,3" FontSize="11"/>
                    </StackPanel>
                </Grid>
                <TextBox x:Name="TxtUrls" Grid.Row="1" Height="50" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" TextWrapping="NoWrap"
                         ToolTip="F&#xFC;ge hier Links ein und klicke auf 'Zur Liste hinzuf&#xFC;gen'"/>
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
                        <ComboBoxItem Content="&#x1F3B5; MP3 Audio (Beste Qualit&#xE4;t 320kbps)" Tag="mp3_best"/>
                        <ComboBoxItem Content="&#x1F3AC; MP4 Video (Beste Qualit&#xE4;t)" Tag="mp4_best"/>
                        <ComboBoxItem Content="&#x1F3AC; MP4 Video (1080p Full HD)" Tag="mp4_1080p"/>
                        <ComboBoxItem Content="&#x1F3AC; MP4 Video (720p HD)" Tag="mp4_720p"/>
                        <ComboBoxItem Content="&#x1F3B5; M4A Audio (Apple AAC)" Tag="m4a_best"/>
                        <ComboBoxItem Content="&#x1F3B5; WAV Audio (Lossless)" Tag="wav_best"/>
                        <ComboBoxItem Content="&#x1F3B5; FLAC Audio (Lossless)" Tag="flac_best"/>
                    </ComboBox>
                </StackPanel>

                <!-- Download Path Selection -->
                <StackPanel Grid.Row="0" Grid.Column="1" Margin="0,0,0,6">
                    <TextBlock Text="&#x1F4C1; Zielordner:" FontWeight="SemiBold" Margin="0,0,0,3" FontSize="12"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="TxtDownloadPath" Grid.Column="0" IsReadOnly="True" Margin="0,0,6,0"/>
                        <Button x:Name="BtnBrowsePath" Grid.Column="1" Content="Durchsuchen..." Style="{StaticResource ModernBtn}" Margin="0,0,6,0"/>
                        <Button x:Name="BtnOpenFolder" Grid.Column="2" Content="&#x1F4C2; &#xD6;ffnen" Style="{StaticResource ModernBtn}"/>
                    </Grid>
                </StackPanel>

                <!-- Options Checkboxes -->
                <WrapPanel Grid.Row="1" Grid.ColumnSpan="2" Margin="0,2,0,0">
                    <CheckBox x:Name="ChkEmbedThumbnail" Content="Cover / Thumbnail einbetten" IsChecked="True"/>
                    <CheckBox x:Name="ChkEmbedMetadata" Content="Metadaten einbetten" IsChecked="True"/>
                    <CheckBox x:Name="ChkDownloadPlaylist" Content="Ganze Playlist laden" IsChecked="False"/>
                    <CheckBox x:Name="ChkEmbedSubs" Content="Untertitel einbetten" IsChecked="False"/>
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
                    <TextBlock x:Name="TxtQueueHeader" Text="&#x1F4CB; Warteschlange (0 Videos)" FontWeight="SemiBold" FontSize="13"/>
                    <TextBlock x:Name="TxtOverallStatus" Text="Bereit" HorizontalAlignment="Right" FontSize="12" Foreground="#89B4FA" FontWeight="SemiBold"/>
                </Grid>

                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <StackPanel x:Name="QueueContainer">
                        <!-- Empty Placeholder -->
                        <Border x:Name="EmptyPlaceholder" Background="#151521" CornerRadius="8" Padding="24" Margin="0,20,0,0" HorizontalAlignment="Center">
                            <StackPanel HorizontalAlignment="Center">
                                <TextBlock Text="&#x1F3AC;" FontSize="32" HorizontalAlignment="Center" Margin="0,0,0,6" Foreground="#6C7086"/>
                                <TextBlock Text="Noch keine Videos in der Liste" FontWeight="SemiBold" FontSize="14" HorizontalAlignment="Center" Foreground="#BAC2DE"/>
                                <TextBlock Text="F&#xFC;ge oben einen oder mehrere Links ein und klicke auf 'Zur Liste hinzuf&#xFC;gen'." FontSize="12" Foreground="#6C7086" Margin="0,4,0,0" HorizontalAlignment="Center"/>
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

            <TextBlock x:Name="TxtFooter" Grid.Column="0" Text="PowerShell &amp; yt-dlp Engine &#x2022; Bereit" VerticalAlignment="Center" FontSize="12" Foreground="#6C7086"/>

            <Button x:Name="BtnCancel" Grid.Column="1" Content="&#x23F9; Abbrechen" Style="{StaticResource DangerBtn}" Margin="0,0,10,0" IsEnabled="False" Width="130" Height="36"/>
            <Button x:Name="BtnStartDownload" Grid.Column="2" Content="&#x2B07; Alle herunterladen" Style="{StaticResource AccentBtn}" Width="200" Height="36"/>
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
$BtnUpdateTools     = $window.FindName("BtnUpdateTools")
$BtnCancel          = $window.FindName("BtnCancel")
$BtnStartDownload   = $window.FindName("BtnStartDownload")

$TxtDownloadPath.Text = $DefaultDownloadDir

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
            <TextBlock x:Name="TxtTitle" Grid.Row="0" Text="Video-Titel..." FontWeight="Bold" FontSize="13" TextTrimming="CharacterEllipsis" MaxHeight="22" Foreground="#CDD6F4"/>

            <!-- Meta -->
            <TextBlock x:Name="TxtMeta" Grid.Row="1" Text="Kanal &#x2022; 00:00" FontSize="11" Foreground="#BAC2DE" Margin="0,2,0,3"/>

            <!-- Status & Percentage -->
            <Grid Grid.Row="2" Margin="0,0,0,3">
                <TextBlock x:Name="TxtStatus" Text="In Warteschlange..." FontSize="11" Foreground="#A6ADC8"/>
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
                <TextBlock x:Name="TxtBadge" Text="Wartend" FontSize="11" FontWeight="SemiBold" Foreground="#BAC2DE"/>
            </Border>
            <Button x:Name="BtnRemoveItem" Content="&#x2715;" Background="Transparent" Foreground="#6C7086" BorderThickness="0"
                    FontSize="12" FontWeight="Bold" Margin="0,6,0,0" Cursor="Hand" HorizontalAlignment="Right"/>
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

    $itemId = $itemData.Id
    $uiRefs.BtnRemove.Add_Click({
        Remove-QueueItem $itemId
    })

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
                    Uploader  = if ($json.uploader) { $json.uploader } else { "Kanal" }
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
        Meta     = "Lade Metadaten..."
        ThumbJpg = $thumbJpg
        Status   = "In Warteschlange"
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
    if ($global:EngineState.IsDownloading -and $global:EngineState.ActiveItemId -eq $itemId) {
        [System.Windows.MessageBox]::Show("Dieses Video wird gerade heruntergeladen und kann nicht entfernt werden.", "Hinweis", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    if ($global:ItemUIMap.ContainsKey($itemId)) {
        $uiRefs = $global:ItemUIMap[$itemId]
        $QueueContainer.Children.Remove($uiRefs.Card) | Out-Null
        $global:ItemUIMap.Remove($itemId)
    }

    $matchObj = $global:ItemsList | Where-Object { $_.Id -eq $itemId } | Select-Object -First 1
    if ($matchObj) {
        $global:ItemsList.Remove($matchObj) | Out-Null
    }

    Update-QueueHeader
}

function Update-QueueHeader {
    $count = $global:ItemsList.Count
    $clipIcon = [char]::ConvertFromUtf32(0x1F4CB)
    $TxtQueueHeader.Text = "$clipIcon Warteschlange ($count Video$(if ($count -ne 1) { 's' }))"
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
    $BtnUpdateTools.IsEnabled   = -not $downloading

    if ($status) {
        $TxtOverallStatus.Text = $status
        $TxtFooter.Text        = $status
    }

    if ($downloading) {
        $TxtPillStatus.Text = "Laeuft..."
        $TxtPillStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F9E2AF")
    } else {
        $TxtPillStatus.Text = "Bereit"
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
            $durStr = if ($res.Duration) { " $bullet Dauer: $($res.Duration)" } else { "" }
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
            $detailStr = if ($speed) { " • $speed" } else { "" }
            $etaStr    = if ($eta) { " (ETA $eta)" } else { "" }
            $ui.TxtStatus.Text = "Lade herunter: $([math]::Round($pct))%$detailStr$etaStr"

            $ui.PillBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F9E2AF")
            $ui.TxtBadge.Text = "Laeuft"
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
            $ui.TxtStatus.Text    = "$checkIcon Erfolgreich fertiggestellt"
            $ui.PillBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A6E3A1")
            $ui.TxtBadge.Text = "Fertig"
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
            $ui.TxtStatus.Text    = "$crossIcon Fehlgeschlagen oder abgebrochen"
            $ui.PillBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F38BA8")
            $ui.TxtBadge.Text = "Fehler"
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
            Set-UIBusyState -downloading $false -status "Download abgebrochen."
        } else {
            Set-UIBusyState -downloading $false -status "Alle Downloads abgeschlossen!"
            [System.Windows.MessageBox]::Show("Alle Downloads in der Warteschlange wurden abgeschlossen!`n`nGespeichert in:`n$destDir", "Fertig!", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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

# Liste leeren
$BtnClearAll.Add_Click({
    if ($global:EngineState.IsDownloading) {
        [System.Windows.MessageBox]::Show("Downloads laufen gerade. Bitte zuerst abbrechen.", "Hinweis", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    $QueueContainer.Children.Clear()
    $global:ItemsList.Clear()
    $global:ItemUIMap.Clear()
    $TxtUrls.Text = ""
    Update-QueueHeader
})

# Ordner waehlen
$BtnBrowsePath.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.SelectedPath = $TxtDownloadPath.Text
    $dialog.Description = "Waehle den Zielordner fuer Downloads"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtDownloadPath.Text = $dialog.SelectedPath
    }
})

# Ordner oeffnen
$BtnOpenFolder.Add_Click({
    $path = $TxtDownloadPath.Text
    if (Test-Path $path) {
        [System.Diagnostics.Process]::Start("explorer.exe", $path) | Out-Null
    } else {
        [System.Windows.MessageBox]::Show("Ordner existiert noch nicht!", "Hinweis", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
})

# Tools pruefen
$BtnUpdateTools.Add_Click({
    $setupScript = Join-Path $ScriptDir "Setup-Dependencies.ps1"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$setupScript`" -ForceUpdate" -WindowStyle Hidden
    [System.Windows.MessageBox]::Show("Tools werden im Hintergrund aktualisiert.", "Update", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Abbrechen
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
        [System.Windows.MessageBox]::Show("Bitte mindestens einen Video-Link zur Liste hinzufuegen!", "Warteschlange leer", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    if (-not (Test-Path $YtDlpExe) -or -not (Test-Path $FfmpegExe)) {
        [System.Windows.MessageBox]::Show("yt-dlp oder ffmpeg fehlen im bin-Ordner.", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    $downloadDir = $TxtDownloadPath.Text
    if (-not (Test-Path $downloadDir)) {
        New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    }

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

    Set-UIBusyState -downloading $true -status "Starte Download-Warteschlange..."
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
            $argsList.Add("download:[PROGRESS] %(progress._percent_str)s von %(progress._total_bytes_str)s bei %(progress._speed_str)s (ETA %(progress._eta_str)s)")
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
                        if ($line -match "bei\s+([^\s]+)") { $state.CurrentItemSpeed = $matches[1] }
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
# INITIAL STARTUP
# ------------------------------------------------------------------------------
$window.ShowDialog() | Out-Null