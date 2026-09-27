import json,urllib.request
from datetime import datetime,timedelta,timezone
LEAGUES={"caf":[("africa.cup_of_nations","CAF / CAN"),("caf.champions","CAF Champions League"),("caf.confed","CAF Confederation Cup")],"ucl":[("uefa.champions","UEFA Champions League")],"world":[("fifa.world","Coupe du Monde")],"extra":[("fra.1","France — Ligue 1"),("esp.1","Espagne — LaLiga"),("ger.1","Allemagne — Bundesliga"),("eng.1","Angleterre — Premier League")]}
def get(u):
 r=urllib.request.Request(u,headers={"User-Agent":"Mozilla/5.0 FootballMatchTracker/6.0","Accept":"application/json"})
 with urllib.request.urlopen(r,timeout=30) as x:return json.loads(x.read())
def main():
 now=datetime.now(timezone.utc);a=now-timedelta(days=2);b=now+timedelta(days=14);dates=f"{a:%Y%m%d}-{b:%Y%m%d}";out={};errors=[]
 for cat,leagues in LEAGUES.items():
  for league,name in leagues:
   try:
    d=get(f"https://site.api.espn.com/apis/site/v2/sports/soccer/{league}/scoreboard?dates={dates}")
    for e in d.get("events",[]):
     c=(e.get("competitions") or [{}])[0];cs=c.get("competitors") or []
     h=next((x for x in cs if x.get("homeAway")=="home"),None);v=next((x for x in cs if x.get("homeAway")=="away"),None)
     if not h or not v:continue
     st=(e.get("status") or {}).get("type") or {};sn=st.get("name","")
     status="LIVE" if "IN_PROGRESS" in sn or "HALFTIME" in sn or "FIRST_HALF" in sn or "SECOND_HALF" in sn or "OVERTIME" in sn else ("FINAL" if "FINAL" in sn else "UPCOMING")
     def nm(x):return (x.get("team") or {}).get("displayName") or "Équipe"
     def sc(x):
      try:return int(x.get("score"))
      except:return None
     out[str(e.get("id"))]={"id":str(e.get("id")),"date":e.get("date"),"home":nm(h),"away":nm(v),"homeScore":sc(h),"awayScore":sc(v),"competition":name,"category":cat if cat in ("caf","ucl","world") else "extra","status":status,"statusLabel":{"LIVE":"EN DIRECT","FINAL":"Terminé","UPCOMING":"À venir"}[status]}
   except Exception as ex:errors.append(f"{league}: {ex}")
 matches=sorted(out.values(),key=lambda x:x.get("date") or "")
 json.dump({"generatedAt":now.isoformat(),"source":"ESPN public scoreboard API","errors":errors,"matches":matches},open("matches.json","w",encoding="utf-8"),ensure_ascii=False,indent=2)
 print(len(matches),"matchs")
if __name__=="__main__":main()
