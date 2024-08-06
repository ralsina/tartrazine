import sys
import string

# Run it as grep token lexers/* | python scripts/token_abbrevs.py


def abbr(line):
    return "".join(c for c in line if c in string.ascii_uppercase).lower()

abbrevs = {}
tokens = set([])
for line in sys.stdin:
    if "<token" not in line:
        continue
    line = line.strip()
    line = line.split('<token ',1)[-1]
    line = line.split('"')[1]
    abbrevs[line] = abbr(line)
    tokens.add(line)

print("Abbreviations: {")
for k, v in abbrevs.items():
    print(f'    "{k}" => "{v}",')
print("}")
