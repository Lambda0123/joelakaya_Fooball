param([int]$Port = 8765)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host ""
Write-Host "Football Match Tracker demarre sur http://localhost:$Port/" -ForegroundColor Green
Write-Host "Laissez cette fenetre ouverte pendant l'utilisation." -ForegroundColor Yellow
Start-Process "http://localhost:$Port/"

$leagues = @{
  cafqual="caf.nations_qual"
  cafcl="caf.champions"
  cafconf="caf.confed"
  ucl="uefa.champions"
  world="fifa.world"
  ligue1="fra.1"
  liga="esp.1"
  bundes="ger.1"
  premier="eng.1"
}
function Get-Events($slug) {
  $start=(Get-Date).ToUniversalTime().ToString("yyyyMMdd")
  $end=(Get-Date).ToUniversalTime().AddDays(90).ToString("yyyyMMdd")
  $url="https://site.api.espn.com/apis/site/v2/sports/soccer/$slug/scoreboard?limit=500&dates=$start-$end"
  try {
    $x=Invoke-RestMethod -Uri $url -TimeoutSec 20 -Headers @{"User-Agent"="FootballMatchTracker/1.0"}
    return @($x.events)
  } catch {
    Write-Host "Source indisponible: $slug" -ForegroundColor DarkYellow
    return @()
  }
}
function Normalize($events,$leagueName) {
  $out=@()
  foreach($e in $events) {
    $c=$e.competitions[0]
    $home=$c.competitors | Where-Object {$_.homeAway -eq "home"} | Select-Object -First 1
    $away=$c.competitors | Where-Object {$_.homeAway -eq "away"} | Select-Object -First 1
    if($home -and $away) {
      $out += [pscustomobject]@{
        id=$e.id; date=$e.date
        home=$home.team.displayName; away=$away.team.displayName
        hs=($(if($home.score){$home.score}else{""})); as=($(if($away.score){$away.score}else{""}))
        status=$e.status.type.shortDetail; league=$leagueName
      }
    }
  }
  return $out
}
function Get-AllData {
  $caf=@()
  $caf += Normalize (Get-Events $leagues.cafqual) "CAN 2027 - Qualifications"
  $caf += Normalize (Get-Events $leagues.cafcl) "CAF Champions League"
  $caf += Normalize (Get-Events $leagues.cafconf) "CAF Confederation Cup"
  $ucl=Normalize (Get-Events $leagues.ucl) "UEFA Champions League"
  $wc=Normalize (Get-Events $leagues.world) "Coupe du Monde"
  $extra=@()
  $extra += Normalize (Get-Events $leagues.ligue1) "Ligue 1"
  $extra += Normalize (Get-Events $leagues.liga) "La Liga"
  $extra += Normalize (Get-Events $leagues.bundes) "Bundesliga"
  $extra += Normalize (Get-Events $leagues.premier) "Premier League"
  $all=@($caf)+@($ucl)+@($wc)+@($extra)
  $all=$all | Sort-Object date
  return [pscustomobject]@{caf=($caf|Sort-Object date);ucl=($ucl|Sort-Object date);wc=($wc|Sort-Object date);matches=$all}
}
function Send-Json($ctx,$obj) {
  $json=$obj|ConvertTo-Json -Depth 12 -Compress
  $bytes=[Text.Encoding]::UTF8.GetBytes($json)
  $ctx.Response.ContentType="application/json; charset=utf-8"; $ctx.Response.ContentLength64=$bytes.Length
  $ctx.Response.Headers.Add("Cache-Control","no-store")
  $ctx.Response.OutputStream.Write($bytes,0,$bytes.Length);$ctx.Response.Close()
}
function Send-File($ctx,$path,$type) {
  $bytes=[IO.File]::ReadAllBytes($path);$ctx.Response.ContentType=$type;$ctx.Response.ContentLength64=$bytes.Length
  $ctx.Response.OutputStream.Write($bytes,0,$bytes.Length);$ctx.Response.Close()
}
while($listener.IsListening){
  try {
    $ctx=$listener.GetContext(); $p=$ctx.Request.Url.AbsolutePath
    if($p -eq "/api/matches"){Send-Json $ctx (Get-AllData)}
    elseif($p -eq "/" -or $p -eq "/index.html"){Send-File $ctx (Join-Path $Root "index.html") "text/html; charset=utf-8"}
    else {$ctx.Response.StatusCode=404;$ctx.Response.Close()}
  } catch { if($listener.IsListening){Write-Host $_ -ForegroundColor Red} }
}
