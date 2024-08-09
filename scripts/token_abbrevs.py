import sys
import string
import glob

tokens = {"Highlight"}
abbrevs = {"Highlight": "hl"}

def abbr(line):
    return "".join(c for c in line if c in string.ascii_uppercase).lower()

def check_abbrevs():
    if len(abbrevs) != len(tokens):
        print("Warning: Abbreviations are not unique")
        print(len(abbrevs), len(tokens))
        sys.exit(1)

# Processes all files in lexers looking for token names
for fname in glob.glob("lexers/*.xml"):
    with open(fname) as f:
        for line in f:
            if "<token" not in line:
                continue
            line = line.strip()
            line = line.split('<token ',1)[-1]
            line = line.split('"')[1]
            abbrevs[line] = abbr(line)
            tokens.add(line)
            check_abbrevs()

# Processes all files in styles looking for token names too
for fname in glob.glob("styles/*.xml"):
    with open(fname) as f:
        for line in f:
            if "<entry" not in line:
                continue
            line = line.strip()
            line = line.split('type=',1)[-1]
            line = line.split('"')[1]
            abbrevs[line] = abbr(line)
            tokens.add(line)
            check_abbrevs()

print("Abbreviations = {")
for k, v in abbrevs.items():
    print(f'    "{k}" => "{v}",')
print("}")
