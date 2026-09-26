param([int]$Port=19876)
$ErrorActionPreference="Continue"
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$listener=New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
try{$listener.Start()}catch{Write-Host "Impossible d'utiliser le port $Port : $($_.Exception.Message)" -ForegroundColor Red;pause;exit}
Write-Host "Football Match Tracker V3 : http://127.0.0.1:$Port/" -ForegroundColor Green
Start-Process "http://127.0.0.1:$Port/"

# ESPN documents these soccer league slugs for scoreboard/schedule data.
$leagues=@(
 @{slug="caf.nations_qual"; name="Qualifications CAN"; cat="caf"},
 @{slug="caf.nations"; name="Coupe d'Afrique des Nations"; cat="caf"},
 @{slug="caf.champions"; name="CAF Champions League"; cat="caf"},
 @{slug="caf.confed"; name="CAF Confederation Cup"; cat="caf"},
 @{slug="uefa.champions"; name="UEFA Champions League"; cat="ucl"},
 @{slug="fifa.world"; name="Coupe du Monde"; cat="wc"},
 @{slug="fifa.worldq.caf"; name="Qualifications Coupe du Monde - CAF"; cat="wc"},
 @{slug="fra.1"; name="Ligue 1"; cat="other"},
 @{slug="esp.1"; name="La Liga"; cat="other"},
 @{slug="ger.1"; name="Bundesliga"; cat="other"},
 @{slug="eng.1"; name="Premier League"; cat="other"}
)
function FetchLeague($L){
  $d1=(Get-Date).ToUniversalTime().ToString("yyyyMMdd");$d2=(Get-Date).ToUniversalTime().AddDays(120).ToString("yyyyMMdd")
  $url="https://site.api.espn.com/apis/site/v2/sports/soccer/$($L.slug)/scoreboard?limit=1000&dates=$d1-$d2"
  try{
    $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25 -Headers @{"User-Agent"="Mozilla/5.0 FootballMatchTracker"}
    $j=$r.Content|ConvertFrom-Json
    $arr=@()
    foreach($e in @($j.events)){
      $c=$e.competitions[0];$h=@($c.competitors)|Where-Object {$_.homeAway -eq "home"}|Select-Object -First 1;$a=@($c.competitors)|Where-Object {$_.homeAway -eq "away"}|Select-Object -First 1
      if($h -and $a){$arr+=[pscustomobject]@{id=$e.id;date=$e.date;home=$h.team.displayName;away=$a.team.displayName;hs=$(if($h.score){$h.score}else{""});as=$(if($a.score){$a.score}else{""});status=$e.status.type.shortDetail;league=$L.name;cat=$L.cat}}
    };return $arr
  }catch{Write-Host "Source non disponible: $($L.slug)" -ForegroundColor DarkYellow;return @()}
}
function Data(){
 $caf=@();$ucl=@();$wc=@();$other=@();$all=@()
 foreach($L in $leagues){
   $x=@(FetchLeague $L)
   if($L.cat -eq "caf"){$caf+=$x}elseif($L.cat -eq "ucl"){$ucl+=$x}elseif($L.cat -eq "wc"){$wc+=$x}else{$other+=$x}
 }
 $all=@($caf)+@($ucl)+@($wc)+@($other)|Sort-Object date
 [pscustomobject]@{caf=(@($caf)|Sort-Object date);ucl=(@($ucl)|Sort-Object date);wc=(@($wc)|Sort-Object date);matches=$all}
}
function Json($ctx,$obj){
 $b=[Text.Encoding]::UTF8.GetBytes(($obj|ConvertTo-Json -Depth 12 -Compress));$ctx.Response.ContentType="application/json; charset=utf-8";$ctx.Response.ContentLength64=$b.Length;$ctx.Response.Headers.Add("Cache-Control","no-store");$ctx.Response.OutputStream.Write($b,0,$b.Length);$ctx.Response.Close()
}
function File($ctx,$p){
 $b=[IO.File]::ReadAllBytes($p);$ctx.Response.ContentType="text/html; charset=utf-8";$ctx.Response.ContentLength64=$b.Length;$ctx.Response.OutputStream.Write($b,0,$b.Length);$ctx.Response.Close()
}
while($listener.IsListening){
 try{
  $c=$listener.GetContext();$p=$c.Request.Url.AbsolutePath
  if($p -eq "/football-data"){Json $c (Data)}
  elseif($p -eq "/" -or $p -eq "/index.html"){File $c (Join-Path $root "index.html")}
  else{$c.Response.StatusCode=404;$c.Response.Close()}
 }catch{if($listener.IsListening){Write-Host $_ -ForegroundColor Red}}
}
