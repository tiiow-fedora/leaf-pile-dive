param([string]$Name)
# Saves the image currently on the clipboard (Gemini "Copy image") to assets/thumbnails/ai/raw/<Name>.png
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$img = [System.Windows.Forms.Clipboard]::GetImage()
if (-not $img) { "no image on clipboard"; exit 1 }
$dir = Join-Path $PSScriptRoot "..\assets\thumbnails\ai\raw"
New-Item -ItemType Directory -Force $dir | Out-Null
$p = Join-Path $dir "$Name.png"
$img.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
"saved $Name $($img.Width)x$($img.Height)"
