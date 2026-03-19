# scripts/gui.ps1
# WinToolerV1 GUI - Full WPF interface
# Features: Dark/Light mode, macOS-style icons, Tweak templates,
#           App Updates tab, Uninstall tab, Async SFC/DISM

function Start-WinToolerGUI {

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms

    # ----------------------------------------------------------------
    #  AERO / DWM GLASS  -- extend frame into client area for frosted look
    # ----------------------------------------------------------------
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class AeroGlass {
    [StructLayout(LayoutKind.Sequential)]
    public struct MARGINS { public int Left, Right, Top, Bottom; }
    [DllImport("dwmapi.dll")]
    public static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref MARGINS m);
    [DllImport("dwmapi.dll")]
    public static extern int DwmIsCompositionEnabled(out bool enabled);
    [DllImport("user32.dll")]
    public static extern bool SetLayeredWindowAttributes(IntPtr hwnd, uint crKey, byte bAlpha, uint dwFlags);
}
'@ -ErrorAction SilentlyContinue
    } catch {}

    $script:IsDark = $false

    # ----------------------------------------------------------------
    #  THEME HELPERS - called at build time and on toggle
    # ----------------------------------------------------------------
    $script:T = @{}  # theme palette - rebuilt by Set-Theme

    function script:Set-Theme {
        param([bool]$dark)
        if ($dark) {
            # Dark mode — Windows 11 dark gray palette
            $script:T = @{
                WinBG        = "#202020"; SidebarBG     = "#181818"; SidebarBorder = "#2D2D2D"
                Surface1     = "#242424"; Surface2      = "#2C2C2C"; Surface3      = "#202020"
                Border1      = "#333333"; Border2       = "#3C3C3C"
                Text1        = "#F0F0F0"; Text2         = "#CCCCCC"; Text3         = "#999999"; Text4 = "#666666"
                Accent       = "#60AEFF"; AccentH       = "#7AB8FF"; AccentP       = "#4A9AEE"
                NavBtnFG     = "#CCCCCC"; NavActBG      = "#1E3452"; NavActFG      = "#7AB8FF"
                CardBG       = "#272727"; CardBorder    = "#333333"
                InputBG      = "#2C2C2C"; StatusBG      = "#181818"; StatusBorder  = "#2D2D2D"
                Green        = "#4EC94E"; Red           = "#F04747"; Yellow        = "#FFCA28"; Orange = "#FF7043"
                BadgeIconBG  = "#383838"; BadgeIconFG  = "#BBBBBB"
            }
        } else {
            # Light mode — Pure Windows 11 Fluent Design palette
            $script:T = @{
                WinBG        = "#F3F3F3"; SidebarBG     = "#FFFFFF"; SidebarBorder = "#E0E0E0"
                Surface1     = "#FFFFFF"; Surface2      = "#F9F9F9"; Surface3      = "#F3F3F3"
                Border1      = "#E5E5E5"; Border2       = "#D1D1D1"
                Text1        = "#1A1A1A"; Text2         = "#3A3A3A"; Text3         = "#5A5A5A"; Text4 = "#888888"
                Accent       = "#0067C0"; AccentH       = "#0078D4"; AccentP       = "#005AA8"
                NavBtnFG     = "#3C3C3C"; NavActBG      = "#EEF3FC"; NavActFG      = "#0067C0"
                CardBG       = "#FFFFFF"; CardBorder    = "#E5E5E5"
                InputBG      = "#FFFFFF"; StatusBG      = "#F9F9F9"; StatusBorder  = "#E5E5E5"
                Green        = "#107C10"; Red           = "#C42B1C"; Yellow        = "#B06B00"; Orange = "#D83B01"
                BadgeIconBG  = "#EBEBEB"; BadgeIconFG  = "#3C3C3C"
            }
        }
    }

    function script:Brush { param([string]$hex)
        New-Object Windows.Media.SolidColorBrush([Windows.Media.ColorConverter]::ConvertFromString($hex))
    }
    function script:BrushA { param([string]$hex, [byte]$a)
        $c = [Windows.Media.ColorConverter]::ConvertFromString($hex)
        New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromArgb($a, $c.R, $c.G, $c.B))
    }

    & script:Set-Theme $false

    # ----------------------------------------------------------------
    #  LANGUAGE STRINGS
    # ----------------------------------------------------------------
    # Pin language immediately so nothing can reset it later in the session
    $lang = if ($global:UILanguage -eq "ES") { "ES" } else { "EN" }
    $global:UILanguage = $lang
    $script:lang = $lang   # script-scoped so Apply-Language and toggle closures can read/write it

    $S = @{}   # UI strings - keyed by control/label name

    if ($lang -eq "ES") {
        $S = @{
            # Nav labels
            NavApps       = "Act. de Apps"
            NavAppManager = "Gestor de Apps"
            NavTweaks      = "Ajustes"
            NavServices   = "Servicios";        NavRepair      = "Reparar"
            # Page titles
            TitleApps       = "Actualizaciones de Apps"
            TitleAppManager = "Gestor de Aplicaciones"
            SubAppManager   = "Instala o desinstala apps via winget/Chocolatey"
            SubApps         = "Comprueba e instala actualizaciones de apps via winget"
            ModeLblUpdateAll = "Actualizar Todo"
            TitleTweaks     = "Ajustes del Sistema"
            SubTweaks       = "Optimizacion de rendimiento, privacidad e interfaz"
            TitleServices   = "Servicios de Windows"
            SubServices     = "Gestiona servicios en segundo plano"
            TitleRepair     = "Reparacion y Mantenimiento"
            SubRepair       = "Diagnostica y repara problemas comunes de Windows"
            TitleAbout      = "Acerca de WinToolerV1"
            SubAbout        = "Informacion de version y creditos"
            # Buttons
            BtnCheckAppUpdates = "Buscar Actualizaciones de Apps"
            BtnCheckAll      = "Selec. Todo";   BtnUncheckAll   = "Ninguno"
            BtnApplyTweaks   = "Aplicar Ajustes Seleccionados"
            BtnUndoTweaks    = "Deshacer Seleccionados"
            BtnSvcDisable    = "Deshabilitar Selec."
            BtnSvcManual     = "Poner Manual"
            BtnSvcEnable     = "Reactivar"
            BtnOpenLog       = "Abrir Archivo de Log"
            TplNone          = "Ninguno";        TplStandard = "Estandar"
            TplMinimal       = "Minimo";         TplHeavy    = "Completo"
            LangToggleLabel  = "Idioma"
            DiskCleanTitle   = "Limpieza de Disco"
            DiskCleanMsg     = "Ejecutando limpieza de disco en segundo plano..."
            DiskCleanDone    = "Limpieza de disco finalizada."
            TweaksDone       = "Listo! Aplicados"
            TweaksOf         = "de"
            TweaksDiskClean  = "tweaks. Iniciando limpieza de disco..."
            SearchPlaceholder = "Buscar...";     Ready = "Listo"
            StatusReady      = "Listo"
            AboutVersion     = "Version";        AboutLicense = "Licencia"
            AboutInspired    = "Inspirado en"
            AboutLog         = "Archivo de log"
        }
    } else {
        $S = @{
            NavApps       = "App Updates"
            NavAppManager = "App Manager"
            NavAppUpdates = "App Updates";      NavTweaks      = "Tweaks"
            NavServices   = "Services";         NavRepair      = "Repair"
            TitleApps       = "App Updates"
            TitleAppManager = "App Manager"
            SubAppManager   = "Install or uninstall apps via winget / Chocolatey"
            SubApps         = "Check and install available app updates via winget"
            ModeLblUpdateAll = "Update All Apps"
            TitleTweaks     = "System Tweaks"
            SubTweaks       = "Apply performance, privacy and UI optimisations"
            TitleServices   = "Windows Services"
            SubServices     = "Manage and disable unnecessary background services"
            TitleRepair     = "Repair and Maintenance"
            SubRepair       = "Diagnose and fix common Windows issues"
            TitleAbout      = "About WinToolerV1"
            SubAbout        = "Version information and credits"
            BtnCheckAppUpdates = "Check for App Updates"
            BtnCheckAll      = "Select All";    BtnUncheckAll   = "None"
            BtnApplyTweaks   = "Apply Selected Tweaks"
            BtnUndoTweaks    = "Undo Selected"
            BtnSvcDisable    = "Disable Selected"
            BtnSvcManual     = "Set Manual"
            BtnSvcEnable     = "Re-Enable"
            BtnOpenLog       = "Open Log File"
            TplNone          = "None";           TplStandard = "Standard"
            TplMinimal       = "Minimal";        TplHeavy    = "Heavy"
            LangToggleLabel  = "Language"
            DiskCleanTitle   = "Disk Cleanup"
            DiskCleanMsg     = "Running disk cleanup in the background..."
            DiskCleanDone    = "Disk cleanup finished."
            TweaksDone       = "Done! Applied"
            TweaksOf         = "of"
            TweaksDiskClean  = "tweaks. Running disk cleanup..."
            SearchPlaceholder = "Search..."
            StatusReady      = "Ready"
            AboutVersion     = "Version";        AboutLicense = "License"
            AboutInspired    = "Inspired by"
            AboutLog         = "Log file"
        }
    }
    $global:UIStrings = $S

    # ----------------------------------------------------------------
    #  XAML
    # ----------------------------------------------------------------
    [xml]$XAML = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="WinTooler V0.7 beta - Build 5035"
    Width="1180" Height="780"
    MinWidth="980" MinHeight="640"
    WindowStartupLocation="CenterScreen"
    Background="#F3F3F3"
    FontFamily="Segoe UI Variable Text, Segoe UI, Sans-Serif"
    FontSize="13"
    ResizeMode="CanResize">

  <Window.Resources>
    <!-- Fluent Design color tokens -->
    <SolidColorBrush x:Key="Accent"      Color="#0067C0"/>
    <SolidColorBrush x:Key="AccentHover" Color="#0078D4"/>
    <SolidColorBrush x:Key="AccentPress" Color="#005AA8"/>
    <SolidColorBrush x:Key="Green"       Color="#107C10"/>
    <SolidColorBrush x:Key="Red"         Color="#C42B1C"/>
    <SolidColorBrush x:Key="Yellow"      Color="#B06B00"/>
    <SolidColorBrush x:Key="Orange"      Color="#D83B01"/>

    <!-- Drop shadow effect for cards -->
    <DropShadowEffect x:Key="CardShadow" BlurRadius="12" ShadowDepth="1"
                      Direction="270" Color="#000000" Opacity="0.07"/>
    <DropShadowEffect x:Key="CardShadowMd" BlurRadius="18" ShadowDepth="2"
                      Direction="270" Color="#000000" Opacity="0.09"/>

    <!-- Primary accent button -->
    <Style x:Key="BtnAccent" TargetType="Button">
      <Setter Property="Background"      Value="#0067C0"/>
      <Setter Property="Foreground"      Value="White"/>
      <Setter Property="FontWeight"      Value="SemiBold"/>
      <Setter Property="FontSize"        Value="13"/>
      <Setter Property="Padding"         Value="18,8"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor"          Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}"
                    CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#0078D4"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#005AA8"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bd" Property="Background" Value="#E8E8E8"/>
                <Setter Property="Foreground" Value="#AAAAAA"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Ghost / outline button -->
    <Style x:Key="BtnGhost" TargetType="Button">
      <Setter Property="Background"      Value="#FFFFFF"/>
      <Setter Property="Foreground"      Value="#323130"/>
      <Setter Property="FontSize"        Value="13"/>
      <Setter Property="Padding"         Value="14,7"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush"     Value="#D1D1D1"/>
      <Setter Property="Cursor"          Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#F0F6FF"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="#0067C0"/>
                <Setter Property="Foreground" Value="#0067C0"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#E3EEFA"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Foreground" Value="#AAAAAA"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="#E0E0E0"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="BtnDanger" TargetType="Button" BasedOn="{StaticResource BtnGhost}">
      <Setter Property="BorderBrush" Value="#F8BBBB"/>
      <Setter Property="Foreground"  Value="#C42B1C"/>
      <Setter Property="Background"  Value="#FFF6F6"/>
    </Style>

    <Style x:Key="BtnSuccess" TargetType="Button" BasedOn="{StaticResource BtnGhost}">
      <Setter Property="BorderBrush" Value="#B3DEB3"/>
      <Setter Property="Foreground"  Value="#107C10"/>
      <Setter Property="Background"  Value="#F3FBF3"/>
    </Style>

    <!-- Fluent nav button - with left accent bar via Grid trick -->
    <Style x:Key="NavBtn" TargetType="Button">
      <Setter Property="Background"                  Value="Transparent"/>
      <Setter Property="Foreground"                  Value="#5A5A5A"/>
      <Setter Property="FontSize"                    Value="13"/>
      <Setter Property="Padding"                     Value="6,8"/>
      <Setter Property="BorderThickness"             Value="0"/>
      <Setter Property="HorizontalContentAlignment"  Value="Left"/>
      <Setter Property="Margin"                      Value="8,1,8,1"/>
      <Setter Property="Cursor"                      Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <!-- Left accent bar (hidden when inactive) -->
              <Border x:Name="accent" Width="3" HorizontalAlignment="Left"
                      Background="#0067C0" CornerRadius="2" Visibility="Collapsed"
                      Margin="-8,4,-8,4"/>
              <Border x:Name="bd" Background="{TemplateBinding Background}"
                      CornerRadius="6" Padding="{TemplateBinding Padding}">
                <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
              </Border>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd"     Property="Background" Value="#EEF3FC"/>
                <Setter Property="Foreground" Value="#0067C0"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#E3EEFA"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="NavBtnActive" TargetType="Button" BasedOn="{StaticResource NavBtn}">
      <Setter Property="Background" Value="#EEF3FC"/>
      <Setter Property="Foreground" Value="#0067C0"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>

    <!-- Fluent search / input box -->
    <Style x:Key="SearchBox" TargetType="TextBox">
      <Setter Property="Background"       Value="Transparent"/>
      <Setter Property="Foreground"       Value="#323130"/>
      <Setter Property="CaretBrush"       Value="#999999"/>
      <Setter Property="BorderBrush"      Value="#D1D1D1"/>
      <Setter Property="BorderThickness"  Value="1"/>
      <Setter Property="Padding"          Value="10,7"/>
      <Setter Property="FontSize"         Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border x:Name="bd" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ScrollViewer x:Name="PART_ContentHost"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsFocused" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="#0067C0"/>
                <Setter TargetName="bd" Property="BorderThickness" Value="1.5"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="#888888"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Slim scrollbar -->
    <Style x:Key="ScrollBarThumb" TargetType="Thumb">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Thumb">
            <Border Background="#C8C8C8" CornerRadius="3" Margin="1"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ScrollBar">
      <Setter Property="Width"      Value="5"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Track x:Name="PART_Track" IsDirectionReversed="True">
              <Track.Thumb>
                <Thumb Style="{StaticResource ScrollBarThumb}" Margin="0,2"/>
              </Track.Thumb>
            </Track>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Fluent checkbox -->
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#323130"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <StackPanel Orientation="Horizontal">
              <Border x:Name="box" Width="18" Height="18" CornerRadius="4"
                      Background="#FFFFFF" BorderBrush="#AAAAAA" BorderThickness="1.5"
                      VerticalAlignment="Center">
                <TextBlock x:Name="chk" Text="&#x2714;" FontSize="10"
                           FontWeight="Bold" Foreground="White"
                           HorizontalAlignment="Center" VerticalAlignment="Center"
                           Visibility="Collapsed"/>
              </Border>
              <ContentPresenter Margin="8,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="box" Property="Background"  Value="#0067C0"/>
                <Setter TargetName="box" Property="BorderBrush" Value="#0067C0"/>
                <Setter TargetName="chk" Property="Visibility"  Value="Visible"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="box" Property="BorderBrush" Value="#0067C0"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Fluent card style for ComboBox -->
    <Style TargetType="ComboBox">
      <Setter Property="Background"      Value="#FFFFFF"/>
      <Setter Property="Foreground"      Value="#323130"/>
      <Setter Property="BorderBrush"     Value="#D1D1D1"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding"         Value="10,6"/>
      <Setter Property="Height"          Value="34"/>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Grid Grid.Row="0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="210"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <!-- LEFT SIDEBAR -->
      <Border x:Name="Sidebar" Grid.Column="0" Background="#FFFFFF"
              BorderBrush="#E0E0E0" BorderThickness="0,0,1,0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <!-- Logo -->
          <StackPanel Grid.Row="0" Margin="14,12,14,8">
            <Grid Margin="0,0,0,6">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <!-- App icon -->
              <Border Grid.Column="0" Width="36" Height="36" CornerRadius="10"
                      Background="Transparent" Margin="0,0,0,0">
                <Image x:Name="SidebarIcon" Width="36" Height="36"
                       RenderOptions.BitmapScalingMode="HighQuality"
                       Stretch="UniformToFill"/>
              </Border>
            </Grid>
            <TextBlock x:Name="SidebarTitle" Text="WinTooler" FontSize="15" FontWeight="Bold" Foreground="#1A1A1A"/>
            <TextBlock x:Name="SidebarSub" Text="V0.7 beta  ·  Build 5035" FontSize="10" Foreground="#888888" Margin="0,2,0,0"/>
          </StackPanel>

          <!-- Nav items -->
          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                        HorizontalScrollBarVisibility="Disabled">
          <StackPanel Margin="0,0,0,4">

            <TextBlock Text="APPS" FontSize="9" FontWeight="SemiBold"
                       Foreground="#999999" Margin="16,8,0,2"/>

            <!-- App Manager — E80F AllApps grid -->
            <Button x:Name="NavAppManager" Style="{StaticResource NavBtnActive}">
              <StackPanel Orientation="Horizontal">
                <Border Width="26" Height="26" CornerRadius="7" Background="#EBEBEB" Margin="0,0,9,0">
                  <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons" Text="&#xE80F;" FontSize="13"
                             HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#3C3C3C"/>
                </Border>
                <TextBlock Text="App Manager"/>
              </StackPanel>
            </Button>

            <TextBlock Text="SYSTEM" FontSize="9" FontWeight="SemiBold"
                       Foreground="#999999" Margin="16,8,0,2"/>

            <!-- Tweaks — E713 Settings gear -->
            <Button x:Name="NavTweaks" Style="{StaticResource NavBtn}">
              <StackPanel Orientation="Horizontal">
                <Border Width="26" Height="26" CornerRadius="7" Background="#EBEBEB" Margin="0,0,9,0">
                  <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons" Text="&#xE713;" FontSize="13"
                             HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#3C3C3C"/>
                </Border>
                <TextBlock Text="Tweaks"/>
              </StackPanel>
            </Button>

            <!-- Services — E896 AllApps list -->
            <Button x:Name="NavServices" Style="{StaticResource NavBtn}">
              <StackPanel Orientation="Horizontal">
                <Border Width="26" Height="26" CornerRadius="7" Background="#EBEBEB" Margin="0,0,9,0">
                  <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons" Text="&#xE896;" FontSize="13"
                             HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#3C3C3C"/>
                </Border>
                <TextBlock Text="Services"/>
              </StackPanel>
            </Button>

            <TextBlock Text="TOOLS" FontSize="9" FontWeight="SemiBold"
                       Foreground="#999999" Margin="16,8,0,2"/>

            <!-- Repair — E90F Repair wrench -->
            <Button x:Name="NavRepair" Style="{StaticResource NavBtn}">
              <StackPanel Orientation="Horizontal">
                <Border Width="26" Height="26" CornerRadius="7" Background="#EBEBEB" Margin="0,0,9,0">
                  <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons" Text="&#xE90F;" FontSize="13"
                             HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#3C3C3C"/>
                </Border>
                <TextBlock Text="Repair"/>
              </StackPanel>
            </Button>

            <!-- Startup Manager — E7EF Launch -->
            <Button x:Name="NavStartup" Style="{StaticResource NavBtn}">
              <StackPanel Orientation="Horizontal">
                <Border Width="26" Height="26" CornerRadius="7" Background="#EBEBEB" Margin="0,0,9,0">
                  <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons" Text="&#xE7EF;" FontSize="13"
                             HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#3C3C3C"/>
                </Border>
                <TextBlock Text="Startup Manager"/>
              </StackPanel>
            </Button>

            <!-- DNS Changer — E774 Globe -->
            <Button x:Name="NavDNS" Style="{StaticResource NavBtn}">
              <StackPanel Orientation="Horizontal">
                <Border Width="26" Height="26" CornerRadius="7" Background="#EBEBEB" Margin="0,0,9,0">
                  <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons" Text="&#xE774;" FontSize="13"
                             HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#3C3C3C"/>
                </Border>
                <TextBlock Text="DNS Changer"/>
              </StackPanel>
            </Button>

            <!-- Profile Backup — E74E Save disk -->
            <Button x:Name="NavBackup" Style="{StaticResource NavBtn}">
              <StackPanel Orientation="Horizontal">
                <Border Width="26" Height="26" CornerRadius="7" Background="#EBEBEB" Margin="0,0,9,0">
                  <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons" Text="&#xE74E;" FontSize="13"
                             HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#3C3C3C"/>
                </Border>
                <TextBlock Text="Profile Backup"/>
              </StackPanel>
            </Button>

            <TextBlock Text="MEDIA" FontSize="9" FontWeight="SemiBold"
                       Foreground="#999999" Margin="16,8,0,2"/>

            <Button x:Name="NavISO" Style="{StaticResource NavBtn}">
              <StackPanel Orientation="Horizontal">
                <Border Width="26" Height="26" CornerRadius="7" Background="#EBEBEB" Margin="0,0,9,0">
                  <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons" Text="&#xE93C;" FontSize="13"
                             HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#3C3C3C"/>
                </Border>
                <TextBlock Text="ISO Creator"/>
              </StackPanel>
            </Button>

            <Button x:Name="NavAbout" Style="{StaticResource NavBtn}">
              <StackPanel Orientation="Horizontal">
                <Border Width="26" Height="26" CornerRadius="7" Background="#EBEBEB" Margin="0,0,9,0">
                  <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons" Text="&#xE946;" FontSize="13"
                             HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#3C3C3C"/>
                </Border>
                <TextBlock Text="About"/>
              </StackPanel>
            </Button>

          </StackPanel>
          </ScrollViewer>

          <!-- Theme + Winget + OS footer -->
          <Border x:Name="SidebarFooter" Grid.Row="2" Margin="6,0,6,8" Padding="10,8"
                  Background="#F8F9FA" CornerRadius="8"
                  BorderBrush="#EEEEEE" BorderThickness="1"
                  Effect="{StaticResource CardShadow}">
            <StackPanel>
              <!-- Language toggle -->
              <StackPanel Orientation="Horizontal" Margin="0,0,0,6" HorizontalAlignment="Center">
                <TextBlock x:Name="LangLabel" Text="Language" FontSize="10" FontWeight="SemiBold"
                           Foreground="#777777" VerticalAlignment="Center" Margin="0,0,8,0"/>
                <Border CornerRadius="6" BorderBrush="#B8D0E8" BorderThickness="1" ClipToBounds="True">
                  <StackPanel Orientation="Horizontal">
                    <Button x:Name="BtnLangEN" Content="EN"
                            FontSize="11" FontWeight="SemiBold"
                            Width="34" Height="22" BorderThickness="0"
                            Background="#0067C0" Foreground="White"
                            Cursor="Hand">
                      <Button.Template>
                        <ControlTemplate TargetType="Button">
                          <Border x:Name="bdEN" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                          </Border>
                          <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bdEN" Property="Opacity" Value="0.85"/></Trigger>
                          </ControlTemplate.Triggers>
                        </ControlTemplate>
                      </Button.Template>
                    </Button>
                    <Button x:Name="BtnLangES" Content="ES"
                            FontSize="11" FontWeight="SemiBold"
                            Width="34" Height="22" BorderThickness="0"
                            Background="Transparent" Foreground="#3A5570"
                            Cursor="Hand">
                      <Button.Template>
                        <ControlTemplate TargetType="Button">
                          <Border x:Name="bdES" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                          </Border>
                          <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bdES" Property="Opacity" Value="0.75"/></Trigger>
                          </ControlTemplate.Triggers>
                        </ControlTemplate>
                      </Button.Template>
                    </Button>
                  </StackPanel>
                </Border>
              </StackPanel>
              <!-- Theme toggle -->
              <StackPanel Orientation="Horizontal" Margin="0,0,0,8" HorizontalAlignment="Center">
                <TextBlock x:Name="ThemeLabel" Text="Theme" FontSize="10" FontWeight="SemiBold"
                           Foreground="#777777" VerticalAlignment="Center" Margin="0,0,8,0"/>
                <Border CornerRadius="6" BorderBrush="#B8D0E8" BorderThickness="1" ClipToBounds="True">
                  <StackPanel Orientation="Horizontal">
                    <Button x:Name="BtnThemeLight" FontSize="11" FontWeight="SemiBold"
                            Width="46" Height="22" BorderThickness="0"
                            Background="#0067C0" Foreground="White" Cursor="Hand">
                      <Button.Template>
                        <ControlTemplate TargetType="Button">
                          <Border x:Name="bdL" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                          </Border>
                          <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bdL" Property="Opacity" Value="0.85"/></Trigger>
                          </ControlTemplate.Triggers>
                        </ControlTemplate>
                      </Button.Template>
                      <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#x2600;" FontSize="10" Margin="0,0,3,0" VerticalAlignment="Center"/>
                        <TextBlock Text="Light" FontSize="10" VerticalAlignment="Center"/>
                      </StackPanel>
                    </Button>
                    <Button x:Name="BtnThemeDark" FontSize="11" FontWeight="SemiBold"
                            Width="46" Height="22" BorderThickness="0"
                            Background="Transparent" Foreground="#3A5570" Cursor="Hand">
                      <Button.Template>
                        <ControlTemplate TargetType="Button">
                          <Border x:Name="bdD" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                          </Border>
                          <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bdD" Property="Opacity" Value="0.75"/></Trigger>
                          </ControlTemplate.Triggers>
                        </ControlTemplate>
                      </Button.Template>
                      <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#x263D;" FontSize="10" Margin="0,0,3,0" VerticalAlignment="Center"/>
                        <TextBlock Text="Dark" FontSize="10" VerticalAlignment="Center"/>
                      </StackPanel>
                    </Button>
                  </StackPanel>
                </Border>
              </StackPanel>
              <!-- Winget status -->
              <StackPanel Orientation="Horizontal" Margin="0,0,0,3">
                <Ellipse x:Name="WingetDot" Width="7" Height="7"
                         Fill="#FFB900" VerticalAlignment="Center" Margin="0,0,7,0"/>
                <TextBlock x:Name="WingetLabel" Text="winget" FontSize="11" FontWeight="SemiBold" Foreground="#AAAAAA"/>
              </StackPanel>
              <TextBlock x:Name="WingetStatus" Text="Checking..."
                         FontSize="9" Foreground="#777777" TextWrapping="Wrap"/>
              <TextBlock x:Name="OsBadge" FontSize="9" Foreground="#888888"
                         Margin="0,2,0,0" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>
        </Grid>
      </Border>

      <!-- RIGHT CONTENT -->
      <Grid Grid.Column="1">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- Page header -->
        <Border x:Name="PageHeader" Grid.Row="0" Background="#FFFFFF"
                BorderBrush="#E5E5E5" BorderThickness="0,0,0,1"
                Padding="24,16">
          <Grid>
            <StackPanel>
              <TextBlock x:Name="PageTitle"    Text="Install Applications"
                         FontSize="20" FontWeight="SemiBold" Foreground="#1A1A1A"/>
              <TextBlock x:Name="PageSubtitle" Text="Select apps to install via winget"
                         FontSize="12" Foreground="#777777" Margin="0,3,0,0"/>
            </StackPanel>
          </Grid>
        </Border>

        <!-- Page switcher -->
        <Grid Grid.Row="1">

          <!-- PAGE: APP UPDATES (hidden - Update All moved to App Manager) -->
          <Grid x:Name="PageApps" Visibility="Collapsed">
          </Grid>

          <!-- legacy stubs kept so $ctrl[] lookups don't crash -->
          <Grid x:Name="PageInstall"    Visibility="Collapsed" Width="0" Height="0"/>
          <Grid x:Name="PageUninstall"  Visibility="Collapsed" Width="0" Height="0"/>
          <Grid x:Name="PageAppUpdates" Visibility="Collapsed" Width="0" Height="0"/>

          <!-- PAGE: APP MANAGER (Install / Uninstall) -->
          <Grid x:Name="PageAppManager" Visibility="Visible">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="170"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Left: category sidebar -->
            <Border x:Name="AMCatSidebar" Grid.Column="0" Background="#F7F7F7" BorderBrush="#E0E0E0" BorderThickness="0,0,1,0">
              <DockPanel>
                <!-- Mode toggle -->
                <Border x:Name="AMModePillBar" DockPanel.Dock="Top" Padding="8,10" BorderBrush="#E0E0E0" BorderThickness="0,0,0,1">
                  <StackPanel>
                    <Border x:Name="AMPillInstall" CornerRadius="6" Padding="10,5"
                            Background="#0067C0" Margin="0,0,0,4" Cursor="Hand">
                      <TextBlock Text="&#x2B07;  Install" FontSize="11" FontWeight="SemiBold"
                                 Foreground="White" HorizontalAlignment="Center"/>
                    </Border>
                    <Border x:Name="AMPillUninstall" CornerRadius="6" Padding="10,5"
                            Background="Transparent" Margin="0,0,0,0" Cursor="Hand"
                            BorderBrush="#DDE4EC" BorderThickness="1">
                      <TextBlock x:Name="AMPillUninstallTxt" Text="&#x2715;  Uninstall" FontSize="11" FontWeight="SemiBold"
                                 Foreground="#5A6A7A" HorizontalAlignment="Center"/>
                    </Border>
                  </StackPanel>
                </Border>
                <!-- Category list -->
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                  <StackPanel x:Name="AMCatPanel" Margin="6,8"/>
                </ScrollViewer>
              </DockPanel>
            </Border>

            <!-- Right: content area -->
            <Grid Grid.Column="1">
              <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
              </Grid.RowDefinitions>

              <!-- Toolbar -->
              <Border x:Name="AMToolbar" Grid.Row="0" Padding="12,9" Background="#FFFFFF"
                      BorderBrush="#E8E8E8" BorderThickness="0,0,0,1">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                  </Grid.ColumnDefinitions>
                  <TextBox x:Name="AMSearch" Grid.Column="0"
                           Style="{StaticResource SearchBox}" Text="" Margin="0,0,10,0"/>
                  <Button x:Name="AMBtnSelectAll"   Grid.Column="1" Content="All"
                          Style="{StaticResource BtnGhost}" Margin="0,0,4,0"/>
                  <Button x:Name="AMBtnDeselectAll" Grid.Column="2" Content="None"
                          Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
                  <TextBlock x:Name="AMSelCount" Grid.Column="3"
                             FontSize="11" Foreground="#888" VerticalAlignment="Center"/>
                </Grid>
              </Border>

              <!-- App list panels -->
              <Grid Grid.Row="1">
                <!-- INSTALL panel -->
                <ScrollViewer x:Name="AMInstallScroll" VerticalScrollBarVisibility="Auto"
                              HorizontalScrollBarVisibility="Disabled">
                  <StackPanel x:Name="AMInstallPanel" Margin="14,10,10,10"/>
                </ScrollViewer>
                <!-- UNINSTALL panel -->
                <ScrollViewer x:Name="AMUninstallScroll" VerticalScrollBarVisibility="Auto"
                              Visibility="Collapsed">
                  <StackPanel x:Name="AMUninstallPanel" Margin="14,10,10,10"/>
                </ScrollViewer>
              </Grid>

              <!-- Bottom action bar -->
              <Border x:Name="AMBottomBar" Grid.Row="2" Background="#F5F5F5" BorderBrush="#E0E0E0"
                      BorderThickness="0,1,0,0" Padding="12,9">
                <Grid>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                  </Grid.RowDefinitions>
                  <!-- Install actions -->
                  <StackPanel x:Name="AMInstallActions" Grid.Row="0" Orientation="Horizontal">
                    <Button x:Name="AMBtnInstall" Content="Install Selected"
                            Style="{StaticResource BtnAccent}" IsEnabled="False" Margin="0,0,8,0"/>
                    <Border x:Name="BtnUpdateAllApps" CornerRadius="8" Padding="14,7"
                            Background="Transparent" Margin="0,0,8,0" Cursor="Hand"
                            ToolTip="Run: winget upgrade --all (opens external window)">
                      <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#x2B06;" FontSize="11" Foreground="#107C10"
                                   VerticalAlignment="Center" Margin="0,0,6,0"/>
                        <TextBlock x:Name="ModeLblUpdateAll" Text="Update All Apps"
                                   FontSize="12" FontWeight="SemiBold"
                                   Foreground="#107C10" VerticalAlignment="Center"/>
                      </StackPanel>
                    </Border>
                    <TextBlock x:Name="AMInstallStatus" FontSize="11"
                               Foreground="#777" VerticalAlignment="Center"/>
                  </StackPanel>
                  <!-- Uninstall actions -->
                  <StackPanel x:Name="AMUninstallActions" Grid.Row="0"
                              Orientation="Horizontal" Visibility="Collapsed">
                    <Button x:Name="AMBtnUninstall" Content="Uninstall Selected"
                            Style="{StaticResource BtnDanger}" IsEnabled="False" Margin="0,0,8,0"/>
                    <Button x:Name="AMBtnRefreshList" Content="Refresh"
                            Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
                    <TextBlock x:Name="AMUninstallStatus" FontSize="11"
                               Foreground="#777" VerticalAlignment="Center"/>
                  </StackPanel>
                  <!-- Progress bar -->
                  <StackPanel x:Name="AMProgressPanel" Grid.Row="1"
                              Visibility="Collapsed" Margin="0,8,0,0">
                    <TextBlock x:Name="AMProgressLabel" FontSize="11"
                               Foreground="#888" Margin="0,0,0,5"/>
                    <ProgressBar x:Name="AMProgressBar" Height="4"
                                 Background="#E0E0E0" Foreground="#0067C0"
                                 BorderThickness="0" Minimum="0" Maximum="100"/>
                  </StackPanel>
                </Grid>
              </Border>
            </Grid>
          </Grid>

          <!-- PAGE: TWEAKS -->
          <Grid x:Name="PageTweaks" Visibility="Collapsed">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Toolbar + Templates -->
            <Border Grid.Row="0" Padding="16,12" Background="#FFFFFF"
                    BorderBrush="#E8E8E8" BorderThickness="0,0,0,1">
              <StackPanel>
                <!-- Templates row -->
                <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                  <TextBlock Text="Templates:" FontSize="12" Foreground="#777777"
                             VerticalAlignment="Center" Margin="0,0,10,0"/>
                  <Button x:Name="TplNone"     Content="None"
                          Style="{StaticResource BtnGhost}" Margin="0,0,6,0" Padding="12,6"/>
                  <Button x:Name="TplStandard" Content="Standard"
                          Style="{StaticResource BtnGhost}" Margin="0,0,6,0" Padding="12,6"/>
                  <Button x:Name="TplMinimal"  Content="Minimal"
                          Style="{StaticResource BtnGhost}" Margin="0,0,6,0" Padding="12,6"/>
                  <Button x:Name="TplHeavy"    Content="Heavy"
                          Style="{StaticResource BtnDanger}" Margin="0,0,6,0" Padding="12,6"/>
                </StackPanel>
                <!-- Controls row -->
                <StackPanel Orientation="Horizontal">
                  <TextBox x:Name="TweakSearch" Style="{StaticResource SearchBox}"
                           Width="220" Margin="0,0,10,0"/>
                  <Button x:Name="BtnCheckAll"   Content="Select All"
                          Style="{StaticResource BtnGhost}" Margin="0,0,6,0"/>
                  <Button x:Name="BtnUncheckAll" Content="None"
                          Style="{StaticResource BtnGhost}" Margin="0,0,6,0"/>
                  <TextBlock x:Name="TweakCountLabel" Text="0 selected"
                             FontSize="12" Foreground="#777777" VerticalAlignment="Center"
                             Margin="10,0,0,0"/>
                </StackPanel>
              </StackPanel>
            </Border>

            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
              <StackPanel x:Name="TweakPanel" Margin="16,12,16,12"/>
            </ScrollViewer>

            <Border Grid.Row="2" Background="#F5F5F5"
                    BorderBrush="#E0E0E0" BorderThickness="0,1,0,0" Padding="16,12">
              <StackPanel Orientation="Horizontal">
                <Button x:Name="BtnApplyTweaks" Content="Apply Selected Tweaks"
                        Style="{StaticResource BtnAccent}" Margin="0,0,10,0"/>
                <Button x:Name="BtnUndoTweaks"  Content="Undo Selected"
                        Style="{StaticResource BtnGhost}"/>
              </StackPanel>
            </Border>
          </Grid>

          <!-- PAGE: SERVICES -->
          <Grid x:Name="PageServices" Visibility="Collapsed">
            <Grid.RowDefinitions>
              <RowDefinition Height="*"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto">
              <StackPanel x:Name="ServicePanel" Margin="16,12,16,12"/>
            </ScrollViewer>
            <Border Grid.Row="1" Background="#F5F5F5"
                    BorderBrush="#E0E0E0" BorderThickness="0,1,0,0" Padding="16,12">
              <StackPanel Orientation="Horizontal">
                <Button x:Name="BtnSvcDisable" Content="Disable Selected"
                        Style="{StaticResource BtnDanger}" Margin="0,0,8,0"/>
                <Button x:Name="BtnSvcManual"  Content="Set Manual"
                        Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
                <Button x:Name="BtnSvcEnable"  Content="Re-Enable"
                        Style="{StaticResource BtnSuccess}"/>
              </StackPanel>
            </Border>
          </Grid>

          <!-- PAGE: REPAIR -->
          <Grid x:Name="PageRepair" Visibility="Collapsed">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <WrapPanel Grid.Row="0" Margin="20,16" Orientation="Horizontal">

              <Border Margin="0,0,12,12" CornerRadius="12" Background="#EEF6FF"
                      BorderBrush="#B8D0E8" BorderThickness="1" Width="200">
                <Button x:Name="BtnSFC" Background="Transparent" BorderThickness="0"
                        Cursor="Hand" Padding="18,16">
                  <StackPanel>
                    <Border Width="44" Height="44" CornerRadius="12" Background="#D8E8F8" Margin="0,0,0,10">
                      <TextBlock Text="&#x1F6E1;" FontSize="22"
                                 HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="SFC + DISM" FontSize="13" FontWeight="SemiBold" Foreground="#1A1A1A"/>
                    <TextBlock Text="Full system file check" FontSize="10" Foreground="#777777" Margin="0,3,0,0" TextWrapping="Wrap"/>
                  </StackPanel>
                </Button>
              </Border>

              <Border Margin="0,0,12,12" CornerRadius="12" Background="#EEF6FF"
                      BorderBrush="#B8D0E8" BorderThickness="1" Width="200">
                <Button x:Name="BtnClearTemp" Background="Transparent" BorderThickness="0"
                        Cursor="Hand" Padding="18,16">
                  <StackPanel>
                    <Border Width="44" Height="44" CornerRadius="12" Background="#F5E8D8" Margin="0,0,0,10">
                      <TextBlock Text="&#x1F5D1;" FontSize="22"
                                 HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="Clear Temp" FontSize="13" FontWeight="SemiBold" Foreground="#1A1A1A"/>
                    <TextBlock Text="Remove junk files" FontSize="10" Foreground="#777777" Margin="0,3,0,0" TextWrapping="Wrap"/>
                  </StackPanel>
                </Button>
              </Border>

              <Border Margin="0,0,12,12" CornerRadius="12" Background="#EEF6FF"
                      BorderBrush="#B8D0E8" BorderThickness="1" Width="200">
                <Button x:Name="BtnFlushDNS" Background="Transparent" BorderThickness="0"
                        Cursor="Hand" Padding="18,16">
                  <StackPanel>
                    <Border Width="44" Height="44" CornerRadius="12" Background="#D8F0E8" Margin="0,0,0,10">
                      <TextBlock Text="&#x1F310;" FontSize="22"
                                 HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="Flush DNS" FontSize="13" FontWeight="SemiBold" Foreground="#1A1A1A"/>
                    <TextBlock Text="Clear DNS resolver cache" FontSize="10" Foreground="#777777" Margin="0,3,0,0" TextWrapping="Wrap"/>
                  </StackPanel>
                </Button>
              </Border>

              <Border Margin="0,0,12,12" CornerRadius="12" Background="#EEF6FF"
                      BorderBrush="#B8D0E8" BorderThickness="1" Width="200">
                <Button x:Name="BtnWsReset" Background="Transparent" BorderThickness="0"
                        Cursor="Hand" Padding="18,16">
                  <StackPanel>
                    <Border Width="44" Height="44" CornerRadius="12" Background="#EED8F0" Margin="0,0,0,10">
                      <TextBlock Text="&#x1F6D2;" FontSize="22"
                                 HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="Reset Store" FontSize="13" FontWeight="SemiBold" Foreground="#1A1A1A"/>
                    <TextBlock Text="Fix Microsoft Store issues" FontSize="10" Foreground="#777777" Margin="0,3,0,0" TextWrapping="Wrap"/>
                  </StackPanel>
                </Button>
              </Border>

              <Border Margin="0,0,12,12" CornerRadius="12" Background="#EEF6FF"
                      BorderBrush="#B8D0E8" BorderThickness="1" Width="200">
                <Button x:Name="BtnRestorePoint" Background="Transparent" BorderThickness="0"
                        Cursor="Hand" Padding="18,16">
                  <StackPanel>
                    <Border Width="44" Height="44" CornerRadius="12" Background="#D8F0DA" Margin="0,0,0,10">
                      <TextBlock Text="&#x1F4BE;" FontSize="22"
                                 HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="Restore Point" FontSize="13" FontWeight="SemiBold" Foreground="#1A1A1A"/>
                    <TextBlock Text="Save system snapshot now" FontSize="10" Foreground="#777777" Margin="0,3,0,0" TextWrapping="Wrap"/>
                  </StackPanel>
                </Button>
              </Border>

              <Border Margin="0,0,12,12" CornerRadius="12" Background="#EEF6FF"
                      BorderBrush="#B8D0E8" BorderThickness="1" Width="200">
                <Button x:Name="BtnNetReset" Background="Transparent" BorderThickness="0"
                        Cursor="Hand" Padding="18,16">
                  <StackPanel>
                    <Border Width="44" Height="44" CornerRadius="12" Background="#F5E8D8" Margin="0,0,0,10">
                      <TextBlock Text="&#x1F504;" FontSize="22"
                                 HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="Network Reset" FontSize="13" FontWeight="SemiBold" Foreground="#1A1A1A"/>
                    <TextBlock Text="Reset Winsock and TCP/IP" FontSize="10" Foreground="#777777" Margin="0,3,0,0" TextWrapping="Wrap"/>
                  </StackPanel>
                </Button>
              </Border>

              <Border Margin="0,0,12,12" CornerRadius="12" Background="#FFF0F0"
                      BorderBrush="#F0C0C0" BorderThickness="1" Width="200">
                <Button x:Name="BtnDeleteRestorePoints" Background="Transparent" BorderThickness="0"
                        Cursor="Hand" Padding="18,16">
                  <StackPanel>
                    <Border Width="44" Height="44" CornerRadius="12" Background="#FDDADA" Margin="0,0,0,10">
                      <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons"
                                 Text="&#xE74D;" FontSize="22" Foreground="#C42B1C"
                                 HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="Delete Restore Points" FontSize="13" FontWeight="SemiBold" Foreground="#1A1A1A"/>
                    <TextBlock Text="Remove all system restore points" FontSize="10" Foreground="#777777" Margin="0,3,0,0" TextWrapping="Wrap"/>
                  </StackPanel>
                </Button>
              </Border>

            </WrapPanel>

            <Border x:Name="RepairOutputBorder" Grid.Row="1" Margin="20,0,20,20" CornerRadius="10"
                    Background="#F8F8F8" BorderBrush="#E0E0E0" BorderThickness="1">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border x:Name="RepairOutputHeader" Grid.Row="0" Background="#F0F0F0" CornerRadius="10,10,0,0"
                        BorderBrush="#E0E0E0" BorderThickness="0,0,0,1" Padding="14,8">
                  <StackPanel Orientation="Horizontal">
                    <TextBlock Text="Output" FontSize="11" FontWeight="SemiBold" Foreground="#777777"/>
                    <TextBlock x:Name="RepairSpinner" Text=" Running..." FontSize="11"
                               Foreground="#0078D4" Visibility="Collapsed"/>
                  </StackPanel>
                </Border>
                <ScrollViewer Grid.Row="1" Height="180" VerticalScrollBarVisibility="Auto">
                  <TextBox x:Name="RepairOutput" Background="Transparent"
                           Foreground="#1A1A1A" FontFamily="Consolas, Courier New"
                           FontSize="11" IsReadOnly="True" BorderThickness="0"
                           TextWrapping="Wrap" Padding="14,10"/>
                </ScrollViewer>
              </Grid>
            </Border>
          </Grid>

          <!-- PAGE: WINDOWS UPDATES — REMOVED Build 5035 -->
          <Grid x:Name="PageUpdates" Visibility="Collapsed" Width="0" Height="0"/>

          <!-- PAGE: ABOUT -->
          <!-- ====================================================== -->
          <!-- PAGE: STARTUP MANAGER                                  -->
          <!-- ====================================================== -->
          <Grid x:Name="PageStartup" Visibility="Collapsed">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Toolbar -->
            <Border Grid.Row="0" Background="#FAFAFA" BorderBrush="#E0E0E0" BorderThickness="0,0,0,1"
                    Padding="16,10">
              <StackPanel Orientation="Horizontal">
                <Button x:Name="StartupBtnRefresh" Content="Refresh List"
                        Style="{StaticResource BtnAccent}" Margin="0,0,8,0"/>
                <Button x:Name="StartupBtnEnable"  Content="Enable Selected"
                        Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
                <Button x:Name="StartupBtnDisable" Content="Disable Selected"
                        Style="{StaticResource BtnGhost}" Margin="0,0,16,0"/>
                <TextBlock x:Name="StartupStatusLabel" VerticalAlignment="Center"
                           FontSize="12" Foreground="#666666"/>
              </StackPanel>
            </Border>

            <!-- List -->
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="16,12,16,0">
              <StackPanel x:Name="StartupPanel"/>
            </ScrollViewer>

            <!-- Bottom status -->
            <Border x:Name="StartupBottomBar" Grid.Row="2" Background="#FAFAFA" BorderBrush="#E0E0E0" BorderThickness="0,1,0,0"
                    Padding="16,8">
              <TextBlock x:Name="StartupCountLabel" FontSize="11" Foreground="#888888"
                         FontFamily="Consolas, Courier New"/>
            </Border>
          </Grid>

          <!-- ====================================================== -->
          <!-- PAGE: DNS CHANGER                                      -->
          <!-- ====================================================== -->
          <Grid x:Name="PageDNS" Visibility="Collapsed">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
              <StackPanel Margin="32,24" MaxWidth="560" HorizontalAlignment="Left">

                <!-- Current DNS info card -->
                <Border x:Name="DNSCurrentCard" Background="#FFFFFF" CornerRadius="10" Padding="18,14"
                        BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,20">
                  <StackPanel>
                    <TextBlock Text="Current DNS" FontSize="11" FontWeight="SemiBold"
                               Foreground="#888888" Margin="0,0,0,8"/>
                    <TextBlock x:Name="DNSCurrentLabel" FontSize="13" Foreground="#1A1A1A"
                               FontFamily="Consolas, Courier New" TextWrapping="Wrap"/>
                    <Button x:Name="DNSBtnRefreshCurrent" Content="Refresh"
                            Style="{StaticResource BtnGhost}" Margin="0,10,0,0"
                            HorizontalAlignment="Left"/>
                  </StackPanel>
                </Border>

                <!-- Presets -->
                <TextBlock x:Name="DNSLblPresets" Text="Quick Presets" FontSize="13" FontWeight="SemiBold"
                           Foreground="#1A1A1A" Margin="0,0,0,10"/>
                <UniformGrid Columns="2" Margin="0,0,0,20">
                  <Button x:Name="DNSBtnCloudflare" Margin="0,0,6,6"
                          Style="{StaticResource BtnGhost}">
                    <StackPanel>
                      <TextBlock Text="Cloudflare" FontWeight="SemiBold" FontSize="13"/>
                      <TextBlock Text="1.1.1.1  /  1.0.0.1" FontSize="10" Foreground="#888888"
                                 FontFamily="Consolas, Courier New"/>
                    </StackPanel>
                  </Button>
                  <Button x:Name="DNSBtnGoogle" Margin="6,0,0,6"
                          Style="{StaticResource BtnGhost}">
                    <StackPanel>
                      <TextBlock Text="Google" FontWeight="SemiBold" FontSize="13"/>
                      <TextBlock Text="8.8.8.8  /  8.8.4.4" FontSize="10" Foreground="#888888"
                                 FontFamily="Consolas, Courier New"/>
                    </StackPanel>
                  </Button>
                  <Button x:Name="DNSBtnQuad9" Margin="0,0,6,0"
                          Style="{StaticResource BtnGhost}">
                    <StackPanel>
                      <TextBlock Text="Quad9" FontWeight="SemiBold" FontSize="13"/>
                      <TextBlock Text="9.9.9.9  /  149.112.112.112" FontSize="10" Foreground="#888888"
                                 FontFamily="Consolas, Courier New"/>
                    </StackPanel>
                  </Button>
                  <Button x:Name="DNSBtnOpenDNS" Margin="6,0,0,0"
                          Style="{StaticResource BtnGhost}">
                    <StackPanel>
                      <TextBlock Text="OpenDNS" FontWeight="SemiBold" FontSize="13"/>
                      <TextBlock Text="208.67.222.222  /  208.67.220.220" FontSize="10" Foreground="#888888"
                                 FontFamily="Consolas, Courier New"/>
                    </StackPanel>
                  </Button>
                </UniformGrid>

                <!-- Custom DNS -->
                <TextBlock x:Name="DNSLblCustom" Text="Custom DNS" FontSize="13" FontWeight="SemiBold"
                           Foreground="#1A1A1A" Margin="0,0,0,10"/>
                <Border x:Name="DNSCustomCard" Background="#FFFFFF" CornerRadius="10" Padding="18,14"
                        BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,16">
                  <StackPanel>
                    <TextBlock Text="Primary DNS" FontSize="11" Foreground="#888888" Margin="0,0,0,4"/>
                    <TextBox x:Name="DNSPrimary" FontFamily="Consolas, Courier New"
                             FontSize="13" Padding="8,6" Margin="0,0,0,12"
                             Background="#F8F8F8" BorderBrush="#DDDDDD" BorderThickness="1"/>
                    <TextBlock Text="Secondary DNS" FontSize="11" Foreground="#888888" Margin="0,0,0,4"/>
                    <TextBox x:Name="DNSSecondary" FontFamily="Consolas, Courier New"
                             FontSize="13" Padding="8,6" Margin="0,0,0,16"
                             Background="#F8F8F8" BorderBrush="#DDDDDD" BorderThickness="1"/>
                    <StackPanel Orientation="Horizontal">
                      <Button x:Name="DNSBtnApplyCustom" Content="Apply Custom DNS"
                              Style="{StaticResource BtnAccent}" Margin="0,0,8,0"/>
                      <Button x:Name="DNSBtnRestoreDefault" Content="Restore Default (DHCP)"
                              Style="{StaticResource BtnGhost}"/>
                    </StackPanel>
                  </StackPanel>
                </Border>

                <!-- Adapter selector note -->
                <Border Background="#F0F7FF" CornerRadius="8" Padding="14,10"
                        BorderBrush="#C5DCF5" BorderThickness="1" Margin="0,0,0,16">
                  <TextBlock FontSize="12" Foreground="#0067C0" TextWrapping="Wrap">
                    <Run FontWeight="SemiBold">Note:</Run>
                    <Run>DNS changes apply to all active network adapters (Ethernet and Wi-Fi). A flush of the DNS cache is performed automatically after applying.</Run>
                  </TextBlock>
                </Border>

                <!-- Output log -->
                <TextBlock x:Name="DNSOutput" FontSize="12" Foreground="#333333"
                           FontFamily="Consolas, Courier New" TextWrapping="Wrap"
                           Margin="0,0,0,8"/>
              </StackPanel>
            </ScrollViewer>
          </Grid>

          <!-- ====================================================== -->
          <!-- PAGE: PROFILE BACKUP                                   -->
          <!-- ====================================================== -->
          <Grid x:Name="PageBackup" Visibility="Collapsed">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
              <StackPanel Margin="32,24" MaxWidth="560" HorizontalAlignment="Left">

                <!-- Export card -->
                <TextBlock x:Name="BackupLblExport" Text="Export Profile" FontSize="13" FontWeight="SemiBold"
                           Foreground="#1A1A1A" Margin="0,0,0,10"/>
                <Border x:Name="BackupExportCard" Background="#FFFFFF" CornerRadius="10" Padding="18,16"
                        BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,20">
                  <StackPanel>
                    <TextBlock FontSize="12" Foreground="#666666" TextWrapping="Wrap" Margin="0,0,0,12">
                      <Run>Saves your current tweak selections, service states and app preferences to a shareable JSON file.</Run>
                    </TextBlock>
                    <TextBlock Text="Profile name (optional)" FontSize="11" Foreground="#888888" Margin="0,0,0,4"/>
                    <TextBox x:Name="BackupProfileName" FontSize="13" Padding="8,6"
                             Background="#F8F8F8" BorderBrush="#DDDDDD" BorderThickness="1"
                             Margin="0,0,0,14"/>
                    <Button x:Name="BackupBtnExport" Content="Export Profile..."
                            Style="{StaticResource BtnAccent}" HorizontalAlignment="Left"/>
                  </StackPanel>
                </Border>

                <!-- Import card -->
                <TextBlock x:Name="BackupLblImport" Text="Import Profile" FontSize="13" FontWeight="SemiBold"
                           Foreground="#1A1A1A" Margin="0,0,0,10"/>
                <Border x:Name="BackupImportCard" Background="#FFFFFF" CornerRadius="10" Padding="18,16"
                        BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,20">
                  <StackPanel>
                    <TextBlock FontSize="12" Foreground="#666666" TextWrapping="Wrap" Margin="0,0,0,12">
                      <Run>Load a previously exported WinTooler profile. Your tweak checkboxes will be updated to match the saved profile.</Run>
                    </TextBlock>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,12">
                      <TextBox x:Name="BackupImportPath" FontFamily="Consolas, Courier New"
                               FontSize="11" Padding="8,6" Width="310" IsReadOnly="True"
                               Background="#F8F8F8" BorderBrush="#DDDDDD" BorderThickness="1"
                               Margin="0,0,8,0"/>
                      <Button x:Name="BackupBtnBrowse" Content="Browse..."
                              Style="{StaticResource BtnGhost}"/>
                    </StackPanel>
                    <Button x:Name="BackupBtnImport" Content="Import and Apply"
                            Style="{StaticResource BtnAccent}" HorizontalAlignment="Left"/>
                  </StackPanel>
                </Border>

                <!-- Saved profiles list -->
                <TextBlock x:Name="BackupLblSaved" Text="Saved Profiles" FontSize="13" FontWeight="SemiBold"
                           Foreground="#1A1A1A" Margin="0,0,0,10"/>
                <Border x:Name="BackupSavedCard" Background="#FFFFFF" CornerRadius="10" Padding="18,14"
                        BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,16">
                  <StackPanel>
                    <TextBlock x:Name="BackupSavedList" FontSize="12" Foreground="#666666"
                               TextWrapping="Wrap" FontFamily="Consolas, Courier New"/>
                    <Button x:Name="BackupBtnRefreshList" Content="Refresh"
                            Style="{StaticResource BtnGhost}" Margin="0,10,0,0"
                            HorizontalAlignment="Left"/>
                  </StackPanel>
                </Border>

                <!-- Status output -->
                <TextBlock x:Name="BackupOutput" FontSize="12" Foreground="#0067C0"
                           TextWrapping="Wrap" FontFamily="Consolas, Courier New"/>
              </StackPanel>
            </ScrollViewer>
          </Grid>

          <!-- ====================================================== -->
          <!-- PAGE: ISO CREATOR                                      -->
          <!-- ====================================================== -->
          <!-- PAGE ISO redesigned Build 5035 -->
          <Grid x:Name="PageISO" Visibility="Collapsed">
            <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
              <Grid Margin="24,20,24,20">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="16"/>
                  <ColumnDefinition Width="330"/>
                </Grid.ColumnDefinitions>

                <!-- LEFT: step controls -->
                <StackPanel Grid.Column="0">

                  <!-- Hidden ISOLanguage kept for code compat -->
                  <ComboBox x:Name="ISOLanguage" Visibility="Collapsed">
                    <ComboBoxItem Content="English (United States)" IsSelected="True"/>
                  </ComboBox>

                  <!-- Step 1: Add ISO file -->
                  <TextBlock Text="Step 1 &#x2014; Select Windows 11 ISO (Required)" FontSize="13" FontWeight="SemiBold"
                             Foreground="#1A1A1A" Margin="0,0,0,8"/>
                  <Border Background="#FFFFFF" CornerRadius="8" Padding="16,14"
                          BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,16">
                    <StackPanel>
                      <TextBlock FontSize="11" Foreground="#666666" TextWrapping="Wrap" Margin="0,0,0,12">
                        Select a Windows 11 ISO to customise. Download official ISOs from Microsoft using the button on the right.
                      </TextBlock>
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="8"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="ISOSelectedPath" Grid.Column="0"
                                 FontFamily="Consolas, Courier New" FontSize="11"
                                 Padding="8,6" Height="32" IsReadOnly="True"
                                 Background="#F8F8F8" BorderBrush="#DDDDDD" BorderThickness="1"
                                 Text="No ISO selected - click Add .iso +"/>
                        <Button x:Name="ISOBtnBrowseISO" Grid.Column="2"
                                Content="Add .iso  +" Style="{StaticResource BtnGhost}"
                                Padding="12,6" FontWeight="SemiBold"/>
                      </Grid>
                    </StackPanel>
                  </Border>

                  <!-- Step 2: Customizations -->
                  <TextBlock Text="Step 2 &#x2014; Customizations" FontSize="13" FontWeight="SemiBold"
                             Foreground="#1A1A1A" Margin="0,0,0,8"/>
                  <Border Background="#FFFFFF" CornerRadius="8" Padding="16,14"
                          BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,16">
                    <StackPanel>
                      <TextBlock Text="Compatibility" FontSize="10" FontWeight="SemiBold"
                                 Foreground="#888888" Margin="0,0,0,8"/>
                      <CheckBox x:Name="ISOBypassTPM"        Content="Bypass TPM 2.0 requirement"                 Margin="0,0,0,8"/>
                      <CheckBox x:Name="ISOBypassSecureBoot" Content="Bypass Secure Boot requirement"              Margin="0,0,0,8"/>
                      <CheckBox x:Name="ISOBypassRAM"        Content="Bypass 4 GB RAM requirement"                 Margin="0,0,0,8"/>
                      <CheckBox x:Name="ISOUnattended"       Content="Enable unattended install (autounattend.xml)" Margin="0,0,0,16"/>
                      <TextBlock Text="Optimisations" FontSize="10" FontWeight="SemiBold"
                                 Foreground="#888888" Margin="0,0,0,8"/>
                      <CheckBox x:Name="ISORemoveBloat" Margin="0,0,0,8">
                        <StackPanel>
                          <TextBlock Text="Remove Microsoft Bloatware" FontSize="12"/>
                          <TextBlock FontSize="10" Foreground="#888888" TextWrapping="Wrap"
                                     Text="Strips Teams, Xbox, News, Weather, Cortana and 15+ pre-installed apps from the WIM"/>
                        </StackPanel>
                      </CheckBox>
                      <CheckBox x:Name="ISOAddDrivers" Margin="0,0,0,10">
                        <StackPanel>
                          <TextBlock Text="Inject Network Drivers" FontSize="12"/>
                          <TextBlock FontSize="10" Foreground="#888888" TextWrapping="Wrap"
                                     Text="Adds .inf drivers from a selected folder into the WIM using DISM"/>
                        </StackPanel>
                      </CheckBox>
                      <Border x:Name="ISODriverPanel" Visibility="Collapsed"
                              Background="#F5F5F5" CornerRadius="6" Padding="10,8"
                              BorderBrush="#DDDDDD" BorderThickness="1">
                        <StackPanel>
                          <TextBlock Text="Driver folder (.inf files):" FontSize="10"
                                     Foreground="#555555" Margin="0,0,0,6"/>
                          <Grid>
                            <Grid.ColumnDefinitions>
                              <ColumnDefinition Width="*"/>
                              <ColumnDefinition Width="8"/>
                              <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="ISODriverPath" Grid.Column="0"
                                     FontFamily="Consolas, Courier New" FontSize="10"
                                     Padding="6,5" Height="28" IsReadOnly="True"
                                     Background="#FFFFFF" BorderBrush="#CCCCCC" BorderThickness="1"
                                     Text="(select folder with .inf drivers)"/>
                            <Button x:Name="ISOBtnBrowseDrivers" Grid.Column="2"
                                    Content="Browse..." Style="{StaticResource BtnGhost}"
                                    Padding="10,5"/>
                          </Grid>
                        </StackPanel>
                      </Border>
                    </StackPanel>
                  </Border>

                  <!-- Step 3: App Packages -->
                  <TextBlock Text="Step 3 &#x2014; App Packages (Optional)" FontSize="13" FontWeight="SemiBold"
                             Foreground="#1A1A1A" Margin="0,0,0,8"/>
                  <Border x:Name="ISOAppsCard" Background="#FFFFFF" CornerRadius="8" Padding="16,14"
                          BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,16">
                    <StackPanel>
                      <TextBlock FontSize="11" Foreground="#666666" TextWrapping="Wrap" Margin="0,0,0,12">
                        Choose apps to embed in the ISO. A winget install script is placed in the ISO root
                        and runs automatically on first logon if Unattended mode is enabled.
                      </TextBlock>
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="12"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <!-- Badge showing selected count -->
                        <Border Grid.Column="0" Background="#F0F7FF" CornerRadius="6" Padding="12,8"
                                BorderBrush="#C5DCF5" BorderThickness="1">
                          <StackPanel Orientation="Horizontal">
                            <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons"
                                       Text="&#xE74C;" FontSize="14" Foreground="#0067C0"
                                       VerticalAlignment="Center" Margin="0,0,10,0"/>
                            <TextBlock x:Name="ISOAppCount" FontSize="12" Foreground="#0067C0"
                                       VerticalAlignment="Center" Text="No apps selected"/>
                          </StackPanel>
                        </Border>
                        <!-- Open picker button -->
                        <Button x:Name="ISOBtnPickApps" Grid.Column="2"
                                Style="{StaticResource BtnAccent}" Padding="16,8">
                          <StackPanel Orientation="Horizontal">
                            <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons"
                                       Text="&#xE710;" FontSize="13" Margin="0,0,8,0" VerticalAlignment="Center"/>
                            <TextBlock Text="Select Apps..." VerticalAlignment="Center"/>
                          </StackPanel>
                        </Button>
                      </Grid>
                    </StackPanel>
                  </Border>

                  <!-- Step 4: Output Folder -->
                  <TextBlock Text="Step 4 &#x2014; Output Folder" FontSize="13" FontWeight="SemiBold"
                             Foreground="#1A1A1A" Margin="0,0,0,8"/>
                  <Border Background="#FFFFFF" CornerRadius="8" Padding="16,12"
                          BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,20">
                    <Grid>
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="8"/>
                        <ColumnDefinition Width="Auto"/>
                      </Grid.ColumnDefinitions>
                      <TextBox x:Name="ISOOutputPath" Grid.Column="0"
                               FontFamily="Consolas, Courier New" FontSize="11"
                               Padding="8,6" Height="32" IsReadOnly="True"
                               Background="#F8F8F8" BorderBrush="#DDDDDD" BorderThickness="1"
                               Text="C:\Users\Public\Downloads"/>
                      <Button x:Name="ISOBtnBrowse" Grid.Column="2"
                              Content="Browse..." Style="{StaticResource BtnGhost}"
                              Padding="12,6"/>
                    </Grid>
                  </Border>

                  <!-- Create button -->
                  <Button x:Name="ISOBtnCreate" Style="{StaticResource BtnAccent}"
                          Padding="24,12" FontSize="14" HorizontalAlignment="Left" Margin="0,0,0,20">
                    <StackPanel Orientation="Horizontal">
                      <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons"
                                 Text="&#xE93C;" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
                      <TextBlock Text="Create Windows 11 ISO" VerticalAlignment="Center"/>
                    </StackPanel>
                  </Button>

                  <!-- Status Log panel -->
                  <Border x:Name="ISOStatusPanel" CornerRadius="8" Background="#F8F8F8" BorderBrush="#E0E0E0" BorderThickness="1">
                    <StackPanel>
                      <TextBlock x:Name="ISOLogLabel" Text="Status Log" FontSize="11" FontWeight="SemiBold" Foreground="#444444"
                                 Margin="16,10,16,6"/>
                      <Border x:Name="ISOLogDivider" Height="1" Background="#E0E0E0"/>
                      <Border x:Name="ISOProgressBorder" Padding="16,10" Visibility="Collapsed">
                        <StackPanel>
                          <TextBlock x:Name="ISOProgressLabel" FontSize="11" FontWeight="SemiBold"
                                     Foreground="#0067C0" Margin="0,0,0,6"/>
                          <ProgressBar x:Name="ISOProgressBar" Height="5" Minimum="0" Maximum="100"
                                       Background="#E0E0E0" Foreground="#0067C0" BorderThickness="0"/>
                        </StackPanel>
                      </Border>
                      <ScrollViewer MaxHeight="140" VerticalScrollBarVisibility="Auto">
                        <TextBox x:Name="ISOOutput" Background="Transparent" Margin="16,8,16,12"
                                 Foreground="#333333" FontFamily="Consolas, Courier New"
                                 FontSize="10" IsReadOnly="True" BorderThickness="0"
                                 TextWrapping="Wrap"/>
                      </ScrollViewer>
                    </StackPanel>
                  </Border>

                  <!-- Hidden controls kept for code compatibility -->
                  <ComboBox x:Name="ISOArch"    Visibility="Collapsed"/>
                  <ComboBox x:Name="ISOVersion" Visibility="Collapsed"/>

                </StackPanel>

                <!-- Spacer -->
                <Grid Grid.Column="1"/>

                <!-- RIGHT: info cards -->
                <StackPanel Grid.Column="2">

                  <!-- Warning card -->
                  <Border Background="#FFF3E0" CornerRadius="8" Padding="16,14"
                          BorderBrush="#FFCC80" BorderThickness="1" Margin="0,0,0,14">
                    <StackPanel>
                      <TextBlock FontSize="12" FontWeight="SemiBold" Foreground="#BF360C"
                                 TextWrapping="Wrap" Margin="0,0,0,8">
                        WARNING: Use only Official Microsoft ISOs
                      </TextBlock>
                      <TextBlock FontSize="11" Foreground="#5D4037" TextWrapping="Wrap">
                        Download Windows 11 directly from Microsoft.com. Third-party or unofficial images are not supported and may produce broken results.
                      </TextBlock>
                    </StackPanel>
                  </Border>

                  <!-- MS download card -->
                  <Border Background="#FFFFFF" CornerRadius="8" Padding="16,14"
                          BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,14">
                    <StackPanel>
                      <TextBlock Text="Get Windows 11 ISO from Microsoft:" FontSize="11"
                                 FontWeight="SemiBold" Foreground="#333333" Margin="0,0,0,10"/>
                      <TextBlock FontSize="11" Foreground="#555555" Margin="0,0,0,4">- Edition: Windows 11 (English)</TextBlock>
                      <TextBlock FontSize="11" Foreground="#555555" Margin="0,0,0,4">- Language: your preferred language</TextBlock>
                      <TextBlock FontSize="11" Foreground="#555555" Margin="0,0,0,14">- Architecture: 64-bit (x64)</TextBlock>
                      <Button x:Name="ISOOpenMSPage" Style="{StaticResource BtnAccent}"
                              Padding="12,8" HorizontalAlignment="Stretch">
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                          <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons"
                                     Text="&#xE774;" FontSize="13" Margin="0,0,8,0" VerticalAlignment="Center"/>
                          <TextBlock Text="Open Microsoft Download Page" FontSize="11" VerticalAlignment="Center"/>
                        </StackPanel>
                      </Button>
                    </StackPanel>
                  </Border>

                  <!-- Requirements card -->
                  <Border Background="#E3F2FD" CornerRadius="8" Padding="16,12"
                          BorderBrush="#90CAF9" BorderThickness="1" Margin="0,0,0,14">
                    <StackPanel>
                      <TextBlock Text="Requirements" FontSize="11" FontWeight="SemiBold"
                                 Foreground="#0D47A1" Margin="0,0,0,8"/>
                      <TextBlock FontSize="10" Foreground="#1565C0" TextWrapping="Wrap" Margin="0,0,0,4">&#x2713; Official Windows 11 ISO from Microsoft</TextBlock>
                      <TextBlock FontSize="10" Foreground="#1565C0" TextWrapping="Wrap" Margin="0,0,0,4">&#x2713; ~8 GB free disk space</TextBlock>
                      <TextBlock FontSize="10" Foreground="#1565C0" TextWrapping="Wrap" Margin="0,0,0,4">&#x2713; DISM (built into Windows)</TextBlock>
                      <TextBlock FontSize="10" Foreground="#1565C0" TextWrapping="Wrap">&#x2713; Administrator privileges</TextBlock>
                    </StackPanel>
                  </Border>

                  <!-- How it works card -->
                  <Border Background="#F9F9F9" CornerRadius="8" Padding="16,12"
                          BorderBrush="#E0E0E0" BorderThickness="1">
                    <StackPanel>
                      <TextBlock Text="How it works" FontSize="11" FontWeight="SemiBold"
                                 Foreground="#333333" Margin="0,0,0,8"/>
                      <TextBlock FontSize="10" Foreground="#555555" TextWrapping="Wrap" Margin="0,0,0,4">1. Mount your official Windows 11 ISO</TextBlock>
                      <TextBlock FontSize="10" Foreground="#555555" TextWrapping="Wrap" Margin="0,0,0,4">2. Extract and patch the WIM (DISM)</TextBlock>
                      <TextBlock FontSize="10" Foreground="#555555" TextWrapping="Wrap" Margin="0,0,0,4">3. Strip bloatware / inject drivers (optional)</TextBlock>
                      <TextBlock FontSize="10" Foreground="#555555" TextWrapping="Wrap">4. Rebuild bootable ISO with oscdimg</TextBlock>
                    </StackPanel>
                  </Border>

                </StackPanel>
              </Grid>
            </ScrollViewer>
          </Grid>

          <Grid x:Name="PageAbout" Visibility="Collapsed">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
              <StackPanel Margin="40,30" MaxWidth="520" HorizontalAlignment="Left">
                <Border Width="72" Height="72" CornerRadius="18" Background="Transparent"
                        Margin="0,0,0,20" HorizontalAlignment="Left">
                  <Image x:Name="AboutIcon" Width="72" Height="72"
                         RenderOptions.BitmapScalingMode="HighQuality"
                         Stretch="UniformToFill"/>
                </Border>
                <TextBlock x:Name="AboutTitle" Text="WinTooler" FontSize="26" FontWeight="Bold" Foreground="#1A1A1A"/>
                <TextBlock x:Name="AboutSub" Text="V0.7 beta  &#xB7;  Build 5035  by ErickP (Eperez98)" FontSize="13" Foreground="#0067C0" Margin="0,4,0,4"/>
                <TextBlock Text="A modern Windows 11 optimization and deployment toolkit." FontSize="12"
                           Foreground="#666666" Margin="0,0,0,16" TextWrapping="Wrap"/>

                <!-- Features list -->
                <Border Background="#F9F9F9" CornerRadius="8" Padding="16,12"
                        BorderBrush="#E5E5E5" BorderThickness="1" Margin="0,0,0,16">
                  <StackPanel>
                    <TextBlock Text="Features in Build 5035" FontSize="12" FontWeight="SemiBold"
                               Foreground="#3A3A3A" Margin="0,0,0,8"/>
                    <TextBlock FontSize="12" Foreground="#555555" TextWrapping="Wrap" LineHeight="22">
                      &#x2022; App Manager (winget / Chocolatey, 376 apps, 9 categories)&#x0A;&#x2022; System Tweaks (23 tweaks - Bloatware, Performance, Privacy, UI)&#x0A;&#x2022; Services Manager (18 services - Enable / Disable / Manual)&#x0A;&#x2022; Repair tools (SFC+DISM, DNS flush, Restore Point, Delete Restore Points)&#x0A;&#x2022; Startup Manager (registry Run keys + startup folders)&#x0A;&#x2022; DNS Changer (Cloudflare, Google, Quad9, OpenDNS, Custom)&#x0A;&#x2022; Profile Backup (JSON export / import with name)&#x0A;&#x2022; ISO Creator (TPM bypass, bloat removal, driver injection, app embedding, unattended)&#x0A;&#x2022; Light &amp; Dark Mode theme + EN / ES language toggle
                    </TextBlock>
                  </StackPanel>
                </Border>

                <!-- Version info card -->
                <Border x:Name="AboutInfoCard" Background="#FFFFFF" CornerRadius="10" Padding="20,16"
                        BorderBrush="#E0E0E0" BorderThickness="1" Margin="0,0,0,16">
                  <StackPanel>
                    <Grid Margin="0,0,0,10">
                      <TextBlock Text="Version"     Foreground="#777777"/>
                      <TextBlock x:Name="AboutVersion" Text="V0.7 beta  Build 5035" Foreground="#1A1A1A" HorizontalAlignment="Right"/>
                    </Grid>
                    <Grid Margin="0,0,0,10">
                      <TextBlock Text="Platform"    Foreground="#777777"/>
                      <TextBlock x:Name="AboutOS"   Foreground="#1A1A1A" HorizontalAlignment="Right"/>
                    </Grid>
                    <Grid Margin="0,0,0,10">
                      <TextBlock Text="License"     Foreground="#777777"/>
                      <TextBlock Text="GPL-3.0"     Foreground="#00CC6A" HorizontalAlignment="Right"/>
                    </Grid>
                    <Grid Margin="0,0,0,10">
                      <TextBlock Text="Engine" Foreground="#777777"/>
                      <TextBlock Text="WinTooler Native Engine v0.7" Foreground="#0078D4" HorizontalAlignment="Right"/>
                    </Grid>
                    <Grid Margin="0,0,0,10">
                      <TextBlock Text="GitHub"      Foreground="#777777"/>
                      <TextBlock Text="github.com/eperez98" Foreground="#0078D4" HorizontalAlignment="Right"/>
                    </Grid>
                    <Grid>
                      <TextBlock Text="Log file"    Foreground="#777777"/>
                      <TextBlock x:Name="LogPathTxt" Foreground="#444444" FontSize="10"
                                 HorizontalAlignment="Right" VerticalAlignment="Center" TextWrapping="Wrap" MaxWidth="280"/>
                    </Grid>
                  </StackPanel>
                </Border>

                <Button x:Name="BtnOpenLog" Content="Open Log File"
                        Style="{StaticResource BtnGhost}"
                        Margin="0,0,0,16" HorizontalAlignment="Left"/>

                <!-- Known Issues card -->
                <Border Background="#FFF8F0" CornerRadius="8" Padding="16,14"
                        BorderBrush="#F0C070" BorderThickness="1" Margin="0,0,0,16">
                  <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                      <TextBlock FontFamily="Segoe MDL2 Assets,Segoe Fluent Icons"
                                 Text="&#xE7BA;" FontSize="14" Foreground="#C45000"
                                 Margin="0,0,8,0" VerticalAlignment="Center"/>
                      <TextBlock Text="Known Issues" FontSize="12" FontWeight="SemiBold"
                                 Foreground="#C45000" VerticalAlignment="Center"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x26A0;" Foreground="#C45000" FontSize="10" Margin="0,1,8,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="440" FontSize="11" Foreground="#555555">
                        ISO Creator requires DISM or Windows ADK (oscdimg). ADK auto-install may need a restart.
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x26A0;" Foreground="#C45000" FontSize="10" Margin="0,1,8,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="440" FontSize="11" Foreground="#555555">
                        ISO app embedding requires winget on the target system. Apps embedded via Install-Apps.bat in the ISO root.
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x26A0;" Foreground="#C45000" FontSize="10" Margin="0,1,8,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="440" FontSize="11" Foreground="#555555">
                        Some Segoe MDL2 Assets icons may not render on Windows 10 builds before 19041. Unicode fallback characters are used.
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x26A0;" Foreground="#C45000" FontSize="10" Margin="0,1,8,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="440" FontSize="11" Foreground="#555555">
                        Chocolatey integration requires a separate install. winget is the primary package manager.
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal">
                      <TextBlock Text="&#x26A0;" Foreground="#C45000" FontSize="10" Margin="0,1,8,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="440" FontSize="11" Foreground="#555555">
                        Startup Manager task disabling requires the TaskScheduler service to be running.
                      </TextBlock>
                    </StackPanel>
                  </StackPanel>
                </Border>

                <!-- v0.7 CURRENT RELEASE badge -->
                <Border Background="#E8F5E9" CornerRadius="6" Padding="10,5"
                        BorderBrush="#A8DFB0" BorderThickness="1" Margin="0,0,0,8"
                        HorizontalAlignment="Left">
                  <StackPanel Orientation="Horizontal">
                    <TextBlock Text="&#x2714;" Foreground="#107C10" FontSize="11" Margin="0,0,6,0" VerticalAlignment="Center"/>
                    <TextBlock Text="v0.7 BETA  -  Tools Expansion  (Current Release)" FontSize="12" FontWeight="SemiBold"
                               Foreground="#107C10"/>
                  </StackPanel>
                </Border>
                <Border x:Name="RoadmapV7Card" Background="#F0FFF4" CornerRadius="10" Padding="18,14"
                        BorderBrush="#A8DFB0" BorderThickness="1" Margin="0,0,0,16">
                  <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x2714;" Foreground="#107C10" FontSize="10" Margin="0,2,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">ISO Creator</Run>
                        <Run Foreground="#666666"> - Mount official ISO, apply patches, rebuild custom bootable ISO</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x2714;" Foreground="#107C10" FontSize="10" Margin="0,2,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Bloatware Removal</Run>
                        <Run Foreground="#666666"> - DISM removes 24 pre-installed Microsoft apps from the WIM</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x2714;" Foreground="#107C10" FontSize="10" Margin="0,2,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">App Package Embedding</Run>
                        <Run Foreground="#666666"> - Select apps from the 376-app catalog to embed as a winget install script</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x2714;" Foreground="#107C10" FontSize="10" Margin="0,2,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Delete All Restore Points</Run>
                        <Run Foreground="#666666"> - New Repair tool: vssadmin + WMI cleanup with confirmation</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x2714;" Foreground="#107C10" FontSize="10" Margin="0,2,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Full Dark Mode</Run>
                        <Run Foreground="#666666"> - All pages and dynamic rows fully themed in Light and Dark</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal">
                      <TextBlock Text="&#x2714;" Foreground="#107C10" FontSize="10" Margin="0,2,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">PS5.1 Compatibility</Run>
                        <Run Foreground="#666666"> - All inline-if patterns eliminated; runs on default Windows PowerShell</Run>
                      </TextBlock>
                    </StackPanel>
                  </StackPanel>
                </Border>

                <!-- Roadmap: v0.8 BETA - Power Features -->
                <TextBlock Text="v0.8 BETA  -  Power Features" FontSize="12" FontWeight="SemiBold"
                           Foreground="#C45000" Margin="0,0,0,8"/>
                <Border x:Name="RoadmapV8Card" Background="#FFF8F0" CornerRadius="10" Padding="18,14"
                        BorderBrush="#F0D0A8" BorderThickness="1" Margin="0,0,0,16">
                  <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x25CF;" Foreground="#C45000" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Hosts File Editor</Run>
                        <Run Foreground="#666666"> - Visual editor with ad-block and privacy presets built in</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x25CF;" Foreground="#C45000" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Driver Updater</Run>
                        <Run Foreground="#666666"> - Scan and update outdated device drivers via winget or vendor sources</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x25CF;" Foreground="#C45000" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Performance Benchmarks</Run>
                        <Run Foreground="#666666"> - Before / after CPU, RAM and disk scoring via WinSAT</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x25CF;" Foreground="#C45000" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Registry Cleaner</Run>
                        <Run Foreground="#666666"> - Orphaned key scan with preview and full undo support</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x25CF;" Foreground="#C45000" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">WSL Manager</Run>
                        <Run Foreground="#666666"> - Install, update and manage Linux distros from the GUI</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x25CF;" Foreground="#C45000" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Custom Tweak Builder</Run>
                        <Run Foreground="#666666"> - Create and save your own registry and service tweaks in-app</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal">
                      <TextBlock Text="&#x25CF;" Foreground="#C45000" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">More Languages</Run>
                        <Run Foreground="#666666"> - French, Portuguese, German and Italian UI translations</Run>
                      </TextBlock>
                    </StackPanel>
                  </StackPanel>
                </Border>

                <!-- Roadmap: v1.0 Release Candidate -->
                <TextBlock Text="v1.0 Release Candidate  -  Stability and Polish" FontSize="12" FontWeight="SemiBold"
                           Foreground="#107C10" Margin="0,0,0,8"/>
                <Border Background="#F0FFF4" CornerRadius="10" Padding="18,14"
                        BorderBrush="#A8DFB0" BorderThickness="1" Margin="0,0,0,20">
                  <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x25CF;" Foreground="#107C10" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Zero known bugs</Run>
                        <Run Foreground="#666666"> - All BETA cycle issues resolved before tagging 1.0</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x25CF;" Foreground="#107C10" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Installer</Run>
                        <Run Foreground="#666666"> - Proper .msi or NSIS installer with Start Menu shortcut and clean uninstall</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x25CF;" Foreground="#107C10" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Auto-Update Check</Run>
                        <Run Foreground="#666666"> - In-app notification when a new version is available on GitHub</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
                      <TextBlock Text="&#x25CF;" Foreground="#107C10" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Code-Signed Script</Run>
                        <Run Foreground="#666666"> - Eliminates SmartScreen warnings on first run</Run>
                      </TextBlock>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal">
                      <TextBlock Text="&#x25CF;" Foreground="#107C10" FontSize="9" Margin="0,3,10,0"/>
                      <TextBlock TextWrapping="Wrap" MaxWidth="420" FontSize="12" Foreground="#333333">
                        <Run FontWeight="SemiBold">Full OS Test Coverage</Run>
                        <Run Foreground="#666666"> - Win10 21H2 and Win11 22H2, 23H2, 24H2 on Intel, AMD and ARM64</Run>
                      </TextBlock>
                    </StackPanel>
                  </StackPanel>
                </Border>

              </StackPanel>
            </ScrollViewer>
          </Grid>

        </Grid>
      </Grid>
    </Grid>

    <!-- Status bar -->
    <Border x:Name="StatusBorder" Grid.Row="1" Background="#F8F9FA"
            BorderBrush="#E5E5E5" BorderThickness="0,1,0,0" Padding="20,5">
      <Grid>
        <TextBlock x:Name="StatusBar" Text="Ready"
                   Foreground="#444444" FontSize="11" FontFamily="Consolas, Courier New"/>
        <TextBlock x:Name="ClockText" HorizontalAlignment="Right"
                   Foreground="#333333" FontSize="11" FontFamily="Consolas, Courier New"/>
      </Grid>
    </Border>
  </Grid>
</Window>
'@

    # Load window
    $reader = New-Object System.Xml.XmlNodeReader($XAML)
    $win    = [Windows.Markup.XamlReader]::Load($reader)

    # ----------------------------------------------------------------
    #  GET CONTROLS
    # ----------------------------------------------------------------
    $ctrl = @{}
    $names = @(
        "Sidebar","PageHeader","StatusBorder",
        "NavAppManager","NavTweaks","NavServices","NavRepair",
        "NavStartup","NavDNS","NavBackup","NavISO","NavAbout",
        "PageApps","PageAppManager","PageInstall","PageUninstall","PageAppUpdates",
        "PageTweaks","PageServices","PageRepair","PageAbout",
        "PageTitle","PageSubtitle","OsBadge","WingetDot","WingetStatus","AboutOS",

        "BtnUpdateAllApps","ModeLblUpdateAll",

        "AMCatSidebar","AMToolbar","AMBottomBar","AMModePillBar",
        "AMPillInstall","AMPillUninstall","AMPillUninstallTxt","AMCatPanel","AMSearch",
        "AMBtnSelectAll","AMBtnDeselectAll","AMSelCount",
        "AMInstallScroll","AMInstallPanel","AMUninstallScroll","AMUninstallPanel",
        "AMInstallActions","AMBtnInstall","AMInstallStatus",
        "AMUninstallActions","AMBtnUninstall","AMBtnRefreshList","AMUninstallStatus",
        "AMProgressPanel","AMProgressLabel","AMProgressBar",

        "TweakSearch","TweakPanel","TweakCountLabel","BtnCheckAll","BtnUncheckAll","BtnApplyTweaks","BtnUndoTweaks",
        "TplNone","TplStandard","TplMinimal","TplHeavy",
        "ServicePanel","BtnSvcDisable","BtnSvcManual","BtnSvcEnable",
        "BtnSFC","BtnClearTemp","BtnFlushDNS","BtnWsReset","BtnRestorePoint","BtnNetReset","BtnDeleteRestorePoints",
        "RepairOutput","RepairSpinner",
        "BtnOpenLog","LogPathTxt","StatusBar","ClockText",
        "SidebarTitle","SidebarSub","SidebarFooter","WingetLabel",

        "TweaksToolbar","TweaksBottomBar","ServicesBottomBar",
        "RepairOutputBorder","RepairOutputHeader",
        "AboutInfoCard","RoadmapV7Card","RoadmapV8Card",
        "AboutTitle","AboutSub","AboutVersion",
        "SidebarIcon","AboutIcon",
        "BtnLangEN","BtnLangES","LangLabel",

        "PageStartup","PageDNS","PageBackup","PageISO",
        "StartupBtnRefresh","StartupBtnEnable","StartupBtnDisable",
        "StartupStatusLabel","StartupPanel","StartupCountLabel",
        "DNSCurrentCard","DNSCustomCard","DNSLblPresets","DNSLblCustom","DNSCurrentLabel","DNSBtnRefreshCurrent",
        "StartupBottomBar",
        "BackupExportCard","BackupImportCard","BackupSavedCard","BackupLblExport","BackupLblImport","BackupLblSaved",
        "DNSBtnCloudflare","DNSBtnGoogle","DNSBtnQuad9","DNSBtnOpenDNS",
        "DNSPrimary","DNSSecondary","DNSBtnApplyCustom","DNSBtnRestoreDefault","DNSOutput",
        "BackupProfileName","BackupBtnExport","BackupImportPath","BackupBtnBrowse",
        "BackupBtnImport","BackupSavedList","BackupBtnRefreshList","BackupOutput",
        "ISOVersion","ISOLanguage","ISOArch","ISOBypassTPM","ISOBypassSecureBoot",
        "ISOBypassRAM","ISOUnattended","ISORemoveBloat","ISOAddDrivers",
        "ISODriverPanel","ISODriverPath","ISOBtnBrowseDrivers",
        "ISOAppsCard","ISOAppCount","ISOBtnPickApps",
        "ISOOutputPath","ISOBtnBrowse","ISOBtnCreate",
        "ISOProgressBorder","ISOProgressLabel","ISOProgressBar","ISOOutput",
        "ISOBtnBrowseISO","ISOSelectedPath","ISOOpenMSPage","ISOStatusPanel","ISOLogLabel","ISOLogDivider",
        "BtnThemeLight","BtnThemeDark","ThemeLabel",
        "SelCountBadge","TweakSelBadge"
    )
    foreach ($n in $names) { $ctrl[$n] = $win.FindName($n) }

    # ----------------------------------------------------------------
    #  THEME APPLY FUNCTION
    # ----------------------------------------------------------------
    function script:Apply-Theme {
        param([bool]$dark)
        $script:IsDark = $dark
        & script:Set-Theme $dark
        $t = $script:T

        # Window + chrome
        $win.Background = script:Brush $t.WinBG
        $ctrl["Sidebar"].Background          = script:Brush $t.SidebarBG
        $ctrl["Sidebar"].BorderBrush         = script:Brush $t.SidebarBorder
        $ctrl["PageHeader"].Background       = script:Brush $t.Surface1
        $ctrl["PageHeader"].BorderBrush      = script:Brush $t.Border1
        $ctrl["StatusBorder"].Background     = script:Brush $t.StatusBG
        $ctrl["StatusBorder"].BorderBrush    = script:Brush $t.StatusBorder
        $ctrl["StatusBar"].Foreground        = script:Brush $t.Text4
        $ctrl["ClockText"].Foreground        = script:Brush $t.Text4
        $ctrl["PageTitle"].Foreground        = script:Brush $t.Text1
        $ctrl["PageSubtitle"].Foreground     = script:Brush $t.Text3


        # Helper to recursively repaint all WPF elements by type
        function script:Repaint-Tree {
            param($root)
            if ($null -eq $root) { return }
            $type = $root.GetType().Name
            switch ($type) {
                "Border" {
                    $tag = $root.Tag
                    if ($tag -eq "card") {
                        $root.Background  = script:Brush $t.CardBG
                        $root.BorderBrush = script:Brush $t.CardBorder
                    } elseif ($tag -eq "surface") {
                        $root.Background  = script:Brush $t.Surface2
                        $root.BorderBrush = script:Brush $t.Border1
                    } elseif ($tag -eq "input") {
                        $root.Background  = script:Brush $t.InputBG
                        $root.BorderBrush = script:Brush $t.Border2
                    } elseif ($tag -eq "header") {
                        $root.Background  = script:Brush $t.Surface1
                        $root.BorderBrush = script:Brush $t.Border1
                    } elseif ($tag -eq "output") {
                        $outBG = if ($t.WinBG -eq "#F3F3F3") { "#F8F8F8" } else { "#1A1A1A" }
                        $root.Background  = script:Brush $outBG
                        $root.BorderBrush = script:Brush $t.Border1
                    }
                }
                "TextBox" {
                    if ($root.IsReadOnly) {
                        $root.Foreground = script:Brush $t.Green
                        $root.Background = script:Brush "Transparent"
                    } else {
                        $root.Background  = script:Brush $t.InputBG
                        $root.Foreground  = script:Brush $t.Text1
                        $root.BorderBrush = script:Brush $t.Border2
                    }
                }
                "TextBlock" {
                    $tag = $root.Tag
                    if     ($tag -eq "muted")  { $root.Foreground = script:Brush $t.Text3 }
                    elseif ($tag -eq "label")  { $root.Foreground = script:Brush $t.Text2 }
                    elseif ($tag -eq "title")  { $root.Foreground = script:Brush $t.Text1 }
                    elseif ($tag -eq "section"){ $root.Foreground = script:Brush $t.Text3 }
                }
                "ComboBox" {
                    $root.Background  = script:Brush $t.InputBG
                    $root.Foreground  = script:Brush $t.Text1
                    $root.BorderBrush = script:Brush $t.Border2
                }
                "ScrollViewer" {
                    $root.Background = script:Brush "Transparent"
                }
            }
            # Walk children
            try {
                $children = switch ($type) {
                    "Grid"         { $root.Children }
                    "StackPanel"   { $root.Children }
                    "WrapPanel"    { $root.Children }
                    "DockPanel"    { $root.Children }
                    "Border"       { if ($root.Child) { @($root.Child) } else { @() } }
                    "ScrollViewer" { if ($root.Content) { @($root.Content) } else { @() } }
                    "ContentPresenter" { @() }
                    default        { @() }
                }
                foreach ($ch in $children) { script:Repaint-Tree $ch }
            } catch {}
        }

        # Paint the main content area
        $mainGrid = $win.Content
        if ($mainGrid) { script:Repaint-Tree $mainGrid }

        # Nav buttons - repaint all with current theme colors
        $navPageMap = @{
            "NavAppManager" = "AppManager"
            "NavTweaks"     = "Tweaks"; "NavServices"   = "Services"; "NavRepair" = "Repair"
            "NavStartup"    = "Startup"; "NavDNS"       = "DNS"; "NavBackup" = "Backup"
            "NavISO"        = "ISO"; "NavAbout"         = "About"
        }
        foreach ($n in $navPageMap.Keys) {
            if ($ctrl[$n]) {
                $isActive = ($script:CurrentPage -eq $navPageMap[$n])
                if ($isActive) {
                    $ctrl[$n].Background = script:Brush $t.NavActBG
                    $ctrl[$n].Foreground = script:Brush $t.NavActFG
                    $ctrl[$n].FontWeight = [Windows.FontWeights]::SemiBold
                } else {
                    $ctrl[$n].Background = [Windows.Media.Brushes]::Transparent
                    $ctrl[$n].Foreground = script:Brush $t.NavBtnFG
                    $ctrl[$n].FontWeight = [Windows.FontWeights]::Normal
                }
            }
        }
        # Repaint nav icon badge backgrounds — monochrome, theme-aware
        $badgeBG = $t.BadgeIconBG
        $badgeFG = $t.BadgeIconFG
        if ($ctrl["Sidebar"]) {
            $sGrid = $ctrl["Sidebar"].Child
            if ($sGrid -and $sGrid.GetType().Name -eq "Grid") {
                foreach ($row in $sGrid.Children) {
                    if ($row.GetType().Name -eq "StackPanel") {
                        foreach ($btn in $row.Children) {
                            if ($btn.GetType().Name -eq "Button") {
                                try {
                                    $sp = $btn.Content
                                    if ($sp -and $sp.GetType().Name -eq "StackPanel") {
                                        $bd = $sp.Children[0]
                                        if ($bd -and $bd.GetType().Name -eq "Border" -and $bd.Width -eq 22) {
                                            $bd.Background = script:Brush $badgeBG
                                            if ($bd.Child) { $bd.Child.Foreground = script:Brush $badgeFG }
                                        }
                                    }
                                } catch {}
                            }
                        }
                        break
                    }
                }
            }
        }

        # Sidebar logo texts
        if ($ctrl["SidebarTitle"])  { $ctrl["SidebarTitle"].Foreground = script:Brush $t.Text1 }
        if ($ctrl["SidebarSub"])    { $ctrl["SidebarSub"].Foreground   = script:Brush $t.Text3 }
        if ($ctrl["WingetLabel"])   { $ctrl["WingetLabel"].Foreground  = script:Brush $t.Text2 }
        if ($ctrl["WingetStatus"])  { $ctrl["WingetStatus"].Foreground = script:Brush $t.Text3 }
        if ($ctrl["OsBadge"])       { $ctrl["OsBadge"].Foreground      = script:Brush $t.Text4 }
        if ($ctrl["SidebarFooter"]) {
            $ctrl["SidebarFooter"].Background  = script:Brush $t.Surface2
            $ctrl["SidebarFooter"].BorderBrush = script:Brush $t.Border1
        }
        # Sidebar section labels (APPS/SYSTEM/TOOLS) - walk nav StackPanel
        if ($ctrl["Sidebar"]) {
            $sg = $ctrl["Sidebar"].Child
            if ($sg -and $sg.GetType().Name -eq "Grid") {
                foreach ($child in $sg.Children) {
                    if ($child.GetType().Name -eq "StackPanel") {
                        foreach ($el in $child.Children) {
                            if ($el.GetType().Name -eq "TextBlock" -and $el.FontSize -eq 9) {
                                $el.Foreground = script:Brush $t.Text4
                            }
                        }
                        break
                    }
                }
            }
        }

        # Page backgrounds - ensure all pages switch
        $pageNames = @("PageAppManager","PageTweaks",
                       "PageServices","PageRepair",
                       "PageStartup","PageDNS","PageBackup","PageISO","PageAbout")
        foreach ($n in $pageNames) {
            if ($ctrl[$n]) { $ctrl[$n].Background = script:Brush $t.WinBG }
        }

        # -- Repaint all hardcoded-dark XAML surfaces -----------------------------
        # Toolbars and sidebars
        $surfaceNames = @("TweaksToolbar")
        foreach ($n in $surfaceNames) {
            if ($ctrl[$n]) {
                $ctrl[$n].Background  = script:Brush $t.Surface1
                $ctrl[$n].BorderBrush = script:Brush $t.Border1
            }
        }
        # Bottom action bars
        $bottomNames = @(
            "TweaksBottomBar","ServicesBottomBar"
        )
        foreach ($n in $bottomNames) {
            if ($ctrl[$n]) {
                $ctrl[$n].Background  = script:Brush $t.StatusBG
                $ctrl[$n].BorderBrush = script:Brush $t.Border1
            }
        }
        # SelCount badge
        if ($ctrl["SelCountBadge"]) {
            $ctrl["SelCountBadge"].Background = script:Brush $t.Surface2
        }
        # Output terminal borders
        $termBG = if ($dark) { "#1A1A1A" } else { "#F8F8F8" }
        $termHd = if ($dark) { "#222222" } else { "#F0F0F0" }
        foreach ($n in @("RepairOutputBorder","ISOProgressBorder")) {
            if ($ctrl[$n]) {
                $ctrl[$n].Background  = script:Brush $termBG
                $ctrl[$n].BorderBrush = script:Brush $t.Border1
            }
        }
        foreach ($n in @("RepairOutputHeader")) {
            if ($ctrl[$n]) {
                $ctrl[$n].Background  = script:Brush $termHd
                $ctrl[$n].BorderBrush = script:Brush $t.Border1
            }
        }
        # About page info card
        if ($ctrl["AboutInfoCard"]) {
            $ctrl["AboutInfoCard"].Background  = script:Brush $t.Surface1
            $ctrl["AboutInfoCard"].BorderBrush = script:Brush $t.Border1
        }
        # Roadmap cards keep their tinted colors but border switches
        if ($ctrl["RoadmapV7Card"]) { $ctrl["RoadmapV7Card"].BorderBrush = script:Brush $t.Border1 }
        if ($ctrl["RoadmapV8Card"]) { $ctrl["RoadmapV8Card"].BorderBrush = script:Brush $t.Border1 }
        # About page text
        if ($ctrl["AboutTitle"])   { $ctrl["AboutTitle"].Foreground   = script:Brush $t.Text1 }
        if ($ctrl["AboutVersion"]) { $ctrl["AboutVersion"].Foreground = script:Brush $t.Text1 }
        if ($ctrl["AboutOS"])      { $ctrl["AboutOS"].Foreground      = script:Brush $t.Text1 }

        # ── App Manager static surfaces ──────────────────────────────────────
        if ($ctrl["AMCatSidebar"]) {
            $ctrl["AMCatSidebar"].Background  = script:Brush $t.Surface2
            $ctrl["AMCatSidebar"].BorderBrush = script:Brush $t.Border1
        }
        if ($ctrl["AMModePillBar"]) {
            $ctrl["AMModePillBar"].Background  = [Windows.Media.Brushes]::Transparent
            $ctrl["AMModePillBar"].BorderBrush = script:Brush $t.Border1
        }
        if ($ctrl["AMToolbar"]) {
            $ctrl["AMToolbar"].Background  = script:Brush $t.Surface1
            $ctrl["AMToolbar"].BorderBrush = script:Brush $t.Border1
        }
        if ($ctrl["AMBottomBar"]) {
            $ctrl["AMBottomBar"].Background  = script:Brush $t.StatusBG
            $ctrl["AMBottomBar"].BorderBrush = script:Brush $t.Border1
        }
        # -- Startup page
        if ($ctrl["StartupBottomBar"]) {
            $ctrl["StartupBottomBar"].Background  = script:Brush $t.StatusBG
            $ctrl["StartupBottomBar"].BorderBrush = script:Brush $t.Border1
        }
        # Startup rows: repaint background and text
        if ($ctrl["StartupPanel"]) {
            foreach ($row in $ctrl["StartupPanel"].Children) {
                if ($row.GetType().Name -eq "Border") {
                    $isEnabled = $true
                    try {
                        $g = $row.Child
                        if ($g -and $g.GetType().Name -eq "Grid") {
                            foreach ($tb in $g.Children) {
                                if ($tb.GetType().Name -eq "TextBlock" -and $tb.HorizontalAlignment -eq "Right") {
                                    $isEnabled = ($tb.Text -eq "Enabled")
                                }
                            }
                        }
                    } catch {}
                    if ($dark) {
                        if ($isEnabled) { $row.Background = script:Brush "#1A2E1A" } else { $row.Background = script:Brush "#2A2A2A" }
                    } else {
                        if ($isEnabled) { $row.Background = script:Brush "#F6FFF7" } else { $row.Background = script:Brush "#FAFAFA" }
                    }
                    try {
                        foreach ($tb in $row.Child.Children) {
                            if ($tb.GetType().Name -eq "TextBlock") {
                                if ($tb.HorizontalAlignment -eq "Right") { continue }
                                if ($tb.FontSize -ge 13) { $tb.Foreground = script:Brush $t.Text1 } else { $tb.Foreground = script:Brush $t.Text3 }
                            }
                        }
                    } catch {}
                }
            }
        }

        # -- DNS page
        foreach ($n in @("DNSCurrentCard","DNSCustomCard")) {
            if ($ctrl[$n]) {
                $ctrl[$n].Background  = script:Brush $t.CardBG
                $ctrl[$n].BorderBrush = script:Brush $t.Border1
            }
        }
        foreach ($n in @("DNSLblPresets","DNSLblCustom")) {
            if ($ctrl[$n]) { $ctrl[$n].Foreground = script:Brush $t.Text1 }
        }
        foreach ($n in @("DNSPrimary","DNSSecondary")) {
            if ($ctrl[$n]) {
                $ctrl[$n].Background  = script:Brush $t.InputBG
                $ctrl[$n].Foreground  = script:Brush $t.Text1
                $ctrl[$n].BorderBrush = script:Brush $t.Border2
            }
        }
        # DNS / Backup text outputs
        foreach ($n in @("DNSOutput","BackupOutput","DNSCurrentLabel","BackupSavedList")) {
            if ($ctrl[$n]) { $ctrl[$n].Foreground = script:Brush $t.Text1 }
        }

        # -- Backup page
        foreach ($n in @("BackupExportCard","BackupImportCard","BackupSavedCard")) {
            if ($ctrl[$n]) {
                $ctrl[$n].Background  = script:Brush $t.CardBG
                $ctrl[$n].BorderBrush = script:Brush $t.Border1
            }
        }
        foreach ($n in @("BackupLblExport","BackupLblImport","BackupLblSaved")) {
            if ($ctrl[$n]) { $ctrl[$n].Foreground = script:Brush $t.Text1 }
        }
        foreach ($n in @("BackupProfileName","BackupImportPath")) {
            if ($ctrl[$n]) {
                $ctrl[$n].Background  = script:Brush $t.InputBG
                $ctrl[$n].Foreground  = script:Brush $t.Text1
                $ctrl[$n].BorderBrush = script:Brush $t.Border2
            }
        }

        # -- ISO page inputs
        foreach ($n in @("ISOOutputPath","ISOSelectedPath")) {
            if ($ctrl[$n]) {
                $ctrl[$n].Background  = script:Brush $t.InputBG
                $ctrl[$n].Foreground  = script:Brush $t.Text3
                $ctrl[$n].BorderBrush = script:Brush $t.Border2
            }
        }
        if ($ctrl["ISOStatusPanel"]) {
            $ctrl["ISOStatusPanel"].Background  = script:Brush $t.StatusBG
            $ctrl["ISOStatusPanel"].BorderBrush = script:Brush $t.Border1
        }
        if ($ctrl["ISOLogLabel"])   { $ctrl["ISOLogLabel"].Foreground   = script:Brush $t.Text3 }
        if ($ctrl["ISOLogDivider"]) { $ctrl["ISOLogDivider"].Background = script:Brush $t.Border1 }
        if ($ctrl["ISOOutput"])     { $ctrl["ISOOutput"].Foreground     = script:Brush $t.Text1 }
        if ($ctrl["ISOProgressBorder"]) { $ctrl["ISOProgressBorder"].Background = script:Brush $t.StatusBG }
        # ISO app panel
        if ($ctrl["ISOAppsCard"]) {
            $ctrl["ISOAppsCard"].Background  = script:Brush $t.CardBG
            $ctrl["ISOAppsCard"].BorderBrush = script:Brush $t.Border1
        }
        if ($ctrl["ISOAppCount"])  { $ctrl["ISOAppCount"].Foreground  = script:Brush $t.Text3 }
        if ($ctrl["ISOAppSearch"]) {
            $ctrl["ISOAppSearch"].Background  = script:Brush $t.InputBG
            $ctrl["ISOAppSearch"].Foreground  = script:Brush $t.Text1
            $ctrl["ISOAppSearch"].BorderBrush = script:Brush $t.Border2
        }
        # Rebuild app rows with correct theme colors
        if ($ctrl["ISOAppPanel"] -and $ctrl["ISOAppPanel"].Children.Count -gt 0) {
            $sepClr = if ($dark) { "#333333" } else { "#EEEEEE" }
            $nameFG = if ($dark) { "#E0E0E0" } else { "#1A1A1A" }
            $idFG   = if ($dark) { "#888888" } else { "#888888" }
            $hdrFG  = if ($dark) { "#666666" } else { "#888888" }
            foreach ($child in $ctrl["ISOAppPanel"].Children) {
                if ($child.GetType().Name -eq "TextBlock") {
                    $child.Foreground = script:Brush $hdrFG
                } elseif ($child.GetType().Name -eq "Border") {
                    $child.BorderBrush = script:Brush $sepClr
                    try {
                        $sp = $child.Child.Children | Where-Object { $_.GetType().Name -eq "StackPanel" }
                        if ($sp) {
                            $kids = @($sp.Children)
                            if ($kids.Count -ge 1) { $kids[0].Foreground = script:Brush $nameFG }
                            if ($kids.Count -ge 2) { $kids[1].Foreground = script:Brush $idFG   }
                        }
                    } catch {}
                }
            }
            & $script:ISOBuildCatBar
        }
        # Search box text color
        if ($ctrl["AMSearch"]) {
            $ctrl["AMSearch"].Background  = script:Brush $t.InputBG
            $ctrl["AMSearch"].Foreground  = script:Brush $t.Text1
            $ctrl["AMSearch"].BorderBrush = script:Brush $t.Border2
        }
        # AM button / label colors
        if ($ctrl["AMSelCount"])       { $ctrl["AMSelCount"].Foreground       = script:Brush $t.Text3 }
        if ($ctrl["AMInstallStatus"])  { $ctrl["AMInstallStatus"].Foreground  = script:Brush $t.Text3 }
        if ($ctrl["AMUninstallStatus"]){ $ctrl["AMUninstallStatus"].Foreground= script:Brush $t.Text3 }
        # Pill borders (inactive state)
        if (-not $script:AMIsUninstall -and $ctrl["AMPillUninstall"]) {
            $ctrl["AMPillUninstall"].BorderBrush = script:Brush $t.Border2
            if ($ctrl["AMPillUninstallTxt"]) {
                $ctrl["AMPillUninstallTxt"].Foreground = script:Brush $t.Text3
            }
        }

        # ── Repaint dynamically-built AM rows & category buttons ─────────────
        $rowBorderColor = if ($dark) { "#333333" } else { "#EEEEEE" }
        $rowTextMain    = if ($dark) { "#E0E0E0" } else { "#1A1A1A" }
        $rowTextMuted   = if ($dark) { "#888888" } else { "#777777" }
        $catActiveBG    = if ($dark) { "#1E3452" } else { "#E3F0FB" }
        $catActiveFG    = if ($dark) { "#7AB8FF" } else { "#0067C0" }
        $catInactiveFG  = if ($dark) { "#CCCCCC" } else { "#444444" }
        $hdrFG          = if ($dark) { "#666666" } else { "#888888" }

        # Repaint category buttons
        if ($ctrl["AMCatPanel"]) {
            foreach ($bd in $ctrl["AMCatPanel"].Children) {
                $isActive = ($bd.Tag -eq $script:AMCurCat)
                if ($isActive) { $bd.Background = script:Brush $catActiveBG } else { $bd.Background = [Windows.Media.Brushes]::Transparent }
                if ($bd.Child) {
                    if ($isActive) { $bd.Child.Foreground = script:Brush $catActiveFG } else { $bd.Child.Foreground = script:Brush $catInactiveFG }
                }
            }
        }

        # Repaint install rows
        foreach ($panel in @($ctrl["AMInstallPanel"], $ctrl["AMUninstallPanel"])) {
            if (-not $panel) { continue }
            foreach ($child in $panel.Children) {
                $type = $child.GetType().Name
                if ($type -eq "Border") {
                    # App row border
                    $child.BorderBrush = script:Brush $rowBorderColor
                    # Walk into row contents and recolor text
                    try {
                        $grid = $child.Child
                        if ($grid -and $grid.GetType().Name -eq "Grid") {
                            foreach ($gc in $grid.Children) {
                                if ($gc.GetType().Name -eq "StackPanel") {
                                    foreach ($tb in $gc.Children) {
                                        if ($tb.GetType().Name -eq "TextBlock") {
                                            $tag = $tb.Tag
                                            if     ($tag -eq "appName") { $tb.Foreground = script:Brush $rowTextMain  }
                                            elseif ($tag -eq "appDesc") { $tb.Foreground = script:Brush $rowTextMuted }
                                            elseif ($tag -eq "appId")   { $tb.Foreground = script:Brush $rowTextMuted }
                                        }
                                    }
                                }
                            }
                        }
                    } catch {}
                } elseif ($type -eq "TextBlock") {
                    # Category header label
                    $child.Foreground = script:Brush $hdrFG
                }
            }
        }


        # Explicit control overrides (controls without Tag that need specific colours)
        $specText = @(
            "PageTitle","PageSubtitle","WingetStatus","OsBadge","RepairSpinner",
            "StatusBar","ClockText","TweakCountLabel"
        )
        foreach ($n in $specText) {
            if ($ctrl[$n]) { $ctrl[$n].Foreground = script:Brush $t.Text2 }
        }
        # Titles stay bright
        if ($ctrl["PageTitle"])    { $ctrl["PageTitle"].Foreground    = script:Brush $t.Text1 }
        if ($ctrl["PageSubtitle"]) { $ctrl["PageSubtitle"].Foreground = script:Brush $t.Text3 }

        # Search boxes
        foreach ($n in @("TweakSearch")) {
            if ($ctrl[$n]) {
                $ctrl[$n].Background  = script:Brush $t.InputBG
                $ctrl[$n].Foreground  = script:Brush $t.Text1
                $ctrl[$n].BorderBrush = script:Brush $t.Border2
            }
        }

        # Output consoles adapt to theme
        foreach ($n in @("RepairOutput","ISOOutput","AppUpdateOutput")) {
            if ($ctrl[$n]) {
                $ctrl[$n].Foreground = script:Brush $t.Text1
                $ctrl[$n].Background = script:Brush "Transparent"
            }
        }

        # Rebuild dynamic panels so they pick up new $script:T token values
        if ($ctrl["TweakPanel"] -and $ctrl["TweakPanel"].Children.Count -gt 0) {
            foreach ($child in $ctrl["TweakPanel"].Children) {
                $tn = $child.GetType().Name
                if ($tn -eq "Border" -and $child.Child -and $child.Child.GetType().Name -eq "Grid") {
                    $child.Background  = script:Brush $t.CardBG
                    $child.BorderBrush = script:Brush $t.CardBorder
                    $grid = $child.Child
                    foreach ($col in $grid.Children) {
                        if ($col.GetType().Name -eq "StackPanel") {
                            $kids = @($col.Children)
                            if ($kids.Count -ge 1) { $kids[0].Foreground = script:Brush $t.Text1 }
                            if ($kids.Count -ge 2) { $kids[1].Foreground = script:Brush $t.Text3 }
                        }
                    }
                } elseif ($tn -eq "TextBlock") {
                    $child.Foreground = script:Brush $t.Text3
                }
            }
        }

        if ($ctrl["ServicePanel"] -and $ctrl["ServicePanel"].Children.Count -gt 0) {
            foreach ($card in $ctrl["ServicePanel"].Children) {
                if ($card.GetType().Name -eq "Border" -and $card.Child -and $card.Child.GetType().Name -eq "Grid") {
                    $card.Background  = script:Brush $t.CardBG
                    $card.BorderBrush = script:Brush $t.CardBorder
                    $grid = $card.Child
                    foreach ($col in $grid.Children) {
                        if ($col.GetType().Name -eq "StackPanel") {
                            $kids = @($col.Children)
                            if ($kids.Count -ge 1) { $kids[0].Foreground = script:Brush $t.Text1 }
                            if ($kids.Count -ge 2) { $kids[1].Foreground = script:Brush $t.Text3 }
                            if ($kids.Count -ge 3) { $kids[2].Foreground = script:Brush $t.Text4 }
                        }
                    }
                }
            }
        }
    }

    # ----------------------------------------------------------------
    #  HELPERS
    # ----------------------------------------------------------------
    $pages   = @("AppManager","Tweaks","Services","Repair","Startup","DNS","Backup","ISO","About")
    $navBtns = @{
        "AppManager" = $ctrl["NavAppManager"]
        "Tweaks"     = $ctrl["NavTweaks"]
        "Services"   = $ctrl["NavServices"]
        "Repair"     = $ctrl["NavRepair"]
        "Startup"    = $ctrl["NavStartup"]
        "DNS"        = $ctrl["NavDNS"]
        "Backup"     = $ctrl["NavBackup"]
        "ISO"        = $ctrl["NavISO"]
        "About"      = $ctrl["NavAbout"]
    }
    $pageTitles = @{
        "AppManager" = @("App Manager",                  "Install or uninstall apps via winget / Chocolatey")
        "Tweaks"     = @("System Tweaks",                "Apply performance, privacy and UI optimisations")
        "Services"   = @("Windows Services",             "Manage and disable unnecessary background services")
        "Repair"     = @("Repair & Maintenance",         "Diagnose and fix common Windows issues")
        "Startup"    = @("Startup Manager",              "View, enable and disable startup programs and tasks")
        "DNS"        = @("DNS Changer",                  "Switch between Cloudflare, Google, Quad9 or custom DNS")
        "Backup"     = @("Profile Backup",               "Export and restore your tweak configuration as JSON")
        "ISO"        = @("Windows 11 ISO Creator",       "Download and build a custom Windows 11 installation ISO")
        "About"      = @("About WinTooler",              "Version information, credits and roadmap")
    }

    $navStyleActive   = $win.Resources["NavBtnActive"]
    $navStyleInactive = $win.Resources["NavBtn"]
    $script:CurrentPage = "AppManager"
    $script:setStatus = { param($msg, $color = "#444444")
        $ctrl["StatusBar"].Text       = $msg
        $ctrl["StatusBar"].Foreground = script:Brush $color
        Write-WTLog $msg
    }

    $switchPage = {
        param($page)
        foreach ($p in $pages) {
            $ctrl["Page$p"].Visibility = if ($p -eq $page) { "Visible" } else { "Collapsed" }
            if ($navBtns.ContainsKey($p)) {
                $btn = $navBtns[$p]
                if ($p -eq $page) {
                    $btn.Background = script:Brush $script:T.NavActBG
                    $btn.Foreground = script:Brush $script:T.NavActFG
                    $btn.FontWeight = [Windows.FontWeights]::SemiBold
                } else {
                    $btn.Background = [Windows.Media.Brushes]::Transparent
                    $btn.Foreground = script:Brush $script:T.NavBtnFG
                    $btn.FontWeight = [Windows.FontWeights]::Normal
                }
            }
        }
        $ctrl["PageTitle"].Text    = $pageTitles[$page][0]
        $ctrl["PageSubtitle"].Text = $pageTitles[$page][1]
        $script:CurrentPage = $page
    }

    foreach ($p in $pages) {
        $pg = $p
        if ($navBtns.ContainsKey($pg)) {
            $navBtns[$pg].Add_Click({ & $switchPage $pg }.GetNewClosure())
        }
    }

    # -- App Manager: Update All Apps -- launches external PowerShell window --
    $ctrl["BtnUpdateAllApps"].Add_MouseLeftButtonUp({
        if (-not $global:WingetPath) {
            [System.Windows.MessageBox]::Show(
                "winget not found. Please install App Installer from the Microsoft Store.",
                "WinTooler - winget not found",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            ) | Out-Null
            return
        }
        $ps = "Write-Host '  WinTooler - Update All Apps' -ForegroundColor Cyan; " +
              "Write-Host '  Running: winget upgrade --all --accept-source-agreements --accept-package-agreements -h' -ForegroundColor DarkGray; " +
              "Write-Host ''; " +
              "& '$($global:WingetPath)' upgrade --all --accept-source-agreements --accept-package-agreements -h; " +
              "Write-Host ''; " +
              "Write-Host '  Done. Press any key to close...' -ForegroundColor Green; " +
              "`$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')"
        Start-Process "powershell.exe" -ArgumentList "-NoProfile -NoLogo -ExecutionPolicy Bypass -Command `"$ps`"" -WindowStyle Normal
        Write-WTLog "Launched external winget upgrade --all -h"
    })
    $ctrl["BtnUpdateAllApps"].Add_MouseEnter({
        $ctrl["BtnUpdateAllApps"].Background = New-Object Windows.Media.SolidColorBrush(
            [Windows.Media.Color]::FromArgb(25, 16, 124, 16))
    })
    $ctrl["BtnUpdateAllApps"].Add_MouseLeave({
        $ctrl["BtnUpdateAllApps"].Background = [Windows.Media.Brushes]::Transparent
    })

    # Clock
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({ $ctrl["ClockText"].Text = Get-Date -Format "HH:mm:ss  ddd dd MMM" })
    $timer.Start()

    # Theme toggle


    # OS / winget badges
    $ctrl["OsBadge"].Text    = "$($global:OSLabel) Build $($global:OSBuild)"
    $ctrl["LogPathTxt"].Text = $global:LogFile
    $ctrl["AboutOS"].Text    = "$($global:OSLabel) Build $($global:OSBuild)"

    # ----------------------------------------------------------------
    #  APPLY-LANGUAGE  -- builds $S from current $lang, updates all controls
    #  Call at startup AND whenever the in-app toggle is clicked
    # ----------------------------------------------------------------
    function script:Build-StringTable { param([string]$l)
        if ($l -eq "ES") {
            return @{
                NavApps       = "Act. de Apps"
                NavAppManager = "Gestor de Apps"
                NavAppUpdates = "Act. de Apps";     NavTweaks      = "Ajustes"
                NavServices   = "Servicios";        NavRepair      = "Reparar"
                TitleApps         = "Actualizaciones de Apps"
                TitleAppManager   = "Gestor de Aplicaciones"
                SubAppManager     = "Instala o desinstala apps via winget/Chocolatey"
                SubApps           = "Comprueba e instala actualizaciones de apps via winget"
                ModeLblUpdateAll = "Actualizar Todo"
                TitleTweaks     = "Ajustes del Sistema"
                SubTweaks       = "Optimizacion de rendimiento, privacidad e interfaz"
                TitleServices   = "Servicios de Windows"
                SubServices     = "Gestiona servicios en segundo plano"
                TitleRepair     = "Reparacion y Mantenimiento"
                SubRepair       = "Diagnostica y repara problemas comunes de Windows"
                TitleAbout      = "Acerca de WinToolerV1"
                SubAbout        = "Informacion de version y creditos"
                BtnCheckAppUpdates = "Buscar Actualizaciones de Apps"
                BtnCheckAll      = "Selec. Todo";   BtnUncheckAll   = "Ninguno"
                BtnApplyTweaks   = "Aplicar Ajustes Seleccionados"
                BtnUndoTweaks    = "Deshacer Seleccionados"
                BtnSvcDisable    = "Deshabilitar Selec."
                BtnSvcManual     = "Poner Manual"
                BtnSvcEnable     = "Reactivar"
                BtnOpenLog       = "Abrir Archivo de Log"
                TplNone          = "Ninguno";        TplStandard = "Estandar"
                TplMinimal       = "Minimo";         TplHeavy    = "Completo"
                LangToggleLabel  = "Idioma"
                DiskCleanTitle   = "Limpieza de Disco"
                DiskCleanMsg     = "Ejecutando limpieza de disco en segundo plano..."
                DiskCleanDone    = "Limpieza de disco finalizada."
                TweaksDone       = "Listo! Aplicados"
                TweaksOf         = "de"
                TweaksDiskClean  = "tweaks. Iniciando limpieza de disco..."
                SearchPlaceholder = "Buscar..."
                StatusReady      = "Listo"
                AboutVersion     = "Version";        AboutLicense = "Licencia"
                AboutInspired    = "Inspirado en";   AboutLog     = "Archivo de log"
            }
        } else {
            return @{
                NavApps       = "App Updates"
                NavAppManager = "App Manager"
                NavAppUpdates = "App Updates";      NavTweaks      = "Tweaks"
                NavServices   = "Services";         NavRepair      = "Repair"
                TitleApps         = "App Updates"
                TitleAppManager   = "App Manager"
                SubAppManager     = "Install or uninstall apps via winget / Chocolatey"
                SubApps           = "Check and install available app updates via winget"
                ModeLblUpdateAll = "Update All Apps"
                TitleTweaks     = "System Tweaks"
                SubTweaks       = "Apply performance, privacy and UI optimisations"
                TitleServices   = "Windows Services"
                SubServices     = "Manage and disable unnecessary background services"
                TitleRepair     = "Repair and Maintenance"
                SubRepair       = "Diagnose and fix common Windows issues"
                TitleAbout      = "About WinToolerV1"
                SubAbout        = "Version information and credits"
                BtnCheckAppUpdates = "Check for App Updates"
                BtnCheckAll      = "Select All";    BtnUncheckAll   = "None"
                BtnApplyTweaks   = "Apply Selected Tweaks"
                BtnUndoTweaks    = "Undo Selected"
                BtnSvcDisable    = "Disable Selected"
                BtnSvcManual     = "Set Manual"
                BtnSvcEnable     = "Re-Enable"
                BtnOpenLog       = "Open Log File"
                TplNone          = "None";           TplStandard = "Standard"
                TplMinimal       = "Minimal";        TplHeavy    = "Heavy"
                LangToggleLabel  = "Language"
                DiskCleanTitle   = "Disk Cleanup"
                DiskCleanMsg     = "Running disk cleanup in the background..."
                DiskCleanDone    = "Disk cleanup finished."
                TweaksDone       = "Done! Applied"
                TweaksOf         = "of"
                TweaksDiskClean  = "tweaks. Running disk cleanup..."
                SearchPlaceholder = "Search..."
                StatusReady      = "Ready"
                AboutVersion     = "Version";        AboutLicense = "License"
                AboutInspired    = "Inspired by";    AboutLog     = "Log file"
            }
        }
    }

    $script:applyLanguage = { param([string]$newLang)
        $script:lang        = $newLang
        $global:UILanguage  = $newLang
        $S                  = script:Build-StringTable $newLang
        $global:UIStrings   = $S

        # -- Button / control labels --
        $map = @{
            "BtnCheckAppUpdates" = "BtnCheckAppUpdates"
            "BtnCheckAll"      = "BtnCheckAll";    "BtnUncheckAll"    = "BtnUncheckAll"
            "BtnApplyTweaks"   = "BtnApplyTweaks"; "BtnUndoTweaks"    = "BtnUndoTweaks"
            "BtnSvcDisable"    = "BtnSvcDisable";  "BtnSvcManual"     = "BtnSvcManual"
            "BtnSvcEnable"     = "BtnSvcEnable"
            "TplNone"          = "TplNone";        "TplStandard"      = "TplStandard"
            "TplMinimal"       = "TplMinimal";     "TplHeavy"         = "TplHeavy"
        }
        foreach ($ctrlName in $map.Keys) {
            if ($ctrl[$ctrlName]) { $ctrl[$ctrlName].Content = $S[$map[$ctrlName]] }
        }

        # -- Lang label --
        if ($ctrl["LangLabel"]) { $ctrl["LangLabel"].Text = $S["LangToggleLabel"] }

        # -- Toggle button visual state --
        $isES = ($newLang -eq "ES")
        $enBG = if (-not $isES) { "#0067C0" } else { "Transparent" }
        $inactLangFG = if ($script:IsDark) { "#AAAAAA" } else { "#3A5570" }
        $enFG = if (-not $isES) { "#FFFFFF"  } else { $inactLangFG }
        $esBG = if ($isES)      { "#0067C0" } else { "Transparent" }
        $esFG = if ($isES)      { "#FFFFFF"  } else { $inactLangFG }
        if ($ctrl["BtnLangEN"]) {
            $ctrl["BtnLangEN"].Background = script:Brush $enBG
            $ctrl["BtnLangEN"].Foreground = script:Brush $enFG
        }
        if ($ctrl["BtnLangES"]) {
            $ctrl["BtnLangES"].Background = script:Brush $esBG
            $ctrl["BtnLangES"].Foreground = script:Brush $esFG
        }

        # -- Nav button text --
        $navLabelMap = @{
            "NavApps"="NavApps"; "NavAppManager"="NavAppManager"; "NavTweaks"="NavTweaks"
            "NavServices"="NavServices"; "NavRepair"="NavRepair"
            "NavAbout"="NavAbout"
        }
        foreach ($n in $navLabelMap.Keys) {
            if (-not $ctrl[$n]) { continue }
            try {
                $sp = $ctrl[$n].Content
                if ($sp -and $sp.GetType().Name -eq "StackPanel") {
                    $lbl = $sp.Children | Where-Object { $_.GetType().Name -eq "TextBlock" } | Select-Object -Last 1
                    if ($lbl -and $S.ContainsKey($navLabelMap[$n])) {
                        $lbl.Text = $S[$navLabelMap[$n]]
                    }
                }
            } catch {}
        }

        # -- Page titles map --
        $pageTitles["AppManager"] = @($S["TitleAppManager"],  $S["SubAppManager"])
        $pageTitles["Tweaks"]     = @($S["TitleTweaks"],      $S["SubTweaks"])
        $pageTitles["Services"]   = @($S["TitleServices"],    $S["SubServices"])
        $pageTitles["Repair"]     = @($S["TitleRepair"],      $S["SubRepair"])
        $pageTitles["Updates"]    = @($S["TitleUpdates"],     $S["SubUpdates"])
        $pageTitles["About"]      = @($S["TitleAbout"],       $S["SubAbout"])

        # -- Update All Apps pill label --
        if ($ctrl["ModeLblUpdateAll"]) { $ctrl["ModeLblUpdateAll"].Text = if ($S.ContainsKey("ModeLblUpdateAll")) { $S["ModeLblUpdateAll"] } else { "Update All Apps" } }

        # -- Refresh current page header immediately --
        if ($pageTitles.ContainsKey($script:CurrentPage)) {
            $ctrl["PageTitle"].Text    = $pageTitles[$script:CurrentPage][0]
            $ctrl["PageSubtitle"].Text = $pageTitles[$script:CurrentPage][1]
        }
    }

    # Apply Aero glass effect once window handle is available
    $win.Add_SourceInitialized({
        try {
            $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($win)).Handle
            $enabled = $false
            [AeroGlass]::DwmIsCompositionEnabled([ref]$enabled) | Out-Null
            if ($enabled) {
                # Extend frame across entire client area (-1 = all margins)
                $m = New-Object AeroGlass+MARGINS
                $m.Left = -1; $m.Right = -1; $m.Top = -1; $m.Bottom = -1
                [AeroGlass]::DwmExtendFrameIntoClientArea($hwnd, [ref]$m) | Out-Null
            }
        } catch {}
    })

    $win.Add_Loaded({
        try {
            # Apply startup theme
            & script:Apply-Theme $false

            # Load app icon -- use $global:Root set by WinToolerV1.ps1 launcher
            try {
                $iconBase = if ($global:Root) { $global:Root } else { $PSScriptRoot }
                $iconPath = Join-Path $iconBase "WinToolerV1_icon.png"
                if (Test-Path $iconPath) {
                    $iconAbsPath = (Resolve-Path $iconPath).Path
                    $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
                    $bmp.BeginInit()
                    $bmp.UriSource        = New-Object System.Uri($iconAbsPath, [System.UriKind]::Absolute)
                    $bmp.DecodePixelWidth = 128
                    $bmp.CacheOption      = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                    $bmp.EndInit()
                    $bmp.Freeze()
                    if ($ctrl["SidebarIcon"]) { $ctrl["SidebarIcon"].Source = $bmp }
                    if ($ctrl["AboutIcon"])   { $ctrl["AboutIcon"].Source   = $bmp }
                    $winBmp = New-Object System.Windows.Media.Imaging.BitmapImage
                    $winBmp.BeginInit()
                    $winBmp.UriSource        = New-Object System.Uri($iconAbsPath, [System.UriKind]::Absolute)
                    $winBmp.DecodePixelWidth = 32
                    $winBmp.CacheOption      = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                    $winBmp.EndInit()
                    $winBmp.Freeze()
                    $win.Icon = $winBmp
                }
            } catch { Write-WTLog "Icon load error: $_" "WARN" }

            # Winget status indicator
            if ($global:WingetPath) {
                $ctrl["WingetDot"].Fill    = script:Brush "#00CC6A"
                if ($S.ContainsKey("StatusReady")) { $ctrl["WingetStatus"].Text = $S["StatusReady"] } else { $ctrl["WingetStatus"].Text = "Ready" }
            } else {
                $ctrl["WingetDot"].Fill    = script:Brush "#FC3E3E"
                $ctrl["WingetStatus"].Text = "not found"
                if ($ctrl["BtnCheckAppUpdates"]) { $ctrl["BtnCheckAppUpdates"].IsEnabled = $false }
            }

            # Apply language strings after window is fully loaded.
            # IMPORTANT: capture script-scoped refs into locals BEFORE GetNewClosure()
            # so the closure captures them as local variables (script: lookup fails in
            # DispatcherTimer callbacks when the closure was created via GetNewClosure).
            $applyLangFn  = $script:applyLanguage
            $applyLangArg = $script:lang
            $langTimer = New-Object System.Windows.Threading.DispatcherTimer
            $langTimer.Interval = [TimeSpan]::FromMilliseconds(50)
            $langTimer.Add_Tick({
                $langTimer.Stop()
                try {
                    & $applyLangFn $applyLangArg
                } catch {
                    Write-WTLog "Apply-Language error: $($_.Exception.Message) at $($_.InvocationInfo.ScriptLineNumber)" "ERROR"
                }
            }.GetNewClosure())
            $langTimer.Start()

        } catch {
            Write-WTLog "Add_Loaded error: $($_.Exception.Message) | Line: $($_.InvocationInfo.ScriptLineNumber)" "ERROR"
        }
    })

    # Open log button
    $ctrl["BtnOpenLog"].Add_Click({
        if (Test-Path $global:LogFile) { Start-Process notepad.exe -ArgumentList $global:LogFile }
    })

    # ----------------------------------------------------------------
    #  IN-APP LANGUAGE TOGGLE  (EN / ES pill in sidebar footer)
    # ----------------------------------------------------------------
    $ctrl["BtnLangEN"].Add_Click({
        if ($script:lang -ne "EN") { & $script:applyLanguage "EN"; Write-WTLog "Language switched to EN" }
    })
    $ctrl["BtnLangES"].Add_Click({
        if ($script:lang -ne "ES") { & $script:applyLanguage "ES"; Write-WTLog "Language switched to ES" }
    })

    # ================================================================
    #  TASK 2 — DARK / LIGHT THEME TOGGLE
    # ================================================================
    $script:applyTheme = { param([bool]$dark)
        $script:IsDark = $dark
        & script:Apply-Theme $dark
        # Update theme pill visuals
        $actBG = "#0067C0"; $actFG = "#FFFFFF"; $inactBG = "Transparent"; $inactFG = "#3A5570"
        if ($dark) { $inactFG = "#AAAAAA" }
        if ($ctrl["BtnThemeLight"]) {
            if (-not $dark) { $ctrl["BtnThemeLight"].Background = script:Brush $actBG } else { $ctrl["BtnThemeLight"].Background = script:Brush $inactBG }
            if (-not $dark) { $ctrl["BtnThemeLight"].Foreground = script:Brush $actFG } else { $ctrl["BtnThemeLight"].Foreground = script:Brush $inactFG }
        }
        if ($ctrl["BtnThemeDark"]) {
            if ($dark) { $ctrl["BtnThemeDark"].Background = script:Brush "#3A3A3A" } else { $ctrl["BtnThemeDark"].Background = script:Brush $inactBG }
            if ($dark) { $ctrl["BtnThemeDark"].Foreground = script:Brush $actFG } else { $ctrl["BtnThemeDark"].Foreground = script:Brush $inactFG }
        }
        Write-WTLog "Theme switched to $(if($dark){'Dark'}else{'Light'})"
    }
    $ctrl["BtnThemeLight"].Add_Click({ if ($script:IsDark)  { & $script:applyTheme $false } })
    $ctrl["BtnThemeDark"].Add_Click({  if (-not $script:IsDark) { & $script:applyTheme $true  } })
    # ================================================================
    #  BUILD APP MANAGER TAB
    #  Source: WinUtil application list (376 apps, 9 categories)
    #  Logic: winget-first with choco fallback, matching WinUtil exactly
    # ================================================================

    # -- State ----
    $script:AMMode          = "Install"   # "Install" | "Uninstall"
    $script:AMCBMap         = @{}         # appId -> CheckBox (install panel)
    $script:AMRowMap        = @{}         # appId -> Border row (install panel)
    $script:AMSelInstall    = [System.Collections.Generic.HashSet[string]]::new()
    $script:AMSelUninstall  = [System.Collections.Generic.HashSet[string]]::new()
    $script:AMUninstallData = @()         # array of PSObjects from winget list
    $script:AMUninstallFetching = $false
    $script:AMProcessRunning    = $false
    $script:AMCurCat        = "All"

    # -- Load WinUtil app catalog ----
    $amCatalogPath = Join-Path $PSScriptRoot "..\config\wm_apps.json"
    if (-not (Test-Path $amCatalogPath)) {
        Write-WTLog "wm_apps.json not found at $amCatalogPath" "WARN"
        $global:AMCatalog = @()
    } else {
        try {
            $global:AMCatalog = Get-Content $amCatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-WTLog "App Manager: loaded $($global:AMCatalog.Count) apps from wm_apps.json"
        } catch {
            Write-WTLog "Error loading wm_apps.json: $_" "ERROR"
            $global:AMCatalog = @()
        }
    }

    # All categories (sorted) + "All" pseudo-category
    $amAllCategories = @("All") + ($global:AMCatalog | Select-Object -ExpandProperty Category -Unique | Sort-Object)

    # -- Helper: update selection counter ----
    $script:AMUpdateSelCount = {
        $sel  = if ($script:AMMode -eq "Install") { $script:AMSelInstall.Count } else { $script:AMSelUninstall.Count }
        if ($sel -eq 0) { $ctrl["AMSelCount"].Text = "" } else { $ctrl["AMSelCount"].Text = "$sel selected" }
        $ctrl["AMBtnInstall"].IsEnabled   = ($script:AMMode -eq "Install"   -and $sel -gt 0)
        $ctrl["AMBtnUninstall"].IsEnabled = ($script:AMMode -eq "Uninstall" -and $sel -gt 0)
    }

    # -- Helper: switch Install / Uninstall mode ----
    $script:AMSwitchMode = { param([string]$mode)
        $script:AMMode = $mode
        $isInstall = ($mode -eq "Install")
        # Pill styles
        if ($isInstall) {
            $ctrl["AMPillInstall"].Background   = script:Brush "#0067C0"
            if ($ctrl["AMPillInstall"].Child) { $ctrl["AMPillInstall"].Child.Foreground = [Windows.Media.Brushes]::White }
            $ctrl["AMPillUninstall"].Background = [Windows.Media.Brushes]::Transparent
            if ($ctrl["AMPillUninstallTxt"]) { $ctrl["AMPillUninstallTxt"].Foreground = script:Brush "#5A6A7A" }
            $ctrl["AMPillUninstall"].BorderBrush = script:Brush "#DDE4EC"
        } else {
            $ctrl["AMPillInstall"].Background   = [Windows.Media.Brushes]::Transparent
            if ($ctrl["AMPillInstall"].Child) { $ctrl["AMPillInstall"].Child.Foreground = script:Brush "#5A6A7A" }
            $ctrl["AMPillUninstall"].Background = script:Brush "#C42B1C"
            if ($ctrl["AMPillUninstallTxt"]) { $ctrl["AMPillUninstallTxt"].Foreground = [Windows.Media.Brushes]::White }
            $ctrl["AMPillUninstall"].BorderBrush = [Windows.Media.Brushes]::Transparent
        }
        # Panels
        if ($isInstall) { $ctrl["AMInstallScroll"].Visibility = "Visible" } else { $ctrl["AMInstallScroll"].Visibility = "Collapsed" }
        if (-not $isInstall) { $ctrl["AMUninstallScroll"].Visibility = "Visible" } else { $ctrl["AMUninstallScroll"].Visibility = "Collapsed" }
        if ($isInstall) { $ctrl["AMInstallActions"].Visibility = "Visible" } else { $ctrl["AMInstallActions"].Visibility = "Collapsed" }
        if (-not $isInstall) { $ctrl["AMUninstallActions"].Visibility = "Visible" } else { $ctrl["AMUninstallActions"].Visibility = "Collapsed" }
        if ($isInstall) { $ctrl["AMCatPanel"].Visibility = "Visible" } else { $ctrl["AMCatPanel"].Visibility = "Collapsed" }
        # Reset search
        $ctrl["AMSearch"].Text = ""
        & $script:AMUpdateSelCount
        # Load uninstall list when switching to uninstall
        if (-not $isInstall -and $script:AMUninstallData.Count -eq 0) {
            & $script:AMFetchUninstall
        } elseif (-not $isInstall) {
            & $script:AMBuildUninstallList ""
        }
    }

    # -- Build category sidebar ----
    $script:AMBuildCategories = {
        $ctrl["AMCatPanel"].Children.Clear()
        $isDark = $script:IsDark
        $catActiveBG   = if ($isDark) { "#1E3452"  } else { "#E3F0FB"  }
        $catActiveFG   = if ($isDark) { "#7AB8FF"  } else { "#0067C0"  }
        $catInactiveFG = if ($isDark) { "#CCCCCC"  } else { "#444444"  }
        foreach ($cat in $amAllCategories) {
            $bd = New-Object Windows.Controls.Border
            $bd.CornerRadius = [Windows.CornerRadius]::new(6)
            $bd.Padding = [Windows.Thickness]::new(10,6,10,6)
            $bd.Margin  = [Windows.Thickness]::new(0,1,0,1)
            $bd.Cursor  = [Windows.Input.Cursors]::Hand
            $bd.Tag     = $cat
            $isActive   = ($cat -eq $script:AMCurCat)
            if ($isActive) { $bd.Background = script:Brush $catActiveBG } else { $bd.Background = [Windows.Media.Brushes]::Transparent }
            $tb = New-Object Windows.Controls.TextBlock
            $tb.Text       = $cat
            $tb.FontSize   = 12
            $tb.Padding    = [Windows.Thickness]::new(2,0,0,0)
            if ($isActive) { $tb.FontWeight = [Windows.FontWeights]::SemiBold } else { $tb.FontWeight = [Windows.FontWeights]::Normal }
            if ($isActive) { $tb.Foreground = script:Brush $catActiveFG } else { $tb.Foreground = script:Brush $catInactiveFG }
            $bd.Child = $tb
            $bd.Add_MouseLeftButtonUp({
                $script:AMCurCat = $this.Tag
                & $script:AMBuildCategories
                & $script:AMFilterInstallList $ctrl["AMSearch"].Text
            })
            $ctrl["AMCatPanel"].Children.Add($bd) | Out-Null
        }
    }

    # -- Build install list rows ----
    $script:AMBuildInstallList = {
        $ctrl["AMInstallPanel"].Children.Clear()
        $script:AMCBMap.Clear()
        $script:AMRowMap.Clear()
        $script:AMSelInstall.Clear()
        & $script:AMUpdateSelCount

        $lastCat = ""
        $isDark        = $script:IsDark
        $rowBorderClr  = if ($isDark) { "#333333" } else { "#EEEEEE" }
        $rowTextMain   = if ($isDark) { "#E0E0E0" } else { "#1A1A1A" }
        $rowTextMuted  = if ($isDark) { "#888888" } else { "#777777" }
        $hdrFGClr      = if ($isDark) { "#666666" } else { "#888888" }
        foreach ($app in ($global:AMCatalog | Sort-Object Category, Name)) {
            # Category header
            if ($app.Category -ne $lastCat) {
                $lastCat = $app.Category
                $hdr = New-Object Windows.Controls.TextBlock
                $hdr.Text       = $app.Category.ToUpper()
                $hdr.FontSize   = 10
                $hdr.FontWeight = [Windows.FontWeights]::SemiBold
                $hdr.Foreground = script:Brush $hdrFGClr
                $hdr.Margin     = [Windows.Thickness]::new(2,10,0,4)
                $ctrl["AMInstallPanel"].Children.Add($hdr) | Out-Null
            }
            # App row
            $row = New-Object Windows.Controls.Border
            $row.CornerRadius    = [Windows.CornerRadius]::new(6)
            $row.Padding         = [Windows.Thickness]::new(10,6,10,6)
            $row.Margin          = [Windows.Thickness]::new(0,1,0,1)
            $row.Background      = [Windows.Media.Brushes]::Transparent
            $row.BorderBrush     = script:Brush $rowBorderClr
            $row.BorderThickness = [Windows.Thickness]::new(0,0,0,1)
            $row.Cursor          = [Windows.Input.Cursors]::Hand

            $grid = New-Object Windows.Controls.Grid
            $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Auto)
            $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
            $grid.ColumnDefinitions.Add($c0)
            $grid.ColumnDefinitions.Add($c1)

            $cb = New-Object Windows.Controls.CheckBox
            $cb.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $cb.Margin = [Windows.Thickness]::new(0,0,10,0)
            [Windows.Controls.Grid]::SetColumn($cb, 0)

            $sp = New-Object Windows.Controls.StackPanel
            [Windows.Controls.Grid]::SetColumn($sp, 1)

            $nameBlock = New-Object Windows.Controls.TextBlock
            $nameBlock.Text       = $app.Name
            $nameBlock.FontSize   = 12
            $nameBlock.FontWeight = [Windows.FontWeights]::SemiBold
            $nameBlock.Foreground = script:Brush $rowTextMain
            $nameBlock.Tag        = "appName"

            $descBlock = New-Object Windows.Controls.TextBlock
            $descLine  = $app.Description
            if ($app.Winget -ne "na") { $descLine += "  |  " + $app.Winget }
            $descBlock.Text         = $descLine
            $descBlock.FontSize     = 10
            $descBlock.Foreground   = script:Brush $rowTextMuted
            $descBlock.Tag          = "appDesc"
            $descBlock.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis

            $sp.Children.Add($nameBlock) | Out-Null
            $sp.Children.Add($descBlock) | Out-Null
            $grid.Children.Add($cb) | Out-Null
            $grid.Children.Add($sp) | Out-Null
            $row.Child = $grid

            # Store appId in both cb.Tag and row.Tag for handler lookup
            $cb.Tag  = $app.Id
            $row.Tag = $app.Id

            # Wire checkbox -- use $this.Tag to get appId, $script:AMRowMap for row
            $cb.Add_Checked({
                $id = $this.Tag
                $script:AMSelInstall.Add($id) | Out-Null
                $r = $script:AMRowMap[$id]
                if ($r) {
                    $selHL = if ($script:IsDark) { "#1E3452" } else { "#EBF5FF" }
                    $r.Background = script:Brush $selHL
                }
                & $script:AMUpdateSelCount
            })
            $cb.Add_Unchecked({
                $id = $this.Tag
                $script:AMSelInstall.Remove($id) | Out-Null
                $r = $script:AMRowMap[$id]
                if ($r) { $r.Background = [Windows.Media.Brushes]::Transparent }
                & $script:AMUpdateSelCount
            })
            # Click anywhere on row toggles its checkbox
            $row.Add_MouseLeftButtonUp({
                $id  = $this.Tag
                $chk = $script:AMCBMap[$id]
                if ($chk) { $chk.IsChecked = -not $chk.IsChecked }
            })

            $script:AMCBMap[$app.Id]  = $cb
            $script:AMRowMap[$app.Id] = $row
            $ctrl["AMInstallPanel"].Children.Add($row) | Out-Null
        }
        # Re-apply current category/search filter
        & $script:AMFilterInstallList $ctrl["AMSearch"].Text
    }

    # -- Filter install list by category + search ----
    $script:AMFilterInstallList = { param([string]$query)
        $q = $query.Trim().ToLower()
        foreach ($app in $global:AMCatalog) {
            $row = $script:AMRowMap[$app.Id]
            if (-not $row) { continue }
            $catMatch  = ($script:AMCurCat -eq "All") -or ($app.Category -eq $script:AMCurCat)
            $textMatch = ($q -eq "") -or
                         ($app.Name.ToLower().Contains($q)) -or
                         ($app.Description.ToLower().Contains($q)) -or
                         ($app.Winget.ToLower().Contains($q))
            if ($catMatch -and $textMatch) { $row.Visibility = "Visible" } else { $row.Visibility = "Collapsed" }
        }
        # Also show/hide category headers (show if any visible app under them)
        $lastVis = $false
        foreach ($child in $ctrl["AMInstallPanel"].Children) {
            if ($child.GetType().Name -eq "TextBlock") {
                # Next pass: peek at following siblings - if any visible, show header
                $lastVis = $false
            } elseif ($child.GetType().Name -eq "Border") {
                if ($child.Visibility -eq "Visible") { $lastVis = $true }
            }
        }
        # Simpler: rebuild header visibility in second pass
        $catHeaders = @{}
        $catVisible = @{}
        $lastHdr = $null
        foreach ($child in $ctrl["AMInstallPanel"].Children) {
            if ($child.GetType().Name -eq "TextBlock") {
                $lastHdr = $child
                $catHeaders[$child] = $false
            } elseif ($child.GetType().Name -eq "Border" -and $lastHdr) {
                if ($child.Visibility -eq "Visible") {
                    $catHeaders[$lastHdr] = $true
                }
            }
        }
        foreach ($hdr in $catHeaders.Keys) {
            if ($catHeaders[$hdr]) { $hdr.Visibility = "Visible" } else { $hdr.Visibility = "Collapsed" }
        }
    }

    # -- Fetch installed apps for Uninstall list ----
    $script:AMFetchUninstall = {
        if ($script:AMUninstallFetching) { return }
        $script:AMUninstallFetching = $true
        $ctrl["AMUninstallStatus"].Text    = "Loading installed apps..."
        $ctrl["AMBtnUninstall"].IsEnabled  = $false
        $ctrl["AMBtnRefreshList"].IsEnabled = $false

        $fetchJob = Start-Job -ScriptBlock {
            param($wgPath)
            $results = @()
            try {
                if ($wgPath) {
                    $raw = & $wgPath list --accept-source-agreements 2>&1
                    $inTable = $false
                    foreach ($line in $raw) {
                        if ($line -match 'Name\s+Id\s+Version') { $inTable = $true; continue }
                        if (-not $inTable) { continue }
                        if ($line -match '^[-\s]+$' -or $line -notmatch '\S') { continue }
                        # Parse fixed-width table: Name, Id, Version, Available, Source
                        $parts = ($line -split '\s{2,}').Where({ $_ -ne '' })
                        if ($parts.Count -ge 2) {
                            $results += [PSCustomObject]@{
                                Name      = $parts[0].Trim()
                                Id        = if ($parts.Count -ge 2) { $parts[1].Trim() } else { "" }
                                Version   = if ($parts.Count -ge 3) { $parts[2].Trim() } else { "" }
                            }
                        }
                    }
                }
            } catch {}
            return $results
        } -ArgumentList $global:WingetPath

        $amFetchTimer = New-Object System.Windows.Threading.DispatcherTimer
        $amFetchTimer.Interval = [TimeSpan]::FromMilliseconds(400)
        $script:AMFetchTimer = $amFetchTimer
        $amFetchTimer.Add_Tick({
            if ((Get-Job -Id $script:AMFetchJobId -ErrorAction SilentlyContinue).State -in @("Completed","Failed","Stopped")) {
                $script:AMFetchTimer.Stop()
                try {
                    $script:AMUninstallData = @(Receive-Job -Id $script:AMFetchJobId -ErrorAction SilentlyContinue)
                } catch {}
                Remove-Job -Id $script:AMFetchJobId -Force -ErrorAction SilentlyContinue
                $script:AMUninstallFetching    = $false
                $ctrl["AMBtnRefreshList"].IsEnabled = $true
                & $script:AMBuildUninstallList $ctrl["AMSearch"].Text
            }
        })
        $script:AMFetchJobId = $fetchJob.Id
        $amFetchTimer.Start()
    }

    # -- Build uninstall list rows ----
    $script:AMBuildUninstallList = { param([string]$query)
        $ctrl["AMUninstallPanel"].Children.Clear()
        $script:AMSelUninstall.Clear()
        & $script:AMUpdateSelCount

        $q = $query.Trim().ToLower()
        $apps = $script:AMUninstallData | Where-Object {
            $q -eq "" -or
            $_.Name.ToLower().Contains($q) -or
            $_.Id.ToLower().Contains($q)
        }
        $count = @($apps).Count
        $ctrl["AMUninstallStatus"].Text = "$count installed apps"

        $isDark       = $script:IsDark
        $rowBorderClr = if ($isDark) { "#333333" } else { "#EEEEEE" }
        $rowTextMain  = if ($isDark) { "#E0E0E0" } else { "#1A1A1A" }
        $rowTextMuted = if ($isDark) { "#888888" } else { "#777777" }
        foreach ($app in ($apps | Sort-Object Name)) {
            $row = New-Object Windows.Controls.Border
            $row.CornerRadius    = [Windows.CornerRadius]::new(6)
            $row.Padding         = [Windows.Thickness]::new(10,7,10,7)
            $row.Margin          = [Windows.Thickness]::new(0,1,0,1)
            $row.Background      = [Windows.Media.Brushes]::Transparent
            $row.BorderBrush     = script:Brush $rowBorderClr
            $row.BorderThickness = [Windows.Thickness]::new(0,0,0,1)
            $row.Cursor          = [Windows.Input.Cursors]::Hand

            $grid = New-Object Windows.Controls.Grid
            $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Auto)
            $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
            $c2 = New-Object Windows.Controls.ColumnDefinition; $c2.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Auto)
            $grid.ColumnDefinitions.Add($c0)
            $grid.ColumnDefinitions.Add($c1)
            $grid.ColumnDefinitions.Add($c2)

            $cb = New-Object Windows.Controls.CheckBox
            $cb.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $cb.Margin = [Windows.Thickness]::new(0,0,10,0)
            [Windows.Controls.Grid]::SetColumn($cb, 0)

            $sp = New-Object Windows.Controls.StackPanel
            [Windows.Controls.Grid]::SetColumn($sp, 1)

            $nameBlock = New-Object Windows.Controls.TextBlock
            $nameBlock.Text       = $app.Name
            $nameBlock.FontSize   = 12
            $nameBlock.FontWeight = [Windows.FontWeights]::SemiBold
            $nameBlock.Foreground = script:Brush $rowTextMain
            $nameBlock.Tag        = "appName"

            $idBlock = New-Object Windows.Controls.TextBlock
            $verSuffix = if ($app.Version) { "  v" + $app.Version } else { "" }
            $idBlock.Text       = $app.Id + $verSuffix
            $idBlock.FontSize   = 10
            $idBlock.Foreground = script:Brush $rowTextMuted
            $idBlock.Tag        = "appId"

            $sp.Children.Add($nameBlock) | Out-Null
            $sp.Children.Add($idBlock)   | Out-Null
            $grid.Children.Add($cb) | Out-Null
            $grid.Children.Add($sp) | Out-Null
            $row.Child = $grid

            # Store id in Tag for handler lookup -- no GetNewClosure needed
            $cb.Tag  = $app.Id
            $row.Tag = $app.Id

            $cb.Add_Checked({
                $id = $this.Tag
                $script:AMSelUninstall.Add($id) | Out-Null
                $unSelHL = if ($script:IsDark) { "#3D1A1A" } else { "#FFF0F0" }
                $this.Parent.Background = script:Brush $unSelHL
                & $script:AMUpdateSelCount
            })
            $cb.Add_Unchecked({
                $id = $this.Tag
                $script:AMSelUninstall.Remove($id) | Out-Null
                $this.Parent.Background = [Windows.Media.Brushes]::Transparent
                & $script:AMUpdateSelCount
            })
            $row.Add_MouseLeftButtonUp({
                $g = $this.Child
                if ($g) {
                    $chk = $g.Children | Where-Object { $_ -is [Windows.Controls.CheckBox] } | Select-Object -First 1
                    if ($chk) { $chk.IsChecked = -not $chk.IsChecked }
                }
            })

            $ctrl["AMUninstallPanel"].Children.Add($row) | Out-Null
        }
    }

    # -- Install handler (WinUtil logic: winget-first, choco fallback) -
    $script:AMDoInstall = {
        if ($script:AMProcessRunning) {
            [System.Windows.MessageBox]::Show("A process is already running.", "WinTooler", "OK", "Warning") | Out-Null
            return
        }
        if ($script:AMSelInstall.Count -eq 0) { return }

        $toInstall = @($global:AMCatalog | Where-Object { $script:AMSelInstall.Contains($_.Id) })
        if ($toInstall.Count -eq 0) { return }

        $script:AMProcessRunning = $true
        $ctrl["AMBtnInstall"].IsEnabled   = $false
        $ctrl["AMProgressPanel"].Visibility = "Visible"
        $ctrl["AMProgressLabel"].Text = "Starting install..."

        $wgPath = $global:WingetPath

        # Serialize to JSON -- guarantees Start-Job deserialization keeps correct types
        $appsJson = $toInstall | Select-Object Id, Name, Winget, Choco | ConvertTo-Json -Compress

        $installJob = Start-Job -ScriptBlock {
            param([string]$appsJson, [string]$wgPath)

            # Helper: resolve winget executable -- tries passed path, then name lookup
            $wgExe = $null
            if ($wgPath -ne "" -and (Test-Path $wgPath -ErrorAction SilentlyContinue)) {
                $wgExe = $wgPath
            } else {
                # Path may be a Store symlink that fails Test-Path in elevated job; try by name
                $found = Get-Command winget -ErrorAction SilentlyContinue
                if ($found) { $wgExe = $found.Source }
            }

            # Write a small log to TEMP for diagnostics
            $logFile = "$env:TEMP\WinTooler_install_job.log"
            "=== Install Job START $(Get-Date) ===" | Out-File $logFile -Encoding UTF8
            "wgPath param  : $wgPath"                | Out-File $logFile -Append -Encoding UTF8
            "wgExe resolved: $wgExe"                 | Out-File $logFile -Append -Encoding UTF8

            $apps = $appsJson | ConvertFrom-Json

            foreach ($app in @($apps)) {
                $name   = [string]$app.Name
                $winget = [string]$app.Winget
                $choco  = [string]$app.Choco
                $id     = [string]$app.Id
                $ok      = $false
                $manager = ""

                "--- $name (winget=$winget)" | Out-File $logFile -Append -Encoding UTF8

                if ($winget -ne "na" -and $winget -ne "" -and $wgExe) {
                    $isMsStore = ($winget -match '^[0-9A-Z]{10,16}$')
                    $src       = if ($isMsStore) { "msstore" } else { "winget" }
                    try {
                        # Use & call operator -- always blocks correctly inside Start-Job
                        # Do NOT use Start-Process -NoNewWindow in a job (no console to attach to)
                        $argList = @("install","--id",$winget,"--silent",
                                     "--accept-source-agreements","--accept-package-agreements",
                                     "--source",$src)
                        & $wgExe @argList 2>&1 | Out-File $logFile -Append -Encoding UTF8
                        $code = $LASTEXITCODE
                        $manager = "winget"
                        "  exit=$code" | Out-File $logFile -Append -Encoding UTF8
                        if ($code -eq 0 -or $code -eq -1978335189) {
                            $ok = $true
                        }
                    } catch {
                        "  ERROR: $_" | Out-File $logFile -Append -Encoding UTF8
                    }
                }

                if (-not $ok -and $choco -ne "na" -and $choco -ne "") {
                    $chocoExe = Get-Command choco -ErrorAction SilentlyContinue
                    if ($chocoExe) {
                        try {
                            & choco install $choco -y --no-progress 2>&1 | Out-File $logFile -Append -Encoding UTF8
                            $code2 = $LASTEXITCODE
                            $manager = "choco"
                            "  choco exit=$code2" | Out-File $logFile -Append -Encoding UTF8
                            if ($code2 -eq 0) { $ok = $true }
                        } catch {
                            "  choco ERROR: $_" | Out-File $logFile -Append -Encoding UTF8
                        }
                    }
                }

                [PSCustomObject]@{ Name=$name; Id=$id; Manager=$manager; Success=$ok }
            }
            "=== Install Job END $(Get-Date) ===" | Out-File $logFile -Append -Encoding UTF8
        } -ArgumentList $appsJson, $wgPath

        $script:AMInstallJobId = $installJob.Id
        $amInstTimer  = New-Object System.Windows.Threading.DispatcherTimer
        $amInstTimer.Interval = [TimeSpan]::FromMilliseconds(500)
        $script:AMInstallTimer = $amInstTimer

        $amInstTimer.Add_Tick({
            $job = Get-Job -Id $script:AMInstallJobId -ErrorAction SilentlyContinue
            if ($job -and $job.State -in @("Completed","Failed","Stopped")) {
                $script:AMInstallTimer.Stop()
                $results = @()
                try { $results = @(Receive-Job -Id $script:AMInstallJobId -ErrorAction SilentlyContinue) } catch {}
                Remove-Job -Id $script:AMInstallJobId -Force -ErrorAction SilentlyContinue

                $ok   = @($results | Where-Object { $_.Success -eq $true }).Count
                $fail = @($results | Where-Object { $_.Success -ne $true }).Count
                $ctrl["AMInstallStatus"].Text       = "Done: $ok installed, $fail failed"
                $ctrl["AMProgressPanel"].Visibility = "Collapsed"
                $ctrl["AMProgressBar"].Value        = 100
                $ctrl["AMBtnInstall"].IsEnabled     = $true
                $script:AMProcessRunning            = $false
                Write-WTLog "App Manager install complete: $ok ok, $fail failed"
                & $script:setStatus "App Manager: $ok installed, $fail failed" "#107C10"
            } else {
                $v = $ctrl["AMProgressBar"].Value
                if ($v -ge 95) { $ctrl["AMProgressBar"].Value = 10 } else { $ctrl["AMProgressBar"].Value = $v + 3 }
                $ctrl["AMProgressLabel"].Text = "Installing apps via winget..."
            }
        })
        $amInstTimer.Start()
    }

    # -- Uninstall handler (WinUtil logic: winget uninstall --silent) --
    $script:AMDoUninstall = {
        if ($script:AMProcessRunning) {
            [System.Windows.MessageBox]::Show("A process is already running.", "WinTooler", "OK", "Warning") | Out-Null
            return
        }
        if ($script:AMSelUninstall.Count -eq 0) { return }

        $names = ($script:AMSelUninstall | ForEach-Object { $_ }) -join ", "
        $confirm = [System.Windows.MessageBox]::Show(
            "Uninstall the following apps?`n`n$names",
            "Confirm Uninstall",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -ne "Yes") { return }

        $toUninstall = @($script:AMUninstallData | Where-Object { $script:AMSelUninstall.Contains($_.Id) })
        if ($toUninstall.Count -eq 0) { return }

        $script:AMProcessRunning = $true
        $ctrl["AMBtnUninstall"].IsEnabled  = $false
        $ctrl["AMProgressPanel"].Visibility = "Visible"
        $ctrl["AMProgressLabel"].Text       = "Uninstalling $($toUninstall.Count) apps..."

        $wgPath     = $global:WingetPath
        # Serialize to JSON for safe Start-Job deserialization
        $uninstJson = $toUninstall | Select-Object Id, Name | ConvertTo-Json -Compress

        $uninstJob  = Start-Job -ScriptBlock {
            param([string]$uninstJson, [string]$wgPath)
            # Resolve winget exe (same pattern as install job)
            $wgExe = $null
            if ($wgPath -ne "" -and (Test-Path $wgPath -ErrorAction SilentlyContinue)) {
                $wgExe = $wgPath
            } else {
                $found = Get-Command winget -ErrorAction SilentlyContinue
                if ($found) { $wgExe = $found.Source }
            }
            $apps = $uninstJson | ConvertFrom-Json
            foreach ($app in @($apps)) {
                $name = [string]$app.Name
                $id   = [string]$app.Id
                $ok   = $false
                if ($id -ne "" -and $wgExe) {
                    try {
                        # Use & operator -- Start-Process -NoNewWindow fails in job context
                        $argList = @("uninstall","--id",$id,"--silent","--accept-source-agreements")
                        & $wgExe @argList 2>&1 | Out-Null
                        $code = $LASTEXITCODE
                        if ($code -eq 0) { $ok = $true }
                    } catch {}
                }
                [PSCustomObject]@{ Name=$name; Id=$id; Success=$ok }
            }
        } -ArgumentList $uninstJson, $wgPath

        $script:AMUninstJobId = $uninstJob.Id
        $amUninstTimer = New-Object System.Windows.Threading.DispatcherTimer
        $amUninstTimer.Interval = [TimeSpan]::FromMilliseconds(500)
        $script:AMUninstallTimer = $amUninstTimer

        $amUninstTimer.Add_Tick({
            $job = Get-Job -Id $script:AMUninstJobId -ErrorAction SilentlyContinue
            if ($job -and $job.State -in @("Completed","Failed","Stopped")) {
                $script:AMUninstallTimer.Stop()
                $results = @()
                try { $results = @(Receive-Job -Id $script:AMUninstJobId -ErrorAction SilentlyContinue) } catch {}
                Remove-Job -Id $script:AMUninstJobId -Force -ErrorAction SilentlyContinue

                $ok   = @($results | Where-Object { $_.Success -eq $true }).Count
                $fail = @($results | Where-Object { $_.Success -ne $true }).Count
                $ctrl["AMUninstallStatus"].Text     = "Done: $ok removed, $fail failed"
                $ctrl["AMProgressPanel"].Visibility = "Collapsed"
                $ctrl["AMBtnUninstall"].IsEnabled   = ($script:AMSelUninstall.Count -gt 0)
                $script:AMProcessRunning            = $false
                # Refresh list
                $script:AMUninstallData = @()
                & $script:AMFetchUninstall
                Write-WTLog "App Manager uninstall complete: $ok removed, $fail failed"
                & $script:setStatus "App Manager: $ok removed, $fail failed" "#C42B1C"
            } else {
                $v = $ctrl["AMProgressBar"].Value
                if ($v -ge 95) { $ctrl["AMProgressBar"].Value = 10 } else { $ctrl["AMProgressBar"].Value = $v + 3 }
            }
        })
        $amUninstTimer.Start()
    }

    # -- Wire pill clicks ----
    $ctrl["AMPillInstall"].Add_MouseLeftButtonUp({   & $script:AMSwitchMode "Install"   })
    $ctrl["AMPillUninstall"].Add_MouseLeftButtonUp({ & $script:AMSwitchMode "Uninstall" })

    # -- Wire toolbar buttons ----
    $ctrl["AMBtnSelectAll"].Add_Click({
        foreach ($id in $global:AMCatalog.Id) {
            $cb = $script:AMCBMap[$id]
            if ($cb -and $cb.Visibility -ne "Collapsed") { $cb.IsChecked = $true }
        }
    })
    $ctrl["AMBtnDeselectAll"].Add_Click({
        foreach ($id in $global:AMCatalog.Id) {
            $cb = $script:AMCBMap[$id]
            if ($cb) { $cb.IsChecked = $false }
        }
    })

    # Search box
    $ctrl["AMSearch"].Add_TextChanged({
        $q = $ctrl["AMSearch"].Text
        if ($script:AMMode -eq "Install") {
            & $script:AMFilterInstallList $q
        } else {
            & $script:AMBuildUninstallList $q
        }
    })

    # -- Wire action buttons ----
    $ctrl["AMBtnInstall"].Add_Click({   & $script:AMDoInstall   })
    $ctrl["AMBtnUninstall"].Add_Click({ & $script:AMDoUninstall })
    $ctrl["AMBtnRefreshList"].Add_Click({
        $script:AMUninstallData = @()
        & $script:AMFetchUninstall
    })

    # -- Populate install list on first load ----
    if ($global:AMCatalog.Count -gt 0) {
        & $script:AMBuildCategories
        & $script:AMBuildInstallList
    } else {
        $ctrl["AMInstallStatus"].Text = "App catalog not found. Place wm_apps.json in config\\"
    }


    # ================================================================
    #  BUILD TWEAKS TAB
    # ================================================================
    $script:TweakCBs = @{}

    $riskColors = @{ "Low"="#27AE60"; "Medium"="#FFB900"; "High"="#FC3E3E" }
    $lastTweakCat = ""

    foreach ($tweak in ($global:TweaksCatalog | Sort-Object Category, Name)) {
        if ($tweak.Category -ne $lastTweakCat) {
            if ($lastTweakCat -ne "") {
                $sp2 = New-Object Windows.Controls.Border; $sp2.Height = 10
                $ctrl["TweakPanel"].Children.Add($sp2) | Out-Null
            }
            $catLbl = New-Object Windows.Controls.TextBlock
            $catLbl.Text = $tweak.Category.ToUpper(); $catLbl.FontSize = 10; $catLbl.FontWeight = [Windows.FontWeights]::Bold
            $catLbl.Foreground = script:Brush $script:T.Text3
            $catLbl.Margin = New-Object Windows.Thickness(0,0,0,6)
            $ctrl["TweakPanel"].Children.Add($catLbl) | Out-Null
            $lastTweakCat = $tweak.Category
        }

        $tc = New-Object Windows.Controls.Border
        $tc.Background      = script:Brush $script:T.CardBG
        $tc.CornerRadius    = New-Object Windows.CornerRadius(8)
        $tc.BorderBrush     = script:Brush $script:T.CardBorder
        $tc.BorderThickness = New-Object Windows.Thickness(1)
        $tc.Padding         = New-Object Windows.Thickness(14,11,14,11)
        $tc.Margin          = New-Object Windows.Thickness(0,0,0,5)
        $tc.Cursor          = [System.Windows.Input.Cursors]::Hand

        $tg  = New-Object Windows.Controls.Grid
        $tc1 = New-Object Windows.Controls.ColumnDefinition; $tc1.Width = [Windows.GridLength]::Auto
        $tc2 = New-Object Windows.Controls.ColumnDefinition
        $tc3 = New-Object Windows.Controls.ColumnDefinition; $tc3.Width = [Windows.GridLength]::Auto
        $tg.ColumnDefinitions.Add($tc1); $tg.ColumnDefinitions.Add($tc2); $tg.ColumnDefinitions.Add($tc3)

        $tcb = New-Object Windows.Controls.CheckBox
        $tcb.IsChecked = $false; $tcb.VerticalAlignment = "Center"; $tcb.Tag = $tweak.Key
        [Windows.Controls.Grid]::SetColumn($tcb, 0); $tg.Children.Add($tcb) | Out-Null

        $tInfoSp = New-Object Windows.Controls.StackPanel; $tInfoSp.Margin = New-Object Windows.Thickness(12,0,12,0)
        $tNm = New-Object Windows.Controls.TextBlock; $tNm.Text = $tweak.Name; $tNm.FontSize = 13
        $tNm.FontWeight = [Windows.FontWeights]::SemiBold; $tNm.Foreground = script:Brush $script:T.Text1
        $tDs = New-Object Windows.Controls.TextBlock; $tDs.Text = $tweak.Description; $tDs.FontSize = 11
        $tDs.Foreground = script:Brush $script:T.Text3
        $tDs.Margin = New-Object Windows.Thickness(0,3,0,0); $tDs.TextWrapping = "Wrap"
        $tInfoSp.Children.Add($tNm) | Out-Null; $tInfoSp.Children.Add($tDs) | Out-Null
        [Windows.Controls.Grid]::SetColumn($tInfoSp, 1); $tg.Children.Add($tInfoSp) | Out-Null

        $rColor = if ($riskColors.ContainsKey($tweak.Risk)) { $riskColors[$tweak.Risk] } else { "#888888" }
        $rRgb   = [Windows.Media.ColorConverter]::ConvertFromString($rColor)
        $rBd    = New-Object Windows.Controls.Border
        $rBd.Background      = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromArgb(20,$rRgb.R,$rRgb.G,$rRgb.B))
        $rBd.BorderBrush     = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromArgb(70,$rRgb.R,$rRgb.G,$rRgb.B))
        $rBd.BorderThickness = New-Object Windows.Thickness(1)
        $rBd.CornerRadius    = New-Object Windows.CornerRadius(4)
        $rBd.Padding         = New-Object Windows.Thickness(8,3,8,3); $rBd.VerticalAlignment = "Center"
        $rTb = New-Object Windows.Controls.TextBlock; $rTb.Text = $tweak.Risk; $rTb.FontSize = 10; $rTb.FontWeight = [Windows.FontWeights]::SemiBold
        $rTb.Foreground = New-Object Windows.Media.SolidColorBrush($rRgb)
        $rBd.Child = $rTb
        [Windows.Controls.Grid]::SetColumn($rBd, 2); $tg.Children.Add($rBd) | Out-Null

        $tc.Child = $tg
        $ctrl["TweakPanel"].Children.Add($tc) | Out-Null
        $script:TweakCBs[$tweak.Key] = $tcb

        # Click card to toggle
        $tc.Add_MouseLeftButtonUp({
            param($s,$e)
            $key = $s.Child.Children[0].Tag
            $script:TweakCBs[$key].IsChecked = -not $script:TweakCBs[$key].IsChecked
        })
    }

    $updateTweakCount = {
        $n = ($script:TweakCBs.Values | Where-Object { $_.IsChecked }).Count
        $ctrl["TweakCountLabel"].Text = "$n selected"
    }
    & $updateTweakCount
    foreach ($cb in $script:TweakCBs.Values) {
        $cb.Add_Checked({   & $updateTweakCount })
        $cb.Add_Unchecked({ & $updateTweakCount })
    }

    # Template definitions: key -> list of tweak Keys to enable
    $templates = @{
        "Standard" = @("HighPerfPower","DisableSysMain","ReduceAnimations","DisableTelemetry",
                       "DisableAdID","DisableActivity","BlockTelemetryHosts","DarkMode",
                       "ShowExtensions","RemoveStartAds","CleanTaskbar","DisableBingStart","DisableEdgeBloat")
        "Minimal"  = @("DisableTelemetry","DisableAdID","DisableActivity","RemoveStartAds","CleanTaskbar","DisableBingStart")
        "Heavy"    = @("HighPerfPower","DisableSysMain","DisableSearch","ReduceAnimations","DisableHibernation",
                       "GameMode","DisableTelemetry","DisableAdID","DisableActivity","DisableLocation",
                       "BlockTelemetryHosts","DarkMode","ShowExtensions","ShowHidden","RemoveStartAds",
                       "CleanTaskbar","DisableBingStart","RemoveMSBloat","RemoveXbox","DisableEdgeBloat","DisableOneDrive")
    }

    $applyTemplate = {
        param([string]$tpl)
        foreach ($cb in $script:TweakCBs.Values) { $cb.IsChecked = $false }
        if ($tpl -and $templates.ContainsKey($tpl)) {
            foreach ($key in $templates[$tpl]) {
                if ($script:TweakCBs.ContainsKey($key)) { $script:TweakCBs[$key].IsChecked = $true }
            }
        }
        & $updateTweakCount
    }

    $ctrl["TplNone"].Add_Click({     & $applyTemplate "" })
    $ctrl["TplStandard"].Add_Click({ & $applyTemplate "Standard" })
    $ctrl["TplMinimal"].Add_Click({  & $applyTemplate "Minimal" })
    $ctrl["TplHeavy"].Add_Click({    & $applyTemplate "Heavy" })

    $ctrl["BtnCheckAll"].Add_Click({
        foreach ($cb in $script:TweakCBs.Values) { $cb.IsChecked = $true }
        & $updateTweakCount
    })
    $ctrl["BtnUncheckAll"].Add_Click({
        foreach ($cb in $script:TweakCBs.Values) { $cb.IsChecked = $false }
        & $updateTweakCount
    })

    $ctrl["TweakSearch"].Add_TextChanged({
        $txt = $ctrl["TweakSearch"].Text.Trim()
        foreach ($child in $ctrl["TweakPanel"].Children) {
            if ($child -is [Windows.Controls.Border] -and $child.Child -is [Windows.Controls.Grid]) {
                $key = $child.Child.Children[0].Tag
                if ($key) {
                    $tweak = $global:TweaksCatalog | Where-Object { $_.Key -eq $key }
                    if ($txt -eq "" -or $tweak.Name -like "*$txt*" -or $tweak.Description -like "*$txt*") { $child.Visibility = "Visible" } else { $child.Visibility = "Collapsed" }
                }
            }
        }
    })

    $ctrl["BtnApplyTweaks"].Add_Click({
        $selected = $global:TweaksCatalog | Where-Object { $script:TweakCBs.ContainsKey($_.Key) -and $script:TweakCBs[$_.Key].IsChecked -eq $true }
        $n = @($selected).Count
        if ($n -eq 0) { & $script:setStatus "No tweaks selected." "#FFB900"; return }
        & $script:setStatus "Applying $n tweaks..."
        Write-Host ""
        Write-Host "  --[ Applying $n Tweaks ]" -ForegroundColor Cyan
        Write-WTLog "Applying $n tweaks..."
        $ok = 0
        foreach ($t in $selected) {
            try {
                & $t.Script
                Write-Host "  OK: $($t.Name)" -ForegroundColor Green
                Write-WTLog "Applied: $($t.Name)"
                $ok++
            } catch {
                Write-Host "  FAIL: $($t.Name) - $_" -ForegroundColor Red
                Write-WTLog "Failed tweak $($t.Name): $_" "ERROR"
            }
        }
        Write-Host "  Tweaks done: $ok of $n applied" -ForegroundColor Cyan

        # ---- Disk Cleanup after tweaks ----
        $curS = $global:UIStrings
        $doneWord  = if ($curS -and $curS.ContainsKey("TweaksDone"))     { $curS["TweaksDone"] }    else { "Done! Applied" }
        $ofWord    = if ($curS -and $curS.ContainsKey("TweaksOf"))       { $curS["TweaksOf"] }      else { "of" }
        $cleanWord = if ($curS -and $curS.ContainsKey("TweaksDiskClean")){ $curS["TweaksDiskClean"]}else { "tweaks. Running disk cleanup..." }
        $cleanMsg  = if ($curS -and $curS.ContainsKey("DiskCleanMsg"))   { $curS["DiskCleanMsg"] }  else { "Running disk cleanup in the background..." }
        $cleanDone = if ($curS -and $curS.ContainsKey("DiskCleanDone"))  { $curS["DiskCleanDone"] } else { "Disk cleanup finished." }

        & $script:setStatus "$doneWord $ok $ofWord $n $cleanWord" "#00CC6A"
        Write-Host "  [Disk Cleanup] Registering cleanmgr profile and launching..." -ForegroundColor DarkGray
        Write-WTLog "Post-tweak disk cleanup starting"

        # Pre-configure sageset:64 silently so /sagerun:64 runs without UI dialogs
        try {
            $sagePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
            $cleanTargets = @(
                "Active Setup Temp Folders","Downloaded Program Files","Internet Cache Files",
                "Memory Dump Files","Old ChkDsk Files","Previous Installations",
                "Recycle Bin","Setup Log Files","System error memory dump files",
                "System error minidump files","Temporary Files","Temporary Setup Files",
                "Thumbnail Cache","Update Cleanup","Windows Error Reporting Files","Windows Upgrade Log Files"
            )
            foreach ($t2 in $cleanTargets) {
                $keyPath = Join-Path $sagePath $t2
                if (Test-Path $keyPath) {
                    Set-ItemProperty $keyPath -Name "StateFlags0064" -Value 2 -Type DWord -EA SilentlyContinue
                }
            }
            # Launch cleanmgr /sagerun:64 as a background job so the UI stays responsive
            Start-Job -ScriptBlock {
                Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:64" -Wait -WindowStyle Hidden
            } | Out-Null
            & $script:setStatus $cleanMsg "#0067C0"
            Write-WTLog "Disk cleanup launched (sagerun:64)"

            # Store in script scope so the timer tick can reliably access them
            $script:diskFinalMsg = "$doneWord $ok $ofWord $n tweaks. $cleanDone"

            # Poll the job in the background and update status when done
            $script:diskPollTimer = New-Object System.Windows.Threading.DispatcherTimer
            $script:diskPollTimer.Interval = [TimeSpan]::FromSeconds(3)
            $script:diskPollTimer.Add_Tick({
                $job = Get-Job | Where-Object { $_.State -eq "Completed" -and $_.Command -like "*cleanmgr*" }
                if ($job) {
                    $job | Remove-Job -Force -EA SilentlyContinue
                    $script:diskPollTimer.Stop()
                    & $script:setStatus $script:diskFinalMsg "#107C10"
                    Write-WTLog "Disk cleanup completed"
                }
            })
            $script:diskPollTimer.Start()
        } catch {
            Write-WTLog "Disk cleanup error: $_" "ERROR"
            & $script:setStatus "$doneWord $ok $ofWord $n tweaks. Reboot may be needed." "#00CC6A"
        }
    })

    # ================================================================
    #  BUILD SERVICES TAB
    # ================================================================
    $script:SvcCBs = @{}

    foreach ($svc in $global:ServicesList) {
        $svcCard = New-Object Windows.Controls.Border
        $svcCard.Background      = script:Brush $script:T.CardBG
        $svcCard.CornerRadius    = New-Object Windows.CornerRadius(8)
        $svcCard.BorderBrush     = script:Brush $script:T.CardBorder
        $svcCard.BorderThickness = New-Object Windows.Thickness(1)
        $svcCard.Padding         = New-Object Windows.Thickness(14,11,14,11)
        $svcCard.Margin          = New-Object Windows.Thickness(0,0,0,5)

        $sg = New-Object Windows.Controls.Grid
        $sc1 = New-Object Windows.Controls.ColumnDefinition; $sc1.Width = [Windows.GridLength]::Auto
        $sc2 = New-Object Windows.Controls.ColumnDefinition
        $sc3 = New-Object Windows.Controls.ColumnDefinition; $sc3.Width = [Windows.GridLength]::Auto
        $sg.ColumnDefinitions.Add($sc1); $sg.ColumnDefinitions.Add($sc2); $sg.ColumnDefinitions.Add($sc3)

        $scb = New-Object Windows.Controls.CheckBox
        $scb.VerticalAlignment = "Center"; $scb.Tag = $svc.Name
        [Windows.Controls.Grid]::SetColumn($scb, 0); $sg.Children.Add($scb) | Out-Null

        $sInfoSp = New-Object Windows.Controls.StackPanel; $sInfoSp.Margin = New-Object Windows.Thickness(12,0,12,0)
        $sNm = New-Object Windows.Controls.TextBlock; $sNm.Text = $svc.DisplayName; $sNm.FontSize = 13
        $sNm.FontWeight = [Windows.FontWeights]::SemiBold; $sNm.Foreground = script:Brush $script:T.Text1
        $sDs = New-Object Windows.Controls.TextBlock; $sDs.Text = $svc.Description; $sDs.FontSize = 11
        $sDs.Foreground = script:Brush $script:T.Text3
        $sDs.Margin = New-Object Windows.Thickness(0,3,0,0)
        $sNm2 = New-Object Windows.Controls.TextBlock; $sNm2.Text = $svc.Name; $sNm2.FontSize = 10
        $sNm2.Foreground = script:Brush $script:T.Text4
        $sInfoSp.Children.Add($sNm) | Out-Null; $sInfoSp.Children.Add($sDs) | Out-Null; $sInfoSp.Children.Add($sNm2) | Out-Null
        [Windows.Controls.Grid]::SetColumn($sInfoSp, 1); $sg.Children.Add($sInfoSp) | Out-Null

        $svcObj = Get-Service $svc.Name -ErrorAction SilentlyContinue
        $startType = if ($svcObj) { $svcObj.StartType } else { "Unknown" }
        $statusText = $startType; $statusColor = switch ($startType.ToString()) {
            "Automatic" { "#FC3E3E" }; "Manual" { "#FFB900" }; "Disabled" { "#27AE60" }
            default     { "#555555" }
        }
        $sBd = New-Object Windows.Controls.Border
        $sRgb = [Windows.Media.ColorConverter]::ConvertFromString($statusColor)
        $sBd.Background   = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromArgb(20,$sRgb.R,$sRgb.G,$sRgb.B))
        $sBd.BorderBrush  = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromArgb(60,$sRgb.R,$sRgb.G,$sRgb.B))
        $sBd.BorderThickness = New-Object Windows.Thickness(1); $sBd.CornerRadius = New-Object Windows.CornerRadius(4)
        $sBd.Padding = New-Object Windows.Thickness(8,3,8,3); $sBd.VerticalAlignment = "Center"
        $sTb = New-Object Windows.Controls.TextBlock; $sTb.Text = $statusText; $sTb.FontSize = 10; $sTb.FontWeight = [Windows.FontWeights]::SemiBold
        $sTb.Foreground = New-Object Windows.Media.SolidColorBrush($sRgb); $sBd.Child = $sTb
        [Windows.Controls.Grid]::SetColumn($sBd, 2); $sg.Children.Add($sBd) | Out-Null

        $svcCard.Child = $sg
        $ctrl["ServicePanel"].Children.Add($svcCard) | Out-Null
        $script:SvcCBs[$svc.Name] = $scb
    }

    $svcAction = {
        param([string]$action)
        $selected = $script:SvcCBs.GetEnumerator() | Where-Object { $_.Value.IsChecked }
        foreach ($kv in $selected) {
            $svcName = $kv.Key
            try {
                switch ($action) {
                    "Disable" { Stop-Service $svcName -Force -EA SilentlyContinue; Set-Service $svcName -StartupType Disabled -EA Stop }
                    "Manual"  { Set-Service $svcName -StartupType Manual -EA Stop }
                    "Enable"  { Set-Service $svcName -StartupType Automatic -EA Stop; Start-Service $svcName -EA SilentlyContinue }
                }
                Write-Host "  [${action}] $svcName" -ForegroundColor DarkGray
                Write-WTLog "Service ${action}: $svcName"
            } catch {
                Write-Host "  [FAIL] $svcName - $_" -ForegroundColor Red
                Write-WTLog "Service ${action} failed: $svcName - $_" "ERROR"
            }
        }
        & $script:setStatus "Service changes applied." "#00CC6A"
    }

    $ctrl["BtnSvcDisable"].Add_Click({ & $svcAction "Disable" })
    $ctrl["BtnSvcManual"].Add_Click({  & $svcAction "Manual"  })
    $ctrl["BtnSvcEnable"].Add_Click({  & $svcAction "Enable"  })

    # ================================================================
    #  REPAIR TAB - async SFC/DISM with live output
    # ================================================================
    $script:appendRepair = {
        param([string]$text)
        $ctrl["RepairOutput"].AppendText($text + "`n")
        $ctrl["RepairOutput"].ScrollToEnd()
        Write-Host "  $text" -ForegroundColor DarkGray
    }

    $ctrl["BtnSFC"].Add_Click({
        $ctrl["RepairOutput"].Clear()
        $ctrl["RepairSpinner"].Visibility = "Visible"
        & $script:appendRepair "Running SFC /scannow ..."
        & $script:appendRepair "(This may take 5-15 minutes. GUI remains responsive.)"
        & $script:appendRepair ""
        $win.Dispatcher.Invoke([action]{}, "Render")

        $job = Start-Job -ScriptBlock { sfc /scannow 2>&1 | ForEach-Object { $_ } }
        $processed = ""
        while ($job.State -eq "Running") {
            Start-Sleep -Milliseconds 400
            $partial = Receive-Job $job -Keep 2>$null | Where-Object { $_ -and $_ -ne $processed }
            foreach ($line in $partial) {
                if ($line.Trim()) {
                    $ctrl["RepairOutput"].Dispatcher.Invoke([action]{
                        $ctrl["RepairOutput"].AppendText($line + "`n")
                        $ctrl["RepairOutput"].ScrollToEnd()
                    })
                }
            }
            $win.Dispatcher.Invoke([action]{}, "Background")
        }
        $final = Receive-Job $job | Out-String
        Remove-Job $job -Force

        $ctrl["RepairOutput"].Dispatcher.Invoke([action]{
            & $script:appendRepair ""
            & $script:appendRepair "SFC complete."
            & $script:appendRepair "Running DISM RestoreHealth ..."
        })

        $job2 = Start-Job -ScriptBlock { DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | ForEach-Object { $_ } }
        while ($job2.State -eq "Running") {
            Start-Sleep -Milliseconds 400
            $partial = Receive-Job $job2 -Keep 2>$null
            foreach ($line in $partial) {
                if ($line.Trim()) {
                    $ctrl["RepairOutput"].Dispatcher.Invoke([action]{
                        $ctrl["RepairOutput"].AppendText($line + "`n")
                        $ctrl["RepairOutput"].ScrollToEnd()
                    })
                }
            }
            $win.Dispatcher.Invoke([action]{}, "Background")
        }
        Remove-Job $job2 -Force
        $ctrl["RepairSpinner"].Visibility = "Collapsed"
        & $script:appendRepair ""
        & $script:appendRepair "SFC + DISM complete."
        Write-WTLog "SFC+DISM complete"
    })

    $ctrl["BtnClearTemp"].Add_Click({
        $ctrl["RepairOutput"].Clear()
        & $script:appendRepair "Clearing temp files..."
        $result = Clear-TempFiles
        & $script:appendRepair $result
        & $script:setStatus $result "#00CC6A"
    })

    $ctrl["BtnFlushDNS"].Add_Click({
        $ctrl["RepairOutput"].Clear()
        & $script:appendRepair "Flushing DNS cache..."
        $result = Invoke-FlushDNS
        & $script:appendRepair $result
        & $script:setStatus "DNS flushed." "#00CC6A"
    })

    $ctrl["BtnWsReset"].Add_Click({
        $ctrl["RepairOutput"].Clear()
        & $script:appendRepair "Resetting Windows Store..."
        wsreset.exe 2>&1 | Out-Null
        & $script:appendRepair "Windows Store reset complete."
        & $script:setStatus "Windows Store reset." "#00CC6A"
    })

    $ctrl["BtnRestorePoint"].Add_Click({
        $ctrl["RepairOutput"].Clear()
        & $script:appendRepair "Creating restore point..."
        $result = New-RestorePoint -Label "WinToolerV1 Manual"
        & $script:appendRepair $result
        & $script:setStatus $result "#00CC6A"
    })

    $ctrl["BtnNetReset"].Add_Click({
        $ctrl["RepairOutput"].Clear()
        & $script:appendRepair "Resetting network stack..."
        $result = Reset-NetworkStack
        & $script:appendRepair $result
        & $script:setStatus "Network reset done. Reboot required." "#FFB900"
    })

    $ctrl["BtnDeleteRestorePoints"].Add_Click({
        $msg = "This will permanently delete ALL system restore points on C:\.`n`nThis action cannot be undone.`n`nContinue?"
        $confirm = [System.Windows.MessageBox]::Show($msg, "WinTooler - Delete Restore Points", "YesNo", "Warning")
        if ($confirm -ne "Yes") { return }
        $ctrl["RepairOutput"].Clear()
        & $script:appendRepair "Deleting all system restore points..."
        $result = Remove-AllRestorePoints
        & $script:appendRepair $result
        if ($result -like "Error*") {
            & $script:setStatus "Delete restore points failed." "#C42B1C"
        } else {
            & $script:setStatus "All restore points deleted." "#107C10"
        }
    })


    # ================================================================
    #  STARTUP MANAGER PAGE
    # ================================================================

    $script:StartupEntries = @()

    $script:StartupBuildList = {
        $ctrl["StartupPanel"].Children.Clear()
        $script:StartupEntries | Sort-Object Name | ForEach-Object {
            $entry = $_
            $row = New-Object Windows.Controls.Border
            $row.CornerRadius = [Windows.CornerRadius]::new(6)
            $row.Padding      = [Windows.Thickness]::new(12,8,12,8)
            $row.Margin       = [Windows.Thickness]::new(0,1,0,1)
            $row.Tag          = $entry.KeyPath

            if ($entry.Enabled) { $statusColor = "#107C10" } else { $statusColor = "#999999" }
            if ($script:IsDark) { $rowBgEnabled = "#1A2E1A" } else { $rowBgEnabled = "#F6FFF7" }
            if ($script:IsDark) { $rowBgDisabled = "#2A2A2A" } else { $rowBgDisabled = "#FAFAFA" }
            if ($entry.Enabled) { $rowBgColor = $rowBgEnabled } else { $rowBgColor = $rowBgDisabled }
            $row.Background = script:Brush $rowBgColor

            $grid = New-Object Windows.Controls.Grid
            $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = [Windows.GridLength]::new(1,[Windows.GridUnitType]::Star)
            $c2 = New-Object Windows.Controls.ColumnDefinition; $c2.Width = [Windows.GridLength]::new(200)
            $c3 = New-Object Windows.Controls.ColumnDefinition; $c3.Width = [Windows.GridLength]::new(90)
            $grid.ColumnDefinitions.Add($c1); $grid.ColumnDefinitions.Add($c2); $grid.ColumnDefinitions.Add($c3)

            $nameBlock = New-Object Windows.Controls.TextBlock
            $nameBlock.Text       = $entry.Name
            $nameBlock.FontWeight = [Windows.FontWeights]::SemiBold
            $nameBlock.FontSize   = 13
            if ($script:IsDark) { $nFG = "#E0E0E0" } else { $nFG = "#1A1A1A" }
            if ($script:IsDark) { $cFG = "#888888" } else { $cFG = "#666666" }
            $nameBlock.Foreground = script:Brush $nFG
            [Windows.Controls.Grid]::SetColumn($nameBlock, 0)

            $cmdBlock = New-Object Windows.Controls.TextBlock
            $cmdBlock.Text       = $entry.Command
            $cmdBlock.FontSize   = 11
            $cmdBlock.Foreground = script:Brush $cFG
            $cmdBlock.FontFamily = [Windows.Media.FontFamily]::new("Consolas, Courier New")
            $cmdBlock.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
            [Windows.Controls.Grid]::SetColumn($cmdBlock, 1)

            $statusBlock = New-Object Windows.Controls.TextBlock
            if ($entry.Enabled) { $statusText = "Enabled" } else { $statusText = "Disabled" }
            $statusBlock.Text              = $statusText
            $statusBlock.Foreground        = script:Brush $statusColor
            $statusBlock.FontSize          = 12
            $statusBlock.FontWeight        = [Windows.FontWeights]::SemiBold
            $statusBlock.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
            $statusBlock.VerticalAlignment   = [Windows.VerticalAlignment]::Center
            [Windows.Controls.Grid]::SetColumn($statusBlock, 2)

            $grid.Children.Add($nameBlock) | Out-Null
            $grid.Children.Add($cmdBlock)  | Out-Null
            $grid.Children.Add($statusBlock) | Out-Null
            $row.Child = $grid

            # Row click toggles selection highlight
            $row.Add_MouseLeftButtonUp({
                if ($this.BorderBrush -and $this.BorderBrush.Color.ToString() -eq "#FF0067C0") {
                    $this.BorderBrush     = [Windows.Media.Brushes]::Transparent
                    $this.BorderThickness = [Windows.Thickness]::new(0)
                } else {
                    $this.BorderBrush     = script:Brush "#0067C0"
                    $this.BorderThickness = [Windows.Thickness]::new(2)
                }
            })

            $ctrl["StartupPanel"].Children.Add($row) | Out-Null
        }
        $total = $script:StartupEntries.Count
        $enabled = @($script:StartupEntries | Where-Object { $_.Enabled }).Count
        $ctrl["StartupCountLabel"].Text = "$total startup entries  |  $enabled enabled  |  $($total - $enabled) disabled"
    }

    $script:StartupLoad = {
        $ctrl["StartupStatusLabel"].Text = "Loading..."
        $ctrl["StartupBtnRefresh"].IsEnabled = $false

        $job = Start-Job -ScriptBlock {
            $entries = @()

            # Registry Run keys
            $runKeys = @(
                @{ Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";     Scope="HKLM (All Users)" }
                @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";     Scope="HKCU (Current User)" }
                @{ Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"; Scope="HKLM RunOnce" }
                @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"; Scope="HKCU RunOnce" }
            )
            foreach ($rk in $runKeys) {
                try {
                    $reg = Get-ItemProperty -Path $rk.Path -ErrorAction SilentlyContinue
                    if ($reg) {
                        $reg.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                            $entries += [PSCustomObject]@{
                                Name     = $_.Name
                                Command  = [string]$_.Value
                                Scope    = $rk.Scope
                                Enabled  = $true
                                Type     = "Registry"
                                KeyPath  = "$($rk.Path)\$($_.Name)"
                            }
                        }
                    }
                } catch {}
            }

            # Disabled startup entries (stored by Task Manager in Registry)
            $disabledKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
            try {
                $disabled = Get-ItemProperty -Path $disabledKey -ErrorAction SilentlyContinue
                if ($disabled) {
                    $disabled.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                        $bytes = $_.Value -as [byte[]]
                        if ($bytes -and $bytes[0] -eq 3) {
                            $match = $entries | Where-Object { $_.Name -eq $_.Name }
                            if ($match) { $match.Enabled = $false }
                        }
                    }
                }
            } catch {}

            # Startup folder (All Users)
            $startupFolders = @(
                @{ Path=[System.Environment]::GetFolderPath("CommonStartup"); Scope="All Users Startup" }
                @{ Path=[System.Environment]::GetFolderPath("Startup");       Scope="Current User Startup" }
            )
            foreach ($sf in $startupFolders) {
                if (Test-Path $sf.Path) {
                    Get-ChildItem -Path $sf.Path -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
                        $entries += [PSCustomObject]@{
                            Name    = $_.BaseName
                            Command = $_.FullName
                            Scope   = $sf.Scope
                            Enabled = $true
                            Type    = "Folder"
                            KeyPath = $_.FullName
                        }
                    }
                }
            }
            $entries | ConvertTo-Json -Compress
        }

        $script:StartupJobId = $job.Id
        $stTimer = New-Object System.Windows.Threading.DispatcherTimer
        $stTimer.Interval = [TimeSpan]::FromMilliseconds(400)
        $script:StartupTimer = $stTimer
        $stTimer.Add_Tick({
            $j = Get-Job -Id $script:StartupJobId -ErrorAction SilentlyContinue
            if ($j -and $j.State -in @("Completed","Failed","Stopped")) {
                $script:StartupTimer.Stop()
                try {
                    $raw = Receive-Job -Id $script:StartupJobId -ErrorAction SilentlyContinue
                    Remove-Job -Id $script:StartupJobId -Force -ErrorAction SilentlyContinue
                    if ($raw) {
                        $parsed = $raw | ConvertFrom-Json
                        $script:StartupEntries = @($parsed)
                    }
                } catch {}
                & $script:StartupBuildList
                $ctrl["StartupStatusLabel"].Text = "Loaded"
                $ctrl["StartupBtnRefresh"].IsEnabled = $true
            }
        })
        $stTimer.Start()
    }

    $ctrl["StartupBtnRefresh"].Add_Click({ & $script:StartupLoad })

    $ctrl["StartupBtnEnable"].Add_Click({
        $selected = @($ctrl["StartupPanel"].Children | Where-Object {
            $_.GetType().Name -eq "Border" -and
            $_.BorderThickness.Left -gt 0
        })
        foreach ($row in $selected) {
            $keyPath = $row.Tag
            if ($keyPath -and $keyPath -like "HK*") {
                try {
                    $parent  = Split-Path $keyPath -Parent
                    $valName = Split-Path $keyPath -Leaf
                    $disabledKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
                    if (Test-Path $disabledKey) {
                        Remove-ItemProperty -Path $disabledKey -Name $valName -ErrorAction SilentlyContinue
                    }
                } catch {}
            }
        }
        & $script:StartupLoad
    })

    $ctrl["StartupBtnDisable"].Add_Click({
        $selected = @($ctrl["StartupPanel"].Children | Where-Object {
            $_.GetType().Name -eq "Border" -and
            $_.BorderThickness.Left -gt 0
        })
        foreach ($row in $selected) {
            $keyPath = $row.Tag
            $entry = $script:StartupEntries | Where-Object { $_.KeyPath -eq $keyPath }
            if ($entry -and $entry.Type -eq "Registry") {
                try {
                    $valName = Split-Path $keyPath -Leaf
                    $disabledKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
                    if (-not (Test-Path $disabledKey)) {
                        New-Item -Path $disabledKey -Force | Out-Null
                    }
                    # Byte pattern 03 00 00 00 ... = disabled in StartupApproved
                    $disabledBytes = [byte[]](3,0,0,0,0,0,0,0,0,0,0,0)
                    Set-ItemProperty -Path $disabledKey -Name $valName -Value $disabledBytes -Type Binary -ErrorAction SilentlyContinue
                } catch {}
            }
        }
        & $script:StartupLoad
    })

    # Load startup list when page is first visited
    $script:StartupLoaded = $false
    $origSwitchPage    = $switchPage
    $startupLoadFn     = $script:StartupLoad
    $switchPage = {
        param($page)
        & $origSwitchPage $page
        if ($page -eq "Startup" -and -not $script:StartupLoaded) {
            $script:StartupLoaded = $true
            & $startupLoadFn
        }
    }.GetNewClosure()

    # ================================================================
    #  DNS CHANGER PAGE
    # ================================================================

    $script:DNSApply = {
        param([string]$primary, [string]$secondary, [string]$label)
        $ctrl["DNSOutput"].Text = "Applying $label DNS..."
        try {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            foreach ($adapter in $adapters) {
                $servers = if ($secondary) { @($primary, $secondary) } else { @($primary) }
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex `
                    -ServerAddresses $servers -ErrorAction SilentlyContinue
            }
            # Flush DNS cache
            & ipconfig /flushdns 2>&1 | Out-Null
            $ctrl["DNSOutput"].Text = "DNS set to $label ($primary) on $($adapters.Count) adapter(s). Cache flushed."
            $ctrl["DNSOutput"].Foreground = script:Brush "#107C10"
            & $script:DNSRefreshCurrent
            Write-WTLog "DNS changed to $label ($primary)"
            & $script:setStatus "DNS set to $label" "#107C10"
        } catch {
            $ctrl["DNSOutput"].Text = "Error: $_"
            $ctrl["DNSOutput"].Foreground = script:Brush "#C42B1C"
        }
    }

    $script:DNSRefreshCurrent = {
        try {
            $lines = @()
            Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
                $dns = (Get-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4).ServerAddresses
                if ($dns) { $dnsStr = $dns -join ", " } else { $dnsStr = "DHCP / Auto" }
                $lines += "$($_.Name): $dnsStr"
            }
            if ($lines) { $ctrl["DNSCurrentLabel"].Text = $lines -join "`n" } else { $ctrl["DNSCurrentLabel"].Text = "No active adapters found" }
        } catch {
            $ctrl["DNSCurrentLabel"].Text = "Unable to read DNS settings"
        }
    }

    $ctrl["DNSBtnRefreshCurrent"].Add_Click({ & $script:DNSRefreshCurrent })
    $ctrl["DNSBtnCloudflare"].Add_Click({ & $script:DNSApply "1.1.1.1"           "1.0.0.1"              "Cloudflare" })
    $ctrl["DNSBtnGoogle"].Add_Click({     & $script:DNSApply "8.8.8.8"           "8.8.4.4"              "Google" })
    $ctrl["DNSBtnQuad9"].Add_Click({      & $script:DNSApply "9.9.9.9"           "149.112.112.112"      "Quad9" })
    $ctrl["DNSBtnOpenDNS"].Add_Click({    & $script:DNSApply "208.67.222.222"    "208.67.220.220"       "OpenDNS" })

    $ctrl["DNSBtnApplyCustom"].Add_Click({
        $p = $ctrl["DNSPrimary"].Text.Trim()
        $s = $ctrl["DNSSecondary"].Text.Trim()
        if (-not $p) {
            $ctrl["DNSOutput"].Text = "Enter a primary DNS address first."
            $ctrl["DNSOutput"].Foreground = script:Brush "#C42B1C"
            return
        }
        & $script:DNSApply $p $s "Custom"
    })

    $ctrl["DNSBtnRestoreDefault"].Add_Click({
        $ctrl["DNSOutput"].Text = "Restoring DNS to DHCP..."
        try {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            foreach ($adapter in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex `
                    -ResetServerAddresses -ErrorAction SilentlyContinue
            }
            & ipconfig /flushdns 2>&1 | Out-Null
            $ctrl["DNSOutput"].Text = "DNS restored to DHCP on $($adapters.Count) adapter(s). Cache flushed."
            $ctrl["DNSOutput"].Foreground = script:Brush "#107C10"
            & $script:DNSRefreshCurrent
            & $script:setStatus "DNS restored to DHCP" "#107C10"
        } catch {
            $ctrl["DNSOutput"].Text = "Error: $_"
            $ctrl["DNSOutput"].Foreground = script:Brush "#C42B1C"
        }
    })

    # Load current DNS info when DNS page first visited
    $script:DNSLoaded = $false
    $prevSwitchPage    = $switchPage
    $dnsRefreshFn      = $script:DNSRefreshCurrent
    $switchPage = {
        param($page)
        & $prevSwitchPage $page
        if ($page -eq "DNS" -and -not $script:DNSLoaded) {
            $script:DNSLoaded = $true
            & $dnsRefreshFn
        }
    }.GetNewClosure()

    # ================================================================
    #  PROFILE BACKUP PAGE
    # ================================================================

    $script:BackupDir = Join-Path $env:APPDATA "WinToolerV1\Profiles"

    $script:BackupRefreshList = {
        $ctrl["BackupSavedList"].Text = ""
        if (-not (Test-Path $script:BackupDir)) {
            $ctrl["BackupSavedList"].Text = "No profiles saved yet."
            return
        }
        $files = Get-ChildItem -Path $script:BackupDir -Filter "*.json" -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending
        if ($files.Count -eq 0) {
            $ctrl["BackupSavedList"].Text = "No profiles saved yet."
        } else {
            $ctrl["BackupSavedList"].Text = ($files | ForEach-Object {
                "$($_.Name)  ($([math]::Round($_.Length/1KB,1)) KB)  --  $($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))"
            }) -join "`n"
        }
    }

    $ctrl["BackupBtnExport"].Add_Click({
        try {
            if (-not (Test-Path $script:BackupDir)) {
                New-Item -Path $script:BackupDir -ItemType Directory -Force | Out-Null
            }
            $profileName = $ctrl["BackupProfileName"].Text.Trim()
            if (-not $profileName) {
                $profileName = "WinTooler_Profile_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            }
            $safeProfile = $profileName -replace '[\/:*?"<>|]', '_'
            $outPath = Join-Path $script:BackupDir "$safeProfile.json"

            # Collect current tweak checkbox states
            $tweakStates = @{}
            foreach ($kv in $script:TweakCBs.GetEnumerator()) {
                $cb = $kv.Value
                if ($cb) { $tweakStates[$kv.Key] = [bool]$cb.IsChecked }
            }

            $profile = [PSCustomObject]@{
                WinToolerVersion = "V0.7 beta Build 5035"
                ExportDate       = (Get-Date).ToString("o")
                ProfileName      = $profileName
                Tweaks           = $tweakStates
            }

            $profile | ConvertTo-Json -Depth 5 | Out-File $outPath -Encoding UTF8
            $ctrl["BackupOutput"].Text = "Exported: $outPath"
            $ctrl["BackupOutput"].Foreground = script:Brush "#107C10"
            & $script:BackupRefreshList
            Write-WTLog "Profile exported: $outPath"
        } catch {
            $ctrl["BackupOutput"].Text = "Export failed: $_"
            $ctrl["BackupOutput"].Foreground = script:Brush "#C42B1C"
        }
    })

    $ctrl["BackupBtnBrowse"].Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Title  = "Select WinTooler Profile"
        $dlg.Filter = "JSON Profile|*.json|All Files|*.*"
        $dlg.InitialDirectory = $script:BackupDir
        if ($dlg.ShowDialog() -eq $true) {
            $ctrl["BackupImportPath"].Text = $dlg.FileName
        }
    })

    $ctrl["BackupBtnImport"].Add_Click({
        $path = $ctrl["BackupImportPath"].Text.Trim()
        if (-not $path -or -not (Test-Path $path)) {
            $ctrl["BackupOutput"].Text = "Select a valid profile file first."
            $ctrl["BackupOutput"].Foreground = script:Brush "#C42B1C"
            return
        }
        try {
            $profile = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            $applied = 0
            foreach ($prop in $profile.Tweaks.PSObject.Properties) {
                $id = $prop.Name
                $val = [bool]$prop.Value
                if ($script:TweakCBs.ContainsKey($id)) {
                    $cb = $script:TweakCBs[$id]
                    if ($cb) { $cb.IsChecked = $val; $applied++ }
                }
            }
            $ctrl["BackupOutput"].Text = "Imported '$($profile.ProfileName)' -- $applied tweaks applied. Exported: $($profile.ExportDate)"
            $ctrl["BackupOutput"].Foreground = script:Brush "#107C10"
            Write-WTLog "Profile imported: $path ($applied tweaks)"
            & $script:setStatus "Profile imported: $($profile.ProfileName)" "#107C10"
        } catch {
            $ctrl["BackupOutput"].Text = "Import failed: $_"
            $ctrl["BackupOutput"].Foreground = script:Brush "#C42B1C"
        }
    })

    $ctrl["BackupBtnRefreshList"].Add_Click({ & $script:BackupRefreshList })

    # Auto-refresh saved list when page visited
    $script:BackupLoaded = $false
    $prevSwitchPage2   = $switchPage
    $backupRefreshFn   = $script:BackupRefreshList
    $switchPage = {
        param($page)
        & $prevSwitchPage2 $page
        if ($page -eq "Backup" -and -not $script:BackupLoaded) {
            $script:BackupLoaded = $true
            & $backupRefreshFn
        }
    }.GetNewClosure()

    # ================================================================
    #  TASK 6 — ISO CREATOR PAGE
    # ================================================================

    $ctrl["ISOBtnBrowse"].Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Select output folder for Windows 11 ISO"
        $dlg.SelectedPath = $ctrl["ISOOutputPath"].Text
        if ($dlg.ShowDialog() -eq "OK") {
            $ctrl["ISOOutputPath"].Text = $dlg.SelectedPath
        }
    })

    $ctrl["ISOBtnBrowseISO"].Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Title  = "Select Windows ISO file"
        $dlg.Filter = "ISO Image (*.iso)|*.iso|All Files (*.*)|*.*"
        $dlg.InitialDirectory = [System.Environment]::GetFolderPath("MyDocuments")
        if ($dlg.ShowDialog() -eq $true) {
            $ctrl["ISOSelectedPath"].Text = $dlg.FileName
        }
    })

    # Show/hide driver folder picker when checkbox is toggled
    $ctrl["ISOAddDrivers"].Add_Checked({
        $ctrl["ISODriverPanel"].Visibility = "Visible"
    })
    $ctrl["ISOAddDrivers"].Add_Unchecked({
        $ctrl["ISODriverPanel"].Visibility = "Collapsed"
    })

    $ctrl["ISOBtnBrowseDrivers"].Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Select folder containing .inf network driver files"
        $dlg.SelectedPath = $env:USERPROFILE
        if ($dlg.ShowDialog() -eq "OK") {
            $ctrl["ISODriverPath"].Text = $dlg.SelectedPath
        }
    })

    $ctrl["ISOOpenMSPage"].Add_Click({
        Start-Process "https://www.microsoft.com/en-us/software-download/windows11"
    })

    # ── ISO App Selection: state ─────────────────────────────────────────────
    $script:ISOSelApps = [System.Collections.Generic.HashSet[string]]::new()

    function script:Update-ISOAppBadge {
        $n = $script:ISOSelApps.Count
        if ($ctrl["ISOAppCount"]) {
            if ($n -eq 0) { $ctrl["ISOAppCount"].Text = "No apps selected" } else { $ctrl["ISOAppCount"].Text = "$n app(s) selected for embedding" }
        }
    }

    # ── Popup shared state (script-scoped so event handlers can reach them) ──
    $script:ISOPopCurCat = "All"
    $script:ISOPopRows   = [System.Collections.ArrayList]::new()

    function script:ISO-FilterPopRows {
        param([string]$q, [string]$cat)
        foreach ($pair in $script:ISOPopRows) {
            $row = $pair[0]; $app = $pair[1]
            $catOk  = ($cat -eq "All" -or $app.Category -eq $cat)
            $txtOk  = ($q -eq "" -or $app.Name.ToLower().Contains($q) -or $app.Winget.ToLower().Contains($q))
            if ($catOk -and $txtOk) { $row.Visibility = "Visible" } else { $row.Visibility = "Collapsed" }
        }
    }

    function script:ISO-BuildCatBar {
        param($popCatBar, $accent, $sepClr, $text1)
        $popCatBar.Children.Clear()
        $cats = @("All") + ($global:AMCatalog |
            Where-Object { $_.Winget -and $_.Winget -ne "na" } |
            Select-Object -ExpandProperty Category -Unique | Sort-Object)
        foreach ($cat in $cats) {
            $isAct = ($cat -eq $script:ISOPopCurCat)
            $bd = New-Object Windows.Controls.Border
            $bd.CornerRadius = [Windows.CornerRadius]::new(4)
            $bd.Padding      = [Windows.Thickness]::new(12,5,12,5)
            $bd.Margin       = [Windows.Thickness]::new(0,0,6,0)
            $bd.Cursor       = [Windows.Input.Cursors]::Hand
            $bd.Tag          = $cat
            if ($isAct) { $bd.Background = script:Brush $accent } else { $bd.Background = script:Brush $sepClr }
            $tb = New-Object Windows.Controls.TextBlock
            $tb.Text     = $cat
            $tb.FontSize = 11
            $tb.Tag      = $cat
            if ($isAct) { $tb.Foreground = [Windows.Media.Brushes]::White } else { $tb.Foreground = script:Brush $text1 }
            $bd.Child = $tb
            # Store the bar reference in Tag as "CAT:value:accent:sepClr:text1"
            $bd.Add_MouseLeftButtonUp({
                $script:ISOPopCurCat = $this.Tag
                # Rebuild cat bar and filter - find the search box from the parent
                $catBar = $this.Parent
                if ($catBar) {
                    $sv   = $catBar.Parent
                    $hdr  = if ($sv) { $sv.Parent } else { $null }
                    # Walk up to find the search box via visual tree
                }
                # Call the script-scoped rebuild - store popCatBar ref in script scope
                script:ISO-BuildCatBar $script:ISOPopCatBarRef $script:ISOPopAccent $script:ISOPopSepClr $script:ISOPopText1
                $q = if ($script:ISOPopSearchRef) { $script:ISOPopSearchRef.Text.ToLower().Trim() } else { "" }
                script:ISO-FilterPopRows $q $script:ISOPopCurCat
            })
            $popCatBar.Children.Add($bd) | Out-Null
        }
    }

    function script:Show-ISOAppPicker {
        if (-not $global:AMCatalog -or $global:AMCatalog.Count -eq 0) {
            [System.Windows.MessageBox]::Show(
                "App catalog not loaded yet. Please wait a moment and try again.",
                "WinTooler ISO", "OK", "Information") | Out-Null
            return
        }

        $isDark = $script:IsDark
        $winBG  = if ($isDark) { "#202020" } else { "#F3F3F3" }
        $cardBG = if ($isDark) { "#2A2A2A" } else { "#FFFFFF" }
        $border = if ($isDark) { "#383838" } else { "#E0E0E0" }
        $text1  = if ($isDark) { "#F0F0F0" } else { "#1A1A1A" }
        $text3  = if ($isDark) { "#888888" } else { "#777777" }
        $sepClr = if ($isDark) { "#333333" } else { "#EEEEEE" }
        $accent = if ($isDark) { "#60AEFF" } else { "#0067C0" }

        # Store refs for event handlers
        $script:ISOPopCurCat  = "All"
        $script:ISOPopAccent  = $accent
        $script:ISOPopSepClr  = $sepClr
        $script:ISOPopText1   = $text1

        # Local working copy of selection
        $popLocal = [System.Collections.Generic.HashSet[string]]::new($script:ISOSelApps)
        $script:ISOPopLocalSel = $popLocal

        [xml]$popXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ISO App Packages - WinTooler"
        Width="800" Height="640" MinWidth="600" MinHeight="400"
        WindowStartupLocation="CenterOwner"
        Background="$winBG" FontFamily="Segoe UI">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Border Grid.Row="0" Background="$cardBG" BorderBrush="$border" BorderThickness="0,0,0,1" Padding="20,14">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock Text="Select Apps for ISO" FontSize="16" FontWeight="SemiBold" Foreground="$text1"/>
          <TextBlock Text="Checked apps will be embedded as a winget install script in the ISO root." FontSize="11" Foreground="$text3" Margin="0,3,0,0"/>
        </StackPanel>
        <TextBlock x:Name="PopSelCount" Grid.Column="1" FontSize="11" Foreground="$accent"
                   VerticalAlignment="Center" FontWeight="SemiBold" Text="0 selected"/>
      </Grid>
    </Border>
    <Border Grid.Row="1" Background="$cardBG" BorderBrush="$border" BorderThickness="0,0,0,1" Padding="16,10">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="8"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="4"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <Border Grid.Column="0" Background="$winBG" CornerRadius="6" BorderBrush="$border" BorderThickness="1" Padding="8,6">
          <TextBox x:Name="PopSearch" Background="Transparent" BorderThickness="0"
                   Foreground="$text1" FontSize="12" VerticalAlignment="Center"/>
        </Border>
        <Button x:Name="PopSelAll"  Grid.Column="2" Content="Select All"
                Background="Transparent" BorderBrush="$border" BorderThickness="1"
                Foreground="$text1" Padding="12,6" Cursor="Hand"/>
        <Button x:Name="PopSelNone" Grid.Column="4" Content="Select None"
                Background="Transparent" BorderBrush="$border" BorderThickness="1"
                Foreground="$text1" Padding="12,6" Cursor="Hand"/>
      </Grid>
    </Border>
    <Border Grid.Row="2" Background="$winBG" BorderBrush="$border" BorderThickness="0,0,0,1" Padding="16,8">
      <ScrollViewer HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled">
        <StackPanel x:Name="PopCatBar" Orientation="Horizontal"/>
      </ScrollViewer>
    </Border>
    <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto" Padding="16,8">
      <StackPanel x:Name="PopAppList"/>
    </ScrollViewer>
    <Border Grid.Row="4" Background="$cardBG" BorderBrush="$border" BorderThickness="0,1,0,0" Padding="16,12">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="8"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock Grid.Column="0" FontSize="10" Foreground="$text3" VerticalAlignment="Center"
                   Text="Only apps with a winget ID listed. Script saved as WinTooler\Install-Apps.bat in the ISO."/>
        <Button x:Name="PopBtnCancel"  Grid.Column="1" Content="Cancel"
                Background="Transparent" BorderBrush="$border" BorderThickness="1"
                Foreground="$text1" Padding="20,8" Cursor="Hand"/>
        <Button x:Name="PopBtnConfirm" Grid.Column="3" Content="Confirm Selection"
                Background="$accent" BorderThickness="0"
                Foreground="White" FontWeight="SemiBold" Padding="20,8" Cursor="Hand"/>
      </Grid>
    </Border>
  </Grid>
</Window>
"@
        $popReader = New-Object System.Xml.XmlNodeReader($popXaml)
        $popWin    = [Windows.Markup.XamlReader]::Load($popReader)
        $popWin.Owner = $win

        $popSearch   = $popWin.FindName("PopSearch")
        $popCatBar   = $popWin.FindName("PopCatBar")
        $popAppList  = $popWin.FindName("PopAppList")
        $popSelCount = $popWin.FindName("PopSelCount")
        $popSelAll   = $popWin.FindName("PopSelAll")
        $popSelNone  = $popWin.FindName("PopSelNone")
        $popCancel   = $popWin.FindName("PopBtnCancel")
        $popConfirm  = $popWin.FindName("PopBtnConfirm")

        # Store refs for use by cat-pill click handlers
        $script:ISOPopCatBarRef  = $popCatBar
        $script:ISOPopSearchRef  = $popSearch

        # ── Update count display ──────────────────────────────────────────────
        $updatePopCount = {
            $n = $script:ISOPopLocalSel.Count
            if ($n -eq 0) { $popSelCount.Text = "0 selected" } else { $popSelCount.Text = "$n selected" }
        }

        # ── Build app list ────────────────────────────────────────────────────
        $script:ISOPopRows.Clear()
        $lastCat = ""
        foreach ($app in ($global:AMCatalog |
                Where-Object { $_.Winget -and $_.Winget -ne "na" } |
                Sort-Object Category, Name)) {

            if ($app.Category -ne $lastCat) {
                $lastCat = $app.Category
                $hdr = New-Object Windows.Controls.TextBlock
                $hdr.Text       = $app.Category.ToUpper()
                $hdr.FontSize   = 10
                $hdr.FontWeight = [Windows.FontWeights]::SemiBold
                $hdr.Foreground = script:Brush $text3
                $hdr.Margin     = [Windows.Thickness]::new(2,10,0,4)
                $popAppList.Children.Add($hdr) | Out-Null
            }

            $row = New-Object Windows.Controls.Border
            $row.CornerRadius    = [Windows.CornerRadius]::new(4)
            $row.Padding         = [Windows.Thickness]::new(10,6,10,6)
            $row.Margin          = [Windows.Thickness]::new(0,1,0,1)
            $row.BorderBrush     = script:Brush $sepClr
            $row.BorderThickness = [Windows.Thickness]::new(0,0,0,1)
            $row.Background      = [Windows.Media.Brushes]::Transparent
            $row.Cursor          = [Windows.Input.Cursors]::Hand
            $row.Tag             = $app.Id

            $rg = New-Object Windows.Controls.Grid
            $c0 = New-Object Windows.Controls.ColumnDefinition
            $c0.Width = [Windows.GridLength]::new(1,[Windows.GridUnitType]::Auto)
            $c1 = New-Object Windows.Controls.ColumnDefinition
            $c1.Width = [Windows.GridLength]::new(1,[Windows.GridUnitType]::Star)
            $c2 = New-Object Windows.Controls.ColumnDefinition
            $c2.Width = [Windows.GridLength]::new(120)
            $rg.ColumnDefinitions.Add($c0)
            $rg.ColumnDefinitions.Add($c1)
            $rg.ColumnDefinitions.Add($c2)

            $cb = New-Object Windows.Controls.CheckBox
            $cb.Margin            = [Windows.Thickness]::new(0,0,10,0)
            $cb.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $cb.IsChecked         = $script:ISOPopLocalSel.Contains($app.Id)
            $cb.Tag               = $app.Id
            [Windows.Controls.Grid]::SetColumn($cb, 0)

            $sp = New-Object Windows.Controls.StackPanel
            [Windows.Controls.Grid]::SetColumn($sp, 1)

            $nameBlk = New-Object Windows.Controls.TextBlock
            $nameBlk.Text       = $app.Name
            $nameBlk.FontSize   = 12
            $nameBlk.FontWeight = [Windows.FontWeights]::SemiBold
            $nameBlk.Foreground = script:Brush $text1

            $idBlk = New-Object Windows.Controls.TextBlock
            $idBlk.Text       = $app.Winget
            $idBlk.FontSize   = 10
            $idBlk.Foreground = script:Brush $text3
            $idBlk.FontFamily = [Windows.Media.FontFamily]::new("Consolas, Courier New")

            $catBadge = New-Object Windows.Controls.TextBlock
            $catBadge.Text                = $app.Category
            $catBadge.FontSize            = 10
            $catBadge.Foreground          = script:Brush $text3
            $catBadge.VerticalAlignment   = [Windows.VerticalAlignment]::Center
            $catBadge.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
            [Windows.Controls.Grid]::SetColumn($catBadge, 2)

            $sp.Children.Add($nameBlk) | Out-Null
            $sp.Children.Add($idBlk)   | Out-Null
            $rg.Children.Add($cb)       | Out-Null
            $rg.Children.Add($sp)       | Out-Null
            $rg.Children.Add($catBadge) | Out-Null
            $row.Child = $rg

            $cb.Add_Checked({
                $script:ISOPopLocalSel.Add($this.Tag) | Out-Null
                $n = $script:ISOPopLocalSel.Count
                if ($n -eq 0) { $popSelCount.Text = "0 selected" } else { $popSelCount.Text = "$n selected" }
            })
            $cb.Add_Unchecked({
                $script:ISOPopLocalSel.Remove($this.Tag) | Out-Null
                $n = $script:ISOPopLocalSel.Count
                if ($n -eq 0) { $popSelCount.Text = "0 selected" } else { $popSelCount.Text = "$n selected" }
            })
            $row.Add_MouseLeftButtonUp({
                $innerCB = $this.Child.Children | Where-Object { $_.GetType().Name -eq "CheckBox" }
                if ($innerCB) { $innerCB.IsChecked = -not $innerCB.IsChecked }
            })

            $popAppList.Children.Add($row) | Out-Null
            $script:ISOPopRows.Add([object[]]@($row, $app)) | Out-Null
        }

        # Build cat bar initially
        script:ISO-BuildCatBar $popCatBar $accent $sepClr $text1
        & $updatePopCount

        # ── Search / filter ───────────────────────────────────────────────────
        $popSearch.Add_TextChanged({
            script:ISO-FilterPopRows $popSearch.Text.ToLower().Trim() $script:ISOPopCurCat
        })

        # ── Select All / None ─────────────────────────────────────────────────
        $popSelAll.Add_Click({
            foreach ($pair in $script:ISOPopRows) {
                $row = $pair[0]
                if ($row.Visibility -eq "Visible") {
                    $innerCB = $row.Child.Children | Where-Object { $_.GetType().Name -eq "CheckBox" }
                    if ($innerCB -and -not $innerCB.IsChecked) { $innerCB.IsChecked = $true }
                }
            }
        })
        $popSelNone.Add_Click({
            foreach ($pair in $script:ISOPopRows) {
                $innerCB = $pair[0].Child.Children | Where-Object { $_.GetType().Name -eq "CheckBox" }
                if ($innerCB -and $innerCB.IsChecked) { $innerCB.IsChecked = $false }
            }
        })

        $popCancel.Add_Click({ $popWin.Close() })
        $popConfirm.Add_Click({
            $script:ISOSelApps = [System.Collections.Generic.HashSet[string]]::new($script:ISOPopLocalSel)
            script:Update-ISOAppBadge
            $popWin.Close()
        })

        $popWin.ShowDialog() | Out-Null
    }

    $ctrl["ISOBtnPickApps"].Add_Click({ script:Show-ISOAppPicker })

    $ctrl["ISOBtnCreate"].Add_Click({

        # Safety checks
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            [System.Windows.MessageBox]::Show("Administrator privileges required.", "WinTooler ISO Creator", "OK", "Warning") | Out-Null; return
        }
        $outPath = $ctrl["ISOOutputPath"].Text.Trim()
        if (-not $outPath -or -not (Test-Path $outPath)) {
            [System.Windows.MessageBox]::Show("Output folder does not exist. Please select a valid folder.", "WinTooler ISO Creator", "OK", "Warning") | Out-Null; return
        }
        $free = (Get-PSDrive (Split-Path $outPath -Qualifier).TrimEnd(":")).Free
        if ($free -lt 10GB) {
            [System.Windows.MessageBox]::Show("At least 10 GB of free disk space is required.", "WinTooler ISO Creator", "OK", "Warning") | Out-Null; return
        }

        $versionItem = $ctrl["ISOVersion"].SelectedItem
        $langItem    = $ctrl["ISOLanguage"].SelectedItem
        $archItem    = $ctrl["ISOArch"].SelectedItem
        $isoSrcPath  = $ctrl["ISOSelectedPath"].Text.Trim()
        # Validate that a source ISO was provided
        $invalidPaths = @("(optional)", "No ISO selected - click Add .iso +")
        if ($invalidPaths -contains $isoSrcPath -or -not $isoSrcPath -or -not (Test-Path $isoSrcPath)) {
            [System.Windows.MessageBox]::Show("Please select a Windows 11 ISO file first.`nUse the 'Add .iso +' button in Step 1.", "WinTooler ISO Creator", "OK", "Warning") | Out-Null
            return
        }
        $bypassTPM    = $ctrl["ISOBypassTPM"].IsChecked
        $bypassSB     = $ctrl["ISOBypassSecureBoot"].IsChecked
        $bypassRAM    = $ctrl["ISOBypassRAM"].IsChecked
        $unattended   = $ctrl["ISOUnattended"].IsChecked
        $removeBloat  = $ctrl["ISORemoveBloat"].IsChecked
        $addDrivers   = $ctrl["ISOAddDrivers"].IsChecked
        $driversPath  = $ctrl["ISODriverPath"].Text.Trim()
        if ($driversPath -eq "(select folder with .inf drivers)") { $driversPath = "" }
        # Collect selected winget IDs from the app panel
        $isoWingetIds = @($script:ISOSelApps) -join ","

        $winVersion  = "Windows 11 24H2 (Latest)"
        if ($versionItem -and $versionItem.Content) { $winVersion = $versionItem.Content }
        $winLang     = "English (United States)"
        if ($langItem -and $langItem.Content) { $winLang = $langItem.Content }
        $winArch     = "x64"

        $ctrl["ISOProgressBorder"].Visibility = "Visible"
        $ctrl["ISOBtnCreate"].IsEnabled       = $false
        $ctrl["ISOProgressBar"].Value         = 0
        $ctrl["ISOOutput"].Text               = ""
        $ctrl["ISOProgressLabel"].Text        = "Initialising ISO Creator..."

        & $script:setStatus "ISO Creator: Starting..." "#0067C0"
        Write-WTLog "ISO Creator started: $winVersion / $winLang / $winArch"

        $appendISO = { param([string]$msg)
            $ctrl["ISOOutput"].AppendText("$msg`n")
            $ctrl["ISOOutput"].ScrollToEnd()
        }

        $win.Dispatcher.Invoke([action]{}, "Render")

        # Run Invoke-Win11ISOCreator if loaded (from functions/public)
        if (Get-Command "Invoke-Win11ISOCreator" -ErrorAction SilentlyContinue) {
            # Capture values for the background job closure
            $isoVersion_   = $winVersion
            $isoLang_      = $winLang
            $isoArch_      = $winArch
            $isoOutput_    = $outPath
            $isoBypassTPM_ = [bool]$bypassTPM
            $isoBypassSB_  = [bool]$bypassSB
            $isoBypassRAM_   = [bool]$bypassRAM
            $isoUnattend_    = [bool]$unattended
            $isoRemoveBloat_ = [bool]$removeBloat
            $isoAddDrivers_  = [bool]$addDrivers
            $isoDriversPath_ = $driversPath
            $isoSrcISO_      = $isoSrcPath
            $isoWingetIds_   = $isoWingetIds

            $ctrl["ISOProgressLabel"].Text = "Starting ISO Creator (running in background)..."
            $ctrl["ISOProgressBar"].Value  = 5
            & $appendISO "Source  : $(Split-Path $isoSrcISO_ -Leaf)"
            & $appendISO "Output  : $isoOutput_"
            if ($isoWingetIds_) { & $appendISO "Apps    : $($isoWingetIds_.Split(',').Count) selected" }
            & $appendISO ""
            $win.Dispatcher.Invoke([action]{}, "Render")

            # Run in background thread so GUI stays responsive
            $isoJob = Start-Job -ScriptBlock {
                param($ver,$lang,$arch,$out,$tpm,$sb,$ram,$ua,$root,$srciso,$rmBloat,$addDrv,$drvPath,$wingetIds)
                $env:PATH += ";$root\functions\public;$root\functions\private"
                . "$root\functions\public\Invoke-Win11ISOCreator.ps1"
                . "$root\functions\private\Get-WindowsDownload.ps1"
                . "$root\functions\private\Convert-ESDtoISO.ps1"
                . "$root\functions\private\Invoke-Oscdimg.ps1"
                $msgs = @()
                try {
                    $isoParams = @{
                        SourceISO        = $srciso
                        OutputPath       = $out
                        BypassTPM        = $tpm
                        BypassSecureBoot = $sb
                        BypassRAM        = $ram
                        EnableUnattended = $ua
                        RemoveBloat      = $rmBloat
                        AddNetworkDrivers = $addDrv
                        DriversPath      = $drvPath
                        WingetAppIds     = $wingetIds
                        ProgressCallback = { param($pct,$msg) Write-Output "PROGRESS:$pct`:$msg" }
                    }
                    Invoke-Win11ISOCreator @isoParams
                    Write-Output "DONE:ISO created successfully in: $out"
                } catch {
                    Write-Output "ERROR:$_"
                }
            } -ArgumentList $isoVersion_,$isoLang_,$isoArch_,$isoOutput_,$isoBypassTPM_,$isoBypassSB_,$isoBypassRAM_,$isoUnattend_,$global:Root,$isoSrcISO_,$isoRemoveBloat_,$isoAddDrivers_,$isoDriversPath_,$isoWingetIds_

            # Poll job with DispatcherTimer so GUI stays live
            $isoJobId = $isoJob.Id
            $isoTimer = New-Object System.Windows.Threading.DispatcherTimer
            $isoTimer.Interval = [TimeSpan]::FromMilliseconds(600)
            $script:ISOTimer = $isoTimer
            $script:ISOJobId = $isoJobId
            $isoTimer.Add_Tick({
                $j = Get-Job -Id $script:ISOJobId -ErrorAction SilentlyContinue
                # Drain partial output
                $lines = Receive-Job -Id $script:ISOJobId 2>$null
                foreach ($line in $lines) {
                    if ($line -match "^PROGRESS:(\d+):(.+)$") {
                        $pct = [int]$matches[1]
                        $msg = $matches[2]
                        $ctrl["ISOProgressBar"].Value  = $pct
                        $ctrl["ISOProgressLabel"].Text = $msg
                        $ctrl["ISOOutput"].AppendText("[$pct%] $msg`n")
                        $ctrl["ISOOutput"].ScrollToEnd()
                    } elseif ($line -match "^DONE:(.+)$") {
                        $ctrl["ISOOutput"].AppendText("$($matches[1])`n")
                        $ctrl["ISOOutput"].ScrollToEnd()
                    } elseif ($line -match "^ERROR:(.+)$") {
                        $ctrl["ISOOutput"].AppendText("ERROR: $($matches[1])`n")
                        $ctrl["ISOOutput"].ScrollToEnd()
                    } elseif ($line -match "^LOGINFO:(.+)$") {
                        # Internal log from ISO modules - show in output
                        $ctrl["ISOOutput"].AppendText("$($matches[1])`n")
                        $ctrl["ISOOutput"].ScrollToEnd()
                    } elseif ($line -and -not [string]::IsNullOrWhiteSpace($line)) {
                        $ctrl["ISOOutput"].AppendText("$line`n")
                        $ctrl["ISOOutput"].ScrollToEnd()
                    }
                }
                if ($j -and $j.State -in @("Completed","Failed","Stopped")) {
                    $script:ISOTimer.Stop()
                    if ($j.State -eq "Completed") {
                        $ctrl["ISOProgressBar"].Value  = 100
                        $ctrl["ISOProgressLabel"].Text = "ISO created successfully."
                        & $script:setStatus "ISO Creator: Complete" "#107C10"
                        Write-WTLog "ISO Creator complete"
                    } else {
                        $ctrl["ISOProgressLabel"].Text = "ISO creation failed. Check log above."
                        & $script:setStatus "ISO Creator: Failed" "#C42B1C"
                        Write-WTLog "ISO Creator failed: $($j.State)"
                    }
                    Remove-Job -Id $script:ISOJobId -Force -ErrorAction SilentlyContinue
                    $ctrl["ISOBtnCreate"].IsEnabled = $true
                }
            })
            $isoTimer.Start()
            # Return immediately - timer handles completion
            return
        }
        # ISO path is required; the above block handles everything
    })

    # ================================================================
    #  SHOW WINDOW
    # ================================================================
    & $script:setStatus "Ready - $($global:AppCatalog.Count) apps | $($global:TweaksCatalog.Count) tweaks | $($global:ServicesList.Count) services"
    $win.ShowDialog() | Out-Null
}


# ================================================================
#  STARTUP SELECTION SCREEN  (Language only - light mode always)
# ================================================================
function Show-StartupScreen {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    $result = @{ Language = "EN"; Theme = "Light" }

    [xml]$XAML = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="WinToolerV1"
    Width="460"
    WindowStartupLocation="CenterScreen"
    Background="#F3F3F3"
    ResizeMode="NoResize"
    SizeToContent="Height"
    FontFamily="Segoe UI Variable Text, Segoe UI, Sans-Serif">

  <Window.Resources>
    <Style x:Key="SelBtn" TargetType="Button">
      <Setter Property="Background"      Value="#FFFFFF"/>
      <Setter Property="Foreground"      Value="#444444"/>
      <Setter Property="BorderBrush"     Value="#CCCCCC"/>
      <Setter Property="BorderThickness" Value="2"/>
      <Setter Property="Cursor"          Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd"
                    Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="12" Padding="0">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="#0067C0"/>
                <Setter TargetName="bd" Property="Background"  Value="#EEF5FF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="PrimaryBtn" TargetType="Button">
      <Setter Property="Background"      Value="#0067C0"/>
      <Setter Property="Foreground"      Value="White"/>
      <Setter Property="FontWeight"      Value="SemiBold"/>
      <Setter Property="FontSize"        Value="14"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor"          Value="Hand"/>
      <Setter Property="Padding"         Value="32,12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}"
                    CornerRadius="10" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#0078D4"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#005AA8"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid Margin="32,28,32,28">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="24"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="16"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="28"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Logo + Title -->
    <StackPanel Grid.Row="0" HorizontalAlignment="Center">
      <Border Width="64" Height="64" CornerRadius="16" Background="Transparent"
              HorizontalAlignment="Center" Margin="0,0,0,14">
        <Image x:Name="StartupIcon" Width="64" Height="64"
               RenderOptions.BitmapScalingMode="HighQuality"
               Stretch="UniformToFill"/>
      </Border>
      <TextBlock Text="WinToolerV1" FontSize="26" FontWeight="Bold"
                 Foreground="#1A1A1A" HorizontalAlignment="Center"/>
      <TextBlock Text="v0.7 BETA  by ErickP (Eperez98)" FontSize="12"
                 Foreground="#999999" HorizontalAlignment="Center" Margin="0,4,0,0"/>
    </StackPanel>

    <!-- Language label -->
    <TextBlock Grid.Row="2" Text="Select Language / Seleccionar Idioma"
               FontSize="11" FontWeight="SemiBold" Foreground="#777777"
               HorizontalAlignment="Center"/>

    <!-- Language buttons -->
    <Grid Grid.Row="4">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="16"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <Button x:Name="BtnEN" Grid.Column="0" Style="{StaticResource SelBtn}" Height="86">
        <StackPanel>
          <TextBlock Text="EN" FontSize="28" FontWeight="Black"
                     Foreground="#1A1A1A" HorizontalAlignment="Center"/>
          <TextBlock Text="English" FontSize="13" FontWeight="SemiBold"
                     Foreground="#444444" HorizontalAlignment="Center" Margin="0,4,0,0"/>
          <TextBlock Text="United States" FontSize="10"
                     Foreground="#999999" HorizontalAlignment="Center" Margin="0,2,0,0"/>
        </StackPanel>
      </Button>

      <Button x:Name="BtnES" Grid.Column="2" Style="{StaticResource SelBtn}" Height="86">
        <StackPanel>
          <TextBlock Text="ES" FontSize="28" FontWeight="Black"
                     Foreground="#1A1A1A" HorizontalAlignment="Center"/>
          <TextBlock Text="Espanol" FontSize="13" FontWeight="SemiBold"
                     Foreground="#444444" HorizontalAlignment="Center" Margin="0,4,0,0"/>
          <TextBlock Text="Espana / Latinoamerica" FontSize="10"
                     Foreground="#999999" HorizontalAlignment="Center" Margin="0,2,0,0"/>
        </StackPanel>
      </Button>
    </Grid>

    <!-- Launch button -->
    <Button Grid.Row="6" x:Name="BtnLaunch"
            Style="{StaticResource PrimaryBtn}"
            Content="Launch WinToolerV1"
            HorizontalAlignment="Center"/>
  </Grid>
</Window>
'@

    $reader  = New-Object System.Xml.XmlNodeReader($XAML)
    $sWin    = [Windows.Markup.XamlReader]::Load($reader)

    # Load icon into startup screen -- use $global:Root set by WinToolerV1.ps1
    try {
        $iconBase = if ($global:Root) { $global:Root } else { $PSScriptRoot }
        $iconPath = Join-Path $iconBase "WinToolerV1_icon.png"
        if (Test-Path $iconPath) {
            $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.UriSource       = New-Object System.Uri((Resolve-Path $iconPath).Path, [System.UriKind]::Absolute)
            $bmp.DecodePixelWidth = 64
            $bmp.CacheOption      = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.EndInit()
            $bmp.Freeze()
            $startupImg = $sWin.FindName("StartupIcon")
            if ($startupImg) { $startupImg.Source = $bmp }
            $sWin.Icon = $bmp
        }
    } catch {}

    $btnEN = $sWin.FindName("BtnEN")
    $btnES = $sWin.FindName("BtnES")

    $accentBrush = New-Object Windows.Media.SolidColorBrush([Windows.Media.ColorConverter]::ConvertFromString("#0067C0"))
    $dimBrush    = New-Object Windows.Media.SolidColorBrush([Windows.Media.ColorConverter]::ConvertFromString("#CCCCCC"))

    $setLangHL = {
        param([string]$lang)
        if ($lang -eq "EN") { $btnEN.BorderBrush = $accentBrush } else { $btnEN.BorderBrush = $dimBrush }
        if ($lang -eq "ES") { $btnES.BorderBrush = $accentBrush } else { $btnES.BorderBrush = $dimBrush }
        $result["Language"] = $lang
    }

    & $setLangHL "EN"

    $btnEN.Add_Click({ & $setLangHL "EN" })
    $btnES.Add_Click({ & $setLangHL "ES" })

    $launchBtn = $sWin.FindName("BtnLaunch")
    $launchBtn.Add_Click({ $sWin.DialogResult = $true; $sWin.Close() })

    $sWin.ShowDialog() | Out-Null
    return $result
}
