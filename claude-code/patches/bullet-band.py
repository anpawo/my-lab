#!/usr/bin/env python3
"""Patch the Claude Code binary so the display matches the i-have-adhd answer shape:
- the bullet column carries the same pastel band as the first/last "⟶" lines, and the
  completed-message render paints those lines itself (so a resumed transcript keeps them);
- the footer mode line is not built (the statusline shows the mode), two blank rows stay
  under the prompt, and the hints that replace the footer keep that height;
- a mode change is written to ~/.claude/sessions/<pid>.mode for the statusline.
Pairs with hooks/adhd-colors.sh and statusline.sh.

Bun standalone layout (2.1.28x): [chunks: source + JSC bytecode][module table, 52-byte records]
[Offsets 32 B]["\\n---- Bun! ----\\n"]. Sites are found by their stable string literals with the
minified names captured, since those names move on every release. Each chunk is rewritten at
the same length (bytes reclaimed from, or padded into, its licence comment) and its bytecode
pointer zeroed so Bun compiles the edited source. Then ad-hoc re-sign.

usage: bullet-band.py <binary> [--out <path>] [--check]   (in place by default, keeps <binary>.orig)
"""
import os, re, shutil, struct, subprocess, sys

GREEN, BLUE = b'#d6f5d6', b'#d6e6ff'
TRAILER = b'\n---- Bun! ----\n'
RS = 52
U = b'\\' + b'u27F6'  # the arrow, as a JS escape (kept ASCII on purpose)

def paint(v):
    # first and last "⟶" lines get the band in the completed-message render; a line the hook
    # already painted starts with ESC and is skipped by the [0]=="⟶" test
    return (b'((t,w,P=(l,c)=>c+l+"\\xa0".repeat(Math.max(0,w-l.length))+"\\x1b[0m")=>{let L=t.split("\\n"),i=L.length-1;'
            b'while(i>0&&!L[i].trim())i--;if(L[0][0]=="' + U + b'")L[0]=P(L[0],"\\x1b[48;2;214;245;214m");'
            b'if(i>0&&L[i][0]=="' + U + b'")L[i]=P(L[i],"\\x1b[48;2;214;230;255m");return L.join("\\n")})(' + v + b',(process.stdout.columns||80)-2)')

# (name, regex over the binary, replacement(match) -> bytes, expected match count, applied-marker regex)
PATCHES = [
    ('bullet column + bands on resume',
     rb'if\((\w+)\[(\d+)\]!==(\w+)\)(\w+)=\3&&e\((\w+),\{fromLeftEdge:!0,minWidth:2,children:e\((\w+),\{"aria-label":"claude:",color:"text",children:(\w+)\}\)\}\),\1\[\2\]=\3,\1\[(\d+)\]=\4;else \4=\1\[\8\];let (\w+);if\(\1\[(\d+)\]!==(\w+)\)\9=e\((\w+),\{flexDirection:"column",children:e\((\w+),\{capProseWidth:!0,children:\11\}\)\}\)',
     lambda m: (b'if(%s[%s]!==%s||%s[%s]!==%s)%s=%s&&e(%s,{fromLeftEdge:!0,minWidth:2,flexDirection:"column",justifyContent:"space-between",children:['
                b'e(%s,{"aria-label":"claude:",color:"text",backgroundColor:/^(?:\\x1b\\[[\\d;]*m)*' + U + b'/.test(%s)?"' + GREEN + b'":void 0,children:[%s," "]}),'
                b'/\\n(?:\\x1b\\[[\\d;]*m)*' + U + b'[^\\n]*\\s*$/.test(%s)?e(%s,{backgroundColor:"' + BLUE + b'",children:"  "}):null]}),%s[%s]=%s,%s[%s]=%s;else %s=%s[%s];'
                b'let %s;if(%s[%s]!==%s)%s=e(%s,{flexDirection:"column",children:e(%s,{capProseWidth:!0,children:%s})})') % (
                m[1], m[2], m[3], m[1], m[10], m[11], m[4], m[3], m[5],
                m[6], m[11], m[7],
                m[11], m[6], m[1], m[2], m[3], m[1], m[8], m[4], m[4], m[1], m[8],
                m[9], m[1], m[10], m[11], m[9], m[12], m[13], paint(m[11])),
     1, rb'justifyContent:"space-between",children:\[e\(\w+,\{"aria-label":"claude:"'),
    ('footer: two blank rows (compact)',
     rb'(if\(\w+&&(\w+)\)return e\(\w,\{)height:1(,overflow:"hidden",children:\2\}\);)',
     lambda m: m[1] + b'height:3' + m[3], 2, rb'if\(\w+&&(\w+)\)return e\(\w,\{height:3,overflow:"hidden",children:\1\}\);'),
    ('footer: two blank rows',
     rb'(return r\(\w,\{)height:1(,overflow:"hidden",children:\[(\w+),\3&&\()',
     lambda m: m[1] + b'height:3' + m[2], 2, rb'return r\(\w,\{height:3,overflow:"hidden",children:\[(\w+),\1&&\('),
    ('footer: no mode line',
     rb'(let \w+=)(\w+)(&&\w+\?e\(\w,\{flexShrink:0,children:e\(\w+,\{mode:\w+,)',
     lambda m: m[1] + b'!1' + m[3], 2, rb'let \w+=!1&&\w+\?e\(\w,\{flexShrink:0,children:e\(\w+,\{mode:'),
    ('footer: empty footer keeps two rows',
     rb'\)return \w+\?e\((\w),\{children:" "\}\):null',
     lambda m: b')return e(%s,{height:2,children:e(%s,{children:" "})})' % (BOX[0], m[1]), 2, rb'\)return e\(\w,\{height:2,children:e\(\w,\{children:" "\}\)\}\)'),
    ('footer: hints keep three rows (pasting)',
     rb'(\w+)=e\((\w),(\{dimColor:!0,children:"Pasting\\u2026"\}),"pasting-message"\)',
     lambda m: b'%s=e(%s,{height:3,children:e(%s,%s)},"pasting-message")' % (m[1], BOX[0], m[2], m[3]), 1, rb'height:3,children:e\(\w,\{dimColor:!0,children:"Pasting'),
    ('footer: hints keep three rows (expand paste)',
     rb'(\w+)=e\((\w),(\{dimColor:!0,children:"paste again to expand"\}),"expand-paste-hint"\)',
     lambda m: b'%s=e(%s,{height:3,children:e(%s,%s)},"expand-paste-hint")' % (m[1], BOX[0], m[2], m[3]), 1, rb'height:3,children:e\(\w,\{dimColor:!0,children:"paste again'),
    ('footer: hints keep three rows (exit)',
     rb'(\w+)=r\((\w),(\{dimColor:!0,children:\["Press ",\w+," again to"," ",\w+\]\}),"exit-message"\)',
     lambda m: b'%s=e(%s,{height:3,children:r(%s,%s)},"exit-message")' % (m[1], BOX[0], m[2], m[3]), 1, rb'height:3,children:r\(\w,\{dimColor:!0,children:\["Press "'),
    ('mode file for the statusline',
     rb'if\((\w)!==(\w)\)\{(let \w=\w+\(\1\),\w=\w+\(\2\);if\(\w!==\w\)\{let \w=\w+\(\{rule:"first-entry")',
     lambda m: b'if(%s!==%s){Bun.write(process.env.HOME+"/.claude/sessions/"+process.pid+".mode",%s).catch(()=>{});%s' % (m[1], m[2], m[2], m[3]), 1, rb'\.mode",\w\)\.catch\(\(\)=>\{\}\);let \w=\w+\(\w\),\w=\w+\(\w\);if\(\w!==\w\)\{let \w=\w+\(\{rule:"first-entry"'),
]
# the Box and Text names of the footer chunk, learnt from two of its sites before any edit
BOX, TEXT = [None], [None]

def main():
    src = sys.argv[1]
    out = sys.argv[sys.argv.index('--out') + 1] if '--out' in sys.argv else src
    b = bytearray(open(src, 'rb').read())
    todo = [p for p in PATCHES if not re.search(p[4], b)]
    if '--check' in sys.argv:
        print('unpatched' if todo else 'patched'); return 1 if todo else 0
    if not todo:
        print('already patched'); return 0
    # names are reused across chunks: learn them next to the footer's own "pasting-message" site
    k = b.find(b'"pasting-message"'); near = b[k-30000:k+30000]
    m = re.search(rb'=r\((\w),\{justifyContent:"flex-start",gap:1,children:\[', near); BOX[0] = m[1] if m else None
    m = re.search(rb'=e\((\w),\{dimColor:!0,children:"Pasting\\u2026"\},"pasting-message"\)', near); TEXT[0] = m[1] if m else None
    assert BOX[0] and TEXT[0] and BOX[0] != TEXT[0], f'Box/Text lookup failed: {BOX[0]} {TEXT[0]}'
    sites = []  # (abs offset, old, new)
    for name, rx, repl, count, _ in todo:
        ms = list(re.finditer(rx, b))
        assert len(ms) == count, f'{name}: {len(ms)} match(es), expected {count}'
        for mm in ms:
            sites.append((mm.start(), mm.group(0), repl(mm)))
    t = b.rfind(TRAILER)
    byte_count, mod_off, mod_len = struct.unpack('<QII', b[t-32:t-16])
    G = t - 32 - byte_count
    chunks = {}
    for i in range(mod_len // RS):
        rec = G + mod_off + i * RS
        f = list(struct.unpack('<13I', b[rec:rec+RS]))
        s, e = G + f[2], G + f[2] + f[3]
        mine = [x for x in sites if s <= x[0] < e]
        if mine:
            chunks[i] = (rec, f, s, e, mine)
    assert sum(len(c[4]) for c in chunks.values()) == len(sites), 'a site is outside every chunk'
    for i, (rec, f, s, e, mine) in chunks.items():
        chunk = bytes(b[s:e])
        assert chunk.startswith(b'// @bun @bytecode\n'), chunk[:40]
        for off, old, new in sorted(mine, reverse=True):  # splice by offset: two sites can read the same
            assert chunk[off - s:off - s + len(old)] == old
            chunk = chunk[:off - s] + new + chunk[off - s + len(old):]
        delta = len(chunk) - (e - s)
        hdr_end = chunk.find(b'// Version:')
        comment = chunk[18:hdr_end]
        assert delta < len(comment) - 4, f'chunk {i}: not enough comment bytes to reclaim ({delta} needed)'
        comment2 = comment[:len(comment) - 1 - delta] + b'\n' if delta >= 0 else comment[:-1] + b' ' * -delta + b'\n'
        chunk = chunk[:18] + comment2 + chunk[hdr_end:]
        assert len(chunk) == e - s, (len(chunk), e - s)
        b[s:e] = chunk
        f[6] = f[7] = 0  # drop the bytecode cache for this chunk
        b[rec:rec+RS] = struct.pack('<13I', *f)
        print(f'chunk {i}: {len(mine)} site(s), {delta:+d} bytes taken from the header comment')
    if out == src and not os.path.exists(src + '.orig'):
        shutil.copy2(src, src + '.orig')
    tmp = out + '.new'  # never truncate in place: a running claude has the file mapped
    open(tmp, 'wb').write(b)
    os.chmod(tmp, 0o755)
    subprocess.run(['codesign', '-s', '-', '-f', '--preserve-metadata=entitlements,flags', tmp], check=True)
    os.replace(tmp, out)
    print(f'signed: {out}')

if __name__ == '__main__':
    sys.exit(main())
