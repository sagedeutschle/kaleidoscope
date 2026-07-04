import subprocess, json, time, base64, sys, urllib.request, urllib.error, hashlib
KEY_ID="FLXPLSRBU8"; ISSUER="69a6de6e-581f-47e3-e053-5b8c7c11a4d1"
KEY_PATH="/Users/gtrktscrb/.appstoreconnect/private_keys/AuthKey_FLXPLSRBU8.p8"
def b64u(b): return base64.urlsafe_b64encode(b).rstrip(b'=')
def jwt_token():
    hdr=b64u(json.dumps({"alg":"ES256","kid":KEY_ID,"typ":"JWT"},separators=(',',':')).encode())
    now=int(time.time())
    pl=b64u(json.dumps({"iss":ISSUER,"iat":now,"exp":now+1000,"aud":"appstoreconnect-v1"},separators=(',',':')).encode())
    signing=hdr+b'.'+pl
    der=subprocess.run(["openssl","dgst","-sha256","-sign",KEY_PATH],input=signing,capture_output=True).stdout
    assert der[0]==0x30
    idx=2 if der[1]<0x80 else 2+(der[1]&0x7f)
    assert der[idx]==0x02; rlen=der[idx+1]; r=der[idx+2:idx+2+rlen]; idx=idx+2+rlen
    assert der[idx]==0x02; slen=der[idx+1]; s=der[idx+2:idx+2+slen]
    sig=int.from_bytes(r,'big').to_bytes(32,'big')+int.from_bytes(s,'big').to_bytes(32,'big')
    return (signing+b'.'+b64u(sig)).decode()
def api(method,path,body=None,raw=None,ctype="application/json"):
    url="https://api.appstoreconnect.apple.com"+path
    data=raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req=urllib.request.Request(url,data=data,method=method)
    req.add_header("Authorization","Bearer "+jwt_token())
    if body is not None or raw is not None: req.add_header("Content-Type",ctype)
    try:
        with urllib.request.urlopen(req) as r:
            t=r.read(); return r.status,(json.loads(t) if t else {})
    except urllib.error.HTTPError as e:
        t=e.read(); return e.code,(json.loads(t) if t else {})
if __name__=="__main__":
    cmd=sys.argv[1]
    if cmd=="probe":
        st,app=api("GET","/v1/apps/6785993194")
        d=app.get("data",{}).get("attributes",{})
        print("AUTH/app:",st, d.get("name"), d.get("bundleId"), d.get("primaryLocale"))
        st,vers=api("GET","/v1/apps/6785993194/appStoreVersions?limit=5")
        for v in vers.get("data",[]):
            a=v["attributes"]; print("version:",v["id"],a.get("versionString"),a.get("appStoreState"))
            st,locs=api("GET",f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")
            for l in locs.get("data",[]):
                la=l["attributes"]; print("   loc:",l["id"],la.get("locale"),"| whatsNew:",repr((la.get("whatsNew") or "")[:40]))
            st,builds=api("GET",f"/v1/appStoreVersions/{v['id']}/build")
            b=builds.get("data"); print("   attached build:", b["id"] if b else None)
