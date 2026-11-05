#!/usr/bin/env python3
"""K2 shutdown authorization matrix — LOCAL ANVIL FORK ONLY @ block 26347966.
NEG tests: no impersonation. SYNTH tests: impersonated guardian, labeled."""
import json, urllib.request, subprocess, time

RPC = "http://127.0.0.1:8545"
PORTAL = "0xeece9cd7abd1cc84d9dfc7493e7e68079e47ea73"
L1SB   = "0xba61f25dd9f2d5f02d01b1c2c1c5f0b14c4b48a3"
GUARD  = "0x28a227d4faf0f4f75897438e24c43ef1cdabb920"
USDC   = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
ATK    = "0x00000000000000000000000000000000000000aa"  # synthetic attacker
VIC    = "0x00000000000000000000000000000000000000bb"  # synthetic claimant
OUT = {"pin_block":26347966,"pin_hash":"0x9a1b6259fc3e849d539defa91a0aa6b460fdf28fb5d6c774d7e7b767d08d6e0d","tests":[]}
i = [0]
def rpc(m,p):
    i[0]+=1
    r=urllib.request.Request(RPC,json.dumps({"jsonrpc":"2.0","id":i[0],"method":m,"params":p}).encode(),{"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(r,timeout=120).read())
def sig(s): return subprocess.run(["cast","sig",s],capture_output=True,text=True).stdout.strip()
def keccak(hexdata):
    r=subprocess.run(["cast","keccak",hexdata],capture_output=True,text=True).stdout.strip()
    return r
def enc_addr(a): return "0"*24+a[2:]
def enc_u(v): return "%064x"%v
def leaf_eth(addr,amt):
    inner=keccak("0x"+enc_addr(addr)+enc_u(amt))[2:]
    return keccak("0x"+inner)
def leaf_tok(addr,toks,amts):
    n=len(toks)
    off1=enc_u(96); off2=enc_u(96+32+32*n)
    enc=enc_addr(addr)+off1+off2+enc_u(n)+"".join(enc_addr(t) for t in toks)+enc_u(n)+"".join(enc_u(a) for a in amts)
    return keccak("0x"+keccak("0x"+enc)[2:])
def call(to,data,frm=None):
    o={"to":to,"data":data}
    if frm:o["from"]=frm
    return rpc("eth_call",[o,"latest"])
def send(to,data,frm):
    return rpc("eth_sendTransaction",[{"from":frm,"to":to,"data":data,"gas":hex(3000000)}])
def rcpt(h):
    for _ in range(30):
        r=rpc("eth_getTransactionReceipt",[h])["result"]
        if r: return r
        import time; time.sleep(0.5)
    return None
def bal(a): return int(rpc("eth_getBalance",[a,"latest"])["result"],16)
def bal20(t,a): 
    r=rpc("eth_call",[{"to":t,"data":"0x70a08231"+enc_addr(a)},"latest"]).get("result","0x")
    return int(r,16) if r and r!="0x" else 0
def rec(name,label,expected,actual,passed,detail=""):
    OUT["tests"].append({"test":name,"label":label,"expected":expected,"actual":actual,"pass":passed,"detail":detail})
    print(("PASS" if passed else "FAIL"),label,name,"|",actual[:80])

def errstr(r):
    e=r.get("error",{})
    return e.get("message","?") if isinstance(e,dict) else str(e)

# ---------- NEGATIVE: real boundary, no impersonation ----------
r=call(PORTAL,sig("claimETH(uint256,bytes32[])")+enc_u(10**18)+enc_u(64)+enc_u(0),ATK)
rec("claimETH rand acct empty proof","NEG","revert invalid proof",errstr(r),"invalid proof" in errstr(r))
r=call(PORTAL,sig("claimETH(uint256,bytes32[])")+enc_u(0)+enc_u(64)+enc_u(0),ATK)
rec("claimETH amount=0","NEG","revert invalid amount",errstr(r),"invalid amount" in errstr(r))
fake="0x"+"ab"*32
r=call(PORTAL,sig("claimETH(uint256,bytes32[])")+enc_u(1846*10**18)+enc_u(64)+enc_u(1)+fake[2:],ATK)
rec("claimETH full balance fake proof","NEG","revert invalid proof",errstr(r),"invalid proof" in errstr(r))
r=call(PORTAL,sig("setMerkleRootETH(bytes32)")+fake[2:],ATK)
rec("setMerkleRootETH non-guardian","NEG","revert only guardian",errstr(r),"only guardian" in errstr(r))
r=call(PORTAL,sig("pause()"),ATK); rec("pause non-guardian","NEG","revert",errstr(r),"only guardian" in errstr(r))
r=call(PORTAL,sig("recoverETH(address)")+enc_addr(ATK),ATK); rec("recoverETH non-guardian","NEG","revert",errstr(r),"only guardian" in errstr(r))
r=call(PORTAL,sig("depositTransaction(address,uint256,uint64,bool,bytes)")+enc_addr(ATK)+enc_u(0)+enc_u(21000)+enc_u(0)+enc_u(160)+enc_u(0),ATK)
rec("depositTransaction","NEG","revert deposits disabled",errstr(r),"deposits disabled" in errstr(r))
r=call(PORTAL,sig("initialize(address,address,address,bool)")+enc_addr(ATK)*3+enc_u(0),ATK)
rec("initialize on live proxy","NEG","revert initialized",errstr(r),"initialized" in errstr(r) or "revert" in errstr(r).lower())
enc=enc_u(32)+enc_u(0)+enc_addr(ATK)+enc_addr(ATK)+enc_u(0)+enc_u(0)+enc_u(192)+enc_u(0)
r=call(PORTAL,sig("finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes))")+enc,ATK)
rec("finalizeWithdrawalTransaction","NEG","revert path disabled",errstr(r),"disabled" in errstr(r))
# claimTokens negatives
r=call(L1SB,sig("claimTokens(address[],uint256[],bytes32[])")+enc_u(96)+enc_u(160)+enc_u(224)+enc_u(1)+enc_addr(USDC)+enc_u(1)+enc_u(10**6)+enc_u(0),ATK)
rec("claimTokens fake proof","NEG","revert invalid proof",errstr(r),"invalid proof" in errstr(r))
r=call(L1SB,sig("recoverTokens(address,address[])")+enc_addr(ATK)+enc_u(64)+enc_u(1)+enc_addr(USDC),ATK)
rec("recoverTokens non-guardian","NEG","revert only guardian",errstr(r),"only guardian" in errstr(r))
# ---------- SYNTH: impersonated guardian, single-leaf trees ----------
rpc("anvil_impersonateAccount",[GUARD]); rpc("anvil_impersonateAccount",[VIC]); rpc("anvil_impersonateAccount",[ATK]); rpc("anvil_setBalance",[GUARD,hex(10**18)])
rpc("anvil_setBalance",[VIC,hex(10**18)]); rpc("anvil_setBalance",[ATK,hex(10**18)])
L1=leaf_eth(VIC,100*10**18)
h=send(PORTAL,sig("setMerkleRootETH(bytes32)")+L1[2:],GUARD); rc=rcpt(h["result"])
rec("guardian setMerkleRootETH","SYNTH","status 0x1",rc["status"],rc["status"]=="0x1","root="+L1[:20])
b0=bal(PORTAL); v0=bal(VIC)
h=send(PORTAL,sig("claimETH(uint256,bytes32[])")+enc_u(100*10**18)+enc_u(64)+enc_u(0),VIC); rc=rcpt(h["result"])
v1=bal(VIC); b1=bal(PORTAL)
gas=int(rc["gasUsed"],16)*int(rc["effectiveGasPrice"],16)
rec("SYNTH claimETH valid leaf pays exact","SYNTH","+100 ETH to claimer","delta=%.4f"%((v1-v0)/1e18),abs((v1-v0)/1e18-100)<0.001,"escrow delta=%.4f gas=%.4f"%((b0-b1)/1e18,gas/1e18))
h=send(PORTAL,sig("claimETH(uint256,bytes32[])")+enc_u(100*10**18)+enc_u(64)+enc_u(0),VIC); rc=rcpt(h["result"])
rec("double claim same leaf","SYNTH","revert nothing to claim",rc["status"],rc["status"]=="0x0","receipt status")
r=call(PORTAL,sig("claimETH(uint256,bytes32[])")+enc_u(100*10**18)+enc_u(64)+enc_u(0),ATK)
rec("attacker reuses victim amount/proof","SYNTH","revert invalid proof (msg.sender bound)",errstr(r),"invalid proof" in errstr(r))
# cumulative root upgrade
L2=leaf_eth(VIC,150*10**18)
send(PORTAL,sig("setMerkleRootETH(bytes32)")+L2[2:],GUARD)
v0=bal(VIC)
h=send(PORTAL,sig("claimETH(uint256,bytes32[])")+enc_u(150*10**18)+enc_u(64)+enc_u(0),VIC); rc=rcpt(h["result"])
v1=bal(VIC)
rec("cumulative second claim pays delta","SYNTH","+50 ETH","delta=%.4f"%((v1-v0)/1e18),abs((v1-v0)/1e18-50)<0.001)
# guardian grants attacker a leaf (documented authority, not a bug)
LA=leaf_eth(ATK,10*10**18)
send(PORTAL,sig("setMerkleRootETH(bytes32)")+LA[2:],GUARD)
h=send(PORTAL,sig("claimETH(uint256,bytes32[])")+enc_u(11*10**18)+enc_u(64)+enc_u(0),ATK); rc=rcpt(h["result"])
rec("attacker claims amount not in leaf","SYNTH","revert invalid proof",rc["status"],rc["status"]=="0x0","leaf binds (addr,exact amount)")
a0=bal(ATK)
h=send(PORTAL,sig("claimETH(uint256,bytes32[])")+enc_u(10*10**18)+enc_u(64)+enc_u(0),ATK); rc=rcpt(h["result"])
rec("guardian-granted leaf pays exactly","SYNTH","+10 ETH","delta=%.4f"%((bal(ATK)-a0)/1e18),abs((bal(ATK)-a0)/1e18-10)<0.001)
# ERC20 claimTokens synthetic
LT=leaf_tok(VIC,[USDC],[1000*10**6])
send(L1SB,sig("setMerkleRoot(bytes32)")+LT[2:],GUARD)
u0=bal20(USDC,VIC)
h=send(L1SB,sig("claimTokens(address[],uint256[],bytes32[])")+enc_u(96)+enc_u(160)+enc_u(224)+enc_u(1)+enc_addr(USDC)+enc_u(1)+enc_u(1000*10**6)+enc_u(0),VIC); rc=rcpt(h["result"])
u1=bal20(USDC,VIC)
rec("SYNTH claimTokens pays USDC","SYNTH","+1000 USDC","delta=%.2f"%((u1-u0)/1e6),abs((u1-u0)/1e6-1000)<0.01)
r=call(L1SB,sig("claimTokens(address[],uint256[],bytes32[])")+enc_u(96)+enc_u(192)+enc_u(288)+enc_u(2)+enc_addr(USDC)+enc_addr(USDC)+enc_u(2)+enc_u(1)+enc_u(2)+enc_u(0),VIC)
rec("claimTokens duplicate token","SYNTH","revert duplicate token",errstr(r),"duplicate token" in errstr(r) or "invalid proof" in errstr(r))
# recoverETH gating
r=call(PORTAL,sig("recoverETH(address)")+enc_addr(GUARD),GUARD)
rec("recoverETH while unpaused","SYNTH","revert claims not paused",errstr(r),"not paused" in errstr(r))
send(PORTAL,sig("pause()"),GUARD)
r=call(PORTAL,sig("recoverETH(address)")+enc_addr(GUARD),GUARD)
rec("recoverETH paused but early","SYNTH","revert recovery not available",errstr(r),"not available" in errstr(r))
r=call(PORTAL,sig("claimETH(uint256,bytes32[])")+enc_u(1)+enc_u(64)+enc_u(0),VIC)
rec("claimETH while paused","SYNTH","revert claims paused",errstr(r),"paused" in errstr(r))
rpc("evm_increaseTime",[1820707201-1793815509])
h=send(PORTAL,sig("recoverETH(address)")+enc_addr(GUARD),GUARD); rc=rcpt(h["result"])
rec("recoverETH after 2027 sweeps all","SYNTH","escrow drained","portal_bal=%.4f"%(bal(PORTAL)/1e18),bal(PORTAL)==0 and rc["status"]=="0x1","to guardian")
np_=sum(1 for t in OUT["tests"] if t["pass"])
OUT["summary"]={"total":len(OUT["tests"]),"passed":np_}
open("auth_matrix_results.json","w").write(json.dumps(OUT,indent=1))
print("%d/%d PASS"%(np_,len(OUT["tests"])))
