#!/usr/bin/python

import sys;
import html.entities
import unicodedata

def printOne(lineNo, ln):
    fields = ln.split('\n')[0].split('|')
    print("<dict>")
    print("    <key>alias</key><string>%s</string>" % (entityify(fields[0])))
    print("    <key>ID</key><string>%s</string>" % (fields[1]))
    print("</dict>")

def handlefile(filename):
    n = 0
    with open(filename) as f:
        for ln in f:
            n = n + 1
            printOne(n, ln)

def printprologue():
    print("""
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
""")

def printepilogue():
    print("""
</array>
</plist>
""")

def entityify(s):
    s1 = ""
    for c in s:
        if (ord(c) in html.entities.codepoint2name):
            s1 = s1 + '&' + html.entities.codepoint2name[ord(c)] + ';'
        else:
            s1 = s1 + c
    return s1

if __name__ == '__main__':
    totalitems = 0
    printprologue()
    if len(sys.argv) < 2:
        inputfiles = ["/Users/michael/Projects/LiveTransit-Seattle/timepoint-aliases.txt"]
    else:
        inputfiles = sys.argv[1:]
    for f in inputfiles:
        handlefile(f)
    printepilogue()
