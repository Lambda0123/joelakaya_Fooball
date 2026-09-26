param([int]$Port=19878)
$ErrorActionPreference="SilentlyContinue"
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$listener=New-Object System.Net.HttpListener;$listener.Prefixes.Add("http://127.0.0.1:$Port/");$listener.Start()
Write-Host "FOOTBALL MATCH TRACKER V5 - SOURCE FOOT MERCATO" -ForegroundColor Cyan
Write-Host "http://127.0.0.1:$Port/" -ForegroundColor Green
Write-Host "Laissez cette fenetre ouverte." -ForegroundColor Yellow
Start-Process "http://127.0.0.1:$Port/"

function Get-FM {
  $url="https://www.footmercato.net/live/"
  try {
    $html=(Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30 -Headers @{"User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/138 Safari/537.36";"Accept-Language"="fr-FR,fr;q=0.9"}).Content
    # Extract a broad text representation. Foot Mercato's live page contains
    # competition headings followed by team names and kickoff times.
    $text=$html -replace '(?is)<script.*?</script>',' ' -replace '(?is)<style.*?</style>',' ' -replace '(?is)<[^>]+>',' ' -replace '&nbsp;',' ' -replace '&amp;','&'
    $text=[System.Net.WebUtility]::HtmlDecode($text)
    $text=$text -replace '\s+',' '
    $matches=@()
    # Common Foot Mercato visible pattern: Team Team HH:MM.
    $rx='(?i)(?<home>[A-Za-zÀ-ÿ0-9\.\-''& ]{2,40})\s+(?<away>[A-Za-zÀ-ÿ0-9\.\-''& ]{2,40})\s+(?<time>\d{1,2}:\d{2})'
    foreach($m in [regex]::Matches($text,$rx)){
      $h=$m.Groups["home"].Value.Trim();$a=$m.Groups["away"].Value.Trim()
      if($h -and $a -and $h.Length -lt 40 -and $a.Length -lt 40){
        # discard obvious UI phrases
        if($h -notmatch '^(Matchs|Aujourd|Demain|Filtrer|Classement|Calendrier|Buteurs|Live|Voir|Tous)$' -and $a -notmatch '^(Matchs|Aujourd|Demain|Filtrer|Classement|Calendrier|Buteurs|Live|Voir|Tous)$'){
          $matches += [pscustomobject]@{home=$h;away=$a;time=$m.Groups["time"].Value}
        }
      }
    }
    # Deduplicate and convert today's times to local timestamps.
    $today=Get-Date
    $out=@()
    foreach($x in $matches | Select-Object -Unique home,away,time){
      try{$dt=Get-Date ($today.ToString("yyyy-MM-dd")+" "+$x.time)
        $out += [pscustomobject]@{date=$dt.ToString("o");home=$x.home;away=$x.away;status="À venir";league="Foot Mercato";score=""}
      }catch{}
    }
    # We cannot reliably classify every competition from generic page text,
    # so classify using competition/team keywords where possible.
    $caf=@($out | ? {($_.home+" "+$_.away) -match 'Gabon|Maroc|Algérie|Égypte|Sénégal|Cameroun|Nigeria|Mali|Ghana|Tunisie|Côte'})
    $ucl=@($out | ? {($_.home+" "+$_.away) -match 'Real Madrid|Barcelona|Barcelone|PSG|Paris|Liverpool|Arsenal|Chelsea|Manchester|Bayern|Dortmund|Inter|Milan|Juventus|Napoli|Atlético|Marseille|Lyon|Lille'})
    $wc=@($out | ? {($_.home+" "+$_.away) -match 'France|Angleterre|Espagne|Allemagne|Italie|Portugal|Brésil|Argentine|Japon|Corée|Mexique|États-Unis|Suisse|Croatie'})
    [pscustomobject]@{caf=$caf;ucl=$ucl;wc=$wc;matches=$out}
  } catch {
    [pscustomobject]@{caf=@();ucl=@();wc=@();matches=@();error=$_.Exception.Message}
  }
}
function Reply($ctx,$obj,$type){$b=[Text.Encoding]::UTF8.GetBytes(($obj|ConvertTo-Json -Depth 10 -Compress));$ctx.Response.ContentType=$type;$ctx.Response.ContentLength64=$b.Length;$ctx.Response.OutputStream.Write($b,0,$b.Length);$ctx.Response.Close()}
while($listener.IsListening){
 try{$c=$listener.GetContext();$p=$c.Request.Url.AbsolutePath.TrimEnd('/');if($p -eq ""){$p="/"}
 if($p -eq "/footmercato-data"){Reply $c (Get-FM) "application/json; charset=utf-8"}
 elseif($p -eq "/" -or $p -eq "/index.html"){Reply $c ([IO.File]::ReadAllText((Join-Path $root "index.html"),[Text.Encoding]::UTF8)) "text/html; charset=utf-8"}
 else{$c.Response.StatusCode=404;$c.Response.Close()}}catch{}
}
