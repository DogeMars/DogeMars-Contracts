import csv
import json
import sys

def main(filepath, cnt):
    with open(filepath) as file:
        reader = csv.DictReader(file)
        addrs = [addr for addr in reader]
        addrs.sort(key=lambda x: float(x['Balance']), reverse=True)
        addrs = map(lambda x: x['HolderAddress'], addrs[:cnt])
        print json.dumps(addrs)

if __name__ == '__main__':
    main(sys.argv[1], 100)
