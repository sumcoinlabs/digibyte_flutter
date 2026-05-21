#!/usr/bin/env python3
"""
Enhanced Multi-Coin Seed Scanner with Verbose RPC Logging
- Added older SPV wallet derivation paths (2016–2020) like Breadwallet-style and pre-BIP44.
- Logs net-new positive finds to text and JSON files with '_grok' suffix.
- Fixed running total persistence across interruptions.
"""

import os
import time
import hashlib
import hmac
import base58
import datetime
import requests
import json
import asyncio
import websockets
from decimal import Decimal
from bip_utils import (
    Bip39SeedGenerator,
    Bip39MnemonicValidator,
    Bip32Slip10Secp256k1,
    P2PKHAddr,
    P2WPKHAddr,
    P2TRAddr,
    Secp256k1PrivateKey
)
from bitcoinrpc.authproxy import AuthServiceProxy, JSONRPCException

# -------------------------------
# Global Flags
# -------------------------------
DEBUG_LOGGING = False
SHOW_DERIVATIONS = False
SHOW_ADDRESS_BALANCES = False
LOG_BLOCKCHAIN_INFO = False

# -------------------------------
# Coin Configuration Dictionary
# -------------------------------
COINS = {
    "BTC": {
        "rpc_ip": "127.0.0.1",
        "rpc_port": 8332,
        "rpc_user": "user",
        "rpc_pass": "password",
        "rpc_wallet": "btc",
        "use_rpc": True,
        "fallback_api_url": "https://chainz.cryptoid.info/btc/api.dws",
        "p2pkh_prefix": b"\x00",
        "wif_prefix": b"\x80",
        "bech32_hrp": "bc",
        "bip44_coin": 0,
        "curve": "secp256k1",
        "seed_key": b"Bitcoin seed",
        "coingecko_id": "bitcoin",
        "p2sh_versions": [b"\x05"],
        "supports_taproot": True,
        "supports_segwit": True
    },
    "DOGE": {
        "wss_url": "wss://doge1.totalitywallet.io:50004",
        "use_wss": True,
        "rpc_ip": "127.0.0.1",
        "rpc_port": 22555,
        "rpc_user": "user",
        "rpc_pass": "password",
        "rpc_wallet": "",
        "use_rpc": False,
        "fallback_api_url": "https://chainz.cryptoid.info/doge/api.dws",
        "p2pkh_prefix": b"\x1e",
        "wif_prefix": b"\x9e",
        "bech32_hrp": "doge",
        "bip44_coin": 3,
        "curve": "secp256k1",
        "seed_key": b"Dogecoin seed",
        "coingecko_id": "dogecoin",
        "p2sh_versions": [b"\x16"],
        "supports_taproot": False,
        "supports_segwit": False
    },
    "LTC": {
        "rpc_ip": "127.0.0.1",
        "rpc_port": 9332,
        "rpc_user": "user",
        "rpc_pass": "password",
        "rpc_wallet": "",
        "use_rpc": True,
        "fallback_api_url": "https://chainz.cryptoid.info/ltc/api.dws",
        "p2pkh_prefix": b"\x30",
        "wif_prefix": b"\xb0",
        "bech32_hrp": "ltc",
        "bip44_coin": 2,
        "curve": "secp256k1",
        "seed_key": b"Litecoin seed",
        "coingecko_id": "litecoin",
        "p2sh_versions": [b"\x05", b"\x32"],
        "supports_taproot": True,
        "supports_segwit": True
    },
    "DGB": {
        "rpc_ip": "127.0.0.1",
        "rpc_port": 14022,
        "rpc_user": "user",
        "rpc_pass": "password",
        "rpc_wallet": "dgb",
        "use_rpc": True,
        "fallback_api_url": "https://chainz.cryptoid.info/dgb/api.dws",
        "p2pkh_prefix": b"\x1e",
        "wif_prefix": b"\x80",
        "bech32_hrp": "dgb",
        "bip44_coin": 20,
        "curve": "secp256k1",
        "seed_key": b"DigiByte seed",
        "coingecko_id": "digibyte",
        "p2sh_versions": [b"\x3f"],
        "supports_taproot": False,
        "supports_segwit": True
    },
    "SUM": {
        "rpc_ip": "127.0.0.1",
        "rpc_port": 9334,
        "rpc_user": "user",
        "rpc_pass": "password",
        "rpc_wallet": "",
        "use_rpc": True,
        "fallback_api_url": "https://chainz.cryptoid.info/sum/api.dws",
        "p2pkh_prefix": b"\x3f",
        "wif_prefix": b"\x80",
        "bech32_hrp": "sum",
        "bip44_coin": 552,
        "curve": "secp256k1",
        "seed_key": b"Sumcoin seed",
        "coingecko_id": None,
        "p2sh_versions": [b"\x3f"],
        "supports_taproot": False,
        "supports_segwit": False
    }


}

# -------------------------------
# Global Constants
# -------------------------------
API_KEY = "e8d2ad258c8c"
_price_cache = {}

# -------------------------------
# Logging & Utility Functions
# -------------------------------
def get_log_file(coin):
    return f"/home/electrumbtc1/master_Seed_Scanner/{coin}_found_balances_grok.log"

def get_json_file(coin):
    return f"/home/electrumbtc1/master_Seed_Scanner/{coin}_found_balances_grok.json"

def get_checkpoint_file(coin):
    return f"/home/electrumbtc1/master_Seed_Scanner/{coin}_scan_checkpoint_grok.log"

def get_error_log_file(coin):
    return f"/home/electrumbtc1/master_Seed intakes_Scanner/{coin}_error_grok.log"

def get_debug_log_file(coin):
    return f"/home/electrumbtc1/master_Seed_Scanner/{coin}_debug_grok.log"

def log_error(message, coin):
    timestamp = datetime.datetime.now().isoformat()
    with open(get_error_log_file(coin), "a") as ef:
        ef.write(f"{timestamp} - {message}\n")

def debug_log(message, coin):
    if DEBUG_LOGGING:
        timestamp = datetime.datetime.now().isoformat()
        with open(get_debug_log_file(coin), "a") as df:
            df.write(f"{timestamp} - {message}\n")
        print(f"[{coin}] DEBUG: {message}")

def format_seconds_dhms(seconds):
    sec = int(seconds)
    days, sec = divmod(sec, 86400)
    hours, sec = divmod(sec, 3600)
    minutes, sec = divmod(sec, 60)
    parts = []
    if days > 0: parts.append(f"{days}d")
    if hours > 0: parts.append(f"{hours}h")
    if minutes > 0: parts.append(f"{minutes}m")
    if sec > 0: parts.append(f"{sec}s")
    return " ".join(parts) if parts else "0s"

def format_elapsed_time(seconds):
    minutes = seconds // 60
    hours = minutes // 60
    days = hours // 24
    years = days // 365
    months = (days % 365) // 30
    days_remaining = (days % 365) % 30
    parts = []
    if years > 0:
        parts.append(f"{years} yr{'s' if years > 1 else ''}")
    if months > 0:
        parts.append(f"{months} mo{'s' if months > 1 else ''}")
    if days_remaining > 0 and years == 0:
        parts.append(f"{days_remaining} day{'s' if days_remaining > 1 else ''}")
    return ", ".join(parts) + " ago" if parts else "just now"

def fetch_usd_price_for_coin(coin):
    global _price_cache
    if coin in _price_cache:
        return _price_cache[coin]
    coin_info = COINS[coin]
    if coin == "SUM":
        url = "https://sumcoinindex.com/rates/price2.json"
        try:
            r = requests.get(url, timeout=10)
            r.raise_for_status()
            data = r.json()
            price_val = float(data.get("price", "0.0"))
            _price_cache[coin] = price_val
            return price_val
        except Exception as e:
            debug_log(f"Error fetching SUM price: {e}", coin)
            _price_cache[coin] = 0.0
            return 0.0
    else:
        cg_id = coin_info.get("coingecko_id")
        if not cg_id:
            debug_log(f"No CoinGecko ID for {coin}; using $0.0", coin)
            _price_cache[coin] = 0.0
            return 0.0
        url = f"https://api.coingecko.com/api/v3/simple/price?ids={cg_id}&vs_currencies=usd"
        try:
            r = requests.get(url, timeout=10)
            r.raise_for_status()
            data = r.json()
            usd_price = data.get(cg_id, {}).get("usd", 0.0)
            _price_cache[coin] = float(usd_price)
            return float(usd_price)
        except Exception as e:
            debug_log(f"Error fetching {coin} price: {e}", coin)
            _price_cache[coin] = 0.0
            return 0.0

def decimal_to_serializable(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")

def get_rpc_connection(coin):
    coin_info = COINS[coin]
    rpc_url = (
        f"http://{coin_info['rpc_user']}:{coin_info['rpc_pass']}@{coin_info['rpc_ip']}:{coin_info['rpc_port']}"
        f"/wallet/{coin_info['rpc_wallet']}" if coin_info.get("rpc_wallet") else
        f"http://{coin_info['rpc_user']}:{coin_info['rpc_pass']}@{coin_info['rpc_ip']}:{coin_info['rpc_port']}"
    )
    try:
        rpc = AuthServiceProxy(rpc_url, timeout=300)
        debug_log(f"Initialized RPC connection for {coin} at {coin_info['rpc_ip']}:{coin_info['rpc_port']}", coin)
        if LOG_BLOCKCHAIN_INFO and DEBUG_LOGGING:
            info = rpc.getblockchaininfo()
            debug_log(f"Blockchain info: {json.dumps(info, default=decimal_to_serializable, indent=2)}", coin)
        return rpc
    except Exception as e:
        debug_log(f"Failed to connect to {coin} RPC: {e}", coin)
        return None

def log_checkpoint(seed, coin):
    with open(get_checkpoint_file(coin), "a") as cf:
        cf.write(seed + "\n")
    debug_log(f"Checkpointed seed: {seed[:20]}...", coin)

def load_checkpoints(coin):
    cp_file = get_checkpoint_file(coin)
    if not os.path.exists(cp_file):
        return set()
    with open(cp_file, "r") as cf:
        return set(line.strip() for line in cf if line.strip())

CHECKPOINTS = {coin: load_checkpoints(coin) for coin in COINS}

def get_running_total_from_log(coin):
    total = 0.0
    log_file = get_log_file(coin)
    if os.path.exists(log_file):
        with open(log_file, "r") as f:
            for line in reversed(f.readlines()):
                if line.startswith("Running Total:"):
                    try:
                        total = float(line.split(":")[1].strip().split()[0].replace(",", ""))
                        break
                    except:
                        pass
    return total

# -------------------------------
# Address Tracking
# -------------------------------
def parse_previously_discovered_addresses(coin):
    discovered_addresses = set()
    discovered_wifs = set()
    log_file = get_log_file(coin)
    if not os.path.exists(log_file):
        return discovered_addresses, discovered_wifs
    with open(log_file, "r") as f:
        for line in f:
            if line.startswith("["):
                parts = line.split("|")
                if len(parts) >= 3:
                    addr, wif = parts[1].strip(), parts[2].strip()
                    discovered_addresses.add(addr)
                    discovered_wifs.add(wif)
    return discovered_addresses, discovered_wifs

# -------------------------------
# Balance Retrieval Functions
# -------------------------------
def address_to_scripthash(address):
    try:
        decoded = base58.b58decode(address)
        if len(decoded) != 25:
            raise ValueError("Invalid address length")
        payload = decoded[:-4]
        checksum = decoded[-4:]
        calculated_checksum = hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
        if checksum != calculated_checksum:
            raise ValueError("Invalid checksum")
        if payload[0] != 0x1e:
            raise ValueError("Not a Dogecoin P2PKH address")
        pubkey_hash = payload[1:]
        scriptPubKey = b'\x76\xa9\x14' + pubkey_hash + b'\x88\xac'
        scripthash_bytes = hashlib.sha256(scriptPubKey).digest()
        scripthash = scripthash_bytes[::-1].hex()
        return scripthash
    except Exception as e:
        debug_log(f"Error converting address {address} to scripthash: {e}", "DOGE")
        return None

async def get_doge_balances_wss(addresses):
    uri = COINS["DOGE"]["wss_url"]
    balance_dict = {addr: 0.0 for addr in addresses}
    try:
        async with websockets.connect(uri, ping_interval=20) as ws:
            debug_log("Connected to DOGE WebSocket", "DOGE")
            for addr in addresses:
                scripthash = address_to_scripthash(addr)
                if scripthash is None:
                    debug_log(f"Skipping invalid Dogecoin address: {addr}", "DOGE")
                    continue
                request = {"id": addr, "method": "blockchain.scripthash.get_balance", "params": [scripthash]}
                await ws.send(json.dumps(request))
                response = await ws.recv()
                data = json.loads(response)
                if "result" in data:
                    balance_dict[addr] = data["result"].get("confirmed", 0) / 1e8
                    debug_log(f"DOGE WSS balance for {addr}: {balance_dict[addr]}", "DOGE")
                elif "error" in data:
                    debug_log(f"DOGE WSS error for {addr}: {data['error']}", "DOGE")
    except Exception as e:
        debug_log(f"WebSocket error retrieving DOGE balances: {e}", "DOGE")
    return balance_dict

def bulk_doge_balance_scan(addresses):
    return asyncio.run(get_doge_balances_wss(addresses))

def bulk_rpc_balance_scan(coin, addresses):
    connection = get_rpc_connection(coin)
    if not connection:
        debug_log(f"No RPC connection for {coin}; falling back to API", coin)
        return {addr: None for addr in addresses}

    try:
        connection.getblockchaininfo()
        debug_log(f"RPC connection for {coin} is healthy", coin)
    except Exception as e:
        debug_log(f"RPC health check failed for {coin}: {e}", coin)
        return {addr: None for addr in addresses}

    desc_list = [{"desc": f"addr({addr})"} for addr in addresses]
    balance_dict = {addr: 0.0 for addr in addresses}
    max_retries = 5

    for attempt in range(max_retries):
        try:
            debug_log(f"Sending scantxoutset 'start' for {len(addresses)} addresses: {desc_list[:5]}...", coin)
            scan_result = connection.scantxoutset("start", desc_list)
            debug_log(f"Received scantxoutset response: success={scan_result.get('success')}, unspents={len(scan_result.get('unspents', []))}", coin)
            if DEBUG_LOGGING:
                debug_log(f"Full scantxoutset result: {json.dumps(scan_result, default=decimal_to_serializable, indent=2)}", coin)
            if scan_result.get("success"):
                for utxo in scan_result.get("unspents", []):
                    addr = utxo.get("desc", "").split("#")[0].replace("addr(", "").replace(")", "")
                    if addr in balance_dict:
                        amount = float(utxo.get("amount", 0.0))
                        balance_dict[addr] += amount
                        debug_log(f"Found UTXO for {addr}: {amount} {coin}", coin)
                debug_log(f"Completed scantxoutset scan for {coin}", coin)
                return balance_dict
            else:
                debug_log(f"Scan failed: {scan_result}", coin)
        except Exception as e:
            if "Scan already in progress" in str(e):
                debug_log(f"Scan in progress, retrying ({attempt+1}/{max_retries})", coin)
                try:
                    connection.scantxoutset("abort", {})
                    debug_log("Aborted previous scan", coin)
                except Exception as abort_e:
                    debug_log(f"Failed to abort scan: {abort_e}", coin)
                time.sleep(1)
            else:
                debug_log(f"RPC error on attempt {attempt+1}/{max_retries}: {str(e)}", coin)
                if attempt == max_retries - 1:
                    debug_log(f" personally think that Max retries reached for {coin}; falling back to API", coin)
                    return {addr: None for addr in addresses}
        time.sleep(1)
    debug_log(f"Max retries reached for {coin}; falling back to API", coin)
    return {addr: None for addr in addresses}

def get_balance_api(coin, address):
    coin_info = COINS[coin]
    api_url = coin_info["fallback_api_url"]
    if not api_url:
        debug_log(f"No API URL for {coin}", coin)
        return 0.0
    url = f"{api_url}?q=addressbalance&a={address}&key={API_KEY}"
    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        balance = float(resp.text.strip())
        debug_log(f"API balance for {address}: {balance} {coin}", coin)
        return balance
    except Exception as e:
        debug_log(f"API error for {address}: {e}", coin)
        return 0.0

# -------------------------------
# Compute Last Moved Times
# -------------------------------
def compute_last_moved_times(coin, addresses_with_balance):
    connection = get_rpc_connection(coin)
    if not connection:
        return {a: "N/A" for a in addresses_with_balance}
    unspent_dict = bulk_rpc_unspent_scan(coin, addresses_with_balance)
    all_txids = set()
    addr_tx_map = {}
    for addr in addresses_with_balance:
        addr_tx_map[addr] = []
        for u in unspent_dict.get(addr, []):
            txid = u.get("txid")
            if txid:
                all_txids.add(txid)
                addr_tx_map[addr].append(txid)

    tx_cache = {}
    now_ts = int(time.time())
    for txid in all_txids:
        try:
            tx = connection.getrawtransaction(txid, True)
            tx_cache[txid] = tx
            debug_log(f"Fetched TX {txid}: {json.dumps(tx, default=decimal_to_serializable, indent=2)}", coin)
            time.sleep(0.1)
        except Exception as e:
            debug_log(f"Error retrieving TX {txid}: {e}", coin)
            tx_cache[txid] = None

    last_moved_dict = {}
    for addr in addresses_with_balance:
        max_blocktime = 0
        for txid in addr_tx_map[addr]:
            tx_data = tx_cache.get(txid)
            if not tx_data:
                continue
            tx_time = tx_data.get("blocktime", tx_data.get("time", 0))
            if tx_time == 0 and "blockhash" in tx_data:
                try:
                    blk_info = connection.getblock(tx_data["blockhash"])
                    tx_time = blk_info.get("time", 0)
                    debug_log(f"Fetched block time for {tx_data['blockhash']}: {tx_time}", coin)
                except:
                    tx_time = 0
            if tx_time > max_blocktime:
                max_blocktime = tx_time
        last_moved_dict[addr] = format_elapsed_time(now_ts - max_blocktime) if max_blocktime > 0 else "N/A"
    return last_moved_dict

def bulk_rpc_unspent_scan(coin, addresses):
    connection = get_rpc_connection(coin)
    if not connection:
        return {addr: [] for addr in addresses}
    desc_list = [{"desc": f"addr({addr})"} for addr in addresses]
    unspent_dict = {addr: [] for addr in addresses}
    max_retries = 5
    for attempt in range(max_retries):
        try:
            debug_log(f"Sending scantxoutset for unspents: {desc_list[:5]}...", coin)
            scan_result = connection.scantxoutset("start", desc_list)
            debug_log(f"Unspent scan result: {json.dumps(scan_result, default=decimal_to_serializable, indent=2)}", coin)
            if scan_result.get("success"):
                for utxo in scan_result.get("unspents", []):
                    addr = utxo.get("desc", "").split("#")[0].replace("addr(", "").replace(")", "")
                    if addr in unspent_dict:
                        unspent_dict[addr].append(utxo)
                return unspent_dict
        except Exception as e:
            debug_log(f"Unspent scan error ({attempt+1}/{max_retries}): {e}", coin)
            if "Scan already in progress" in str(e):
                try:
                    connection.scantxoutset("abort", {})
                except:
                    pass
                time.sleep(1)
            else:
                return unspent_dict
    debug_log(f"Max retries reached for unspent scan", coin)
    return unspent_dict

# -------------------------------
# Derivation Scenarios
# -------------------------------
def derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=0, count=10):
    print(f"\n=== Breadwallet-like Derivation: m/0H/{chain}/index ===")

    def hmac_sha512(key, data):
        return hmac.new(key, data, hashlib.sha512).digest()

    def custom_bip32_master(seed_bytes):
        seed_key = b"DigiByte seed" if coin_config["curve"] == "secp256k1" and coin_config.get("coingecko_id") == "digibyte" else coin_config["seed_key"]
        I = hmac_sha512(seed_key, seed_bytes)
        return I[:32], I[32:]

    def private_key_to_public_key(private_key):
        sk = Secp256k1PrivateKey.FromBytes(private_key)
        return sk.PublicKey().RawCompressed().ToBytes()

    def ckd_priv(k_parent, c_parent, i):
        hard = (i & 0x80000000) != 0
        if hard:
            data = b'\x00' + k_parent + i.to_bytes(4, 'big')
        else:
            data = private_key_to_public_key(k_parent) + i.to_bytes(4, 'big')
        I = hmac_sha512(c_parent, data)
        IL, IR = I[:32], I[32:]
        N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
        ki_num = (int.from_bytes(IL, 'big') + int.from_bytes(k_parent, 'big')) % N
        if ki_num == 0:
            return None, None
        return ki_num.to_bytes(32, 'big'), IR

    # Derive master key
    master_secret, master_chain = custom_bip32_master(seed_bytes)
    zeroH = 0x80000000

    # Derive m/0'
    k_0H, c_0H = ckd_priv(master_secret, master_chain, zeroH)
    if k_0H is None:
        debug_log(f"Error deriving m/0H key for chain {chain}", coin_config["coingecko_id"] or coin_config["rpc_wallet"])
        return []

    # Derive m/0H/chain
    k_chain, c_chain = ckd_priv(k_0H, c_0H, chain)
    if k_chain is None:
        debug_log(f"Error deriving m/0H/{chain} key", coin_config["coingecko_id"] or coin_config["rpc_wallet"])
        return []

    # Derive addresses
    derived = []
    for i in range(count):
        k_i, c_i = ckd_priv(k_chain, c_chain, i)
        if k_i is None:
            continue
        wif = encode_wif(k_i, coin_config["wif_prefix"])
        pub_comp = private_key_to_public_key(k_i)
        addr = P2PKHAddr.EncodeKey(pub_comp, net_ver=coin_config["p2pkh_prefix"])
        derived.append((f"m/0H/{chain}/{i}", addr, wif))

    return derived

def derive_standard_p2pkh(mnemonic, coin_config, path, count=10):
    print(f"\n=== Standard P2PKH Derivation: {path} ===")
    seed = Bip39SeedGenerator(mnemonic).Generate()
    try:
        bip32 = Bip32Slip10Secp256k1.FromSeed(seed)
        base_node = bip32.DerivePath(path)
    except Exception as e:
        print(f"Error deriving path {path}: {e}")
        return []
    results = []
    for i in range(count):
        try:
            child = base_node.DerivePath(str(i))
            priv_raw = child.PrivateKey().Raw().ToBytes()
            wif = encode_wif(priv_raw, coin_config["wif_prefix"])
            pub_comp = child.PublicKey().RawCompressed().ToBytes()
            addr = P2PKHAddr.EncodeKey(pub_comp, net_ver=coin_config["p2pkh_prefix"])
            results.append((f"{path}/{i}", addr, wif))
        except:
            pass
    return results

def derive_p2sh_segwit(mnemonic, coin_config, path, count=10):
    if not coin_config.get("supports_segwit", False):
        return []
    print(f"\n=== P2SH-SegWit Derivation: {path} ===")
    versions = coin_config.get("p2sh_versions", [])
    if not versions:
        print("No P2SH versions defined; skipping.")
        return []
    seed = Bip39SeedGenerator(mnemonic).Generate()
    try:
        bip32 = Bip32Slip10Secp256k1.FromSeed(seed)
        base_node = bip32.DerivePath(path)
    except Exception as e:
        print(f"Error deriving path {path}: {e}")
        return []
    derived = []
    for ver in versions:
        for i in range(count):
            try:
                child = base_node.DerivePath(str(i))
                priv_raw = child.PrivateKey().Raw().ToBytes()
                wif = encode_wif(priv_raw, coin_config["wif_prefix"])
                pub_comp = child.PublicKey().RawCompressed().ToBytes()
                h160 = hashlib.new('ripemd160', hashlib.sha256(pub_comp).digest()).digest()
                redeem_script = b'\x00\x14' + h160
                addr = encode_p2sh_address(redeem_script, ver)
                derived.append((f"{path}/{i} [p2sh_ver={ver.hex()}]", addr, wif))
            except:
                pass
    return derived

def derive_bech32_segwit(mnemonic, coin_config, path, count=10):
    if not coin_config.get("supports_segwit", False):
        return []
    print(f"\n=== Bech32 Derivation: {path} ===")
    seed = Bip39SeedGenerator(mnemonic).Generate()
    try:
        bip32 = Bip32Slip10Secp256k1.FromSeed(seed)
        base_node = bip32.DerivePath(path)
    except Exception as e:
        print(f"Error deriving path {path}: {e}")
        return []
    derived = []
    for i in range(count):
        try:
            child = base_node.DerivePath(str(i))
            priv_raw = child.PrivateKey().Raw().ToBytes()
            wif = encode_wif(priv_raw, coin_config["wif_prefix"])
            pub_comp = child.PublicKey().RawCompressed().ToBytes()
            addr = P2WPKHAddr.EncodeKey(pub_comp, hrp=coin_config["bech32_hrp"])
            derived.append((f"{path}/{i}", addr, wif))
        except:
            pass
    return derived

def derive_bech32m(mnemonic, coin_config, path, count=10):
    if not coin_config.get("supports_taproot", False):
        return []
    print(f"\n=== BIP86 (Bech32m) Derivation: {path} ===")
    seed = Bip39SeedGenerator(mnemonic).Generate()
    try:
        bip32 = Bip32Slip10Secp256k1.FromSeed(seed)
        base_node = bip32.DerivePath(path)
    except Exception as e:
        print(f"Error deriving path {path}: {e}")
        return []
    derived = []
    for i in range(count):
        try:
            child = base_node.DerivePath(str(i))
            priv_raw = child.PrivateKey().Raw().ToBytes()
            wif = encode_wif(priv_raw, coin_config["wif_prefix"])
            pub_comp = child.PublicKey().RawCompressed().ToBytes()
            addr = P2TRAddr.EncodeKey(pub_comp, hrp=coin_config["bech32_hrp"])
            derived.append((f"{path}/{i}", addr, wif))
        except:
            pass
    return derived

def derive_legacy(mnemonic, coin_config, base_path="m/0'", branches=[0,1], count=10):
    print(f"\n=== Legacy Derivation: {base_path}/chain/index ===")
    seed = Bip39SeedGenerator(mnemonic).Generate()
    try:
        bip32 = Bip32Slip10Secp256k1.FromSeed(seed)
    except Exception as e:
        print(f"Error initializing Bip32: {e}")
        return []
    results = []
    for chain in branches:
        path = f"{base_path}/{chain}"
        try:
            base_node = bip32.DerivePath(path)
            for i in range(count):
                child = base_node.DerivePath(str(i))
                priv_raw = child.PrivateKey().Raw().ToBytes()
                wif = encode_wif(priv_raw, coin_config["wif_prefix"])
                pub_comp = child.PublicKey().RawCompressed().ToBytes()
                addr = P2PKHAddr.EncodeKey(pub_comp, net_ver=coin_config["p2pkh_prefix"])
                results.append((f"{path}/{i}", addr, wif))
        except Exception as e:
            print(f"Error deriving addresses for {path}: {e}")
    return results

def derive_custom_flutter(mnemonic, coin_config, wallet_count=3, count=10):
    print(f"\n=== Custom Flutter Derivation: m/{walletIndex}'/{addressIndex}/0 ===")
    seed = Bip39SeedGenerator(mnemonic).Generate()
    try:
        bip32 = Bip32Slip10Secp256k1.FromSeed(seed)
    except Exception as e:
        print(f"Error: {e}")
        return []
    derived = []
    for wallet_index in range(wallet_count):
        base_path = f"m/{wallet_index}'"
        for address_index in range(count):
            path_str = f"{base_path}/{address_index}/0"
            try:
                child = bip32.DerivePath(path_str)
                priv_raw = child.PrivateKey().Raw().ToBytes()
                wif = encode_wif(priv_raw, coin_config["wif_prefix"])
                pub_comp = child.PublicKey().RawCompressed().ToBytes()
                addr = P2PKHAddr.EncodeKey(pub_comp, net_ver=coin_config["p2pkh_prefix"])
                derived.append((path_str, addr, wif))
            except:
                pass
    return derived

def encode_wif(priv_key_bytes, prefix):
    extended = prefix + priv_key_bytes + b'\x01'
    checksum = hashlib.sha256(hashlib.sha256(extended).digest()).digest()[:4]
    return base58.b58encode(extended + checksum).decode('ascii')

def encode_p2sh_address(redeem_script, version):
    h160 = hashlib.new('ripemd160', hashlib.sha256(redeem_script).digest()).digest()
    extended = version + h160
    checksum = hashlib.sha256(hashlib.sha256(extended).digest()).digest()[:4]
    return base58.b58encode(extended + checksum).decode('ascii')

# -------------------------------
# Logging Results
# -----------------------
def log_seed_results_if_positive(coin, seed, positive_hits, total_new_coin_for_seed, coin_usd_price, time_for_this_seed_human, running_total_coin):
    if total_new_coin_for_seed <= 0:
        return
    timestamp = datetime.datetime.now().isoformat()
    log_file = get_log_file(coin)
    json_file = get_json_file(coin)
    usd_for_seed = total_new_coin_for_seed * coin_usd_price
    running_total_usd = running_total_coin * coin_usd_price

    with open(log_file, "a") as f:
        f.write("\n" + "-" * 60 + "\n")
        f.write(f"Seed: {seed}\n")
        f.write(f"Coin: {coin}\n")
        f.write(f"Date: {timestamp}\n")
        f.write(f"Coin Price (USD): ${coin_usd_price:,.4f}\n")
        f.write("Positive Hits:\n")
        for scenario, path_addr, addr, wif, bal, last_moved in positive_hits:
            bal_usd = bal * coin_usd_price
            f.write(
                f"[{scenario}] {path_addr} | {addr} | {wif} | "
                f"{bal:,.8f} {coin} (~${bal_usd:,.2f} USD) | Last moved: {last_moved}\n"
            )
        f.write(f"Total {coin} found: {total_new_coin_for_seed:,.8f} {coin}\n")
        f.write(f"Time to process: {time_for_this_seed_human}\n")
        f.write(f"Approx. USD value: ${usd_for_seed:,.2f}\n")
        f.write(f"Running Total: {running_total_coin:,.8f} {coin} (~${running_total_usd:,.2f} USD)\n")
        f.write("-" * 60 + "\n")

    seed_record = {
        "seed": seed,
        "coin": coin,
        "date": timestamp,
        "coin_usd_price_at_scan": float(f"{coin_usd_price:.4f}"),
        "positive_hits": [
            {
                "scenario": scenario,
                "derivation_path": path_addr,
                "address": addr,
                "wif": wif,
                "balance": float(f"{bal:.8f}"),
                "usd_estimate": float(f"{bal * coin_usd_price:.2f}"),
                "last_moved": last_moved
            } for scenario, path_addr, addr, wif, bal, last_moved in positive_hits
        ],
        "total_coin_for_this_seed": float(f"{total_new_coin_for_seed:.8f}"),
        "time_for_this_seed": time_for_this_seed_human,
        "approx_usd_for_this_seed": float(f"{usd_for_seed:.2f}"),
        "running_total_coin": float(f"{running_total_coin:.8f}"),
        "running_total_usd": float(f"{running_total_usd:.2f}")
    }
    existing_data = []
    if os.path.exists(json_file):
        try:
            with open(json_file, "r") as jf:
                existing_data = json.load(jf)
            if not isinstance(existing_data, list):
                existing_data = []
        except:
            existing_data = []
    existing_data.append(seed_record)
    with open(json_file, "w") as jf:
        json.dump(existing_data, jf, indent=2)

def log_final_summary(coin, total_balance, coin_usd_price, total_seeds, total_time_sec):
    total_usd = total_balance * coin_usd_price
    with open(get_log_file(coin), "a") as f:
        f.write("\n" + "=" * 60 + "\n")
        f.write(f"FINAL SUMMARY for {coin}\n")
        f.write(f"Total seeds processed: {total_seeds}\n")
        f.write(f"Total {coin} found: {total_balance:,.8f} {coin}\n")
        f.write(f"Approx. USD value: ${total_usd:,.2f}\n")
        f.write(f"Total time: {format_seconds_dhms(total_time_sec)}\n")
        f.write("=" * 60 + "\n")
    print(f"Final summary logged for {coin}.")

# -------------------------------
# Batch Processing
# -------------------------------
def process_seeds_batch(seeds, address_count, coin, overall_start_time, seeds_already_done, total_seeds_for_coin, starting_balance):
    batch_start_time = time.time()
    coin_usd_price = fetch_usd_price_for_coin(coin)

    # Use the provided starting_balance (cumulative from log) directly
    grand_total_balance = starting_balance
    batch_seeds_processed = 0

    print(f"\n{'='*60}")
    print(f"Processing {len(seeds)} seeds for {coin} in this batch.")
    print(f"{'='*60}")

    discovered_addresses, discovered_wifs = parse_previously_discovered_addresses(coin)

    for seed in seeds:
        seed_start_time = time.time()
        print(f"\nProcessing seed: {seed[:25]} ...")
        coin_config = COINS[coin]

        seed_bytes = Bip39SeedGenerator(seed).Generate()
        derivation_scenarios = [
            ("Breadwallet-like m/0H/0", lambda: derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=0, count=address_count)),
            ("Breadwallet-like m/0H/1", lambda: derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=1, count=address_count)),
            ("Breadwallet-like m/0H/2", lambda: derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=2, count=address_count)),
            ("Breadwallet-like m/0H/3", lambda: derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=3, count=address_count)),
            ("Breadwallet-like m/0H/4", lambda: derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=4, count=address_count)),
            ("Breadwallet-like m/0H/5", lambda: derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=5, count=address_count)),
            ("Breadwallet-like m/0H/6", lambda: derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=6, count=address_count)),
            ("Breadwallet-like m/0H/7", lambda: derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=7, count=address_count)),
            ("Breadwallet-like m/0H/8", lambda: derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=8, count=address_count)),
            ("Breadwallet-like m/0H/9", lambda: derive_breadwallet_keys_custom(seed_bytes, coin_config, chain=9, count=address_count)),
            ("Standard BIP44 (ext)", lambda: derive_standard_p2pkh(seed, coin_config, f"m/44'/{coin_config['bip44_coin']}'/0'/0", count=address_count)),
            ("Standard BIP44 (chg)", lambda: derive_standard_p2pkh(seed, coin_config, f"m/44'/{coin_config['bip44_coin']}'/0'/1", count=address_count)),
            ("BIP44 Account 1 (ext)", lambda: derive_standard_p2pkh(seed, coin_config, f"m/44'/{coin_config['bip44_coin']}'/1'/0", count=address_count)),
            ("BIP44 Account 1 (chg)", lambda: derive_standard_p2pkh(seed, coin_config, f"m/44'/{coin_config['bip44_coin']}'/1'/1", count=address_count)),
            ("Legacy m/0'", lambda: derive_legacy(seed, coin_config, "m/0'", [0,1], count=address_count)),
            ("Custom Flutter m/{w}'/{a}/0", lambda: derive_custom_flutter(seed, coin_config, wallet_count=3, count=address_count)),
            ("Simple Legacy SPV m/i", lambda: derive_standard_p2pkh(seed, coin_config, "m", count=address_count)),
            ("SPV Single-Chain m/0/i", lambda: derive_standard_p2pkh(seed, coin_config, "m/0", count=address_count)),
            ("Pre-BIP44 m/1'/i", lambda: derive_standard_p2pkh(seed, coin_config, "m/1'", count=address_count)),
            ("Pre-BIP44 m/2'/i", lambda: derive_standard_p2pkh(seed, coin_config, "m/2'", count=address_count)),
            ("Breadwallet Flat m/0'/i", lambda: derive_standard_p2pkh(seed, coin_config, "m/0'", count=address_count)),
        ]
        if coin_config.get("supports_segwit", False):
            derivation_scenarios.extend([
                ("BIP84 (Bech32 ext)", lambda: derive_bech32_segwit(seed, coin_config, f"m/84'/{coin_config['bip44_coin']}'/0'/0", count=address_count)),
                ("BIP84 (Bech32 int)", lambda: derive_bech32_segwit(seed, coin_config, f"m/84'/{coin_config['bip44_coin']}'/0'/1", count=address_count)),
                ("BIP49 (P2SH ext)", lambda: derive_p2sh_segwit(seed, coin_config, f"m/49'/{coin_config['bip44_coin']}'/0'/0", count=address_count)),
                ("BIP49 (P2SH int)", lambda: derive_p2sh_segwit(seed, coin_config, f"m/49'/{coin_config['bip44_coin']}'/0'/1", count=address_count)),
                ("BIP84 Account 1 (ext)", lambda: derive_bech32_segwit(seed, coin_config, f"m/84'/{coin_config['bip44_coin']}'/1'/0", count=address_count)),
                ("BIP84 Account 1 (int)", lambda: derive_bech32_segwit(seed, coin_config, f"m/84'/{coin_config['bip44_coin']}'/1'/1", count=address_count)),
            ])
        if coin_config.get("supports_taproot", False):
            derivation_scenarios.append(
                ("BIP86 (Bech32m)", lambda: derive_bech32m(seed, coin_config, f"m/86'/{coin_config['bip44_coin']}'/0'/0", count=address_count))
            )

        all_addresses = []
        for scenario_name, func in derivation_scenarios:
            print(f"Running scenario: {scenario_name}")
            try:
                results = func()
                print(f"Derived {len(results)} addresses for scenario: {scenario_name}")
                for (path_str, addr, wif) in results:
                    if SHOW_DERIVATIONS:
                        print(f" => {scenario_name}: {path_str} | {addr} | {wif}")
                    all_addresses.append((scenario_name, path_str, addr, wif))
            except Exception as e:
                debug_log(f"Error in scenario '{scenario_name}': {e}", coin)

        if not all_addresses:
            log_checkpoint(seed, coin)
            batch_seeds_processed += 1
            continue

        unique_addrs = [t[2] for t in all_addresses]
        balance_map = {}
        if coin == "DOGE" and coin_config.get("use_wss", False):
            balance_map = bulk_doge_balance_scan(unique_addrs)
        elif coin_config.get("use_rpc", True):
            rpc_balances = bulk_rpc_balance_scan(coin, unique_addrs)
            for (scenario, path_str, addr, wif) in all_addresses:
                bal = rpc_balances.get(addr)
                if bal is None:
                    bal = get_balance_api(coin, addr)
                balance_map[addr] = bal if bal is not None else 0.0
        else:
            for (scenario, path_str, addr, wif) in all_addresses:
                bal = get_balance_api(coin, addr)
                balance_map[addr] = bal

        positive_hits = []
        total_new_balance_this_seed = 0.0
        for scenario_name, path_str, addr, wif in all_addresses:
            bal = balance_map.get(addr, 0.0) or 0.0
            if SHOW_ADDRESS_BALANCES or bal > 0:
                print(f"[{scenario_name}] {path_str} | {addr} | {wif} => Balance: {bal:,.8f} {coin}")
            if bal > 0:
                last_moved_str = "N/A"
                if coin_config.get("use_rpc", True) and coin != "DOGE":
                    last_moved_str = compute_last_moved_times(coin, [addr]).get(addr, "N/A")
                positive_hits.append((scenario_name, path_str, addr, wif, bal, last_moved_str))
                if addr not in discovered_addresses and wif not in discovered_wifs:
                    total_new_balance_this_seed += bal
                    discovered_addresses.add(addr)
                    discovered_wifs.add(wif)

        grand_total_balance += total_new_balance_this_seed
        seed_end_time = time.time()
        time_for_this_seed_human = format_seconds_dhms(seed_end_time - seed_start_time)

        log_seed_results_if_positive(
            coin=coin,
            seed=seed,
            positive_hits=positive_hits,
            total_new_coin_for_seed=total_new_balance_this_seed,
            coin_usd_price=coin_usd_price,
            time_for_this_seed_human=time_for_this_seed_human,
            running_total_coin=grand_total_balance
        )

        log_checkpoint(seed, coin)
        batch_seeds_processed += 1

        if total_new_balance_this_seed > 0:
            new_usd = total_new_balance_this_seed * coin_usd_price
            print(f"Seed {seed[:20]} => Net new {coin}: {total_new_balance_this_seed:,.8f} (~${new_usd:,.2f})")
            running_total_usd = grand_total_balance * coin_usd_price
            print(f"Running Total for {coin}: {grand_total_balance:,.8f} {coin} (~${running_total_usd:,.2f})")
        else:
            print(f"Seed {seed[:20]} => No *new* addresses or balance discovered.")

        seeds_done_so_far = seeds_already_done + batch_seeds_processed
        seeds_left = total_seeds_for_coin - seeds_done_so_far
        total_elapsed_for_coin_sec = seed_end_time - overall_start_time
        avg_time = total_elapsed_for_coin_sec / seeds_done_so_far if seeds_done_so_far else 0
        eta_sec = seeds_left * avg_time
        eta_str = format_seconds_dhms(eta_sec)
        elapsed_human = format_seconds_dhms(total_elapsed_for_coin_sec)
        print(f"Time for this seed: {time_for_this_seed_human}. "
              f"Total elapsed: {elapsed_human}. ETA: ~{eta_str}.")

    batch_end_time = time.time()
    print(f"\nBatch completed for {coin}. Seeds in this batch: {len(seeds)}.")
    print(f"Time spent in batch: {batch_end_time - batch_start_time:.2f}s.")
    total_usd_now = grand_total_balance * coin_usd_price
    print(f"Updated Running Total for {coin}: {grand_total_balance:,.8f} {coin} (~${total_usd_now:,.2f})")

    return grand_total_balance, batch_seeds_processed

def process_seed_for_coin(mnemonic, address_count, coin):
    cp = load_checkpoints(coin)
    if mnemonic in cp:
        print(f"Seed already processed for {coin}. Skipping.")
        return
    if not Bip39MnemonicValidator().IsValid(mnemonic):
        print("Invalid mnemonic. Please verify your words.")
        return

    overall_start = time.time()
    total_seeds_for_coin = 1
    seeds_already_done = 0
    starting_balance = get_running_total_from_log(coin)  # Start with historical total

    print(f"\n=== Scanning single seed for {coin} ===")
    updated_total, seeds_processed = process_seeds_batch(
        seeds=[mnemonic],
        address_count=address_count,
        coin=coin,
        overall_start_time=overall_start,
        seeds_already_done=seeds_already_done,
        total_seeds_for_coin=total_seeds_for_coin,
        starting_balance=starting_balance
    )
    final_time = time.time() - overall_start
    coin_usd_price = fetch_usd_price_for_coin(coin)
    log_final_summary(coin, updated_total, coin_usd_price, seeds_processed, final_time)

# ---------------------------
# Main CLI Flow
# ---------------------------
if __name__ == "__main__":
    dbg = input("Enable verbose (debug) logging? (y/n): ").strip().lower()
    if dbg == "y":
        DEBUG_LOGGING = True

    blockchain_info = input("Log blockchain info (requires debug logging)? (y/n): ").strip().lower()
    if blockchain_info == "y" and DEBUG_LOGGING:
        LOG_BLOCKCHAIN_INFO = True

    deriv = input("Show derived addresses (public + private keys)? (y/n): ").strip().lower()
    if deriv == "y":
        SHOW_DERIVATIONS = True

    bal = input("Show individual address balances? (y/n): ").strip().lower()
    if bal == "y":
        SHOW_ADDRESS_BALANCES = True

    print("Select coins to scan:")
    print("  1 - BTC")
    print("  2 - DOGE")
    print("  3 - LTC")
    print("  4 - DGB")
    print("  5 - SUM")
    print("  6 - All coins")
    choice_coins = input("Enter choice (e.g., 1,2 or 6): ").strip()
    coin_map = {"1": "BTC", "2": "DOGE", "3": "LTC", "4": "DGB", "5": "SUM"}
    if choice_coins == "6":
        coins_to_scan = list(COINS.keys())
    else:
        coins_to_scan = [coin_map[x.strip()] for x in choice_coins.split(",") if x.strip() in coin_map]

    if not coins_to_scan:
        print("No valid coins selected. Exiting.")
        exit(1)
    print(f"Selected coins: {coins_to_scan}")

    while True:
        single_or_multi = input("Press '1' for a single seed, '2' for multiple from a file: ").strip()
        if single_or_multi in ['1', '2']:
            break
        print("Invalid choice. Please enter '1' or '2'.")

    try:
        address_count = int(input("How many addresses to derive per path? e.g., 10: ").strip())
    except:
        address_count = 10

    if single_or_multi == '1':
        mnemonic = input("Enter your BIP39 seed phrase (up to 24 words): ").strip()
        for c in coins_to_scan:
            process_seed_for_coin(mnemonic, address_count, c)
    elif single_or_multi == '2':
        default_file = "/home/electrumbtc1/master_Seed_Scanner/allwords.txt"
        user_inp = input(f"Default file is {default_file}. Press Enter or type new path: ").strip()
        seed_file = user_inp if user_inp else default_file
        if not os.path.exists(seed_file):
            print(f"File not found: {seed_file}")
            exit(1)

        with open(seed_file, "r") as f:
            all_seeds = [line.strip() for line in f if line.strip()]

        for coin in coins_to_scan:
            cp = load_checkpoints(coin)
            seeds_to_process = [s for s in all_seeds if s not in cp]
            if not seeds_to_process:
                print(f"No new seeds for {coin}. Already up-to-date.")
                continue

            try:
                batch_size = int(input(f"Enter seeds per batch for {coin} (1-5 recommended): ").strip())
            except:
                batch_size = 5

            total_for_coin = get_running_total_from_log(coin)  # Start with historical total
            start_time_for_coin = time.time()
            seeds_done = 0
            total_needed = len(seeds_to_process)
            print(f"\n--- Starting scanning for {coin} with {total_needed} seeds ---")
            for i in range(0, total_needed, batch_size):
                batch = seeds_to_process[i:i + batch_size]
                print(f"\n--- Batch {i // batch_size + 1} ({len(batch)} seeds) for {coin} ---")
                updated_balance, seeds_scanned = process_seeds_batch(
                    batch,
                    address_count,
                    coin,
                    overall_start_time=start_time_for_coin,
                    seeds_already_done=seeds_done,
                    total_seeds_for_coin=total_needed,
                    starting_balance=total_for_coin
                )
                total_for_coin = updated_balance
                seeds_done += seeds_scanned

            final_time = time.time() - start_time_for_coin
            coin_usd_price = fetch_usd_price_for_coin(coin)
            log_final_summary(coin, total_for_coin, coin_usd_price, seeds_done, final_time)
            print(f"Completed scanning for {coin}.\n")

    print("Done. Thank you.")
