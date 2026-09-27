# This script parses the metadata of all the lexers and generates
# a datafile with all the information so we don't have to instantiate
# all the lexers to get the information.

import glob
from collections import defaultdict

lexer_by_name = {}
lexer_by_mimetype = defaultdict(set)
lexer_by_filename = defaultdict(set)


# Sorted so the generated file is deterministic: when two lexers claim
# the same mimetype the first one in name order wins (c over holyc,
# plaintext over systemd, fortran over fortranfixed)
for fname in sorted(glob.glob("lexers/*.xml")):
    aliases = set([])
    mimetypes = set([])
    filenames = set([])
    print(fname)
    with open(fname) as f:
        lexer_name = fname.split("/")[-1].split(".")[0]
        for line in f:
            if "</config" in line:
                break
            if "<filename>" in line:
                filenames.add(line.split(">")[1].split("<")[0].lower())
            if "<mime_type>" in line:
                mimetypes.add(line.split(">")[1].split("<")[0].lower())
            if "<alias>" in line:
                aliases.add(line.split(">")[1].split("<")[0].lower())
            if "<name>" in line:
                aliases.add(line.split(">")[1].split("<")[0].lower())
    for alias in aliases:
        owner = lexer_by_name.get(alias)
        if owner is not None and owner != lexer_name:
            # Two lexers claim the same alias (eg. "hcl" is both the
            # HCL lexer's name and a Terraform alias). Like chroma,
            # a lexer's own name wins over another lexer's alias
            if alias == owner or alias == lexer_name:
                winner = owner if alias == owner else lexer_name
                print(f"alias {alias} claimed by {owner} and {lexer_name}, keeping {winner}")
                lexer_by_name[alias] = winner
                continue
            raise Exception(f"Alias {alias} already in use by {owner}")
        lexer_by_name[alias] = lexer_name
    for mimetype in mimetypes:
        if mimetype in lexer_by_mimetype:
            print(f"mimetype {mimetype} claimed by {lexer_by_mimetype[mimetype]} and {lexer_name}, keeping {lexer_by_mimetype[mimetype]}")
            continue
        lexer_by_mimetype[mimetype] = lexer_name
    for filename in filenames:
        lexer_by_filename[filename].add(lexer_name)

# text/plain must always mean the plaintext fallback, whatever other
# lexers (nu, systemd) also claim it
lexer_by_mimetype["text/plain"] = "plaintext"

with open("src/constants/lexers.cr", "w") as f:
    # Crystal doesn't come from a xml file
    lexer_by_name["crystal"] = "crystal"
    lexer_by_name["cr"] = "crystal"
    lexer_by_filename["*.cr"] = ["crystal"]
    lexer_by_mimetype["text/x-crystal"] = "crystal"

    f.write("module Tartrazine\n")
    f.write("  LEXERS_BY_NAME = {\n")
    for k in sorted(lexer_by_name.keys()):
        v = lexer_by_name[k]
        f.write(f'"{k}" => "{v}", \n')
    f.write("}\n")
    f.write("  LEXERS_BY_MIMETYPE = {\n")
    for k in sorted(lexer_by_mimetype.keys()):
        v = lexer_by_mimetype[k]
        f.write(f'"{k}" => "{v}", \n')
    f.write("}\n")
    f.write("  LEXERS_BY_FILENAME = {\n")
    for k in sorted(lexer_by_filename.keys()):
        v = lexer_by_filename[k]
        f.write(f'"{k}" => {str(sorted(list(v))).replace("'", "\"")}, \n')
    f.write("}\n")
    f.write("end\n")
