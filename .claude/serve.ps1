param(
  [int]$Port = 5500,
  [string]$Dir = "website"
)
$ErrorActionPreference = "Stop"

# Resolve the directory relative to CWD, falling back to the project root (parent of .claude/)
if (-not (Test-Path $Dir)) { $Dir = Join-Path (Split-Path $PSScriptRoot -Parent) $Dir }
$root = (Resolve-Path $Dir).Path

$mime = @{
  ".html"="text/html; charset=utf-8"; ".htm"="text/html; charset=utf-8";
  ".css"="text/css; charset=utf-8"; ".js"="application/javascript; charset=utf-8";
  ".json"="application/json"; ".svg"="image/svg+xml"; ".png"="image/png";
  ".jpg"="image/jpeg"; ".jpeg"="image/jpeg"; ".gif"="image/gif"; ".webp"="image/webp";
  ".ico"="image/x-icon"; ".woff"="font/woff"; ".woff2"="font/woff2"; ".ttf"="font/ttf";
  ".pdf"="application/pdf"; ".txt"="text/plain; charset=utf-8"
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving '$root' at http://localhost:$Port/  (Ctrl+C to stop)"

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    try {
      $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
      if ([string]::IsNullOrWhiteSpace($rel)) { $rel = "index.html" }
      $full = Join-Path $root $rel
      if (Test-Path $full -PathType Container) { $full = Join-Path $full "index.html" }

      if (Test-Path $full -PathType Leaf) {
        $ext = [IO.Path]::GetExtension($full).ToLower()
        $ct = $mime[$ext]; if (-not $ct) { $ct = "application/octet-stream" }
        $bytes = [IO.File]::ReadAllBytes($full)
        $ctx.Response.ContentType = $ct
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      } else {
        $ctx.Response.StatusCode = 404
        $b = [Text.Encoding]::UTF8.GetBytes("404 Not Found: $rel")
        $ctx.Response.OutputStream.Write($b, 0, $b.Length)
      }
    } catch {
      $ctx.Response.StatusCode = 500
    } finally {
      $ctx.Response.OutputStream.Close()
    }
  }
} finally {
  $listener.Stop()
}
