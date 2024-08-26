# This script parses the metadata of all the lexers and generates
# a datafile with all the information so we don't have to instantiate
# all the lexers to get the information.

import glob
from collections import defaultdict

lexer_by_name = {}
lexer_by_mimetype = defaultdict(set)
lexer_by_filename = defaultdict(set)


for fname in glob.glob("lexers/*.xml"):
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
        if alias in lexer_by_name and alias != lexer_by_name[alias]:
            raise Exception(f"Alias {alias} already in use by {lexer_by_name[alias]}")
        lexer_by_name[alias] = lexer_name
    for mimetype in mimetypes:
        lexer_by_mimetype[mimetype] = lexer_name
    for filename in filenames:
        lexer_by_filename[filename].add(lexer_name)

with open("src/constants/lexers.cr", "w") as f:
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
