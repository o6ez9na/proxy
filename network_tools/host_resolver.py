import socket
from ipwhois import IPWhois
import pandas as pd
import sys
import ipaddress

if len(sys.argv) < 2:
    print("Использование: python resolve_ip.py path/to/domains.txt")
    sys.exit(1)

file_path = sys.argv[1]

with open(file_path, "r") as f:
    domains = [line.strip() for line in f if line.strip()]

results = []

for domain in domains:
    try:
        try:
            ipaddress.ip_address(domain)
            ip = domain
        except ValueError:
            ip = socket.gethostbyname(domain)

        try:
            obj = IPWhois(ip)
            res = obj.lookup_rdap()
            provider = (
                res.get("network", {}).get("name")
                or res.get("network", {}).get("org")
                or "Unknown"
            )
        except Exception:
            provider = "WHOIS ERROR"

        print(f"{domain} - {ip} - {provider}")
        results.append([domain, ip, provider])

    except Exception as e:
        print(f"{domain} - ERROR ({e})")
        results.append([domain, "ERROR", str(e)])

# сохраняем в Excel
df = pd.DataFrame(results, columns=["Domain", "IP", "Provider"])
output_file = "domains_resolved.xlsx"
df.to_excel(output_file, index=False)
print(f"\nРезультат сохранен в {output_file}")
