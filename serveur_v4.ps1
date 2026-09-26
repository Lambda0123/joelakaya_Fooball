param([int]$Port=19877)
$ErrorActionPreference="SilentlyContinue"
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
# Stop only an older copy of THIS tracker using our marker window title is not reliable;
# instead use a fresh port for V4.
$listener=New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Host ""
Write-Host "FOOTBALL MATCH TRACKER V4" -ForegroundColor Cyan
Write-Host "http://127.0.0.1:$Port/" -ForegroundColor Green
Write-Host "Laissez cette fenetre ouverte." -ForegroundColor Yellow
Start-Sleep -Milliseconds 300
Start-Process "http://127.0.0.1:$Port/"

$leagues=@(
 @{slug="caf.nations_qual";name="Qualifications CAN";cat="caf"},
 @{slug="caf.champions";name="CAF Champions League";cat="caf"},
 @{slug="caf.confed";name="CAF Confederation Cup";cat="caf"},
 @{slug="uefa.champions";name="UEFA Champions League";cat="ucl"},
 @{slug="fifa.world";name="Coupe du Monde";cat="wc"},
 @{slug="fifa.worldq.caf";name="Qualifications Coupe du Monde - CAF";cat="wc"},
 @{slug="fra.1";name="Ligue 1";cat="other"},
 @{slug="esp.1";name="La Liga";cat="other"},
 @{slug="ger.1";name="Bundesliga";cat="other"},
 @{slug="eng.1";name="Premier League";cat="other"}
)
function Fetch($L){
$d1=(Get-Date).ToUniversalTime().ToString("yyyyMMdd");$d2=(Get-Date).ToUniversalTime().AddDays(120).ToString("yyyyMMdd")
$url="https://site.api.espn.com/apis/site/v2/sports/soccer/$($L.slug)/scoreboard?limit=1000&dates=$d1-$d2"
try{$j=(Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25 -Headers @{"User-Agent"="Mozilla/5.0"}).Content|ConvertFrom-Json;$o=@()
foreach($e in @($j.events)){$c=$e.competitions[0];$h=@($c.competitors)|? homeAway -eq home|select -First 1;$a=@($c.competitors)|? homeAway -eq away|select -First 1
if($h -and $a){$o+=[pscustomobject]@{id=$e.id;date=$e.date;home=$h.team.displayName;away=$a.team.displayName;hs=$(if($h.score){$h.score}else{""});as=$(if($a.score){$a.score}else{""});status=$e.status.type.shortDetail;league=$L.name;cat=$L.cat}}}return $o}catch{return @()}}
function Build(){
$caf=@();$ucl=@();$wc=@();$other=@()
foreach($L in $leagues){$x=@(Fetch $L);if($L.cat -eq "caf"){$caf+=$x}elseif($L.cat -eq "ucl"){$ucl+=$x}elseif($L.cat -eq "wc"){$wc+=$x}else{$other+=$x}}
[pscustomobject]@{caf=(@($caf)|sort date);ucl=(@($ucl)|sort date);wc=(@($wc)|sort date);matches=(@($caf)+@($ucl)+@($wc)+@($other)|sort date)}}
function Reply($ctx,$obj,$type){$b=[Text.Encoding]::UTF8.GetBytes(($obj|ConvertTo-Json -Depth 12 -Compress));$ctx.Response.ContentType=$type;$ctx.Response.ContentLength64=$b.Length;$ctx.Response.OutputStream.Write($b,0,$b.Length);$ctx.Response.Close()}
while($listener.IsListening){try{$ctx=$listener.GetContext();$path=$ctx.Request.Url.AbsolutePath.TrimEnd('/')
if($path -eq ""){$path="/"}
if($path -eq "/data.json"){Reply $ctx (Build) "application/json; charset=utf-8"}
elseif($path -eq "/" -or $path -eq "/index.html"){Reply $ctx ([IO.File]::ReadAllText((Join-Path $root "index.html"),[Text.Encoding]::UTF8)) "text/html; charset=utf-8"}
elseif($path -eq "/test"){Reply $ctx ([pscustomobject]@{ok=$true;message="Serveur V4 opérationnel"}) "application/json; charset=utf-8"}
else{$ctx.Response.StatusCode=404;$ctx.Response.Close()}}catch{}}
